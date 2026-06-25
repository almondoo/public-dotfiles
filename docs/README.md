# docs/

このディレクトリは2種類のファイルを持つ。**config から参照される load-bearing なもの**と、
**単独ドキュメント（どこからも参照されない読み物）**を、サブディレクトリで分離している。

## 構成

| 場所 | 種別 | 説明 |
|---|---|---|
| `references/` | **load-bearing** | `.claude/CLAUDE.md` や skill から**参照され、必要時に読み込まれる**ファイル。挙動に影響するので編集は慎重に（Tier 2 相当）。 |
| `learnings/` | **load-bearing** | skill が追記する学習ログ（例: `parallel-audit` skill が `learnings/parallel-audit.md` を参照）。 |
| `notes/` | **standalone** | 設計メモ・write-up など、config から参照されない読み物。自由に追加・編集してよい。 |

## 現在の参照関係（load-bearing）

- `references/skill-select.md` ← `.claude/CLAUDE.md`（skill 選択チート、lazy 読込）
- `references/skill-selection-guide.md` ← `.claude/CLAUDE.md` ＋ `references/skill-select.md`（深いリファレンス）
- `learnings/parallel-audit.md` ← `.claude/skills/parallel-audit/SKILL.md`（追記先）

## ルール

- **config（CLAUDE.md / skill）から参照させるファイルは `references/`（または用途別に `learnings/` 等）に置く。**
  直下には置かない —「どれが load-bearing か」を場所で示すため。
- **参照ファイルを移動・改名したら、参照元（`.claude/CLAUDE.md` 等）のパスも必ず更新する。**
- 単独の読み物は `notes/` に置く。**`docs/` 直下にはコンテンツを置かない**（この README だけはディレクトリの index として例外的に直下に残す）。
