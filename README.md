# public-dotfiles

個人の開発環境設定を git 管理するための public リポジトリ。
現時点では Claude Code の設定（`~/.claude/`）のみを対象としている。

## 仕組み

実体は `~/public-dotfiles/.claude/` に置き、`~/.claude/` 配下の各エントリは
そこへの symlink にする。Claude Code は従来通り `~/.claude/` 経由で
透過的に設定を読む。

`~/.claude/` ディレクトリ自体は symlink にしない。Claude Code が
セッション履歴や認証情報などのランタイムデータを書き込むため、
ディレクトリは実体として残し、git 管理対象のみ個別に symlink 化する。

## セットアップ

新しい環境でこのリポジトリを使う場合:

```bash
git clone git@github.com:<user>/public-dotfiles.git ~/public-dotfiles
cd ~/public-dotfiles
./install.sh
```

`install.sh` は冪等。既存の実ファイルは `*.bak` にバックアップしてから
symlink に置き換える。既存の symlink は張り直す。

## 管理対象

`~/public-dotfiles/.claude/` に置く実体:

- `CLAUDE.md` — ユーザー scope のグローバル指示
- `agents/` — ユーザー scope のサブエージェント定義
- `commands/` — ユーザー scope のカスタムスラッシュコマンド定義
- `skills/` — ユーザー scope のスキル
- `workflows/` — ユーザー scope のワークフロー定義（`Workflow` ツール用スクリプト）
- `hooks/` — ユーザー scope の hook スクリプト（`settings.json` の hooks 設定から参照）
- `settings.json` — Claude Code の設定
- `statusline-command.sh` — ステータスライン表示用シェルスクリプト
- `statusline.py` — ステータスライン表示用 Python スクリプト

### git 管理のみ（symlink は張らない）

- `CLAUDE-ja.md` — `CLAUDE.md` の日本語訳参照用。Claude Code は読まないため `~/.claude/` には配置しない。

## 管理対象外（`.gitignore` で除外）

以下は実体のまま `~/.claude/` に残し、git には含めない:

- セッション履歴 / プロジェクトデータ: `projects/`, `sessions/`, `session-env/`, `todos/`, `tasks/`, `history/`, `shell-snapshots/`, `file-history/`, `paste-cache/`
- キャッシュ / 統計: `cache/`, `telemetry/`, `usage-data/`, `statsig/`, `stats-cache.json`, `mcp-needs-auth-cache.json`, `*.jsonl`
- 認証情報 / ローカル設定: `.credentials.json`, `settings.local.json`
- プラグイン: `plugins/`（自動更新と干渉するため除外）
- その他: `backups/`, `debug/`, `downloads/`, `ide/`, `chrome/`, `teams/`, `plans/`, `__store.db`, `security_warnings_state_*.json`, `.last-cleanup`, `.last-release-notes-seen-version`

このほか、リポジトリ作業用の一時ファイル（`tmp/`, `__pycache__/`, OS・エディタ固有ファイルなど）も `.gitignore` で除外している。

## アンインストール

```bash
./uninstall.sh
```

symlink のみ削除する。実体は `~/public-dotfiles/.claude/` に残るので、
`install.sh` を再実行すれば復元できる。

## 注意

- **認証情報を絶対に commit しない**。`.gitignore` を更新する場合は
  `git status` で除外されているかを必ず確認してから add する。
- `~/.claude/settings.json` は MCP サーバ設定など環境固有の値を含む
  可能性がある。共有前に内容を目視確認すること。

## 将来拡張

`.zshrc`, `.gitconfig` などを追加する場合の想定:

```
~/public-dotfiles/
├── .claude/
├── zsh/
│   └── .zshrc
├── git/
│   └── .gitconfig
└── install.sh   ← 各カテゴリの link 呼び出しを追記
```

`install.sh` の `link` 関数を再利用して `link` 呼び出しを追記する形を取る。
