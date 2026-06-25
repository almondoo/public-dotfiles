# agent-teams

## 概要

`agent-teams` は、Claude Code の Agent Teams ランタイム (`TeamCreate` / `TaskCreate` / `SendMessage` / `TaskUpdate` / `TaskList` / `TaskGet` / `TeamDelete`) を用いて、複数役割のエージェントチームで一つの作業 (issue 全体、大型機能、複数 helper の同時追加など) を Wave 単位で進めるための skill です。

単に Implementer だけを並列に並べるとレビュー、セキュリティ確認、テスト検証が抜け落ち品質が下がる、という過去の失敗を踏まえ、Lead / Implementer / Reviewer / Tester (場合により専任の Security Checker) を必ず含めた構成を強制します。さらに「`git add` と `git commit` は Lead が排他的に実行する」「1 タスク = 1 コミット」「Tester は wave 末尾の一括リグレッションのみ」「制御バイト混入の事前検査」といった、過去のインシデントから得たルールを構造的に組み込んでいます。

自動トリガは無効化されており、ユーザが `/agent-teams <タスク内容>` で明示的に起動します。

## いつ使うか

以下のいずれかに当てはまる作業で利用します。

- ひとつの issue を丸ごと処理したい (例: `work through issue 123`)
- 6 タスク前後を 1-2 wave に分けて並列に進めたい中〜大規模機能の実装
- 同形の helper / モジュールを複数同時に追加したい場合
- 認証/認可、課金、PII、外部公開 API、ファイルアップロードなど **セキュリティ重要度が高い** ため Reviewer / Security Checker を必ず通したい場合
- 共有ワークスペースでの `git add` / `git commit` 競合や、レビュー漏れ・テスト漏れを構造的に防ぎたい場合

逆に、単一ファイル・数十行レベルの修正、対話的デバッグ、1 ツールで完結する read-only 調査などには重すぎるため利用しません。

## 仕組み (Wave / 役割 / フロー)

### 役割

| 役割 | 標準ハンドル | 主責務 |
|------|--------------|--------|
| Team Lead (主モデル) | `team-lead` | タスク分割、進行管理、統合、最終判断、**`git add` (path 指定) と `git commit` (amend 禁止) の排他実行** |
| Implementer (1 名以上) | `impl-<area><N>` | 実装、ユニットテスト作成、ローカル検証 (テスト・typecheck・lint) → Lead にコミット代行を依頼 |
| Reviewer | `reviewer-code` | コードレビュー、仕様適合性確認、(兼任時は) セキュリティ確認 |
| Tester | `tester-regression` | wave 末尾でのフルリグレッション 1 回 |
| Security Checker (任意) | `security-checker` | 大規模 or セキュリティ重要タスク時の専任セキュリティレビュー |

スケール判定の目安は「Small: 1-2 ファイル」「Medium: 3-5 ファイル」「Large: 6 ファイル以上」。認証・課金・PII・新規公開 API・外部入力処理などに該当する場合は 1 段階引き上げます。Large またはセキュリティ昇格に該当する場合のみ Security Checker を専任化します。

### Wave 構造

典型は「4 並列 + 2 blocked_by」(計 6 タスク)。タスク名規則は `W<wave>-<D|A|AI|UI><id>` で、`D`=doc/共通、`A`=API/サービス、`AI`=AI/ML、`UI`=コンポーネント等。1 ファイル = 1 owner を厳守し、共有ファイルは 1 名に集約するか Wave をまたいで直列化します。

### フェーズと品質ゲート

- **Phase 0**: `ToolSearch` で deferred tools を 1 回だけロード。失敗時は `Agent` で代替せず停止しユーザに報告。
- **Phase 1 (Plan)**: 引数の解釈、issue 取得、`git log --grep` による重複チェック、Wave 構造の確定、ユーザ承認の取得。検証コマンド (`<TEST_RUNNER_COMMAND>` / `<FULL_TEST_COMMAND>` / `<TYPECHECK_COMMAND>` / `<LINT_COMMAND>` / `<UNIT_TEST_FRAMEWORK>`) を事前に特定し spawn prompt に差し込めるようにする。
- **Phase 2 (Spawn)**: `TeamCreate` → 6 件の `TaskCreate` → `TaskUpdate({ addBlockedBy })` で依存配線 → 必要な teammate (Implementer + Reviewer + Tester + 任意の Security Checker) を **1 メッセージ内で並列 spawn**。Delegate モード (Shift+Tab) の有効化をユーザに案内。
- **Phase 3 (Execute)**: SendMessage によるやりとりで進行。コミット要求 → Lead が `git status` で範囲確認 → `git add <path>` + `git commit` 代行 → Reviewer (+ 専任時は Security Checker) によるレビュー → Critical / Important / High があれば修正サイクル。`MAX_FIX_ITERATIONS = 3` を超えた場合は AskUserQuestion でユーザにエスカレーション。
- **Phase 4 (Disband)**: 全タスク完了・全 Reviewer PASS を確認 → Tester に一度だけフルリグレッションを依頼 → 各 teammate に `shutdown_request` → `TeamDelete` → ユーザにサマリ報告。

## 主な構成要素

### `assets/` (Lead が直接利用するテンプレート群)

- `assets/wave-template.md` — Wave 構成パターン (4+2 標準形)、命名規則、owner 分離戦略、規模別の構成テンプレート。
- `assets/lead-checklist.md` — フェーズ遷移ごとに Lead が確認すべきチェック項目。
- `assets/spawn-prompts/implementer.md` — Implementer の spawn prompt テンプレート。担当ファイル・禁止領域・git 権限・制御バイト注意などを内包。
- `assets/spawn-prompts/reviewer.md` — Reviewer の spawn prompt テンプレート。OWASP Top 10 観点を含む。
- `assets/spawn-prompts/tester.md` — Tester の spawn prompt テンプレート。軽量出力フォーマットを規定。
- `assets/spawn-prompts/security-checker.md` — 専任 Security Checker 用 spawn prompt テンプレート。

### `references/` (詳細リファレンス)

- `references/git-permissions.md` — destructive / non-destructive の全表、Lead 例外の根拠、Implementer のコミット要求ワークフロー。
- `references/implementer-pitfalls.md` — 制御バイト混入 (NULL 等) と検査用 `python3` ワンライナー、`git add -A` 禁止、他人のファイルを「ついでに」編集しない等の落とし穴集。
- `references/tester-optimization.md` — Tester リクエスト集約の根拠、軽量出力、Lead 直接検証 (read-only) のフォールバック、想定時間表。

## 注意点・前提

### 動作前提

- **Claude Code CLI** で実行 (VSCode 拡張では `Task*` 系が無効化されてきた経緯あり)。
- Agent Teams 機能を持つ比較的新しい CLI バージョン。環境によっては `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 等の実験フラグが必要なことがある。
- Step 0 の `ToolSearch` で 7 つの schema がすべて返らない場合は中断し、`Agent` で代替しない。

### Lead が踏み外しやすい点

- **`Agent` ツールでの並列 dispatch を skill 中に行うのは禁止** (Phase 1 の read-only 調査用 `Explore` のみ例外)。 グローバルな「2 つ以上の独立タスクは並列 Agent」ルールはこの skill の間だけ明示的に上書きされる。
- **destructive な git 操作は `git add` (path 指定) と `git commit` (amend なし) のみ** Lead が実行可能。`reset` / `restore` / `push` / `rebase` / `merge` / `amend` / `branch -D` / `clean` / `stash drop|clear` 等は Lead でも禁止。やむを得ない場合は AskUserQuestion でユーザに手動実行を依頼。
- **コードを Lead が直接 Edit / Write しない**。どれだけ小さくても SendMessage で Implementer に依頼。手を入れた瞬間に Reviewer / Tester の品質ゲートが崩れる。
- **タスクをまたいだコミットを 1 つにまとめない**。「1 タスク = 1 コミット」厳守。

### Implementer 側の典型的な落とし穴

- **literal な制御バイト混入** (特に NULL `\x00`): Edit / Write 経由で `\x00` がそのまま 0x00 1 バイトとして埋め込まれ、git がバイナリ判定 → PR diff が見えない / grep に当たらない、という事故が複数回発生。常に 4 文字のエスケープシーケンス (`\`, `x`, `0`, `0`) として書き、コミット要求前に `python3` で `< 32` の非 TAB/LF/CR バイトが 0 件であることを検査する。
- `git add -A` / `git add .` / `git add -u` 禁止。常に path を明示。
- 他人の担当ファイルを「ついでに」修正しない。気付いたら Lead に SendMessage で報告。
- NaN / Infinity / 負値はサイレントフォールバックせず `throw` で fail-closed。
- ms / bytes / % / deg / rad など単位を JSDoc に明記。
- raw 入力 / secret / orgKey / userId などをエラーメッセージやログに含めない。

### Tester 関連の前提

- **コミット毎の検証依頼は禁止**。Implementer の self-verification + Reviewer PASS で per-commit の品質は確立されており、Tester に毎回投げるとコンテキスト圧迫で wave 後半に応答が止まる実例が複数ある。
- Tester への依頼は **wave 末尾のフルリグレッション 1 回のみ**。出力は PASS なら 3-5 行、FAIL なら blocker 詳細という軽量フォーマットを spawn prompt で指定する。
- 想定時間の 3 倍 (例: 1-2 分作業に対し 6 分) を超えても応答がなければ、Lead が read-only な `<FULL_TEST_COMMAND>` / `<TYPECHECK_COMMAND>` / `<LINT_COMMAND>` を直接実行するフォールバックに切り替える。これは品質ゲートのバイパスではない。

### Implementer / Reviewer 無応答時

無応答 Implementer の残タスクは代替 teammate (`impl-<area><N>-r`) を spawn して引き継ぐ。Lead が代わりに編集してはならない (品質ゲート崩壊)。Reviewer / Security Checker も同様に交代 spawn し、未レビュー commit ハッシュ一覧を spawn prompt に渡してコンテキストを再構築する。

### `TeamDelete` の前提

`TeamDelete` は teammate が 1 人でも active だと失敗する。各 teammate からの `shutdown_response` (approve) または `teammate_terminated` 通知をすべて確認してから呼び出す。

## 関連

- [SKILL.md](./SKILL.md) — 英語原本 (skill 本体、Claude Code がロードする source of truth)
- [assets/wave-template.md](./assets/wave-template.md) — Wave 構成テンプレート
- [assets/lead-checklist.md](./assets/lead-checklist.md) — Lead 用フェーズ別チェックリスト
- [assets/spawn-prompts/](./assets/spawn-prompts/) — 各役割の spawn prompt テンプレート (`implementer.md` / `reviewer.md` / `tester.md` / `security-checker.md`)
- [references/git-permissions.md](./references/git-permissions.md) — git 権限の詳細表と Implementer ワークフロー
- [references/implementer-pitfalls.md](./references/implementer-pitfalls.md) — 制御バイト等の落とし穴集
- [references/tester-optimization.md](./references/tester-optimization.md) — Tester 集約と Lead 直接検証フォールバック

このファイルは人間 (日本語話者) が `agent-teams` skill の概要を把握するための参照ガイドであり、Claude Code が自動ロードする skill 本体ではありません。実行ルールの正本は `SKILL.md` および `references/` / `assets/` 配下です。
