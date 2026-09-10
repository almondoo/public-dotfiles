# What to write in .claude/rules/ — content prescription

Verified against official sources (code.claude.com/docs memory / large-codebases /
features-overview / best-practices, and the "Steering Claude Code" blog post),
cross-checked 2026-08. Read this when deciding WHAT goes into a rule file, not
just where it goes.

## Content taxonomy — categories officially named for rules

Officially named rule topics (docs' own example filenames and prose):

| Category | Official evidence |
|---|---|
| Code style guidelines | `code-style.md` in the docs' example tree |
| Testing conventions | `testing.md` (example tree + "descriptive filename" sentence) |
| Security requirements | `security.md` in the docs' example tree |
| API development conventions | The docs' only full rule-body example: input validation required, standard error format, OpenAPI doc comments — scoped to `src/api/**/*.ts` |
| Language- or directory-specific guidelines | features-overview's "Best for" cell for rules |
| File-specific constraints | Blog: "A file-specific constraint, like 'migrations are append-only,' fits best as a rule" — as *documentation* of the constraint; enforcement is separate, see the Zero-exception row below and SKILL.md §1 |
| Personal preferences / personal workflows | User-level `~/.claude/rules/preferences.md`, `workflows.md`. Usually path-free facts, so usually unscoped; a `paths:`-scoped user-level rule is allowed but must be verified with `/context` (SKILL.md §2) |

The CLAUDE.md include-list also applies (rules are path-scoped CLAUDE.md content,
not a different content type): style rules that differ from defaults, testing
instructions and preferred runners, repository etiquette, project-specific
architectural decisions, environment quirks, non-obvious gotchas.

## What NOT to write in a rule

| Content | Route to | Why (official) |
|---|---|---|
| Multi-step procedures, checklists, runbooks | skill | "Procedures belong in skills"; rules docs: task-specific instructions → skills |
| Facts needed in every session, not path-bound | root CLAUDE.md | Rules exist to be conditionally loaded |
| Zero-exception constraints on an *action Claude takes* ("never edit .env", "never run X") — the *enforcement* | `permissions.deny` for static path/command patterns, PreToolUse hook when logic is needed (and keep the one-line fact in a rule). Code-style prohibitions ("offset 禁止") are ordinary conventions: rule only, lint rule if enforcement is wanted (SKILL.md §1) | Rules are "context, not enforced configuration"; deny entries and hooks act deterministically on the tool calls they match (not on arbitrary subprocess / path-indirection routes) |
| Anything derivable from the code | nowhere | "Anything Claude can figure out by reading code" is excluded |
| API documentation dumps | link instead | "Detailed API documentation (link to docs instead)" |
| Frequently changing information | nowhere / live fetch | Goes stale; docs exclude it |
| Standard language conventions, self-evident practices | nowhere | Claude already knows them |

## Writing style (officially cross-referenced from CLAUDE.md guidance)

The rules docs have no dedicated style section — they explicitly defer to the
CLAUDE.md "Write effective instructions" guidance, whose consistency bullet
names `.claude/rules/` directly. Apply all of it:

- **Concrete and verifiable**: "Use 2-space indentation", not "Format code
  properly". Prohibitions should name the exact APIs/patterns banned
  (e.g. `$queryRaw` / `$executeRawUnsafe`), not just the concept.
- **Structure**: markdown headers + bullets; no dense paragraphs.
- **Removal test per line**: would deleting this cause mistakes? If not, cut.
- **Emphasis**: "IMPORTANT" on at most the one line Claude keeps skipping.
- **Consistency**: before finishing, check the new rule against every
  CLAUDE.md (root + nested) and existing rules — contradictions make Claude
  pick one arbitrarily.
- **Size**: no official per-rule-file limit exists. Use the CLAUDE.md
  discipline as proxy: a rule file should be far under 200 lines; if one
  topic needs more, the topic is probably a procedure (→ skill) or reference
  material (→ skill supporting file).

## Granularity and naming

- One topic per file — the only granularity rule stated for rules.
- Descriptive filenames; official examples are kebab-case topic names
  (`code-style.md`, `api-design.md`, `testing.md`, `security.md`).
- Subdirectories are sanctioned for organization (`frontend/`, `backend/`);
  discovery is recursive.
- Unscoped vs `paths:`-scoped is the primary axis: unscoped = always loaded
  (CLAUDE.md-priority) — reserve for rules that must survive `/compact`
  (long-session invariants), are truly path-free facts, or govern creating
  files in a place where nothing under the glob is normally Read first
  (Write-trigger gap, SKILL.md §5–§6); scoped = everything else, including
  creation conventions where a matching Read normally precedes the Write —
  keep those scoped and report the caveat.

## Official templates (verbatim from docs/blog — copy the shape, not the language: write the body in the repo's existing language per SKILL.md §4)

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Development Rules

- All API endpoints must include input validation
- Use the standard error response format
- Include OpenAPI documentation comments
```

```markdown
---
paths:
  - "src/api/**"
  - "**/*.handler.ts"
---
All API handlers must validate input with Zod before processing.
```
