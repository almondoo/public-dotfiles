#!/bin/bash
# inject-subagent-model.sh — Claude Code PreToolUse hook
# 登録: claude/settings.json の PreToolUse / matcher "Agent"。
#
# 目的: 「main の Opus が計画し、サブエージェントの Sonnet が実行する」分担を
# 機械的な既定にする。dispatch 側で model を書き忘れても Opus に流れない。
#
# 動作: Agent/Task ツール起動時に model 未指定なら "sonnet" を注入、既指定は
# 一切触らない(明示指定を尊重)。subagent_type がユーザー自作 agent
# (~/.claude/agents/<name>.md が実在)を指す場合は注入をスキップする —
# 自作 agent は frontmatter の model が実効値になる(このフックは組み込み/
# プラグイン由来エージェントを model 省略で dispatch した場合の既定担当で、
# バックストップではない)。matcher は "Agent" のみで、Task 分岐は旧ツール名
# への保険であり現行登録では到達しない。jq 不在環境では静かに無効化される。
set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat) || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ -z "$tool_name" ] && exit 0

case "$tool_name" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

# キー無し/null/空文字はいずれも空文字として取れる
model=$(printf '%s' "$input" | jq -r '.tool_input.model // empty' 2>/dev/null) || exit 0

[ -n "$model" ] && exit 0

# 自作 agent(~/.claude/agents/<name>.md が実在)は frontmatter の model を
# 実効値として使わせるため注入しない。パス文字(/ : ..)を含む名前は対象外
# (plugin:agent 形式等の誤爆防止)。
subagent_type=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null) || exit 0
if [ -n "$subagent_type" ]; then
  case "$subagent_type" in
    *[!A-Za-z0-9_-]*) ;;
    *)
      # 大文字小文字を区別しないファイルシステムでの誤検出(My-Custom-Agent.md
      # が my-custom-agent.md にヒット)を避けるため、glob で列挙しリテラル
      # 厳密一致するものだけ自作 agent とみなす。
      for f in "$HOME/.claude/agents/"*.md; do
        [ -f "$f" ] || continue  # glob 不一致時のリテラル展開ガード
        if [ "${f##*/}" = "${subagent_type}.md" ]; then
          exit 0
        fi
      done
      ;;
  esac
fi

# updatedInput は tool_input を全体置換する(マージではない、実測で確認済み)。
# 元の tool_input に model を足して返すことで description/prompt 等を保持する。
printf '%s' "$input" | jq '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: ((.tool_input // {}) + {model: "sonnet"})
  }
}'
exit 0
