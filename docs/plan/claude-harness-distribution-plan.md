# OhMyOrch `.claude` Harness Distribution Plan

## Question

Can the OhMyOrch `.claude` harness be distributed so a user can install it with a
single `curl` command?

## Short Answer

Yes. The safest path is to distribute the harness as a versioned bundle with a
small remote installer script:

```bash
curl -fsSL https://ohmyorch.example/install.sh | sh
```

The installer should not blindly overwrite `.claude`. It should install into a
managed namespace, detect collisions, back up any managed files it replaces, and
leave unrelated existing agents, skills, commands, rules, and local settings
untouched.

## Recommended Shape

Use a bundle-first distribution model:

| Option | Recommendation | Why |
|---|---:|---|
| Tarball bundle | Primary | Works with plain `curl`, no package manager required, portable across repos |
| GitHub release asset | Primary host | Versioned, checksummable, easy rollback |
| npm package | Optional later | Useful for users who prefer `npx`, but not required for curl-only install |
| Claude plugin | Optional later | Good for marketplace-style discovery, but not enough by itself for repo-local project files |
| Homebrew package | Optional later | Nice for CLI ergonomics, not necessary for first distribution |

The bundle should contain both:

- the `.claude` harness resources;
- the project-level harness files that make those resources work, such as
  `CLAUDE.md`, `openspec/`, `scripts/`, `PRD.md`, `SPECS.md`, and `README.md`
  baselines when the installer is run in bootstrap mode.

## Package Layout

Create a release artifact with this structure:

```text
ohmyorch-harness-<version>.tar.gz
  manifest.tsv
  checksums.sha256
  install.sh
  uninstall.sh
  payload/
    .claude/
      agents/
      skills/
      commands/
      rules/
      settings.json
      settings.local.example.json
    CLAUDE.md
    openspec/
    scripts/
    PRD.md
    SPECS.md
    README.md
```

Do not include `.claude/settings.local.json` in any public bundle.

## Namespacing Strategy

Avoid collisions by treating OhMyOrch as a managed namespace inside `.claude`.

Preferred names:

```text
.claude/agents/ohmyorch-*.md
.claude/skills/ohmyorch-*/
.claude/commands/ohmyorch/*.md
.claude/rules/ohmyorch-*.md
```

For the existing harness names, migrate or install with prefixed names:

| Current | Distributed name |
|---|---|
| `ohmyorch-codebase-analyst.md` | `ohmyorch-codebase-analyst.md` |
| `ohmyorch-planner.md` | `ohmyorch-planner.md` |
| `ohmyorch-implementer.md` | `ohmyorch-implementer.md` |
| `ohmyorch-reviewer.md` | `ohmyorch-reviewer.md` |
| `ohmyorch-tester.md` | `ohmyorch-tester.md` |
| `ohmyorch-generate-prd` | `ohmyorch-generate-prd` |
| `deliver` | `ohmyorch-deliver` |
| `opsx/*` | `ohmyorch/opsx/*` |

The internal references in skills and commands must use the distributed names.
That prevents an installed OhMyOrch agent from accidentally calling another
project's `ohmyorch-planner`, `ohmyorch-reviewer`, or `ohmyorch-tester`.

## Collision Rules

The installer should classify every target path before writing:

| State | Action |
|---|---|
| Path does not exist | Install |
| Path exists and is OhMyOrch-managed at same version | Skip |
| Path exists and is OhMyOrch-managed at older version | Back up, then upgrade |
| Path exists and is OhMyOrch-managed at newer version | Refuse unless `--force-downgrade` |
| Path exists and is not OhMyOrch-managed | Refuse by default |

Managed files should contain a lightweight marker:

```text
metadata:
  distribution: ohmyorch
  version: "x.y.z"
```

For files that cannot carry frontmatter, track ownership in:

```text
.claude/ohmyorch/manifest.tsv
```

## Installer Modes

Support three modes.

| Mode | Command | Behavior |
|---|---|---|
| Additive | `sh install.sh` | Installs only namespaced `.claude` resources and helper scripts |
| Bootstrap | `sh install.sh --bootstrap` | Adds baseline `CLAUDE.md`, `openspec/`, docs, and scripts if absent |
| Upgrade | `sh install.sh --upgrade` | Updates only files previously marked as OhMyOrch-managed |

The default should be additive. Bootstrap should require an explicit flag because
project-level files like `CLAUDE.md`, `README.md`, `PRD.md`, and `SPECS.md` are
likely to collide with host repository content.

## Existing `.claude` Protection

Before any write, the installer must:

1. Detect the repository root.
2. Read the target `.claude` tree if present.
3. Build a collision report.
4. Create a timestamped backup under `.claude/ohmyorch/backups/<timestamp>/`.
5. Refuse to overwrite unmanaged files.
6. Preserve `.claude/settings.local.json`.
7. Merge settings only through an OhMyOrch-owned include file or documented block.

Recommended settings layout:

```text
.claude/settings.json
.claude/settings.local.json
.claude/ohmyorch/settings.fragment.json
```

If Claude Code does not support settings includes, the installer should avoid
automatic settings merges by default. Instead, write the fragment and print the
exact merge instructions.

## Curl Command

Use a wrapper that downloads the versioned installer and verifies the bundle:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/ohmyorch/main/install.sh | sh
```

Optional pinned install:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/ohmyorch/v1.0.0/install.sh | sh
```

The installer should:

- use `set -eu`;
- create a temporary directory;
- download `ohmyorch-harness-<version>.tar.gz`;
- download `checksums.sha256`;
- verify the checksum before extracting;
- run preflight collision checks;
- write backups;
- install only after preflight passes;
- run validation;
- print installed version and next commands.

## Validation Gates

After installation, run:

```bash
node scripts/check-frontmatter.js
scripts/run-project-validation.sh
scripts/validate-product-artifacts.sh
```

If those scripts are installed under a namespaced path, use:

```bash
.claude/ohmyorch/scripts/check-frontmatter.sh
.claude/ohmyorch/scripts/run-project-validation.sh
.claude/ohmyorch/scripts/validate-product-artifacts.sh
```

The release pipeline should test installation into:

- an empty repository;
- a repository with no `.claude`;
- a repository with unrelated `.claude/agents`;
- a repository with conflicting `ohmyorch-planner.md` or `deliver`;
- a repository with existing `.claude/settings.local.json`;
- a repository with an older OhMyOrch version;
- a repository with dirty working tree changes.

## Uninstall and Rollback

Ship `uninstall.sh`.

It should remove only files listed in `.claude/ohmyorch/manifest.tsv` and only if
their current checksum matches the installed checksum. If a managed file was
modified locally, leave it in place and report it.

Rollback should restore from:

```text
.claude/ohmyorch/backups/<timestamp>/
```

## Security Requirements

The `curl | sh` path is convenient but sensitive. Mitigate it with:

- pinned version URLs;
- published SHA-256 checksums;
- optional GPG or Sigstore signing;
- no bundled secrets;
- no automatic execution of repo scripts before checksum verification;
- clear dry-run mode:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/ohmyorch/main/install.sh | sh -s -- --dry-run
```

## Implementation Phases

### Phase 1: Prepare Harness for Distribution

- Prefix public agents, skills, and commands with `ohmyorch-`.
- Update all internal references to use prefixed names.
- Move installer-owned metadata into `.claude/ohmyorch/`.
- Add ownership markers to managed Markdown files.
- Exclude `.claude/settings.local.json` from bundles.

### Phase 2: Build Bundle

- Add `scripts/package-ohmyorch.sh`.
- Generate `manifest.tsv` with path, mode, checksum, version, and owner.
- Generate `checksums.sha256`.
- Create a tarball from a clean tree.

### Phase 3: Build Installer

- Add remote-safe `install.sh`.
- Support `--dry-run`, `--bootstrap`, `--upgrade`, `--force`, and
  `--target <dir>`.
- Implement collision reporting before writes.
- Implement backup and rollback.

### Phase 4: Test Compatibility

- Add fixture repositories for common collision cases.
- Run install, upgrade, uninstall, and rollback tests.
- Verify existing `.claude` resources survive byte-for-byte unless explicitly
  OhMyOrch-managed.

### Phase 5: Publish

- Publish a GitHub release with tarball, installer, checksums, and release notes.
- Document the curl command, pinned version command, dry run, upgrade, uninstall,
  and bootstrap mode.

## Decision

Proceed with a versioned tarball plus curl installer as the primary distribution
mechanism. Treat Claude plugin packaging as a later discovery layer, not the
first install mechanism, because this harness includes repo-local files and
scripts that need collision-aware installation.

