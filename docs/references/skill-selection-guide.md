# スキル使い分けガイド

タスク種別ごとに、どの skill / コマンドを使うべきかをまとめた早見ガイド。
「新機能を作るならどれ」「バグを直すならどれ」「正しさを確認するならどれ」を
一覧で引けるようにしている。

> [!NOTE]
> **大前提: スキルは強制ではなく提案。** superpowers の `using-superpowers` 自身が
> 優先順位を `User instructions > Skills > 既定挙動` と明記している。
> 「この小タスクに全工程は過剰」と判断するのはユーザーの正当な裁量。
> このガイドは「迷ったときの既定の選択肢」であって、義務ではない。

---

## 1. タスク種別 → 推奨スキル 早見表

| やりたいこと | まず使う | 補助 |
|---|---|---|
| **新機能を作る（一気に設計→実装）** | `feature-dev`（並列ハーネス） | — |
| **新機能を作る（対話しながら段階的に）** | `superpowers:brainstorming` → `writing-plans` → `test-driven-development` | `subagent-driven-development` / `executing-plans` |
| **バグを直す** | `superpowers:systematic-debugging` | `test-driven-development`（回帰テスト）→ `/code-review` |
| **小さな修正（1〜数ステップ）** | `systematic-debugging`（軽量）＋ `test-driven-development` | `verification-before-completion` |
| **リファクタリング** | `test-driven-development`（挙動を固定）→ `/simplify` | `requesting-code-review` |
| **動くか確認したい（実アプリ）** | `/verify` | `/run` |
| **バグ・欠陥がないか確認したい** | `/code-review` | `pr-review-toolkit:review-pr` |
| **テストの合否を証拠で確認したい** | `test-verifier`（agent） | `verification-before-completion` |
| **「完了」と言う前の最終ゲート** | `superpowers:verification-before-completion` | — |
| **レビュー指摘を受けて直す** | `superpowers:receiving-code-review` | — |
| **コミット / PR を作る** | `commit-commands:commit` / `commit-push-pr` | `superpowers:finishing-a-development-branch` |
| **セキュリティ観点で確認** | `/security-review` | — |

---

## 2. 開発ライフサイクル別フロー

「どのスキルを連ねるか」を規模で調整する。スキルそのものを省略するのではなく、
**使うスキルの本数を規模に合わせる**のが基本方針（→ §3）。

### 新機能（大きめ）
```
brainstorming → writing-plans → test-driven-development
  → subagent-driven-development / executing-plans
  → requesting-code-review → verification-before-completion
  → finishing-a-development-branch
```
あるいは、設計から実装・レビューまで**一気に並列で**回したいなら
`feature-dev` ハーネス1本（デフォルトは分析のみ。`{request, build: true}` で実装まで）。

### バグ対応
```
systematic-debugging（根本原因の特定が先）
  → test-driven-development（まず失敗する回帰テスト）
  → 修正 → verification-before-completion（証拠で確認）
  → 必要なら /code-review
```

### 小さな修正（1ステップ〜）
```
systematic-debugging（思考だけ・数十秒）
  → test-driven-development → verification-before-completion
```
`writing-plans` / `executing-plans` / `subagent-driven-development` は
**プラン前提なので適用外**（1ステップ修正にプランは要らない）。

### リファクタリング
```
test-driven-development（既存挙動をテストで固定）
  → /simplify（品質改善・バグ探索はしない）
  → requesting-code-review（任意・ベースライン確認）
```

---

## 3. superpowers の「規模感」ルール（調査根拠付き）

各 SKILL.md 本文を読んで確認した設計思想。

1. **「小さいから」を理由にしたスキップは Rigid スキルでは明示的に禁止。**
   - systematic-debugging: `Use for ANY technical issue` / `Don't skip when: Issue seems simple`
   - test-driven-development: `Thinking 'skip TDD just this once'? Stop. That's rationalization.`
   - verification-before-completion: `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`

2. **スケールさせるのは「プロセスの省略」ではなく「成果物の長さ」。**
   - brainstorming: `The design can be short (a few sentences for truly simple projects)`
   - → ステップは踏むが、出力（設計書など）は数文に縮めてよい。

3. **Rigid と Flexible の二分類がある。**

   | 分類 | スキル | 扱い |
   |---|---|---|
   | **Rigid**（厳格・省略不可） | `systematic-debugging` / `test-driven-development` / `verification-before-completion` / `receiving-code-review` | 規模を問わず適用（ただし軽量に） |
   | **Flexible**（出力を縮小可） | `brainstorming` / `writing-plans` | 短縮版で可 |
   | **プラン前提（自然に下限あり）** | `writing-plans` / `executing-plans` / `subagent-driven-development` | 1ステップ修正には適用外 |

4. **「小バグでも systematic-debugging を使うべきか」→ 本文上は Yes、無条件。**
   ただし「重い儀式」ではなく**数十秒の思考規律**を意図している
   （`Process is fast for simple bugs.`）。当て推量の fix を書く前に根本原因を1分確認しろ、という意味。

---

## 4. 「正しさの確認」の使い分け

「コードが正しいか」は **動作の検証** と **欠陥のレビュー** の2系統に分かれる。

| 確認したいこと | 使うもの | 性質 |
|---|---|---|
| 仕様通り**実際に動くか**（実アプリ） | `/verify` | アプリを起動して挙動を観察 |
| アプリ起動・スクショ | `/run` | 実行のみ |
| **バグ・論理エラー・脆弱性** | `/code-review` | diff を correctness 中心にレビュー（`--fix` で修正適用、`--comment` で PR コメント化、effort: low〜max / ultra） |
| **品質改善のみ**（バグは探さない） | `/simplify` | reuse / 簡潔化 / 効率 / 抽象度 |
| **テストの合否を証拠で** | `test-verifier`（agent） | 出力を読まずに passing と言わない懐疑的検証 |
| **完了宣言の前の最終ゲート** | `superpowers:verification-before-completion` | テスト/ビルドを実走させ証拠を確認 |
| **GitHub PR 全体のレビュー** | `/review` / `pr-review-toolkit:review-pr` / `code-review:code-review` | PR 単位 |
| **セキュリティ専用** | `/security-review` | ブランチの変更を脆弱性観点で |

**一番シンプルな指針**: 「このコード正しい？」を一発で見るなら `/code-review`（静的に欠陥を洗う）。
「本当に動くか」まで含めるなら `/verify` を足す。

---

## 5. 補助スキル早見（開発以外）

| 目的 | スキル |
|---|---|
| 調査・リサーチ（多源・事実確認） | `deep-research` / `deep-research-tiered` |
| コードベースの構造把握 | `Explore` / `repo-explorer`（agent） |
| 2つ以上の独立タスクを並列実行 | `superpowers:dispatching-parallel-agents` |
| 隔離した作業環境（worktree） | `superpowers:using-git-worktrees` |
| CLAUDE.md の整備・改善 | `claude-md-management:revise-claude-md` / `claude-md-improver` |
| 新しい skill を作る・改善する | `skill-creator` / `superpowers:writing-skills` |
| コーディング規約 / ルール生成 | `sync-rules` |
| Claude Code 設定（permissions/env/hooks） | `update-config` |
| 権限プロンプトを減らす | `fewer-permission-prompts` |
| キーバインド変更 | `keybindings-help` |
| Claude Code 自動化の提案 | `claude-code-setup:claude-automation-recommender` |
| UI のビジュアルデザイン指針 | `frontend-design` |
| 定期実行 / スケジュール | `loop` / `schedule` |
| Claude API / SDK のリファレンス | `claude-api` |

---

## 6. feature-dev の2系統（混同注意）

同名で2つある。

- **`feature-dev`（トップレベル Skill / 並列ハーネス）**: 1回の起動で
  「並列コードベース探索 → 要件質問 → アーキ設計3案 + judge → (opt-in) 自律実装 + 敵対的レビュー」。
  デフォルトは**分析のみ**。`{request, build: true}` で実装まで。**機能開発を一気にやる**用途。
- **`feature-dev:feature-dev`（プラグインのコマンド）**: コードベース理解とアーキ設計に
  フォーカスした**ガイド付き**の機能開発フロー。段階的・対話的。
- 同梱の補助エージェント: `feature-dev:code-explorer`（既存実装の深掘り）/
  `feature-dev:code-architect`（実装ブループリント設計）/ `feature-dev:code-reviewer`（レビュー）。

**使い分け**: 設計から実装まで一気に並列で → ハーネスの `feature-dev`。
対話しながらガイドに沿って → `feature-dev:feature-dev`。
新機能・バグ・小修正を一貫した型（計画→実装→レビュー）で回したい → §2 の superpowers フロー。

---

> 判定フロー（decision tree）と競合境界の使い分けは、選択に最適化した
> [`skill-select.md`](skill-select.md) に分離した。タスク開始時の即決はそちらを参照。
