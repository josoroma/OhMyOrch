# Post-Install Codebase Adaptation Plan

## Question

After installing the OhMyOrch `.claude` harness, can a post-install step read the
current project's `PRD.md`, `CODEBASE.md`, and `SPECS.md`, then update `.claude`
files, create `.claude/rules`, and create or update `README.md`, `CLAUDE.md`,
and nested `CLAUDE.md` files that reflect best standards and the preferred
development approach for the current codebase?

## Short Answer

Yes, but it should be an explicit post-install adaptation step, not part of the
default install. The installer should first back up the current harness state to
`docs/pre-install-backup/<timestamp>/`, then generate project-specific `.claude`
rules, optional harness overlays, top-level documentation updates, and scoped
nested `CLAUDE.md` instructions from the repository's existing product and
codebase artifacts.

The default install should remain generic and collision-safe. The adaptation step
should be opt-in because it modifies behavior for future agents.

## Command Shape

Recommended command:

```bash
ohmyorch adapt
```

Curl-only equivalent:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/ohmyorch/main/install.sh | sh -s -- --adapt
```

Dry run:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/ohmyorch/main/install.sh | sh -s -- --adapt --dry-run
```

## Inputs

The adapter should read, in priority order:

| File | Purpose |
|---|---|
| `CODEBASE.md` | Current architecture, runtime, tooling, entry points, constraints |
| `PRD.md` | Product goals, audience, business rules, non-goals |
| `SPECS.md` | Accepted backlog structure, epics, stories, acceptance patterns |
| `.claude/rules/*.md` | Existing agent behavior and team standards |
| `CLAUDE.md` | Existing repo-level instructions that must be preserved or intentionally replaced |
| `README.md` | Operational commands and local setup signals |
| Nested `CLAUDE.md` files | Package-, app-, or service-level agent instructions |

If `CODEBASE.md` is missing but the repo has meaningful source code, the adapter
should stop and ask the user to run the codebase-analysis workflow first. It
should not invent project-specific standards from file names alone.

## Backup Requirement

Before modifying anything, create:

```text
docs/pre-install-backup/<yyyy-mm-dd-hh-mm-ss>/
```

The backup should preserve original paths:

```text
docs/pre-install-backup/<timestamp>/
  .claude/
  CLAUDE.md
  **/CLAUDE.md
  PRD.md
  CODEBASE.md
  SPECS.md
  README.md
```

Backup rules:

- create the timestamp directory with `mkdir`, not `mkdir -p`, so an existing
  backup path fails instead of merging;
- write a `manifest.tsv` containing path, type, size, checksum, and reason;
- verify the backup checksums before any write;
- exclude prior backups from the backup itself;
- never include secrets from `.env`, `secrets/`, keys, certificates, or ignored
  local credential files;
- preserve `.claude/settings.local.json` only when present, but mark the backup as
  sensitive and keep `docs/pre-install-backup/` git-ignored;
- include every existing `CLAUDE.md` outside `.claude/`, preserving nested paths,
  before creating, replacing, or merging any agent instruction file.

## Output Files

The adapter should prefer additive, namespaced files:

```text
.claude/rules/ohmyorch-codebase-standards.md
.claude/rules/ohmyorch-product-rules.md
.claude/rules/ohmyorch-delivery-standards.md
.claude/rules/ohmyorch-testing-standards.md
.claude/ohmyorch/adaptation-report.md
.claude/ohmyorch/adaptation-manifest.tsv
```

It may also create or update project documentation and agent-instruction files:

```text
README.md
CLAUDE.md
<app-or-package>/CLAUDE.md
<service-or-module>/CLAUDE.md
```

Avoid overwriting existing generic rules, `README.md`, `CLAUDE.md`, or nested
`CLAUDE.md` files unless the backup has been verified and the user has selected
an explicit write mode.

## Write Modes

Support three documentation write modes:

| Mode | Behavior |
|---|---|
| `--create-only` | Create missing `.claude/rules`, `README.md`, `CLAUDE.md`, and nested `CLAUDE.md` files; refuse existing files |
| `--merge` | Add OhMyOrch-managed sections to existing files; preserve unmanaged content |
| `--override` | Replace selected files after backup verification and explicit confirmation |

Default to `--merge` for `.claude/rules` and generated OhMyOrch files. Default to
`--create-only` for `README.md`, top-level `CLAUDE.md`, and nested `CLAUDE.md`
because those files often contain project-specific human-authored guidance.

## Top-Level Documentation Responsibilities

### `README.md`

Generated or updated from `CODEBASE.md`, `PRD.md`, and `SPECS.md`.

Should cover:

- what the project is and who it serves;
- local setup and validation commands discovered from `CODEBASE.md`;
- architecture overview and major runtime components;
- delivery workflow using the installed OhMyOrch harness;
- links to `PRD.md`, `CODEBASE.md`, `SPECS.md`, and relevant `.claude/rules`;
- known operational constraints and unknowns.

When merging into an existing `README.md`, write only inside an
OhMyOrch-managed section:

```markdown
<!-- ohmyorch:start README -->
...
<!-- ohmyorch:end README -->
```

### Top-Level `CLAUDE.md`

Generated or updated from all source artifacts.

Should cover:

- repository-wide agent rules;
- development standards for the current stack;
- required context files to read before planning or implementation;
- commands for build, lint, test, validation, and delivery;
- boundaries between product code, docs, specs, and generated artifacts;
- references to `.claude/rules/ohmyorch-*.md`.

When merging, write only inside:

```markdown
<!-- ohmyorch:start CLAUDE -->
...
<!-- ohmyorch:end CLAUDE -->
```

### Nested `CLAUDE.md`

Generated only when `CODEBASE.md` identifies clear bounded areas such as apps,
packages, services, infrastructure directories, or shared libraries.

Each nested file should cover:

- local ownership and scope;
- implementation patterns for that subtree;
- commands that apply only to that subtree;
- testing expectations for that subtree;
- dependencies or boundaries with other subtrees;
- links back to the top-level `CLAUDE.md`.

The adapter should not create nested `CLAUDE.md` files for arbitrary folders. It
must cite the `CODEBASE.md` evidence that makes the boundary meaningful.

## Generated Rule Responsibilities

### `ohmyorch-codebase-standards.md`

Generated from `CODEBASE.md`.

Should cover:

- architecture boundaries;
- entry points and module ownership;
- preferred implementation locations;
- dependency and framework constraints;
- persistence, API, auth, queue, and integration conventions;
- build, lint, test, and validation commands;
- known risks and unknowns agents must respect.

### `ohmyorch-product-rules.md`

Generated from `PRD.md`.

Should cover:

- target users;
- core value proposition;
- product terminology;
- non-goals;
- business rules;
- user-facing quality bar;
- UX and accessibility expectations when relevant.

### `ohmyorch-delivery-standards.md`

Generated from `SPECS.md` and existing `.claude/rules`.

Should cover:

- story states and transition expectations;
- acceptance criteria style;
- Definition of Done;
- planning, review, test, and archive gates;
- how agents should use OpenSpec artifacts in this repository.

### `ohmyorch-testing-standards.md`

Generated from `CODEBASE.md`, `SPECS.md`, and available test scripts.

Should cover:

- test layers used by the project;
- required checks before marking a story complete;
- when to add unit, integration, contract, snapshot, or manual evidence;
- known slow or unavailable tests;
- evidence format expected in `review.md` and `test-report.md`.

## Adaptation Report

Write:

```text
.claude/ohmyorch/adaptation-report.md
```

The report should include:

- timestamp;
- source files read;
- backup path;
- generated or updated files;
- write mode used for each generated or updated file;
- skipped files and reasons;
- unresolved questions;
- validation results;
- restore instructions.

## Collision Policy

For every planned write:

| Target state | Behavior |
|---|---|
| Missing | Create |
| Exists and has OhMyOrch marker | Back up, then update |
| Exists and has OhMyOrch managed block | Back up, then replace only the managed block |
| Exists and has no OhMyOrch marker | Do not overwrite unless `--override` is explicitly selected |
| Exists but checksum changed since last adaptation | Do not overwrite unless `--overwrite-managed` |

Every generated file should contain frontmatter:

```yaml
---
distribution: ohmyorch
generated-by: ohmyorch-adapt
source:
  - CODEBASE.md
  - PRD.md
  - SPECS.md
---
```

For files where frontmatter is inappropriate, such as many `README.md` files, use
managed HTML comment markers instead of frontmatter.

## Post-Install Flow

1. Detect repository root.
2. Confirm `.claude` exists and is readable.
3. Inspect `CODEBASE.md`, `PRD.md`, and `SPECS.md`.
4. Build a write plan without writing files.
5. Detect collisions.
6. Create `docs/pre-install-backup/<timestamp>/`.
7. Verify the backup manifest.
8. Generate additive OhMyOrch rules.
9. Generate or merge `README.md`.
10. Generate or merge top-level `CLAUDE.md`.
11. Generate or merge nested `CLAUDE.md` files only for evidenced codebase boundaries.
12. Write `.claude/ohmyorch/adaptation-report.md`.
13. Run validation.
14. Print summary and restore command.

## Validation

Minimum validation:

```bash
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
scripts/run-project-validation.sh
```

If those scripts are not present, the adapter should record validation as
`SKIPPED` with the reason. It should not fabricate a passing result.

## Restore Model

Print a restore command after every successful adaptation:

```bash
cp -RP docs/pre-install-backup/<timestamp>/. .
```

Also provide a safer managed-file restore mode in the future:

```bash
ohmyorch restore --backup docs/pre-install-backup/<timestamp>
```

## Safety Rules

- Do not overwrite `.claude/settings.local.json`.
- Do not modify product source code.
- Do not create standards unsupported by `CODEBASE.md`, `PRD.md`, or `SPECS.md`.
- Do not erase existing non-OhMyOrch agents, skills, commands, or rules.
- Do not replace existing `README.md`, `CLAUDE.md`, or nested `CLAUDE.md` files
  without a verified backup and explicit override mode.
- Do not create nested `CLAUDE.md` files without a clear subtree boundary cited
  from `CODEBASE.md`.
- Do not infer secrets, endpoints, credentials, or production behavior.
- Mark unknowns explicitly rather than filling gaps with generic best practices.

## Implementation Phases

### Phase 1: Adapter Design

- Define `ohmyorch adapt` arguments.
- Define backup manifest format.
- Define generated rule templates.
- Define `README.md`, top-level `CLAUDE.md`, and nested `CLAUDE.md` templates.
- Define ownership markers.

### Phase 2: Backup Engine

- Implement `docs/pre-install-backup/<timestamp>/` creation.
- Add checksum manifest.
- Add backup verification before writes.
- Add restore instructions.

### Phase 3: Rule Generation

- Parse `CODEBASE.md`, `PRD.md`, and `SPECS.md` as Markdown sections.
- Extract supported standards only from cited content.
- Generate additive `.claude/rules/ohmyorch-*.md` files.
- Generate or merge `README.md`.
- Generate or merge top-level `CLAUDE.md`.
- Generate or merge nested `CLAUDE.md` files for evidenced codebase boundaries.
- Write adaptation report.

### Phase 4: Collision and Upgrade Handling

- Refuse unmanaged collisions.
- Update only OhMyOrch-managed generated files.
- Detect local edits to generated files by checksum.
- Support `--dry-run` and `--overwrite-managed`.

### Phase 5: Test Matrix

- Repository with all three artifacts.
- Repository missing `CODEBASE.md`.
- Repository with existing custom `.claude/rules`.
- Repository with previous OhMyOrch adaptation.
- Repository with locally edited OhMyOrch generated rule.
- Repository with sensitive local settings.

## Decision

Implement post-install adaptation as an explicit, reversible step after the base
harness install. It should use `docs/pre-install-backup/` for verified backups,
generate namespaced OhMyOrch rule files, and refuse to overwrite unmanaged
project-specific `.claude` content.
