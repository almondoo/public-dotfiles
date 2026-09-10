# public-dotfiles

個人の開発環境設定を git 管理するための public リポジトリ。
Claude Code の設定（`~/.claude/`）と zsh の設定（`~/.zshrc`）を対象としている。

## 仕組み

実体は `~/public-dotfiles/claude/` に置き、`~/.claude/` 配下の各エントリは
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

## 前提条件

- macOS（Apple Silicon）。`.zshrc` の Homebrew パスは `/opt/homebrew` 固定。
- [oh-my-zsh](https://ohmyz.sh/) と、カスタムプラグイン `zsh-autosuggestions`
  （`git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions`）。
- `jq` — hooks（`inject-subagent-model.sh` / `guide-destructive-rm.sh`）が使用する。
  未インストールでも起動は妨げないが、両 hook が黙って無効化される。
- `python3` — ステータスライン（`statusline.py`、標準ライブラリのみ）が使用する。
- `.zshrc` は uv（`~/.local/bin/env`）、goenv、nodebrew、pnpm、Docker CLI 補完のパス設定を含む。
  未インストールでもシェル起動時に警告が出るだけで動作はする。
- `browser-qa` エージェントを使う場合は、Claude in Chrome 拡張を別途インストールする必要がある。

## 管理対象

`~/public-dotfiles/claude/` に置く実体:

- `CLAUDE.md` — ユーザー scope のグローバル指示
- `agents/` — ユーザー scope のサブエージェント定義
- `commands/` — ユーザー scope のカスタムスラッシュコマンド定義
- `skills/` — ユーザー scope のスキル
- `workflows/` — ユーザー scope のワークフロー定義（`Workflow` ツール用スクリプト）
- `hooks/` — ユーザー scope の hook スクリプト（`settings.json` の hooks 設定から参照）
- `output-styles/` — ユーザー scope の output style 定義
- `settings.json` — Claude Code の設定
- `statusline.py` — ステータスライン表示用 Python スクリプト

### シェル（リポジトリ直下に置く実体）

- `.zshrc` — `~/.zshrc` へ symlink する。`claude()` ラッパーは
  `~/public-dotfiles/claude/claude-main-extra.md` を固定パスで参照するため、
  別の場所に clone した場合はこの行を書き換えること。
- `.zshrc.local.example` — マシン固有の秘密情報のテンプレート。初回の `install.sh` で
  `~/.zshrc.local` にコピーされ（パーミッション 600）、既存のファイルは上書きしない。
  `~/.zshrc.local` 自体は git 管理しない。

### git 管理のみ（symlink は張らない）

- `claude-main-extra.md` — メインセッション専用の運用ルール。symlink せず、`.zshrc` の `claude()` ラッパーが起動時に `--append-system-prompt-file` で注入する。

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

symlink のみ削除する。実体は `~/public-dotfiles/claude/` に残るので、
`install.sh` を再実行すれば復元できる。

## 注意

- **認証情報を絶対に commit しない**。`.gitignore` を更新する場合は
  `git status` で除外されているかを必ず確認してから add する。
- `~/.claude/settings.json` は MCP サーバ設定など環境固有の値を含む
  可能性がある。共有前に内容を目視確認すること。

## settings.json と本文の対応について

`settings.json` は公開用に簡略化している（`gh` 関連の permissions や個人環境固有の
設定は含めていない）。また `CLAUDE.md` / `claude-main-extra.md` の本文には、
この repo に含めていないスキル（例: `workflow-model-selection`）や設定への言及が
残っている箇所がある。
