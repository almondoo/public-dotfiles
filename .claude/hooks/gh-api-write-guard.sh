#!/bin/bash
#
# PreToolUse(Bash) guard for `gh api`.
#
# Goal: let `gh api` reads (GET) run without a prompt, but force a confirmation
# prompt for writes. Claude Code permission rules match the command string only
# and cannot tell a GET from a DELETE on the same path, so this hook inspects
# the request method itself.
#
# Fail-safe (allowlist-reads) design: only a command we can positively confirm
# is a read is auto-allowed (deferred). Anything else -- a request-body/field
# flag, a non-GET method, or an unrecognizable/dynamic method like `-X $VAR` --
# is sent to a confirmation prompt. This way a write form the matcher does not
# recognize errs toward "ask", never toward silent auto-execution.
#
# Per `gh api --help`: the method is GET by default, switches to POST when any
# field parameter is added, and is overridden by `--method`. So every write
# necessarily carries either a field flag (-f/-F/--field/--raw-field/--input)
# or an explicit non-GET --method/-X. (`--method GET` with field flags sends
# them as a query string and stays a read.)
#
# Pairs with .claude/settings.json:
#   - `gh api *` is NOT in permissions.allow. Under defaultMode "auto", reads
#     (deferred here) auto-execute; this hook lifts every write to "ask".
#   - Defense-in-depth: permissions.ask also lists the common write-flag
#     patterns ("gh api * -X *", "* --method *", "* -f *", ...) so a write still
#     prompts if this hook ever fails to run. No endpoint is exempt.
#
# Destructive endpoints that mirror the direct-command deny set (repo/branch/
# release/secret deletion, PR merge, graphql delete mutations) return "deny"
# instead of "ask", so they are blocked rather than just prompted.

set -u

emit_ask() {
  if command -v jq >/dev/null 2>&1; then
    jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"gh api is not a confirmed read (write method, request-body field, or unrecognized method). Confirm before running."}}'
  else
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"gh api requires confirmation"}}'
  fi
  exit 0
}

emit_deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Destructive gh api call (repo/branch/release/secret deletion or PR merge) is blocked; run it manually if intended."}}'
  else
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Destructive gh api call is blocked."}}'
  fi
  exit 0
}

input=$(cat)

# Fast path: only gh api commands are relevant. Skip everything else without
# spawning jq, so this hook stays cheap on the common Bash call.
case "$input" in
  *"gh api"*) ;;
  *) exit 0 ;;
esac

# Prefer the parsed command; fall back to the raw payload when jq is missing
# (fail safe: the same read/write checks run against the raw payload).
if command -v jq >/dev/null 2>&1; then
  command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
else
  command=$input
fi

has() { printf '%s' "$command" | grep -qiE "$1"; }

# An explicit GET/HEAD method is a read even when field flags are present
# (gh sends them as a query string in that case).
safe_method='(^|[[:space:]])(-X|--method)[[:space:]=]*(GET|HEAD)([^A-Za-z]|$)'
# Any --method/-X flag, regardless of (or with an attached) value.
method_flag='(^|[[:space:]])(-X|--method)([[:space:]=]|[A-Za-z]|$)'
# Request-body / field flags -- presence implies a POST body.
body_flag='(^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]=]|$)'

# Confirmed read -> defer so the normal (auto) permission flow applies.
if has "$safe_method"; then
  exit 0
fi
if ! has "$body_flag" && ! has "$method_flag"; then
  exit 0
fi

# It is a write. Block the destructive endpoints that mirror the direct-command
# deny set (repo/branch/release/secret deletion, PR merge, graphql delete
# mutations); everything else only prompts.
del='(-X|--method)[[:space:]=]*DELETE'
put='(-X|--method)[[:space:]=]*PUT'
if   { has "$del" && has '(^|[[:space:]])/?repos/[^/ ]+/[^/ ]+([[:space:]]|$)'; } \
  || { has "$del" && has 'repos/[^/ ]+/[^/ ]+/git/refs/'; } \
  || { has "$del" && has 'repos/[^/ ]+/[^/ ]+/releases/[^/ ]'; } \
  || { has "$del" && has 'actions/secrets/[^/ ]'; } \
  || { has "$put" && has 'repos/[^/ ]+/[^/ ]+/pulls/[^/ ]+/merge'; } \
  || { has '(^|[[:space:]])graphql([[:space:]]|$)' && has 'delete(Repository|Ref|Issue|ProjectV2|Discussion|Environment|PullRequest)'; }; then
  emit_deny
fi

# Otherwise it is a non-destructive write -> prompt.
emit_ask
