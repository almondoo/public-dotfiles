#!/bin/bash
# inject-subagent-model.sh — Claude Code PreToolUse hook
# Agent/Task ツール起動時に model が未指定ならば "sonnet" を注入する。
# model が既に指定されている場合は一切触らない(明示指定を尊重)。
set -u

# 依存コマンドがなければ静かに無効化
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat) || exit 0

# tool_name を取得。パース失敗時は何もしない
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ -z "$tool_name" ] && exit 0

# Agent / Task 以外はスキップ
case "$tool_name" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

# tool_input.model を取得(キー無し → null、値が null → null、空文字 → "")
model=$(printf '%s' "$input" | jq -r '.tool_input.model // empty' 2>/dev/null) || exit 0

# model が非空文字列なら既に指定済み → 何もしない
[ -n "$model" ] && exit 0

# model 未指定(キー無し / null / 空文字)→ "sonnet" を注入。
# updatedInput は tool_input を「マージ」ではなく「全体置換」する(実測で確認)ため、
# 元の tool_input 全体に model を足して返す(description/prompt 等を保持する)。
printf '%s' "$input" | jq '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: ((.tool_input // {}) + {model: "sonnet"})
  }
}'
exit 0
