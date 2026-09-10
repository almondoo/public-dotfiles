# Research findings behind merge-conflict-resolution

Source: deep-research run 2026-08-05 (103 agents; claims extracted from fetched
sources, each verified by a 3-vote adversarial panel — vote shown per finding).
Confidence: high = primary sources + clean votes; medium = preprint or single
source. Findings the panel refuted are listed at the bottom — do not cite them.

## Confirmed findings

### Conflict markers (high, 3-0 / 2-1)
Standard markers are `<<<<<<<` (ours side) / `=======` / `>>>>>>>` (theirs
side); the part before `=======` is your side, after is their side. Marker
length is configurable via `--marker-size` (passed to merge drivers as `%L`).
Sources: https://git-scm.com/docs/git-merge-file, https://git-scm.com/docs/git-merge

### diff3 / zdiff3 conflict style (high, 3-0 ×3, 2-1 ×1)
`diff3` style adds a `|||||||` marker with the common-ancestor text before
`=======`. Configure via `merge.conflictStyle` (default `merge`); apply one-off
with `git checkout --conflict=diff3 <path>`. `zdiff3` (Git 2.35+) additionally
moves lines matching on both sides out of the conflict region at its edges.
Seeing the base is what lets a resolver determine which side changed what.
Sources: https://git-scm.com/docs/merge-config, https://git-scm.com/docs/git-merge,
https://git-scm.com/book/en/v2/Git-Tools-Advanced-Merging

### Merge strategies (high, 3-0 ×2)
`ort` is the default strategy for single-branch merges/pulls (replaced
`recursive` in v2.33.0). `recursive` is a plain synonym for `ort` since
v2.50.0. Sources: https://git-scm.com/docs/git-merge,
https://git-scm.com/docs/merge-strategies

### -X ours / -X theirs vs the ours strategy (high, 3-0 ×3)
`-X ours` / `-X theirs` (options to `ort`) auto-resolve only conflicting hunks
in favor of one side; non-conflicting changes still merge normally. The `ours`
merge *strategy* is entirely different: it ignores the other tree's contents
completely — the docs explicitly warn against confusing the two. `-X
renormalize` virtually checks out/in all three stages to resolve conflicts
caused by line-ending normalization. Sources:
https://git-scm.com/docs/merge-strategies, https://git-scm.com/docs/git-merge

### git rerere (high, 3-0 ×2)
Records the pair (conflicted automerge state, manual resolution); on
recurrence, replays via a three-way merge between old automerge, old
resolution, and new automerge. Conflict IDs are hashed after normalization
(labels stripped, diff3 ancestor section removed, hunks sorted), so merge
order and marker style don't defeat recognition. Useful for long-lived
branches and repeated rebases. Note: simplified claims about *how rerere is
enabled* were refuted (below) — check current docs before stating activation
semantics. Sources: https://git-scm.com/docs/rerere,
https://git-scm.com/docs/git-rerere

### File-level mechanical resolution (high, 3-0 ×2)
`git merge-file` supports `--ours` / `--theirs` / `--union` auto-resolution.
The built-in `union` merge driver (gitattributes) keeps lines from both sides
without markers, but the docs warn the resulting line order can be random and
the user should verify — suitable for append-only files only, never a blanket
default. Sources: https://git-scm.com/docs/git-merge-file,
https://git-scm.com/docs/gitattributes

### Custom merge drivers (high, 3-0)
Defined via gitattributes (`*.c merge=filfre`) plus `[merge "filfre"] driver =
filfre %O %A %B %L %P` — placeholders: %O ancestor, %A current, %B other, %L
marker size, %P pathname. The official hook for systematizing per-file-type
strategies (e.g. regenerate lockfiles). Source:
https://git-scm.com/docs/gitattributes

### LLM-based resolution accuracy (medium — 2026 preprints)
- MergeGen (LLM-based) beats search-based SBCR on 2,439 Java conflicts: 55%
  exact match vs 19.6%, median similarity 100% vs ~80%. Authors still
  recommend routing by conflict characteristics (hybrid meta-resolver), and
  note possible training-data memorization. Source:
  https://arxiv.org/html/2605.16646v1
- Merge-Bench (11 languages, 1,439 repos, ~7,938 hunks): best commercial model
  (Gemini 2.5 Pro) achieves 54.7% exact / 62.5% source match — **under 60%
  correct**. An independent Java study reports ~55% agreement, consistent.
  Implication: LLM resolutions disagree with the developer's actual resolution
  40%+ of the time → build/test/diff verification is mandatory, not optional.
  Sources: https://arxiv.org/pdf/2605.25890, https://arxiv.org/abs/2607.27674

## Refuted during verification — do not assert these

- "rerere automatically records and reapplies resolutions" (1-2) — the
  unqualified "automatic" framing failed verification.
- "rerere is off by default and must be enabled via `rerere.enabled true`"
  (0-3, 1-2) — activation semantics are more nuanced (rr-cache presence also
  matters); verify against current docs before writing setup steps.
- "Committing .gitattributes overrides per-user core.autocrlf and prevents
  line-ending conflicts" (1-2) — overstated; don't cite as-is.

## Known gaps (not covered by verified findings)

- Lockfile-regeneration recipes (e.g. npm v7+ automatic lockfile conflict
  resolution) — widely practiced but not verified against ecosystem docs here.
- Conflict *prevention* practices (small PRs, frequent base sync, trunk-based
  development) — no primary-source backing obtained in this pass.
- `git mergetool` workflow and GitHub Web UI resolution.
- Index stage (1/2/3) formal semantics for state-transition commands
  (`checkout --ours/-m`, `merge --abort`) — the skill uses the common
  behaviors; primary-source confirmation pending.

Treat items in this section as "generally known practice" and label them as
such if the user asks for authority.
