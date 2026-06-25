# dotfiles repository

Instructions for Claude when working inside this repository.

A Japanese version of this file is available at `CLAUDE-ja.md` for reference.
The English version (this file) is the source of truth.

## What this repository is

macOS dotfiles. Contents under `.claude/` are deployed to `~/.claude/`
(user-level Claude Code configuration) via symlinks managed by `install.sh`.

## Important rules

- **Do NOT apply the contents of `.claude/CLAUDE.md` as instructions for
  working in this repository.** That file is the source of truth for the
  user-level operating rules at `~/.claude/CLAUDE.md`; it is not a guide
  for maintaining this repo.
- **Editing anything under `.claude/` affects every project on this
  machine.** Treat such edits with Tier 2 care (per the user-level CLAUDE.md
  shared-assets rule): always review the diff before committing.
- When the user says "edit CLAUDE.md", confirm which file they mean:
  - `CLAUDE.md` at the repo root → this file (dotfiles working rules)
  - `.claude/CLAUDE.md` → user-level global instructions (affects all projects)
- When adding a new symlink target, update BOTH `install.sh` and
  `uninstall.sh`. Updating only one leaves orphans on uninstall.
- `CLAUDE-ja.md` (both this directory and `.claude/`) is for Japanese
  reference only and is NOT symlinked. Do not add it to `install.sh` or
  `uninstall.sh`.
- Never commit credentials or runtime data. When changing `.gitignore`,
  always verify exclusions with `git status` before `git add`.

## Git workflow

- Make commits on the `develop` branch, not directly on `main`. `main` is
  updated through pull requests, not direct commits.

## Verification commands

- Idempotency check: running `./install.sh` twice must not produce errors
  or unexpected diffs.
- Pre-commit check: use `git status` and `git diff --cached --stat` to
  confirm that excluded paths (`projects/`, `.credentials.json`, etc.) are
  not staged.
