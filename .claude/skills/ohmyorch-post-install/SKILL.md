---
name: ohmyorch-post-install
description: Adapt an installed OhMyOrch harness to the current repository by backing up .claude and project guidance, then generating namespaced .claude/rules plus README.md, CLAUDE.md, and evidenced nested CLAUDE.md guidance from CODEBASE.md, PRD.md, and SPECS.md. Use after installing the harness or when the user says "post install", "adapt OhMyOrch", or "generate project rules".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
license: MIT
compatibility: Requires .claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh. No network access.
metadata:
  author: claude-harness
  version: "1.0"
argument-hint: "[--dry-run] [--mode create-only|merge|override] [--nested]"
---

Adapt the installed OhMyOrch harness to the current repository.

This skill is for the **post-install** step: it reads the current `CODEBASE.md`,
`PRD.md`, and `SPECS.md`, creates a verified backup under
`docs/pre-install-backup/<timestamp>/`, then generates repository-specific guidance
for future Claude Code sessions.

## Step 1 — Dry run first

Always start with a dry run:

```bash
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh --dry-run "$ARGUMENTS"
```

Report:

- the repository root;
- which source artifacts were found;
- which files would be written or skipped;
- whether nested `CLAUDE.md` files would be created;
- the write mode.

If the user asked only to preview, stop here.

## Step 2 — Run the adaptation

Use the same arguments without `--dry-run`:

```bash
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh "$ARGUMENTS"
```

Common modes:

```bash
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh --mode merge
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh --mode create-only
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh --mode override --nested
```

`merge` is the default. It preserves existing unmanaged content and appends or
replaces only OhMyOrch-managed blocks. `create-only` refuses existing docs.
`override` replaces selected files, but only after the backup verifies.

`--nested` enables generation of nested `CLAUDE.md` files for top-level directories
that are explicitly evidenced in `CODEBASE.md`. Without that flag, nested files are
planned but not created.

## Step 3 — Validate

After the script succeeds, run:

```bash
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
```

Run `scripts/run-project-validation.sh --file <source-file>` only when the host
project has configured `scripts/fast-validate.sh`.

## Step 4 — Report

Return:

- the backup path;
- generated or updated files;
- skipped files and why;
- missing source artifacts;
- validation results;
- restore command:

```bash
cp -RP docs/pre-install-backup/<timestamp>/. .
```

## Boundaries

- Never run without a backup unless `--dry-run` is selected.
- Never overwrite `.claude/settings.local.json`.
- Never modify product source code.
- Never invent project standards unsupported by `CODEBASE.md`, `PRD.md`, or
  `SPECS.md`; mark missing evidence as unknown.
- Never create nested `CLAUDE.md` files unless `--nested` is passed and
  `CODEBASE.md` names the subtree.
