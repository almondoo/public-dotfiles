# dotfiles リポジトリ

このリポジトリで作業する際の Claude 向け指示（日本語訳）。

本ファイルは `CLAUDE.md`（英語版）の参照用日本語訳です。
**正本（source of truth）は `CLAUDE.md`** で、本ファイルとの間に齟齬が
あった場合は `CLAUDE.md` を優先してください。

## このリポジトリの性質

macOS 用 dotfiles。`.claude/` 配下は `install.sh` による symlink 経由で
`~/.claude/`（user-level Claude Code 設定）にデプロイされる。

## 重要な指示

- **`.claude/CLAUDE.md` の内容を本リポジトリの作業指示として適用しない。**
  それは user-level の運用ルール（`~/.claude/CLAUDE.md` の実体）であり、
  この repo のメンテナンス指示ではない。
- **`.claude/` 配下を編集する = この端末の全プロジェクトに影響する**。
  ユーザー scope の CLAUDE.md における Tier 2（shared assets の変更）相当の
  慎重さで扱い、必ず差分を確認してから commit する。
- 「CLAUDE.md を編集」と言われたら、どちらを指すか必ず確認する:
  - repo 直下 `CLAUDE.md` → このファイル自体（dotfiles 作業ルール）
  - `.claude/CLAUDE.md` → user-level グローバル指示（全プロジェクトに影響）
- 新たな symlink 対象を追加するときは `install.sh` と `uninstall.sh`
  の両方を更新する。差分を片方だけにすると uninstall で取り残しが出る。
- `CLAUDE-ja.md`（このディレクトリ・`.claude/` 配下ともに）は日本語訳
  参照用で symlink しない。install.sh / uninstall.sh の対象に加えないこと。
- 認証情報・ランタイムデータは絶対 commit しない。`.gitignore` を変更する
  場合は `git status` で除外確認を必ず行ってから add する。

## Git ワークフロー

- commit は `develop` ブランチに対して行い、`main` には直接 commit しない。
  `main` は pull request 経由で更新する。

## 確認系コマンド

- `install.sh` の冪等性確認: `./install.sh` を 2 回実行してもエラーや
  予期せぬ差分が出ないこと
- commit 前確認: `git status` と `git diff --cached --stat` で除外される
  べき項目（`projects/`, `.credentials.json` 等）が含まれていないか目視
