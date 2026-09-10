---
name: systematic-debugging
description: "Root-cause-first debugging: reach the cause fast through evidence, fix at the source, verify. Use for any bug, failing test, or unexpected behavior — before proposing a fix."
---

# Systematic Debugging

## Core principle

This skill has two goals that are really one: fix bugs at their source rather than at their symptoms, and reach that source as fast as possible. Working systematically is not ceremony — it is the shortest evidence-driven path to the cause.

Find the root cause before attempting any fix. The crash site is where a problem becomes visible, not necessarily where it originates — a fix chosen before the cause is understood usually patches the symptom, leaves the defect producing wrong values elsewhere, and costs more time overall through rework. This holds under time pressure too: every guess that misses adds a new variable to untangle, while each piece of evidence — a stack trace read fully, one instrumented run, a bisected test suite — cuts the remaining search space.

Scale the depth to the bug — a one-line typo needs no instrumentation — but keep the order: understand, then hypothesize, then fix.

## Phase 1: Investigate

- Read the error message and the full stack trace. Line numbers, file paths, and error codes often localize the bug outright.
- Reproduce the failure reliably before changing anything. If it won't reproduce, gather more data rather than guessing.
- Check what changed recently: git diff / log, new dependencies, config or environment differences. For a regression with a known-good past state, `git bisect` binary-searches the commit history to the exact culprit commit.
- Trace bad values backward to their origin — what produced this value, what called that, where did it first go wrong. The fix belongs at the origin, not where the error surfaced. `references/root-cause-tracing.md` covers the full technique.
- In multi-component systems (CI → build → signing; API → service → database), don't reason about where it breaks — instrument each boundary (log what enters and exits, verify env/config propagation) and run once so the evidence shows which layer fails.
- At each step, prefer the action that cuts the search space most — one instrumented run that localizes the failing layer, a bisection that halves the candidates — over the action that merely feels productive.

## Phase 2: Compare against what works

Find similar working code in the same codebase and list what differs — including differences that "can't matter" (they often do). When implementing from a reference, read it completely before adapting; partial understanding of a pattern is where subtle bugs come from. Note what the broken path depends on: settings, config, environment, implicit assumptions.

## Phase 3: Hypothesize and test minimally

State the hypothesis concretely — "I think X is the root cause because Y" — then test it with the smallest possible change, one variable at a time. If it is refuted, form a new hypothesis from what you just learned; don't stack another fix on top. When you genuinely don't understand something, say so and keep investigating — a stated unknown is recoverable, a fix built on pretended understanding isn't.

## Phase 4: Fix at the source

1. Write a failing test that reproduces the bug first (red before green) — it proves the diagnosis and keeps the bug fixed. A one-off script works when no test framework exists.
2. Make one change that addresses the root cause. Leave drive-by cleanups and unrelated refactoring out of the same change — they blur what actually fixed it.
3. Verify by running the real test/build command and reading its actual output, and confirm nothing else broke. If verification has to wait on something asynchronous, poll for the condition itself instead of sleeping a fixed time (`references/condition-based-waiting.md`).
4. Once the fix is verified, consider whether the same class of bad data could reach the same failure through another path; if so, add checks at the trust boundaries it would cross (`references/defense-in-depth.md`).

## If fixes keep failing

A failed fix is information: re-investigate with it rather than iterating blindly. After about three failed attempts, the problem is usually not the fix but the design — especially when each fix surfaces a new symptom somewhere else, or a proper fix seems to require massive refactoring. At that point stop and question the architecture with the user instead of attempting fix #4.

## Self-check

The pull toward guessing is strongest exactly when it is most expensive — under time pressure, or when a fix looks obvious. Signs you are skipping investigation:

- "Let me tweak X and see what happens"
- Proposing fixes before tracing where the bad data comes from
- Changing several things at once
- Naming a culprit ("probably the cache") without evidence pointing to it
- Skipping the failing test in favor of a quick manual check

Any of these means: go back to Phase 1.

## When investigation finds no root cause

If the issue is genuinely environmental, timing-dependent, or external: document what you ruled out, implement appropriate handling (retry, timeout, clear error message), and add logging for the next occurrence. Treat this conclusion with suspicion, though — most "no root cause" cases are incomplete investigation.

## Supporting techniques

- `references/root-cause-tracing.md` — follow a bad value upstream from the crash site to where it was first produced
- `references/defense-in-depth.md` — where to add boundary checks once the source fix is in
- `references/condition-based-waiting.md` — wait on the actual condition instead of a fixed sleep
