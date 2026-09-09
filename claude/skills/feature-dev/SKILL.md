---
name: feature-dev
description: "Guided feature development with user checkpoints: discovery → exploration → clarifying questions → architecture options → approval → delegated implementation → multi-lens review → summary. Use whenever the user asks to implement, add, or build a feature, screen, API, or command, or to modify/extend existing behavior — even if they never say the word 'feature'. Not for bug fixes (use systematic-debugging), trivial single-file edits, or explanation-only questions."
argument-hint: Optional feature or change description
---

# Feature Development

Guided workflow for building a feature end-to-end with the user in the loop. "Feature" here means any substantial change — a new capability, or a modification or extension of existing behavior; the phases apply the same way, with exploration centering on the code being changed. Fixing defects is out of scope: bug work needs root-cause analysis first, which is the systematic-debugging skill's job, and this workflow's design-approval gates would only slow it down. The phase order exists because rework is the dominant cost: a wrong assumption caught in the clarifying phase costs one question; the same assumption caught after implementation costs a rewrite. Keep the order, but scale each phase's depth to the size of the feature — a small change may compress phases to a few sentences each. Compression is per phase, not per session: each implementation unit — including a second feature or an ad hoc addition started after the first one is finished — gets its own Phase 4 approval and Phase 6 review, and a QA or hands-on check confirms behavior but is not the review. This text is read once at invocation, so later units are where it is easiest to forget.

Phase names and numbering match the official `feature-dev` plugin so the two stay comparable; the behavior inside each phase follows this environment's rules instead (design on main, execution delegated).

This skill defines the workflow only. Delegation mechanics, agent routing, model selection, and question etiquette all follow the global rules (CLAUDE.md + agent descriptions); do not re-derive them here.

Feature request: $ARGUMENTS

## Phase 1 — Discovery

Goal: understand what needs to be built.

If the request is unclear — what problem it solves, for whom, and under what constraints — ask before spending exploration effort. Summarize your understanding and confirm it when the request left real room for interpretation.

## Phase 2 — Codebase Exploration

Goal: understand the ground the feature stands on before deciding anything.

- Dispatch read-only exploration subagents in parallel, one per distinct lens rather than a fixed count: similar existing features, architecture and abstractions of the affected area, integration points and conventions (tests, error handling, naming). One lens suffices for a small change; three for a sizable feature.
- Ask each agent to return findings plus the handful of decision-critical files, with file:line references.
- Trust the summaries. Read only the few files whose details actually determine the design decision — main context is for deciding, not archiving everything the agents saw.

**Example lens prompts:**
- "Find features similar to [feature] and trace their implementation end to end"
- "Analyze the current implementation of [the feature/area being changed] and trace how it works today"
- "Map the architecture and abstractions of [affected area], including how its layers interact"
- "Identify the conventions [feature] must follow: testing approach, error handling, naming, extension points"

Present a brief synthesis: what exists, and which patterns the feature should follow.

## Phase 3 — Clarifying Questions

Goal: resolve ambiguities while they are still cheap.

From the findings and the original request, collect what is underspecified — edge cases, error handling, scope boundaries, backward compatibility, performance needs — and ask, with your recommended option listed first. If the user answers "whatever you think is best", state your recommendation and get explicit confirmation; silent defaults here are what implementation-phase rework is made of.

Skip this phase only when genuinely nothing is ambiguous, which is rare for anything worth this workflow.

## Phase 4 — Architecture Design (on main)

Goal: an architecture decision the user has actually chosen.

Design on main; do not delegate the design itself. When trade-offs are real, draft 2–3 approaches with different centers of gravity — minimal change, clean abstraction, pragmatic middle. For small features a single approach is fine, but say so rather than manufacturing alternatives.

Optionally dispatch a critique-only reviewer against the draft: fresh context finds the gaps the author cannot.

Write the approaches, trade-offs, and recommendation to `docs/plans/<YYYY-MM-DD>-<slug>.md` before presenting them — a plan that lives only in the conversation is sometimes never shown to the user, and the file is what they review and what later dispatches quote. Then present the summary per approach with your recommendation and reasoning, and ask which approach the user wants. Implementation starts only after that choice — the approval is the point of the phase, not a formality.

## Phase 5 — Implementation (delegated)

Goal: build the chosen design.

- Split the work into implementation units and dispatch implementer subagents, parallel with worktree isolation where units are independent.
- Each dispatch prompt carries the decisions already made: the chosen approach, target files, conventions found in Phase 2, and the required evidence format (files changed, checks run and their output).
- Main integrates the results and performs the final stitching edits. Confirm completion from the evidence, not from a prose "done".

## Phase 6 — Quality Review

Goal: correctness and quality confirmed before declaring victory.

- Dispatch reviewers in parallel with distinct lenses — correctness/bugs, simplification/DRY, project conventions — plus test verification: run the existing tests and check that the behavior this feature introduced is covered, reporting gaps as findings. An area with no tests is where coverage is missing, not a reason to skip the lens. Distinct lenses catch what identical reviewers merely duplicate.
- Have reviewers report only issues they would stake high (≥80/100) confidence on; triaging false positives costs more than it saves.
- Present the consolidated findings and ask whether to fix now, defer, or ship as-is; act on the answer. This is a scope decision, not a reversible default: fixing silently widens the change the user approved in Phase 4, and shipping silently discards findings they never saw — so the question stands even when every fix looks safe.

## Phase 7 — Summary

Goal: a clear record of what happened.

Summarize: what was built, key decisions made, files touched, and suggested next steps.
