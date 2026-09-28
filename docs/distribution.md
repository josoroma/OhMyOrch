# OhMyOrch Harness Distribution

This repository ships a curl-friendly OhMyOrch harness distribution.

## Build

```bash
scripts/package-ohmyorch.sh --version 0.1.0
```

Outputs:

```text
dist/ohmyorch-harness-0.1.0.tar.gz
dist/ohmyorch-harness.tar.gz
dist/checksums.sha256
```

Upload these release assets:

- `ohmyorch-harness-<version>.tar.gz`
- `ohmyorch-harness.tar.gz`
- `checksums.sha256`
- `install.sh`
- `uninstall.sh`

## Install

Latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/josoroma/claude-dev/main/install.sh | sh
```

Pinned release:

```bash
curl -fsSL https://raw.githubusercontent.com/josoroma/claude-dev/v0.1.0/install.sh | \
  OHMYORCH_RELEASE_BASE_URL=https://github.com/josoroma/claude-dev/releases/download/v0.1.0 \
  sh
```

Local bundle:

```bash
sh install.sh --bundle dist/ohmyorch-harness-0.1.0.tar.gz --target /path/to/repo
```

Dry run:

```bash
curl -fsSL https://raw.githubusercontent.com/josoroma/claude-dev/main/install.sh | sh -s -- --dry-run
```

## Modes

Additive install, the default, installs namespaced `.claude` resources only:

```bash
sh install.sh --bundle dist/ohmyorch-harness-0.1.0.tar.gz --target /path/to/repo
```

Bootstrap also installs project-level baseline files when safe:

```bash
sh install.sh --bundle dist/ohmyorch-harness-0.1.0.tar.gz --target /path/to/repo --bootstrap
```

Upgrade updates only already-managed OhMyOrch files:

```bash
sh install.sh --bundle dist/ohmyorch-harness-0.1.0.tar.gz --target /path/to/repo --upgrade
```

## Collision Policy

The installer refuses unmanaged collisions by default. It writes a preflight plan,
then backs up overwritten files under:

```text
.claude/ohmyorch/backups/<timestamp>/
```

Use `--force` only when replacing an unmanaged collision is intentional.

## Post Install

After installing into a real project, adapt the harness to that repository:

```text
/ohmyorch:post-install --mode merge
```

That step reads `CODEBASE.md`, `PRD.md`, and `SPECS.md`, creates a separate backup
under `docs/pre-install-backup/<timestamp>/`, and generates project-specific
OhMyOrch rules and managed `README.md` / `CLAUDE.md` sections.

## Uninstall

Preview:

```bash
sh uninstall.sh --target /path/to/repo --dry-run
```

Remove checksum-matching managed files:

```bash
sh uninstall.sh --target /path/to/repo
```

Locally edited managed files are left in place unless `--force` is used.

## Release Checklist

1. Run `scripts/test-ohmyorch-distribution.sh`.
2. Run `node scripts/check-frontmatter.js`.
3. Run `scripts/validate-product-artifacts.sh`.
4. Build with `scripts/package-ohmyorch.sh --version <version>`.
5. Upload both tarballs, `checksums.sha256`, `install.sh`, and `uninstall.sh`.
6. Smoke-test the published curl command with `--dry-run`.

