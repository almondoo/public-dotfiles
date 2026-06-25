# parallel-audit

## 概要

`parallel-audit` は、`CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` / `GEMINI.md` / `SKILL.md` といった長尺の agent 向け指示ファイルを、複数の auditor subagent で**並列に独立監査**し、その結果を集約することで「修飾語の欠落」「セクション間の用語ドリフト」「暗黙の前提」「断片的な列挙」「セクション間の論理矛盾」といった、単発の監査では検出しきれない欠陥を高い再現性で抽出する skill です。

中心となるアイデアは、`N` 個の auditor を独立に走らせて `threshold` 個以上が同じ欠陥を指摘した場合のみ「再現性のある defect」として残し、それ以下の指摘はノイズとして捨てる、というシンプルな convergence ベースの偽陽性抑制です。デフォルトは `N=3 / threshold=2 / max_iterations=3`(`2 of 3` で convergence)で、必要に応じて `5/3`、`9/4` の深い構成を opt-in できます。最終的に false-positive filter、redundancy 分類、fix safety check、ユーザ承認、適用、再監査までを 1 本のパイプラインで実行します。

## いつ使うか

このskillは**イベント駆動型の診断ツール**であり、定期的な maintenance 用途には不向きです。次のような明確な trigger 条件があるときに使ってください。

- 大規模な refactor の直後(複数のルールを追加・再編した直後で、未検出の cross-section 矛盾が混入しやすいタイミング)
- 特定のルールが無視 / 誤適用されているように見えるとき(該当 section + 近傍を focused に監査)
- agent の挙動 drift を観測したとき(指示ファイルが原因かどうかの切り分け)
- Claude のモデル upgrade 直後(以前のモデルでは通っていた文言が新モデルでは別解釈される可能性がある)
- session learnings がある程度蓄積した直後(例えば `revise-claude-md` 経由の段階的追記による cross-section 矛盾の検査)
- plugin として配布する前の SKILL.md の最終チェック(pre-shipping)

逆に、次の用途には**使わない**でください:新規の CLAUDE.md 作成(`init` / `claude-md-improver`)、session learnings の反映(`revise-claude-md`)、テンプレートベースの gap 分析(`claude-md-improver`)、新規 SKILL.md 作成(`skill-creator`)、ソースコードや非 markdown 設定ファイルの監査。

## 仕組み (パイプライン)

ワークフローは **Pre-check → Setup → Detect → Triage → Fix → Apply → Verify** の 7 グループ・12 フェーズ構成です。要点のみを示します。

- **Phase 1: 症状ヒアリング (symptom interview)** — `references/symptom-interview-protocol.md` に従い、`AskUserQuestion` で何が引き金かを確定する(post-refactor / 特定ルール無視 / behavior drift / pre-shipping / model upgrade / routine)。`routine` を選んだ場合は警告を出し、明示的な続行確認を求める。
- **Phase 1.5: scope 絞り込み** — 症状に応じて、全ファイル / セクション単位 / ルール+近傍 のいずれかに絞る。非全文 scope では 1 instance あたり token 量を 1/3〜1/5 まで圧縮できる。
- **Phase 2: 入力と exclusion 収集** — target file、`target_type` 自動判定の確認、`N / threshold / max_iterations` の妥当性検証(範囲外は最大 3 回まで再要求)、exclusion list の merge(target-specifics + shared-blind-spots のデフォルトをプリロード)、`ab_testing_enabled` の opt-in、`model_string` の override 受付。
- **Phase 2.5: SKILL.md 限定の static pre-check** — `target_type == "skill-md"` かつ外部依存の `skill-eval` が利用可能な場合のみ `static_check.py` を走らせて構造軸を事前にクリアする。`skill-eval` が見つからない場合は警告 1 行のみ出して skip。
- **Phase 3: section purposes ベースライン** — 全 H2 / 主要 H3 ごとに 1 行の意図サマリを作り、`AskUserQuestion` で一括確認。Phase 9 の意図保全判定がこの baseline を使う(自己参照になるのを避ける)。
- **Phase 4: 並列 auditor 投入** — `agents/auditor.md` の全文を prompt にして `N` 個の subagent を**同一の tool-call message** で `run_in_background: true` で投入。prompt は placeholder 置換以外 byte-identical を保つ。デフォルトモデルは `sonnet` 固定で、これは parent モデル継承を明示的に override する唯一の Phase。返ってこないインスタンスがある場合は `working_threshold` を再計算し、`N_received < 2` なら abort。
- **Phase 5: 集約** — Per-instance HIGH count(Table A)と Convergent issues(Table B)の 2 表を作る。`threshold` 未満は記録のみで fix にはしない。main thread が独断で subagent の判定を softening するのは禁止(集約 drift hedge)。
- **Phase 6: triage** — convergent issue を fix 候補 / acceptable / below threshold に分類。fix 候補が 0 なら以降の Phase は一気に Phase 12 までスキップ。
- **Phase 6.5: false-positive filter** — `agents/false-positive-detector.md` で fix 候補を真偽判定。`known_fp_patterns`(target-specifics + shared-blind-spots の union)も渡す。`FALSE` は破棄、`NEEDS_HUMAN` は Phase 10 でユーザ提示。
- **Phase 7: redundancy 分類** — `agents/redundancy-checker.md` で各 fix 候補が upstream authority(Claude Code defaults / sibling skills)で既にカバー済みかを判定し、`KEEP / SIMPLIFY / REMOVE` を返す。
- **Phase 8: fix 起案** — 分類に応じて wording 微調整 / 圧縮 / 削除案を作成。差分が大きい場合や構造変更を伴う場合は 2〜3 案を提示する multi-option mode、3 行以下の wording 修正のみなら single-proposal mode。
- **Phase 9: fix safety check** — `agents/fix-safety-checker.md` を fix(または option)ごとに 1 個ずつ並列投入し、references 破壊や intent 歪曲がないかを判定。`UNSAFE` は 1 度だけ再起案、それでも `UNSAFE` ならユーザ判断にエスカレ。
- **Phase 10: ユーザ承認** — fix ごとに `AskUserQuestion` で個別承認(batch しない)。multi-option mode では trade-off ラベル付きで A/B/C を提示。中断・修正取りやめにも対応。
- **Phase 11: Edit による適用** — fix 同士の line range 衝突(直接 overlap + 行ずれ伝播)を事前検出し、ボトムアップ順で適用、適用後は影響範囲を re-Read して残 fix の `before` が依然一致するかを再検証。`CLAUDE.md` 系や installed `skill-md` は auto-mode classifier がブロックすることが既知なので、Edit より前に authorization を事前取得する。
- **Phase 11.5: 適用後検証** — (a) 反復が残っていれば fresh exclusion list で再監査、(b) `ab_testing_enabled == true` かつ `skill-eval` 利用可能なら A/B benchmark、(c) SKILL.md なら static check を再実行。
- **Phase 12: 停止条件評価** — 全 instance が clean / 実用 convergence(`N − threshold + 1` 以上の instance が clean)/ HIGH avg のプラトー / `max_iterations` 到達 / 0 fix 候補 のいずれかで停止し、Phase 5 各イテレーション表を含む最終 report を出力。

最終的な提案は「広く検出して `threshold` で絞り、redundancy 分類で誇大な refine を抑制し、safety check で破壊的変更を弾いた」**targeted fix の列**として user に提示されます。

## サブエージェント一覧 (`agents/`)

- `auditor.md` — 7 axes 沿いに HIGH 重要度の defect だけを独立に列挙する並列 auditor(Phase 4 で `N` 個投入される本体)。
- `false-positive-detector.md` — convergent issue が複数 auditor の共通 blind spot による偽陽性かを fresh read で再判定する(Phase 6.5)。
- `fix-safety-checker.md` — 提案された fix が cross-reference を壊さず、他ルールと矛盾せず、intent を歪めないかを検証する(Phase 9)。
- `redundancy-checker.md` — fix 対象ルールが upstream authority に既に存在するかを判定し、`KEEP / SIMPLIFY / REMOVE` を出力する(Phase 7)。

## `references/` 構成

- `ab-testing.md` — Phase 11.5(b) のオプション機能 `skill-eval` A/B benchmark のコスト見積もりと有効化条件をまとめた参考資料。
- `claude-md-specifics.md` — `target_type == "claude-md"` 用の exclusion デフォルト、共有 blind spot パターン、Phase 11 の auto-mode classifier 対応 playbook。
- `skill-md-specifics.md` — `target_type == "skill-md"` 用の exclusion、`skill-eval` 連携、Phase 11 におけるマーケットプレース / インストール済みの location 別挙動。
- `pitfalls.md` — workflow / 集約 / fix 起案 / target 固有の典型的なつまずきポイント集(挙動が想定と違うときに参照する)。
- `shared-blind-spots.md` — target type を問わず共有される exclusion と既知の false-positive パターン(`(N − threshold + 1)` 由来の「rationale 欠落」など)。
- `symptom-interview-protocol.md` — Phase 1 で `AskUserQuestion` を組み立てるためのプロトコルと、routine 起動時の警告文テンプレ。

## `evals/`

- `evals.json` — このskillの triggering と挙動に関する自己評価データセット(should-trigger / should-not-trigger 各ケース)。本 README ではその中身までは扱わず、存在のみを示す。

## 注意点・前提

- **shared blind spot を避ける役割分担**:`auditor` は最大限独立に flag し、`false-positive-detector` が事後に偽陽性を弾く 2 段構成。`known_fp_patterns` には target-specifics と shared-blind-spots の union が常に渡る。
- **threshold は集合のサイズと連動する**:デフォルトの `2 of 3` はおよそ 67%、`3 of 5` は 60%、`4 of 9` は 44% に相当する。深い tier ほど絶対数の corroborator は増えるが%基準は緩むことに注意。`threshold == N` は instance 1 個でも practical-convergence を満たしてしまうため拒否される。
- **routine 利用は anti-pattern**:7 axes は十分汎用なので何かしらは必ず flag され、漸近線に達する。Phase 1 が routine を選んだ場合は明示的な警告を出すため、症状なしでの定期実行は控える。
- **symptom interview を飛ばさない**:症状の確定は scope 絞り込み、exclusion のプリロード、A/B 判定すべての起点。スキップすると毎回同じ noise を見続けることになる。
- **コストは tier × iteration × parent モデルで急増する**:Quick(3/2) の Phase 4 で約 150k tokens、Deep(9/4) で約 440k tokens。Phase 6.5 / 7 / 9 は parent モデルを継承するため、Opus 配下では検証 overhead が Sonnet 比 1.5〜2 倍になる。defect-rich なファイルかつ multi-option mode では Phase 9 だけで 300〜750k tokens 領域に達することがある。
- **既知の限界**:in-session での triggering recall は未測定(明示起動を推奨)、should-trigger 評価は trace review であり end-to-end 実行検証ではない、外部 target の運用サンプルは少ない。詳細は `SKILL.md` の "Known limitations" を参照。

## 関連

- 英語の原本: [`SKILL.md`](./SKILL.md)
- subagent 定義: [`agents/`](./agents/)
- 参考資料: [`references/`](./references/)
- 自己評価データ: [`evals/`](./evals/)
- 日本語の代替読み物: 本ファイル(`README.md`)。詳細仕様は常に `SKILL.md` 側が source of truth。
