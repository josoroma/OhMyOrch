---
name: harness-reset
description: Back up the project harness to a timestamped directory, verify the backup, then reset project artifacts (CLAUDE.md, SPEC-LOGS/, openspec/, scripts/, PRD.md, SPECS.md, README.md) to the canonical initial state defined by the installed .claude/ harness, leaving .claude/ completely untouched. Use when the user says "harness reset", "reset the harness", "reset this project", "start over from a clean harness", "restore the virgin harness state", or "wipe project artifacts but keep .claude".
allowed-tools: Read, Grep, Glob, Bash
license: MIT
compatibility: Requires the harness engine at .claude/skills/harness-reset/harness-reset.sh. No Node, Python, or network access.
metadata:
  author: claude-harness
  version: "1.0"
argument-hint: [--dry-run]
---

Reset the scoped project artifacts to the canonical initial state, after writing a
verified backup. This is a **destructive but reversible** operation: the backup is
complete and the reset refuses to start unless the backup verifies.

## What this does, and what it refuses to do

| Path | Backup | Reset |
|---|---:|---:|
| `.claude/` — agents, skills, hooks, commands, rules, settings | yes | **never** |
| `CLAUDE.md` (and every nested copy outside `.claude/`) | yes | yes |
| `SPEC-LOGS/` | yes | yes |
| `openspec/` | yes | yes |
| `scripts/` | yes | yes |
| `PRD.md`, `SPECS.md`, `README.md` | yes | yes |
| Anything else, including application source | no | **never** |

`.claude/` is never written. It *defines* the canonical state, so overwriting it
would destroy the definition of correct that the reset is supposed to restore.

The scope is not hardcoded in the engine. It is data in
`.claude/skills/harness-reset/manifest.tsv`, so the whole blast radius is readable
without reading any code. `PRESERVE.tsv` lists host-provided files that survive
the reset (`scripts/fast-validate.sh` by default, the documented host extension
point); they are captured and restored from the backup.

## Step 1 — Establish the target and show the plan

Run the engine's dry run first. It writes nothing and is safe to run at any time:

```bash
scripts/harness-reset.sh --dry-run
```

Report to the user, from the dry run's own output:

- the repository root that will be reset;
- which scope entries change and which are already canonical;
- that `.claude/` will not be touched;
- the backup path that will be created.

If the user did not ask for a dry run and the intent is clearly to reset, say what
the dry run reported and proceed to Step 2. Do not skip the dry run: it is the
only chance to notice that the target is the wrong repository.

## Step 2 — Reset

```bash
scripts/harness-reset.sh
```

Add `--quiet` to suppress passing checks when the output is being captured
elsewhere. Add `--root <dir>` only when resetting a repository other than the one
containing this script.

**The engine enforces the safety properties itself. Do not work around them:**

- it writes `docs/resets/<yyyy-mm-dd-hh-mm-ss>/`, preserving the original
  directory structure, and creates that directory with `mkdir` (not `-p`), so an
  existing backup makes the run **fail** rather than merge;
- it verifies the backup by SHA-256 manifest before changing anything, and
  **aborts with nothing changed** if any backup step fails;
- it never copies `docs/resets/` into a backup, so backups do not nest;
- it never follows a symlink out of the repository, and refuses to reset a scope
  entry that resolves outside the root rather than deleting its target;
- it handles a missing optional file gracefully: a scope entry that does not exist
  is skipped, and the baseline must define every reset entry, so nothing is
  deleted that cannot be restored;
- it resets by **copying the canonical baseline over the project**, not by
  emptying files, so structure and templates are restored from a source that is
  itself never modified.

If the engine aborts, report its message and stop. Nothing was changed. Do not
retry with a different path or by hand-deleting files.

## Step 3 — Report

The engine prints the report; relay it and do not restate it as a claim you
verified yourself. It names:

- the backup path;
- what was backed up, per scope entry, with file counts;
- what was preserved unchanged, including `.claude/` and any host files;
- what was reset;
- whether the backup check and the reset check passed.

If the reset check failed, the backup is intact and the report gives the exact
restore command. Report the failure; do not attempt a repair.

## Verification the engine performs

It does not merely assert success. After the reset it checks that:

- `CLAUDE.md`, `PRD.md`, `SPECS.md`, and `README.md` are byte-identical to the
  baseline;
- `openspec/changes/` has no active change, and `openspec/specs/`,
  `openspec/changes/archive/`, `openspec/delivery/`, and `openspec/config.yaml`
  exist;
- `scripts/` is restored;
- `SPEC-LOGS/README.md` is restored;
- no nested `CLAUDE.md` outside `.claude/` survived;
- every file, symlink, and directory outside the scope — including **all** of
  `.claude/` — is byte-identical to what it was before the reset. Only a removed
  nested `CLAUDE.md` is an accepted difference, and it is named.

## The reset is a floor, not a ceiling

A reset project is a **valid, empty harness**: it validates, its suites run, and
its backlog is empty. Its suites are written to exercise a full backlog, so some
of them — `scripts/test-guards.sh` in particular, whose navigation cases read the
harness's own `SPECS.md` — report failures on an empty backlog. That is the
canonical state working as intended, not a defect the reset introduced.

## Resuming after a reset

The scoped artifacts are gone, so resume from the harness workflow:

```text
/analyze-codebase     -> CODEBASE.md, when the repository has real source
/generate-prd         -> PRD.md
/ingest-spec          -> SPECS.md
```

To restore the state that was backed up instead:

```bash
cd <root> && cp -RP docs/resets/<timestamp>/. .
```

## The backup contains secrets

A backup of `.claude/` is a byte copy of the live directory, so it contains
`.claude/settings.local.json` and whatever credentials that file holds. `docs/resets/`
is listed in `.gitignore` for this reason. Do not commit a backup, and do not move
one into a tracked path. If a backup has already been committed, treat the
credentials it contains as disclosed and rotate them.

## Before running this

The reset is destructive to working state: an in-flight OpenSpec change, an
unarchived review, and the delivery goal are all removed. Confirm with the user
when the repository has work in progress that has not been archived. `--dry-run`
shows exactly what is at stake without changing anything.
