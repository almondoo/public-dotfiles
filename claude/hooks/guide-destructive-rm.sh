#!/bin/bash
#
# PreToolUse(Bash) フック: 再帰/強制 rm(-r/-f/-rf/--recursive/--force)を
# 検知し、教育的な deny 理由を添えて拒否する。
# 登録: claude/settings.json の PreToolUse / matcher "Bash"。
#
# 目的: permissions.deny の rm パターン(Bash(rm -rf *) 等)はこの3つの正確な
# 綴りしかカバーしない。フルストリング glob で末尾の " *" がワード境界を
# 要求するため、-fr(転置)/-R(大文字。マッチ大小区別は非公開仕様で信頼
# 不可)/-rvf(余分な文字)/--recursive・--force(deny 未収載)/-v -rf(無関係
# flag前置)は deny にマッチしない(2026-08-25 に claude/settings.json を
# 実地確認)。本フックの正規表現(rm_re)はこのうち -fr/-R/-rvf/--recursive/
# --force を検知できる唯一の決定的な手段になっている(-v -rf は rm_re でも
# 未検知の残存ギャップ)。
#
# 経緯: bare な "denied" のみで理由や代替を示さず同じ rm -rf を繰り返す
# セッションが観測されたため、permissions 評価の前段で親切な deny 理由を
# 注入する設計にした。
#
# 適用外(素通し): flag なしの rm(単一ファイル削除) / -i など r/f を含まない
# flag のみの rm / rm がコマンド位置(行頭、または ; && || | の直後)でない
# 場合(echo/grep 内の文字列、git rm など)
#
# fail-open 設計: jq 不在・command 抽出不能など前提が欠けた場合は素通しする。
# 上記の -fr/-R/-rvf/--recursive/--force 等は permissions.deny でブロック
# されないため、fail-open 時はこれらの綴りに対する後段の防御が一切残らない。

set -u

# jq がなければ判定不能 -> 素通し(inject-subagent-model.sh と同じ方針)
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# command が空なら対象外
[ -z "$command" ] && exit 0

# コマンド位置(行頭、または ; && || | の直後)の rm で r/f/R/F を含む短縮flag、
# または --recursive / --force を伴う場合のみ対象。grep ではなく [[ =~ ]] を使う
# のは、grep は行単位処理で `^` が各行頭にマッチする(ヒアドキュメント誤検知)のに
# 対し、[[ =~ ]] は複数行文字列全体を1つとして扱い `^` が先頭にしか一致しないため。
rm_re='(^|;|&&|\|\||\|)[[:space:]]*rm[[:space:]]+(-[a-zA-Z]*[rfRF][a-zA-Z]*|--recursive|--force)([[:space:]]|$)'
if [[ "$command" =~ $rm_re ]]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Recursive/forced rm (-r/-f/-fr/-R/-rvf/--recursive/--force) is denied by this destructive-rm guard. Delete files with flag-less rm and empty directories with rmdir. For deep directory trees, ask the user to run `! rm -rf <path>` manually. Do not try workarounds like find -delete; they are deny-listed too."}}'
  exit 0
fi

exit 0
