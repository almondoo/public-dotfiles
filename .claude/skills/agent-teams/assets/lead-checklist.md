# Lead checklist

What the Lead should verify at each phase of the wave. Consult at wave start / during commit proxying / at wave completion / on disband.

## Wave start (before Phase 1 + Phase 2 spawn)

- [ ] Understand the user's request and grasp the overall scope
- [ ] Read the issue / spec / git log and pick 6 target tasks from the backlog
  - [ ] Prefer new helpers / high independence / no DB schema migration / no new dependencies
  - [ ] Confirm no overlap with existing commits (search similar task names via `git log --grep`)
- [ ] Decide the Wave structure (typical: 4 in parallel + 2 blocked_by)
- [ ] Follow the naming convention `W<n>-<D|A|AI|UI><id>`
- [ ] Decide the owner-separation strategy (1 file = 1 owner)
- [ ] Present the plan (team composition + Wave structure + 6-task outline) to the user and get approval

## During Phase 2 spawn

- [ ] Create the team via `TeamCreate`
- [ ] Register 6 tasks via `TaskCreate` (each description states owned files / forbidden files / acceptance criteria / commit-message draft)
- [ ] Wire Wave 2 dependencies via `TaskUpdate({ taskId, addBlockedBy: [<upstream-id>, …] })` after each task is created (`TaskCreate` itself takes only `subject` / `description` / `activeForm` / `metadata`, no `blocked_by` field)
- [ ] Copy templates from `assets/spawn-prompts/` and substitute placeholders
- [ ] **Spawn all teammates in a single message** — count and roles per the composition table in SKILL.md (Small=2: Implementer×1 + Reviewer×1; Medium=3-4: Implementer×1-2 + Reviewer×1 + Tester×1; Large=5-6: Implementer×2-3 + Reviewer×1 + Security Checker×1 + Tester×1)
  - Add a Security Checker if needed (large or security-critical)
- [ ] State explicitly in spawn prompts that Reviewer / Tester "wait for SendMessage"
- [ ] Confirm Delegate mode (Shift+Tab) is enabled

## During commit proxying (each time an Implementer requests a commit)

- [ ] Confirm the Implementer's request:
  - [ ] Owned file paths (per-path, no off-target contamination)
  - [ ] unit-test counts / typecheck / lint green (per the project's `<TEST_RUNNER_COMMAND>` / `<TYPECHECK_COMMAND>` / `<LINT_COMMAND>`)
  - [ ] **literal control-byte check** reports `[]`
  - [ ] Proposed commit message follows the convention
- [ ] Check the working tree with `git status`
  - [ ] The Implementer's 2 owned files are in Untracked (other teammates' untracked may coexist; they won't contaminate unless staged)
- [ ] **`git add` with per-path** (absolutely no `-A` / `.` / `-u`)
- [ ] Re-check with `git status` to confirm staging contains exactly the 2 owned files
- [ ] Run `git commit -m "..."` (no `--amend`, no push)
- [ ] SendMessage the Implementer: "commit <hash> done, please TaskUpdate completed"
- [ ] SendMessage the Reviewer to request a review (and, **if a dedicated Security Checker exists**, SendMessage them in parallel — both reviewers see the same commit at the same time)

## When Reviewer (and Security Checker) results arrive

- [ ] If there are Critical / Important (Reviewer) **or Critical / High (Security Checker)** findings:
  - [ ] SendMessage the Implementer with a fix request (cite specific file:line + fix proposal)
  - [ ] On Implementer fix completion → run the fix commit via the proxy procedure above
  - [ ] SendMessage the Reviewer for a re-review
  - [ ] **Track per-task fix iteration count locally** (a private note, not in the TaskCreate description — teammates write there too and races clobber notes)
  - [ ] Repeat until Critical/Important (Reviewer) AND Critical/High (Security Checker) are zero **or `MAX_FIX_ITERATIONS = 3` is reached**
- [ ] If iteration 3 still produces Critical / Important (Reviewer) or Critical / High (Security Checker) on the same task (non-convergence):
  - [ ] Halt this task's fix cycle
  - [ ] Ask the Reviewer to summarize the remaining findings
  - [ ] Ask the Implementer for a brief non-convergence diagnosis
  - [ ] **Escalate to the user via `AskUserQuestion`** with three options:
    - (1) Defer this task to a follow-up issue and continue the wave with what passes
    - (2) Reassign the task to a different Implementer (fresh context)
    - (3) Pause for new direction from the user
  - [ ] Continue the rest of the wave (do NOT block other Implementers on a single stuck task)
- [ ] On PASS:
  - [ ] Minor items don't require fixes in this PR; tell the Implementer they'll be follow-ups
  - [ ] Proceed to the next task or wave completion

## Wave completion (after all tasks completed + all Reviewer PASS)

- [ ] **Medium / Large waves**: SendMessage the Tester to request the final full regression (once only)
  - [ ] `<FULL_TEST_COMMAND>` (e.g. `bun run test:unit`, `pnpm test`, `pytest`)
  - [ ] `<TYPECHECK_COMMAND>` (e.g. `bun --filter '*' typecheck && bun run typecheck`, `tsc -b`, `mypy .`)
  - [ ] `<LINT_COMMAND>` (e.g. `bun --filter '*' lint && bun run lint`, `eslint .`, `ruff check`)
  - [ ] `git log --stat` to confirm per-commit staging
- [ ] **Small waves (no Tester)**: run the regression directly via the Lead direct-verification route (read-only `<FULL_TEST_COMMAND>` / `<TYPECHECK_COMMAND>` / `<LINT_COMMAND>` + `git log --stat`, details: `references/tester-optimization.md`) — standard Small-wave path, not an emergency fallback
- [ ] On Tester PASS (or Lead-direct verification PASS for Small waves) → proceed to disband
- [ ] **(Medium / Large only) If no Tester response after 3× the Tester's expected time (~6 min vs ~1-2 min)**:
  - [ ] One status-check ping
  - [ ] One re-request
  - [ ] If still no response, **switch to the Lead direct-verification route** (details: `references/tester-optimization.md`)
- [ ] On FAIL, request fixes from the Implementer → re-regression

## On disband

- [ ] Confirm `TaskList` shows every task `completed`. If any are stuck `in_progress` after the commit clearly landed + Reviewer PASS (known runtime limitation: teammates occasionally forget to mark `completed`), the Lead may `TaskUpdate({ taskId, status: "completed" })` directly — record the commit hash as evidence in a SendMessage to the Implementer
- [ ] Send **individual shutdown_request via SendMessage** to every teammate (one call per teammate, not a broadcast). Example:
      `SendMessage({ to: "impl-doc1", message: { type: "shutdown_request", reason: "wave complete" } })`
- [ ] Wait for `shutdown_response` (`approve: true`) from each teammate. If any teammate responds with `approve: false` (e.g. claims unfinished work), inspect the reason, verify task state, resolve, then re-send — do not force-cleanup a teammate that declined shutdown
- [ ] Confirm `teammate_terminated` notifications from the system for **every** teammate before calling `TeamDelete` — `TeamDelete` fails when active teammates remain (Agent Teams runtime)
- [ ] Run `TeamDelete`
- [ ] Confirm final state with `git log main..HEAD --oneline | head` + `git status`
- [ ] Report wave summary to the user:
  - [ ] N commits added (per-commit listing + contents)
  - [ ] Test count / typecheck / lint results
  - [ ] Any incidents / fixes (literal control bytes / git-reset violations etc.)
  - [ ] State push not performed (the Lead never pushes — the user runs `git push` manually after reviewing the wave)

## Reminders for forbidden actions (Lead easily forgets)

- ❌ Edit / Write on code (implementation belongs to Implementers)
- ❌ `git reset` / `--amend` / `git restore` / `git push` etc. (only `add` / `commit`)
- ❌ Bundling multiple tasks into one commit
- ❌ Per-commit verification requests to the Tester
- ❌ Spawning Reviewer / Tester mid-wave (all spawn at Phase 2)
- ❌ Moving forward without waiting for teammate responses (race / consistency damage)
- ❌ Doing "final polish" after disbanding the team (collapse of the quality gate)
