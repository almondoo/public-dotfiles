---
name: merge-conflict-resolution
description: Safely resolve and integrate Git merge conflicts (merge/rebase/cherry-pick) — file-type classification, mechanical resolution for lockfiles/generated/binary files, semantic 3-way resolution for source code, and mandatory post-resolution verification.
disable-model-invocation: true
---

# Merge Conflict Resolution

A workflow for resolving Git merge conflicts safely. Grounded in a verified
research pass (2026-08, adversarially fact-checked against git-scm.com docs and
2026 empirical studies) — see `references/research-findings.md` for the full
findings with citations.

The core fact that shapes this workflow: **even the best LLMs resolve fewer than
60% of real-world merge conflicts to the resolution the developer actually
chose** (Merge-Bench, 2026). Your semantic resolution is a *proposal*, not a
fact. Therefore: resolve mechanically where a deterministic rule exists, reason
carefully where it doesn't, and always verify before declaring done.

## Step 1: Assess the situation

Before touching any file, understand what you are in the middle of:

1. `git status` — list unmerged paths and identify the in-progress operation
   (merge, rebase, or cherry-pick).
2. Know which side is which. In conflict markers, the part before `=======` is
   "ours" (HEAD) and the part after is "theirs". **During a rebase this is
   inverted from intuition**: HEAD is the branch you are rebasing *onto*, so
   "ours" = the upstream base and "theirs" = your own commits being replayed.
   Misreading this picks the wrong side with full confidence — state explicitly
   which branch each side refers to before resolving.
3. Get the common ancestor into view. The default conflict style shows only the
   two sides; you cannot tell what either side *changed* without the base.
   Read all three versions from the index when needed:
   `git show :1:<path>` (base), `:2:` (ours), `:3:` (theirs).
   Alternatively re-checkout a file with ancestor markers:
   `git checkout --conflict=zdiff3 <path>` (Git 2.35+; use `diff3` on older
   Git). Seeing the base tells you which side changed what — the single most
   useful input for a correct resolution.

## Step 2: Classify each conflicted file

Different file types have different correct strategies. Do not hand-merge what
should be regenerated.

| File type | Strategy |
|---|---|
| Lockfiles (`package-lock.json`, `Cargo.lock`, `poetry.lock`, …) | Do not hand-edit. Take one side (`git checkout --theirs <path>` or `--ours`), then re-run the package manager so the lockfile is regenerated against the merged manifest. Verify the manifest (`package.json` etc.) is resolved first. **If regeneration is impossible in the current environment, still take one side wholesale and stop there** — never hand-assemble entries from both sides' hunks. A hand-merged lockfile is worse than a stale one: it asserts a dependency resolution the package manager never computed (missing transitive updates, unverified integrity data), and it *looks* done, so nobody regenerates it. |
| Generated files (build output, codegen, snapshots) | Resolve the *source* of the generation, then regenerate. Never merge generated content by hand. |
| Binary files | No textual merge exists. Decide which side is correct from the branch context and take it with `git checkout --ours/--theirs <path>`. If unclear, ask the user — a silent wrong pick is unrecoverable by review. |
| Append-only text (CHANGELOG, translation catalogs) | Usually both sides' lines should survive. Merge both, but check ordering yourself — union-style merging is documented to leave lines in unpredictable order. |
| Source code | Semantic 3-way resolution — Step 3. |

Note on `-X ours` / `-X theirs`: these strategy *options* auto-resolve only the
conflicting hunks in favor of one side (non-conflicting changes from both sides
still land). Do not confuse them with the `ours` merge *strategy*, which
discards the other branch's tree entirely — the official docs themselves warn
about this confusion. Use `-X` variants only when one side is genuinely
obsolete wholesale, and say so out loud.

## Step 3: Resolve source conflicts semantically

For each conflicted hunk in source code:

1. Read base, ours, and theirs. State (to yourself, and in the summary to the
   user) what each side's *intent* was: "ours renamed the parameter, theirs
   added null-handling".
2. Produce a resolution that **integrates both intents** wherever they are
   compatible. Picking one side is only correct when the other side's change is
   genuinely superseded — and that is a judgment to flag, not to bury.
3. Watch for conflicts whose sides are textually different but semantically
   equivalent (both fixed the same bug differently) — pick the better one,
   don't stack both.
4. If both sides changed the same logic incompatibly and the right merge is not
   determinable from the code, stop **before writing any resolution**: present
   the options (side A, side B, and any combined design you are considering)
   and ask the user to choose. Do not invent a new design that accommodates
   both sides and present it as the resolution — a written resolution reads as
   a decision already made, and asking for confirmation afterwards anchors the
   user to your invention. This is exactly the class of conflict where
   automated resolutions are measured to fail most; the deliverable here is
   the question, not a merge. Be strict about what counts as "determinable":
   a comment, commit label, or ticket reference on ONE side is that side's
   *claim*, not proof it supersedes the other — proof of supersession requires
   evidence the other side's change was seen and deliberately replaced (the
   base version, or history showing one change reverting the other), which a
   one-sided annotation can never provide. When the only signal favoring a
   side is its own comment or branch name, the case is still undeterminable:
   ask.

## Step 4: Verify — non-negotiable

A resolution is not done when the markers are gone. In order:

1. **Marker sweep**: `git diff --check` and a search for `<<<<<<<` / `=======`
   / `>>>>>>>` across the resolved files. Leftover markers are the most common
   silent corruption.
2. **Machine checks**: run the project's build / type-check / lint / tests —
   whatever exists. A merge that compiles both sides' changes but breaks their
   interaction is caught here or not at all.
3. **Semantic diff review**: review `git diff` of the staged resolution against
   both parents (e.g. `git diff HEAD -- <path>` and `git diff MERGE_HEAD --
   <path>` during a merge). Confirm nothing from either side was silently
   dropped.
4. **Report**: summarize per file which strategy was used and which hunks
   involved judgment calls, so the user can spot-check the risky ones instead
   of re-reviewing everything.

## Step 5: Finish

- `git add` the resolved files. Follow the repository's workflow rules for
  whether to run `git merge --continue` / `git rebase --continue` or commit —
  and do not commit if the project rules or the user haven't sanctioned it.
- Never run `git merge --abort`, `git rebase --abort`, or any `reset --hard`
  on your own initiative — those discard state the user may want. Propose,
  don't execute.

## Recurring conflicts — point the user at tooling

If the same conflict keeps reappearing (long-lived branches, repeated rebases),
mention the built-in machinery instead of re-resolving by hand every time:

- `git rerere` — records a resolution and replays it when the identical
  conflict recurs (order- and style-insensitive via conflict normalization).
  Check the current docs for activation details before recommending exact
  config (`rerere.enabled` semantics have edge cases).
- Custom merge drivers via `.gitattributes` + `[merge "<name>"]` config — the
  official mechanism for systematizing per-file-type strategies (e.g. always
  regenerate lockfiles). See `references/research-findings.md` for the
  placeholder interface (%O %A %B %L %P).

## References

- `references/research-findings.md` — the verified research findings behind
  this skill: claim-by-claim citations (git-scm.com, arXiv 2026), what was
  refuted during verification, and open questions. Read it when you need the
  primary-source wording or when a claim here seems off for the user's Git
  version (e.g. `recursive` became a synonym of `ort` in v2.50.0).
