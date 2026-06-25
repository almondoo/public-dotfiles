#!/usr/bin/env bash
#
# Tests for .claude/hooks/gh-api-write-guard.sh
#
# Verifies the allowlist-reads contract: `gh api` reads pass through untouched
# (the hook exits 0 with no output, deferring to the normal permission flow),
# writes are lifted to "ask", and destructive endpoints are blocked with "deny".
#
set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK="$SCRIPT_DIR/../.claude/hooks/gh-api-write-guard.sh"

if [ ! -x "$HOOK" ]; then
  echo "FATAL: hook not found or not executable: $HOOK" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq is required to run these tests" >&2
  exit 2
fi

pass=0
fail=0

# run_case <expected: pass|ask|deny> <description> <command>
#   pass = deferred (exit 0, no output)
run_case() {
  local expected=$1 desc=$2 command=$3
  local payload out code actual
  payload=$(jq -n --arg cmd "$command" '{tool_name:"Bash",tool_input:{command:$cmd}}')
  out=$(printf '%s' "$payload" | "$HOOK")
  code=$?
  if [ -n "$out" ]; then
    actual=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "PARSE_ERROR"')
  elif [ "$code" -eq 0 ]; then
    actual=pass
  else
    actual="CRASH(exit=$code)"
  fi
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1))
    printf 'ok   [%-4s] %s\n' "$actual" "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL exp=%s got=%s  %s\n      cmd: %s\n' "$expected" "$actual" "$desc" "$command"
  fi
}

# ── Reads: pass through (deferred) ───────────────────────────────────────────
run_case pass "default GET, no flags"               'gh api /repos/owner/repo'
run_case pass "explicit -X GET"                     'gh api -X GET /repos/owner/repo'
run_case pass "explicit --method GET"               'gh api --method GET /user'
run_case pass "GET with field => query string"      'gh api repos/owner/repo/issues --method GET -f state=open'
run_case pass "HEAD is a read"                       'gh api -X HEAD /repos/owner/repo'
run_case pass "not a gh api command"                'gh pr list'
run_case pass "unrelated command"                   'ls -la /var/log'
run_case pass "--method=GET (equals form)"          'gh api --method=GET /repos/owner/repo'
run_case pass "-X GET shorthand with field"         'gh api -X GET search/issues -f q=repo:cli/cli'
run_case pass "read with -H header (not a write)"   'gh api /repos/owner/repo -H Accept:application/vnd.github+json'
run_case pass "-i include is not --input"           'gh api /repos/owner/repo -i'
run_case pass "graphql bare (no flags)"             'gh api graphql'

# ── Writes: ask ──────────────────────────────────────────────────────────────
run_case ask  "POST with field"                     'gh api -X POST /repos/owner/repo/issues -f title=bug'
run_case ask  "PATCH method"                         'gh api --method PATCH /repos/owner/repo/issues/1 -f state=closed'
run_case ask  "implicit POST via field flag"         'gh api repos/owner/repo/issues -f title=x'
run_case ask  "non-destructive DELETE (comment)"     'gh api -X DELETE /repos/owner/repo/issues/comments/1'
run_case ask  "dynamic method -X \$VAR"              'gh api -X $METHOD /repos/owner/repo'
run_case ask  "DELETE on non-listed path (blob)"     'gh api --method DELETE /repos/owner/repo/git/blobs/abc123'
run_case ask  "PUT secret (create/update, not del)"  'gh api -X PUT /repos/owner/repo/actions/secrets/FOO -f encrypted_value=x'
run_case ask  "graphql read query (cannot tell)"     "gh api graphql -f query='{ viewer { login } }'"
run_case ask  "lowercase POST method"               'gh api -X post /repos/owner/repo/issues -f title=x'
run_case ask  "--input body (no method flag)"       'gh api repos/owner/repo/rulesets --input file.json'
run_case ask  "-XPOST shorthand (concatenated)"     'gh api -XPOST /repos/owner/repo/issues -f title=x'
run_case ask  "-F raw field (release create)"        'gh api -F draft=true /repos/owner/repo/releases'

# ── Destructive writes: deny ─────────────────────────────────────────────────
run_case deny "repo deletion"                        'gh api -X DELETE /repos/owner/repo'
run_case deny "repo deletion (no leading slash)"     'gh api --method DELETE repos/owner/repo'
run_case deny "branch/ref deletion"                  'gh api -X DELETE /repos/owner/repo/git/refs/heads/feature'
run_case deny "release deletion"                     'gh api -X DELETE /repos/owner/repo/releases/123'
run_case deny "secret deletion"                      'gh api -X DELETE /repos/owner/repo/actions/secrets/MY_SECRET'
run_case deny "PR merge (PUT merge)"                 'gh api -X PUT /repos/owner/repo/pulls/5/merge'
run_case deny "graphql delete mutation"              "gh api graphql -f query='mutation { deleteRepository(input: {repositoryId: \"x\"}) { clientMutationId } }'"
run_case deny "lowercase DELETE method"             'gh api -X delete /repos/owner/repo'
run_case deny "--method=DELETE (equals form)"       'gh api --method=DELETE /repos/owner/repo'
run_case deny "-XDELETE shorthand (concatenated)"   'gh api -XDELETE /repos/owner/repo'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
