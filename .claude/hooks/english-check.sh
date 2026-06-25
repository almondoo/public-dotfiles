#!/bin/bash
# english-check.sh — Claude Code UserPromptSubmit hook
# 英語プロンプトをHaikuで文法チェックし、Claudeの応答末尾に
# 「説明(日本語)+推奨英文」を含む "English note" ブロックを追加させる。
# タグだけでは意味が取れないため、説明と推奨英文を分けて出す。
# 日本語プロンプト・短文・スラッシュコマンドはスキップ(レイテンシゼロ)。
set -u

# 再帰防止: 下のclaude -p呼び出しが自分自身のhookを発火させるのを防ぐ
[ -n "${ENGLISH_CHECK_RUNNING:-}" ] && exit 0

# 依存コマンドがなければ静かに無効化
command -v jq >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty')

# スキップ条件1: 空、スラッシュコマンド
[ -z "$prompt" ] && exit 0
case "$prompt" in "/"*) exit 0 ;; esac

# スキップ条件2: 4語未満("fix this" 程度は添削対象外)
words=$(printf '%s' "$prompt" | wc -w | tr -d '[:space:]')
[ "$words" -lt 4 ] && exit 0

# スキップ条件3: 非ASCII文字(日本語等)を含むプロンプトはスキップ
# (純粋な英語プロンプトのみチェック。ロケール非依存の判定)
if printf '%s' "$prompt" | tr -d '[:space:]' | LC_ALL=C grep -q '[^ -~]'; then
  exit 0
fi

check_prompt="You are a strict but encouraging English writing coach for a Japanese engineer who is a beginner at English.
Check the text below (it is a prompt written for an AI coding tool, so imperative mood is correct and expected).
Reply with exactly: OK — only if the text is grammatically correct AND already the natural phrasing a proficient engineer would use.
If there is a grammar error, OR the text is understandable but a clearly more natural phrasing exists, reply on a SINGLE line in exactly this format, with no quotes and no preamble:
<improved English text> ||| <one concise Japanese sentence explaining what was wrong and why, specific enough to learn from (roughly 60 Japanese characters or fewer, single line, no line breaks)>
Do not flag trivial stylistic preferences; only suggest when the improvement is clearly better.

Example reply: Create a PR targeting main. ||| 名詞 PR を後置修飾するには、動詞でも名詞でもある target をそのまま並べず分詞 targeting で繋ぐ必要があります
Example reply: Please implement error handling. ||| 名詞化した implementation より動詞 implement を使う方が自然で簡潔です

Text: ${prompt}"

# Haikuで添削(最速・最安モデル)。失敗しても本体の動作は止めない
result=$(ENGLISH_CHECK_RUNNING=1 claude -p --model haiku "$check_prompt" 2>/dev/null) || exit 0
result=$(printf '%s' "$result" | head -n 1)

[ -z "$result" ] && exit 0
case "$result" in OK*|ok*|Ok*) exit 0 ;; esac

# "推奨英文 ||| 日本語の説明" をパース(説明がない場合は推奨英文のみ)
corrected=$(printf '%s' "$result" | awk -F ' \\|\\|\\| ' '{print $1}')
hint=$(printf '%s' "$result" | awk -F ' \\|\\|\\| ' '{print $2}')
[ -z "$corrected" ] && exit 0

# 説明+推奨英文の複数行ブロックを組み立てる(タグだけでは意味が取れないため)
if [ -n "$hint" ]; then
  note=$(printf 'English note:\n- 説明: %s\n- 推奨: %s' "$hint" "$corrected")
else
  note=$(printf 'English note:\n- 推奨: %s' "$corrected")
fi

# additionalContextとして注入(事実の記述として書く: docs推奨)
jq -n --arg note "$note" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("The user is a Japanese engineer who is a beginner at English and is practicing by writing prompts in English. An automated grammar check of their prompt produced the following feedback block:\n\n" + $note + "\n\nThe user has a standing request that the assistant reproduce this exact block, verbatim, at the very end of its response, keeping both the 説明 and 推奨 lines. It is language feedback only and must not change the technical task.")
  }
}'
exit 0
