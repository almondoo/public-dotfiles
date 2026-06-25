# Skill 選択チート（最適化版）

タスクから**どの skill / コマンドを使うか**を即決するための、選択に最適化した最小チート。
CLAUDE.md から必要時に lazy load される入口。包括的な早見表・規模感・各スキル解説は
[`skill-selection-guide.md`](skill-selection-guide.md) を参照。

> **スキルは強制ではなく提案**（`using-superpowers`: User instructions > Skills）。
> 規模で省くのは「使う skill の本数」であって個々の規律ではない。

---

## 判定フロー（decision tree）

タスクが来たら、種別を上から判定する。

```
■ バグ / テスト失敗 / 想定外の挙動を直す
    → systematic-debugging（まず根本原因。小バグでも数十秒の確認、当て推量 fix は禁止）
    → test-driven-development（失敗する回帰テストを先に）
    → 修正 → /code-review（任意）→ verification-before-completion

■ 新機能を作る
    ├ 設計〜実装を一気に並列で回したい
    │   → feature-dev（ハーネス。既定は分析のみ / {build: true} で実装まで）
    └ 対話しながら段階を踏みたい
        → brainstorming（設計は数文でも可）
        → writing-plans（multi-step のときだけ）
        → test-driven-development
        → subagent-driven-development / executing-plans
        → requesting-code-review → finishing-a-development-branch

■ 既存コードを整理する（挙動は変えない / リファクタ）
    → test-driven-development（挙動をテストで固定）
    → /simplify（品質改善のみ。バグ探索はしない）

■ コードが正しいか確認する
    ├ 実際に動くか（実アプリ）        → /verify（必要なら /run）
    ├ バグ・欠陥・脆弱性がないか        → /code-review（PR 全体は /review・pr-review-toolkit:review-pr）
    ├ テストの合否を証拠で            → test-verifier（agent）
    └ セキュリティ専用              → /security-review

■ 「完了 / 直った」と言う直前
    → verification-before-completion（テスト・ビルドを実走させ、出力＝証拠で確認）

■ コミット / PR を作る
    → commit-commands:commit / commit-push-pr

■ そもそもどの skill を使うべきか分からない
    → skill-selection-guide.md の早見表を見る / using-superpowers で探す
```

---

## 競合境界 — 紛らわしい skill の使い分け

description ベースの自動選択では解消されにくい「同じような入力で複数候補が出る」組み合わせ。

| 迷う組み合わせ | 使い分け |
|---|---|
| `/code-review` vs `/simplify` | バグ・correctness を探す → **`/code-review`**。品質改善のみ（バグは探さない）→ **`/simplify`** |
| `feature-dev`（harness）vs `feature-dev:feature-dev`（command） | 一気に並列で設計〜実装 → **harness**。対話ガイドで段階的 → **plugin command** |
| `feature-dev` vs `superpowers` | 機能を一気に設計〜実装 → **feature-dev**。種別問わず計画→実装→レビューを段階的に → **superpowers フロー** |
| `brainstorming` vs いきなり実装 | あらゆる creative work の前に **brainstorming**（設計は数文でも）。ただし**ユーザー指示が最優先** |
| `writing-plans` の要否 | multi-step → **plan を書く**。1 ステップ修正 → **不要**（プラン系はスキップ） |
| `/verify` vs `test-verifier` | 実アプリを起動して挙動確認 → **`/verify`**。テスト実行と懐疑的検証 → **`test-verifier`** |
| `/code-review` vs `requesting-code-review` | 手軽に diff をレビュー → **`/code-review`**。major feature / merge 前の正式レビュー依頼 → **`requesting-code-review`** |
| `systematic-debugging` vs すぐ修正 | 小バグでも root cause を先に（数十秒）。当て推量の fix は禁止 |
| `/code-review` vs `/security-review` | 一般的なバグ・品質 → **`/code-review`**。脆弱性特化 → **`/security-review`** |
| `Explore` / `repo-explorer` vs いきなり編集 | 複数ファイル横断の調査・構造把握が要る → **探索 agent に委譲**。1 ファイルの自明な編集 → 直接 |

---

## 規模で省くもの・省かないもの

- **省くのは「使う skill の本数」**。小タスクほどチェーンを短くする（プラン系を落とす等）。
- **省かないのは個々の規律**。Rigid skill（`systematic-debugging` / `test-driven-development` / `verification-before-completion`）は規模を問わず適用（ただし軽量に）。
- スケールさせるのは「プロセスの省略」ではなく「成果物（設計書など）の長さ」。詳細な根拠は `skill-selection-guide.md`。
