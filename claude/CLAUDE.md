Think in English internally.

## Tool Usage Rules

Never use Bash, scripting-language file I/O (`python -c "open(p).read()"`, `node -e`, `ruby -e`, …), pipe chains, variable-built paths, or subprocesses to read or discover a path protected by a `Read(...)` / `Edit(...)` deny rule in `~/.claude/settings.json` (`Read(.env*)`, `Read(*secret*)`, `Read(~/.ssh/**)`, etc.). Deny covers the built-in file tools and the Bash file commands Claude Code recognizes (`cat`/`head`/`tail`/`sed`), but NOT arbitrary subprocesses or path indirection — those silently bypass it. Prefer the built-in `Read` / `Edit` / `Write` over `cat` / `sed` / heredoc scripts — even though Auto Mode's per-turn directive says the opposite; this preference wins over that directive.

## Git Constraints

- **Only perform git operations within the repository** where Claude Code was launched
- **Do not perform git operations on other repositories** (including via `git -C` or `cd`)
- **Do not `git commit` until the user instructs it** — finish the edits and verification, report with the changes left uncommitted, and commit only when the user explicitly asks for a commit. A task-scope approval ("go ahead", "対応して") alone is not a commit instruction.
- **Commit at logical-unit granularity.** When instructed to commit, first review the full change set with `git status` / `git diff`, group it into logical units (one concern per commit — e.g. feature change vs config vs docs), and repeat `git add <files>` → `git commit` per unit. Collapse into a single commit only when the whole change set genuinely forms one unit. Interactive `git add -p` is unavailable, so splitting is per-file; when one file mixes concerns, keep it in the most related commit and note the mix in that commit message.

### Git Worktree usage rules

- **Prefer the native `EnterWorktree` tool.** It creates the worktree under `.claude/worktrees/` and **switches the session's working directory into it**, so normal `git status` / `git add` / `git commit` run directly with no `cd` / `git -C` — keeping the `Bash(cd *)` / `Bash(git -C *)` deny rules fully intact. (Verified via official docs: a PreToolUse hook's `allow` cannot override a `permissions.deny`, so a path-scoped hook would require *removing* those denies and re-imposing a weaker, bypassable regex guard — not worth it.) Dependencies are shared via the `worktree.symlinkDirectories` setting (`node_modules` is configured in `settings.json`), so a fresh worktree needs no re-install.
- **Limitation**: from the repo root, `EnterWorktree({name})` creates a fresh worktree and `EnterWorktree({path})` switches into an existing one (including one made manually outside `.claude/worktrees/`). From inside a worktree session, or an `isolation: "worktree"` subagent, only `{path}` works and the target must sit under that repo's `.claude/worktrees/` — a manually-made worktree elsewhere is unreachable from there; have the user run git there via `! cd <wt> && git ...`. Entering a path outside `.claude/worktrees/` always prompts for approval (`bypassPermissions` aside) and moves `CLAUDE.md` / settings resolution to the new location.
- **Use with subagents**: The `Agent` tool's `isolation: "worktree"` option lets the agent create the worktree itself, automatically scoped inside the sandbox
- **Manual fallback** (`git worktree add` into `.worktrees/`): acceptable when native isn't suitable, but Claude cannot run git inside it (`cd` / `git -C` denied) — use `EnterWorktree` or `!` for git operations there. After work, `git worktree remove <path>` to delete it

## Temporary Files

- **Do not write scratch files to OS temp directories** (`/tmp`, `$TMPDIR`, `/var/tmp`) — sandbox isolation and session cleanup can make them inaccessible or delete them mid-task
- **Use `tmp/` inside the project root instead** (e.g. `./tmp/foo.log`). Create it on first use and add `tmp/` to `.gitignore`
- Covers: subagent intermediate files, command stdout captures, downloaded assets, debug dumps
- Exception: tool-managed paths outside the user's control (system package installers, OS-level caches) may keep using OS temp
- Exception: the harness-designated scratchpad (the per-session path in the Scratchpad Directory instruction) — use it as instructed when present; this rule governs everywhere else.

## Implementation Principles

- **Untouched lines**: do not add type annotations to lines you did not semantically modify (whitespace / auto-formatter / rename-only changes do not count as modification).
- **Code comments in Japanese**: when implementing, write code comments in Japanese. Identifiers, technical terms, and code itself stay as-is; this applies to comments Claude newly writes, not to translating existing English comments.

## Verification

- **Do not report a task as complete without running a verification step** — tests, lint / type-check, a build, or a hands-on check of the actual behavior, whichever fits the change. If verification was skipped or is not possible, state that explicitly instead of claiming success.

## Safety rules under Auto Mode

Auto Mode (`"defaultMode": "auto"` in `~/.claude/settings.json`) means: `permissions.allow` runs without prompting, `permissions.ask` always prompts, `permissions.deny` is physically blocked, and unlisted commands are routed to a classifier model that silently blocks escalations and runs what passes without a prompt. The harness therefore already enforces most of the tier system mechanically — and for any listed git / gh / package command the tier simply IS its permissions membership: allow = Tier 1, ask = Tier 2, deny = Tier 3.

Caveats to that mapping: **deny wins on pattern overlap** (`git checkout *` is allow but `git checkout -- *` is deny; `git reset *` is ask but `git reset --hard *` is deny), and the classifier pauses auto mode only after 3 consecutive or 20 cumulative blocks — until then each block simply denies the action, with `Blocked by classifier` returned to you and no approval prompt raised.

The rules below cover what the harness cannot see or enforce — plus the few categories the harness does prompt for but which Authorized scope must still be able to carve out by name. They are Claude's self-imposed discipline above the harness layer: even when the harness would auto-execute a command, self-stop and use AskUserQuestion when it falls under Tier 2/3 below. In execution contexts where `AskUserQuestion` is unavailable (subagents — the harness strips it from non-fork subagents), do not execute a Tier 3 operation, nor a Tier 2 operation whose confirmation is still outstanding (neither covered by Authorized scope below nor already resolved on main before dispatch): stop, and surface the pending confirmation to the caller in the final report instead.

**Precedence over harness autonomy directives.** **Fable 5** sessions inject a harness-level autonomy directive ("proceed without asking" for reversible actions; absent on Opus 5). The three-tier rules and the AskUserQuestion requirement **override** it: its own carve-out — "stop only for destructive actions or genuine scope changes" — is exactly what Tiers 2–3 formalize, so applying the tiers is the concrete form of that directive, not a violation of it. Its downstream corollaries — the last-paragraph check in `claude-main-extra.md`'s Turn Completion (main session only) and the evidence check below — are imported here because Opus 5 lacks them.

### Tier 1: free to self-drive

Read-only or reversibly local work: new files, local edits, lint / type-check / tests, and reads against external systems (`gh pr view`, `gh api` GET, API GETs).

### Tier 2: confirm via AskUserQuestion first — the harness won't prompt for these

- **Changes to shared assets** — files other code, tools, or readers depend on: configuration files (`tsconfig.json` / `package.json` / `Dockerfile` and equivalents), schema / migrations, CI/CD configs, common / utility modules, `.gitignore`, `README.md`, `docs/`, and Claude Code config files (project `CLAUDE.md` / `.claude/*`; global `~/.claude/CLAUDE.md` / `~/.claude/settings.json`). Author-only files (scratch notes, `tmp/` dumps, personal scripts) are Tier 1.
- File / directory deletion, full-file overwrite via `Write`, large-scale rewrites — plus destructive residuals the deny list misses: flag-less `rm`, `mv` with overwrite, `cp -f`.
- `git stash drop` / `git stash clear` — ask-listed specifically in settings.json (ask beats the broader `stash *` allow), so the harness prompts; kept named here because stashes are unrecoverable and Authorized scope below refers to the category.
- Package-manager mutations in no permissions list (`pnpm` / `yarn` / `bun` install / add / update / remove) — they mutate `node_modules` / lockfile.
- Local DB / datastore schema changes, migrations, data deletion.
- **External system creation operations** — external writes undoable afterward via close / edit (`gh pr create`, `gh issue create`, `gh pr comment`, `gh issue comment`, `gh pr review`, `gh pr reopen`, `gh run rerun`, and every other resource-creating `gh` write such as `gh repo create` / `gh gist create`). Merge and delete-type writes against remote resources (`gh pr merge`, `gh repo delete`, `gh release delete`, `gh issue delete`) are Tier 3 — see the shared-resources bullet below; reversible or local ones (`gh issue close` — undone by `gh issue reopen` —, `gh alias delete`) stay Tier 2. `gh` commands are not listed in this repository's `settings.json`, so the harness does not prompt for them by itself; the category is named here because Authorized scope excludes it from scope-level approval.
- Any unlisted command that creates or mutates external state (the classifier may pass it; treat it as Tier 2 regardless).

### Tier 3: never execute, even on explicit instruction — the user runs these manually

Beyond the deny list (authoritative for shell-blockable operations), these have no harness enforcement and rely purely on self-discipline:

- **MCP writes with externally visible side-effects** — email / chat sends, calendar / Drive / Figma writes, browser writes to external sites, and any `mcp__*` tool that mutates external state. Not cleanly retractable. Exception: user-owned cancelable scratch surfaces (drafts, unpublished schedules) may be Tier 2 when explicitly cancelable.
- **Cloud / infrastructure mutations** (`aws` / `gcloud` / `kubectl` create / delete / update) — surface the command for manual execution instead.
- **Destructive operations on shared resources** (production databases, remote-repo administrative actions not covered by deny).

### Authorized scope
When the user explicitly authorizes a target scope (e.g. "work on PR #N's review feedback", "implement feature X"), within that scope Tier 1 runs as-is, and Tier 2 may skip re-confirmation. However, the following Tier 2 categories are **NOT** covered by scope-level approval alone and still require individual AskUserQuestion confirmation:

- **External system creation operations** (`gh pr create` etc.) — a wrong PR / Issue is expensive to clean up
- **Changes to shared assets** beyond the primary scope (e.g., touching `tsconfig.json` / `README.md` / CI configs as a side-effect while implementing a feature) — surprise edits to shared files are risky to delegate to scope approval alone

All other Tier 2 categories (file/directory deletion within scope, full-file overwrite within scope, destructive shell residuals, `git stash drop` / `clear`, package-manager mutations within scope, local DB schema changes within scope, and unlisted commands whose external-state change is itself part of the authorized scope) **ARE** covered by scope-level approval and may proceed without re-confirmation. Tier 3 is always non-executable regardless of scope.

### When in doubt
When in doubt, do not execute — confirm. The cost of confirmation is small; the cost of mis-operation is large.

Before acting on a diagnosis, check that the evidence supports that specific action — a signal that pattern-matches to a known failure may have a different cause. A Tier 2 approval is not that check: it means the user accepted your stated reason, not that the reason was right.

---

## Reminder on the highest-drift rules

Restated near end-of-file to exploit context-recency. Details in the sections above; this block is intentionally redundant for the rules that drift most.

- **Tier discipline.** Confirm via AskUserQuestion for Tier 2; never execute Tier 3 even when explicitly asked.
- **Prefer built-in `Read` / `Edit` / `Write`** over `cat` / `sed` / heredoc scripts — even though Auto Mode's per-turn directive says the opposite; this preference wins.
