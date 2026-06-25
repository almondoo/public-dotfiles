# configure-github-permissions

## 概要

`gh` (GitHub CLI、`gh api` を含む) および `git` コマンドの permission を、プロジェクトローカルの `.claude/settings.local.json` に対話的に追加するための skill です。あらかじめ定義された 17 カテゴリそれぞれに対して、`allow` / `ask` / `deny` のいずれかを `AskUserQuestion` で選択させ、その結果を `permissions.{allow,ask,deny}` にマージします。

主な目的は二つあります。一つは、毎回パーミッションプロンプトを出されることによる「プロンプト疲れ」の軽減です。`gh pr view` や `git status` のような純粋な read 系まで毎回確認させる必要はありません。もう一つは、`gh pr merge` / `gh release create` / `git push` / `git reset --hard` のような destructive で取り消しの効かないコマンドを、プロジェクトレベルで明示的に `deny` に固定し、誤実行を遮断することです。書き込み先はあえて gitignore 対象である `.claude/settings.local.json` に限定しており、チーム共有用の `.claude/settings.json` やユーザグローバルの `~/.claude/settings.json` は触りません。

## いつ使うか

- 新しいプロジェクトで `gh` / `git` のパーミッション設定を一気に整えたい時
- 既存プロジェクトで `gh pr view` や `git status` が毎回プロンプトを出していて煩わしい時
- `gh pr merge` / `git push` などの destructive 系を、プロジェクト単位で明示的にブロックしたい時
- カテゴリごとに `allow` / `ask` / `deny` を細かく分けたい時 (一括 tier 選択では表現できない要求)

逆に以下の場面では使わないでください。

- ユーザグローバルの `~/.claude/settings.json` で既に十分カバーされている場合 (skill を走らせても追加 0 件で終わるだけ)
- 実際にはプロンプトが発火していないのに先回りで 17 カテゴリを埋めようとする場合
- 単一の verb だけを変えたい場合 (例: `gh pr view` だけ許可したい) — 手で編集するか `update-config` skill を使う方が早い
- チーム共有のポリシーを `.claude/settings.json` にコミットしたい場合 (この skill はそこには書き込まない)

## 17 カテゴリ概要

カテゴリ 1〜11 が `gh`、カテゴリ 12〜17 が `git` を対象とします。「推奨」列は default 選択ロジック (Pure-read → allow / 外部可視で可逆 → ask / 実質不可逆 → deny / 引数パターン分離不能 → ask) に基づきます。

| #   | カテゴリ                | 対象コマンド (代表例)                                                         | 推奨   |
| --- | ----------------------- | ----------------------------------------------------------------------------- | ------ |
| 1   | Read-only               | `gh issue view` / `gh pr list` / `gh repo view` / `gh search` など read 系全般 | allow  |
| 2   | Local ops               | `gh pr checkout` / `gh browse`                                                | allow  |
| 3   | Comments & reviews      | `gh issue comment` / `gh pr comment` / `gh pr review`                         | ask    |
| 4   | Issue create / edit     | `gh issue create` / `gh issue edit`                                           | ask    |
| 5   | Issue close / reopen    | `gh issue close` / `gh issue reopen`                                          | ask    |
| 6   | PR create / edit        | `gh pr create` / `gh pr edit` / `gh pr ready`                                 | ask    |
| 7   | PR merge / close        | `gh pr merge` / `gh pr close`                                                 | deny   |
| 8   | Release ops             | `gh release create` / `edit` / `upload` / `delete` / `delete-asset`           | deny   |
| 9   | Workflow execution      | `gh workflow run` / `enable` / `disable` / `gh run rerun` / `cancel`          | deny   |
| 10  | gh api low-level        | `gh api` (HTTP method がフラグで切り替わるため arg-pattern 制約不能)          | ask    |
| 11  | Delete-class            | `gh repo delete` / `issue delete` / `run/cache/secret/variable delete`        | deny   |
| 12  | git read-only           | `git status` / `diff` / `log` / `show` / `branch` / `switch` / `checkout` 等 | allow  |
| 13  | git local writes        | `git add` / `commit` / `rm` / `mv` / `stash`                                  | allow  |
| 14  | git history rewrite     | `git merge` / `rebase` / `cherry-pick` / `revert` / `reset` / `commit --amend`| ask    |
| 15  | git tag                 | `git tag` (作成・削除)                                                        | ask    |
| 16  | git destructive local   | `git reset --hard` / `restore` / `checkout -- *` / `branch -D` / `clean -f*` / `stash drop` 等 | deny |
| 17  | git push                | `git push` 全形 (`--force` / `--tags` / `--delete` 等を含む)                  | deny   |

カテゴリ 12 / 13 は「broad allow + narrow deny」の組み合わせを前提に設計されています。たとえば `Bash(git branch:*)` を allow にすると `git branch -D foo` も形式的にはマッチしますが、カテゴリ 16 の `Bash(git branch -D:*)` の deny が `deny → ask → allow` の first-match-wins ルール (`code.claude.com/docs/en/permissions` 参照) によって先に評価されるため、destructive な派生形は遮断されます。カテゴリ 16 を `ask` / `allow` に変更すると、この安全装置が外れる点に注意してください。

## 動作フロー

skill 内部のステップ構成です。

- **Step 1**: `git rev-parse --show-toplevel` でリポジトリルートを特定し、`.claude/settings.local.json` を `Read` で読む (存在しない場合は新規作成扱い)
- **Step 2**: 既存の `permissions.allow` / `ask` / `deny` をパース。既存エントリは「ユーザが過去に設定済み」とみなして保持
- **Step 2.5**: 17 問に入る前に、現状の `gh` / `git` エントリ件数とカテゴリ網羅状況を要約表示し、`AskUserQuestion` で「続行する / ここで終了する」を確認
- **Step 3**: 17 カテゴリを `AskUserQuestion` の 5 バッチ (4+4+4+4+1) で順次質問。1 問あたりの選択肢は 3 つ (allow / ask / deny)、推奨選択肢は先頭に置き `(recommended)` を付与
- **Step 4**: 各回答をもとに `allow` / `ask` / `deny` 配列への追加候補を構築。既存エントリとの重複は、`Bash(... :*)` 形式と `Bash(... *)` 形式を等価とみなして除外
- **Step 5**: 同じパターンが別配列に既に存在する場合は conflict として `AskUserQuestion` で個別解決 (Keep existing / Move / Keep both)。質問前文には「Step 6 のプレビュー承認まではファイル書き込みは行われない」旨の注意書きを毎回付ける
- **Step 6**: 書き込み先パス、新規追加される `allow` / `ask` / `deny` の全件、conflict 解決による削除エントリを 1 つの `AskUserQuestion` で最終確認。差分がゼロ件の場合のみプロンプトをスキップして "Everything is already configured" で終了
- **Step 7**: 既存ファイルがあり `permissions` キーが存在すれば該当配列だけを `Edit` で差し替え (Edit branch)、無ければ最小スキャフォールディングで `Write` (Write branch)。書き込み直前に再 `Read` し、Step 1 以降の手動編集との競合を検知

## 注意点・前提

- **Tier 2/3 との整合性**: 本 skill が `.claude/settings.local.json` に書き込む行為自体が、ユーザグローバル CLAUDE.md の Tier 2「共有アセットへの変更」に該当します。そのため Step 6 のプレビュー承認は省略不可です。スコープ承認 ("`gh` 周りを整えて") があっても、ファイル書き込みは毎回明示確認が必要、という Tier 2 の運用に沿った設計になっています
- **Tier 3 の destructive を誤って allow にしない**: カテゴリ 7 (`gh pr merge / close`)、8 (release 系)、11 (delete 系)、16 (git 破壊的ローカル)、17 (`git push`) はグローバル CLAUDE.md の Tier 3 (実質不可逆な外部書き込み、または取り消し不能なローカル破壊) に該当します。これらを `allow` に変更すると、本来自動実行されてはならないコマンドがプロンプトなしで通るようになり、グローバルポリシーと矛盾します。基本的には推奨の `deny` を受け入れてください
- **`gh api` の扱い**: `gh api` は `-X DELETE` / `--method=DELETE` / `-f` 付与による POST 切り替えなど、HTTP メソッドがフラグで動的に決まるため、Bash の argv パターンマッチで「GET だけ許可」を表現することは原理的にできません (`code.claude.com/docs/en/permissions` の公式注意書きを参照)。default は `ask` です。プロンプト頻度を減らしたい場合は、`Bash(gh api repos/*/pulls/*/comments)` のように **パス限定の allow ルールを個別に追記** してください。`{owner}` のような波括弧プレースホルダは公式仕様外なので、リテラル文字として扱われる点に注意
- **broad-allow + narrow-deny の崩しに注意**: カテゴリ 12 / 13 を `allow`、カテゴリ 16 を `ask` / `allow` の組み合わせにすると、`git branch -D` や `git stash drop` が遮断されなくなります。Step 3 の選択肢説明文でも警告される設計ですが、override 時は意識してください
- **書き込み対象は `.claude/settings.local.json` のみ**: チーム共有用の `.claude/settings.json`、ユーザグローバルの `~/.claude/settings.json` は本 skill では一切触りません。前者を更新したい場合はチーム合意の上で手編集、後者はユーザが明示的に編集する範囲です
- **冪等性**: 同じ選択で 2 回連続実行すると、Step 4 の dedupe により追加 0 件 → Step 6 短絡 → no-op で終了します。これは設計上保証されたプロパティです
- **gitリポジトリ外で実行された場合**: `git rev-parse` が失敗した場合は現在の作業ディレクトリにフォールバックしますが、想定外の親ディレクトリに `.claude/settings.local.json` を作らないよう、ユーザにリポジトリルートへ `cd` してから再実行することを推奨します

## 関連

- `SKILL.md` — 英語原本 (本 README の元となる詳細仕様)
- `.claude/settings.local.json` — 書き込み先ファイル (プロジェクトルート直下、gitignore 対象)
- `~/.claude/CLAUDE.md` — Tier 1 / 2 / 3 の判定ルール。本 skill の推奨デフォルトはこの分類と整合
- `code.claude.com/docs/en/permissions` — Claude Code パーミッションの公式ドキュメント (評価順序 `deny → ask → allow` first-match-wins、`Bash(... :*)` と `Bash(... *)` の等価性、引数パターンマッチの限界の根拠)
- 関連 skill: `fewer-permission-prompts` (transcript ベースで事後的にクリーンアップする方式)、`update-config` (任意コマンドの 1 件追加向け)
