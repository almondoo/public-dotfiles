---
name: rule-creator
description: >-
  Create, revise, or review Claude Code .claude/rules/ files following
  official best practices (correct paths: scoping, fact-not-procedure
  content, verified loading). Invoke explicitly with /rule-creator when
  working on .claude/rules/.
disable-model-invocation: true
---

# Rule Creator

Create `.claude/rules/*.md` files that actually load when intended and stay
cheap in context. The format is trivial; the value of this skill is the
classification, placement, and verification discipline around it.
For review-only requests ("この rules をレビューして"), apply §1–§6 as an
audit checklist without rewriting, and report per §7's review-only variant.

## 1. Classify before writing — the "don't create a rule" checks

Rules are for **facts, normally scoped to paths** (unscoped only when the fact
is path-free, must be present continuously, or governs creation in a place
nothing gets Read first — §5–§6). Route everything else away first:

- **Procedure, checklist, workflow** (multi-step "how to do X") → belongs in a
  skill, not a rule. Official criterion (code.claude.com/docs/en/skills):
  create a skill "when a section of CLAUDE.md has grown into a procedure
  rather than a fact". Procedures usually carry standing facts inside them
  (a naming convention, "destructive changes go in two migrations", an
  invariant) — pull those out too, so they exist even if the skill is never
  invoked, and place each like any other fact: path-bound → the
  `paths:`-scoped rule for that topic (if it governs *creating* files, §6
  decides the scope and whether it must be unscoped); path-free → an
  unscoped rule for that topic, or root CLAUDE.md if needed in every
  session. The skill keeps the steps; the rule keeps the facts.
- **Fact needed in every session** (build commands, repo-wide conventions) →
  root CLAUDE.md (keep it under 200 lines).
- **Zero-exception prohibition on an action Claude takes** — editing or
  reading a protected path, running a command, committing without tests
  ("never edit .env", "existing migrations are append-only") → write BOTH:
  the fact as a rule (so Claude knows the convention and can explain it), AND
  an enforcement recommendation in the report's "Routed away" section. Rule
  text is advisory; a prohibition that lives only in a rule is a wish, not a
  guarantee. What blocks the action at the tool layer: a `permissions.deny`
  entry in settings.json when the target is a static path or command pattern
  (`Read(.env*)`, `Edit(.env*)`) — simplest, prefer it; a PreToolUse hook
  when the block needs logic a pattern cannot express ("existing files only"
  under `prisma/migrations/**`, "no commit unless tests ran"). Both act on
  the tool calls they match — deny covers the built-in file tools and the
  Bash file commands Claude Code recognizes, a hook covers whatever its
  script checks — and neither catches arbitrary subprocesses or path
  indirection, so say "blocks the direct route", not "guarantees". Recommend
  whichever fits; do not present the hook as the only option. The official
  "migrations are append-only fits best as a rule" example describes the
  documentation half — it does not make enforcement unnecessary. Where that
  documentation half goes: a *read* prohibition (`.env*`) must be unscoped
  or in root CLAUDE.md — scoped to `.env*` it could never fire, because the
  deny blocks the very Read that would load it. An *edit* prohibition can be
  scoped to the file's own glob (the Edit tool Reads first; a Bash `sed -i`
  bypasses that, same limit as above); if it also governs creation under
  that path, §6 sets the glob.
- **Zero-exception prohibition on how code is written** ("offset
  ページネーション禁止", "inline style 禁止") → an ordinary convention: rule
  only, no hook line, however absolute the wording. A hook is an arbitrary
  command and could shell out to a linter, but a hook that re-implements the
  linter's job is redundant with the lint/CI step the repo should already
  have; the right enforcement for code style is a lint rule, and that is
  outside this skill. So: the rule documents the convention; if the repo
  obviously already has a matching lint rule, say so in one clause inside the
  rule bullet ("ESLint no-restricted-syntax で検出される"); if it has none,
  add one line under "Routed away" — "<convention> → lint rule if enforcement
  is wanted; the rule alone is documentation" — or, when a linter plainly
  cannot detect the pattern (a semantic rule like "no offset pagination"),
  name the review or test check that would; and write nothing more.
- **Fact tied to specific paths or file types** → this is what rules are for.

Why this matters: unscoped rules cost the same as CLAUDE.md (loaded every
session AND re-injected from disk after every compaction). A rule that
shouldn't exist is a permanent tax.

**Confirm before overriding the request.** When the classification above
would route away something the user asked to put in a rule — a procedure,
an every-session fact, the enforcement half of a prohibition, a whole
migration of nested CLAUDE.md content — do not silently apply the routing.
Before writing anything, ask once via `AskUserQuestion`, one question per
routed item (or one multi-select question when several items share the
same destination): state the item and where it should go instead, with the
recommended routing as the first option and "put it in the rule anyway" as
the second. Then honor the answer: a "rule anyway" answer means the item is
written into the rule verbatim and the "Routed away" section of the §7
report records it as user-overridden, not re-argued. Items the user never
mentioned (facts you pulled out of a procedure, enforcement you recommend on
your own initiative) need no question — they only appear in the report.
If `AskUserQuestion` is unavailable (subagent execution), apply the default
routing and flag each unasked item in the report as "unconfirmed routing".

## 2. Placement

- Repo-specific convention → `<repo>/.claude/rules/<topic>.md` — one topic per
  file, descriptive filename (`testing.md`, `api-design.md`).
- Convention owned by one directory's maintainers, versioned with its code →
  nested `<dir>/CLAUDE.md` instead of a central rule (official decision
  table). Reserve `.claude/rules/` for conventions kept in one place or
  spanning scattered paths. This is a default, not a veto: when the user
  explicitly asks to convert a nested CLAUDE.md into rules (or the reverse),
  do it, and mention the trade-off in one line at most.
- Convention shared across the user's repositories → a shared directory
  symlinked into each repo (e.g. `ln -s ~/shared-claude-rules
  .claude/rules/shared`). Ask before creating the shared directory if it
  doesn't exist yet.
- Prefer project-level for `paths:`-scoped rules. User-level `~/.claude/rules/`
  `paths:` scoping has unresolved bug reports (anthropics/claude-code#21858,
  #19377); if used, verify with `/context`. User-level rules load before
  project rules; project rules take priority (both still load; see §4 on why
  to remove contradictions rather than rely on this).

## 3. Fetch the current spec — never write frontmatter from memory

Before writing any `paths:` frontmatter — and when reviewing existing
frontmatter — fetch https://code.claude.com/docs/en/memory.md and check
against the current documented syntax. Once per session is enough; reuse the
fetched text for every rule you write in that session. The `paths:` format has changed repeatedly (YAML-list support only
since v2.1.84; symlink handling since v2.1.198) and stale knowledge produces
rules that silently never load.

## 4. Content discipline

Read `references/what-to-write.md` (same directory as this file) for the full
content prescription: the official category taxonomy, the exclusion table,
style guidance, and verbatim official rule templates. Summary:

- One topic per file. There is no official per-file limit; use the
  CLAUDE.md 200-line guidance as a proxy and stay far under it — a topic that
  needs anywhere near that is usually a procedure (→ skill).
- Facts only, stated concretely and verifiably ("Use 2-space indentation",
  not "format code properly"). No tutorials, no API docs (link instead),
  nothing derivable from the code itself.
- Write in the language of the repo's existing CLAUDE.md / rules (Japanese
  CLAUDE.md → Japanese rule), keeping identifiers and technical terms as-is.
  If the user asks for a different language, say once that it will differ
  from the existing files and then do as asked.
- Per line, apply the removal test: would deleting this cause Claude to make
  mistakes? If not, cut it.
- Check for contradictions before finishing: grep the repo's existing
  `.claude/rules/`, all CLAUDE.md files, AND user-level `~/.claude/rules/`
  for overlapping topics. Load order gives project rules priority over
  user-level ones (§2), but both texts are still in context and advisory,
  so on a real contradiction which one Claude follows is not guaranteed —
  remove the conflict rather than rely on precedence.

## 5. Scoping discipline

- Scope `paths:` globs to the narrowest set the convention truly governs. A
  glob matching most files a session touches costs nearly the same as an
  unscoped rule: once triggered, the rule sits in message history like any
  other content until the next compaction.
- Compaction trade-off: a scoped rule is summarized away at `/compact`. It is
  restored immediately only if its trigger file is among the up-to-5 most
  recently modified session files that compaction re-reads
  (code.claude.com/docs/en/context-window); otherwise it comes back the next
  time Claude reads a matching file, as at any other point in the session. So
  the gap is "between compaction and the next matching Read", not permanent.
  If the rule must be present continuously (a long-session invariant), leave
  it unscoped or fold it into root CLAUDE.md — official guidance.
- One exception to "narrowest glob": a rule that governs newly *created*
  files must also cover the file normally Read or edited right before the
  creation, even if the convention does not govern that file (migration
  facts → `prisma/**` so the `schema.prisma` edit loads them, not
  `prisma/migrations/**`). §6 has the full Read-not-Write decision.

## 6. Pitfalls that make rules silently miss or misfire

- Rules trigger on **Read, not Write**: a rule meant to govern newly
  generated files may never fire during generation. This is documented
  behavior ("trigger when Claude reads files matching the pattern"); the bug
  report asking to change it (anthropics/claude-code#23478) was stale-closed
  not_planned. So a scoped rule about file creation is only as good as the
  Read that precedes the creation. Decide as follows:
  - a Read under the glob normally precedes the creation (editing
    `schema.prisma` before a migration is generated; reading an existing
    handler before adding one) → keep it scoped, with the glob widened per
    §5, and report the caveat;
  - no such precursor Read (a new or empty directory, nothing related edited
    first) → an unscoped rule, root CLAUDE.md, or the task prompt;
  - the fact must be present continuously → an unscoped rule or root
    CLAUDE.md only (a task prompt does not survive compaction).
  A rule that prohibits editing existing files under a path ("migrations are
  append-only") also governs creation under that path — the new file lands in
  the same glob, but writing it does NOT load the rule; only a prior Read of
  an existing sibling does, and nothing guarantees that happened — so it gets
  the same caveat; do not mark it "n/a", and never report that a scoped rule
  "loads automatically" when a new file is created.
- Path scoping has an open report of being ignored entirely, loading all
  rules at startup (anthropics/claude-code#16299). Never assume scoping
  worked — verify (step 7).
- Brace groups in `paths:` multiply combinatorially
  (`{a,b}/{c,d}/*.{ts,tsx}` = 8 patterns); one rule's list is budgeted at
  1,000 expanded patterns / 4 MiB. Over budget, a pattern is used unexpanded
  and its literal braces match no files — silently.
- A `[` starts a glob bracket expression; a `[` that can't parse as one
  makes the pattern match nothing — silently. Escape a literal bracket
  (`photos \[2024/**`).
- Built-in Explore and Plan subagents skip CLAUDE.md and rules entirely. A
  rule meant to steer research/planning delegation must be restated in the
  delegation prompt. (Non-fork custom subagents do receive rules.)

## 7. Verify and report

After writing:

1. Tell the user to run `/context` and check the **Memory files** list to
   confirm the rule loads (or stays out of context) as intended. For a
   `paths:`-scoped rule: have Claude read a matching file first, THEN check
   `/context` — a scoped rule absent at session start is expected behavior,
   not a failure. This check is for rules and CLAUDE.md only: a skill you
   created alongside is not a memory file and will not appear there, so do
   not send the user looking for it in `/context`.
2. Report in this shape. "Routed away" and "Loading caveats" are mandatory
   even when the answer is "none" — a classification that stays in the
   model's head never reaches the user. "Verify" restates item 1:

   ```
   Created / updated:
   - .claude/rules/<file>.md  (paths: <globs> | always-on)  — <topic>

   Routed away from rules (§1):
   - <item> → skill / permissions.deny / hook / lint rule / root CLAUDE.md /
     task prompt, because <one clause>  [confirmed | user-overridden:
     kept in rule | unconfirmed routing]
     (write "none" if nothing was routed away)

   Loading caveats for the user (§5–§6):
   - Read-not-Write: <which rule will not fire while creating new files, and
     what to do about it>  (or "n/a: no rule governs file creation")
   - anything else from §5–§6 that applies (compaction, subagents, glob traps)

   Verify: <the /context steps from item 1>
   ```

   When the user explicitly asked for a procedure, or for a zero-exception
   constraint on an action Claude takes, to be put *in rules*, the §1
   confirmation question is where they decide, and the "Routed away" section
   is where the decision is recorded — list the item there even when they
   chose "rule anyway", and even when you also wrote the convention part as
   a rule. Code-style prohibitions (§1's second zero-exception bullet) stay
   in the rule and get no hook line.

In review-only mode there is nothing to verify-load: skip step 1, drop the
"Verify" line, and use this variant of the template — "Findings per file"
replaces "Created / updated"; "Routed away from rules (§1)" keeps its name
and lists what should move out of rules; "Loading caveats for the user
(§5–§6)" is unchanged. Those two sections stay mandatory for the same reason: a review is
exactly where "this bullet should be a hook" is noticed and then buried in
prose.
