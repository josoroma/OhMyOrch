# Plugin distribution and maintenance

The supported distribution unit is `plugins/ohmyorch/`, discovered through `.claude-plugin/marketplace.json`. The catalog is named `ohmyorch-marketplace` and the plugin is `ohmyorch`, version **0.0.1**. This repository is the initial colocated marketplace; a separate marketplace can later reference this plugin repository without changing the plugin ID. The owner authorized publication of the repository, version tag and Pages. License/live validation gates remain unresolved for public packaged artifacts and support claims.

## Local development and external consumer trials

```bash
# From any consumer project; both paths are literal absolute paths.
claude --plugin-dir /absolute/checkout/plugins/ohmyorch
```

For the real marketplace/cache flow using a local checkout:

```bash
claude plugin marketplace add /absolute/checkout --scope local
claude plugin install ohmyorch@ohmyorch-marketplace --scope local
```

Run these in the consumer project. The local catalog declaration uses that developer's local settings; do not commit a publisher's absolute path for teammates. `--plugin-dir` bypasses the install cache during authoring. `/reload-plugins` reloads changes; restart when a version's reload behavior is uncertain. Use a distinct disposable Claude configuration directory for integration tests, as `tests/test_marketplace.py` does, rather than editing your real plugin registry.

## Published installation

Install from the published repository marketplace:

```bash
claude plugin marketplace add josoroma/OhMyOrch
claude plugin install ohmyorch@ohmyorch-marketplace --scope project
```

The interactive equivalents are `/plugin marketplace add josoroma/OhMyOrch` and `/plugin install ohmyorch@ohmyorch-marketplace`, followed by scope selection. User scope applies across projects; project scope is shared in project settings; local scope is personal to the project. A project's enabled declaration is distinct from initialized OhMyOrch data. Configure provider credentials through your own settings, never through bundled plugin files. No manual `.claude` copying is needed. Installation/update/SessionStart do not bootstrap.

Initialize through `/ohmyorch:bootstrap --dry-run --with-openspec`, review, then `--apply`. Existing documents are adopted unchanged. Analyze the actual codebase before generating project-specific guidance. Migration of an old copied setup uses the explicit reviewed-hash `/ohmyorch:migrate-legacy` flow, not install-time deletion.

## Update and rollback

```bash
claude plugin marketplace update ohmyorch-marketplace
claude plugin update ohmyorch@ohmyorch-marketplace --scope project
claude plugin uninstall ohmyorch@ohmyorch-marketplace --scope project
```

Use the same scope for update/uninstall. Project upgrade is a separate `/ohmyorch:upgrade-project --dry-run` operation; updates never rewrite schema or intent. Uninstall preserves project docs, OpenSpec history, config and recovery data. Review the CLI's current `--help` for options available in your version. [Official CLI reference](https://code.claude.com/docs/en/plugins/cli-reference).

A plugin rollback must select an immutable prior catalog/plugin Git ref and reinstall at the same scope. For a local trial, check out that prior release in a separate directory, add its catalog, then reinstall through that catalog after uninstalling the conflicting scope. Use the documented marketplace Git `ref` configuration when pinning a team's remote source; do not invent a `plugin update --version` flag, rewrite tags, or delete user caches. Project-state rollback uses the recorded operation ID and verifies current/backup hashes independently of code rollback.

## Release procedure

1. Complete the release checklist in `docs/plan/plugin-release-readiness.json` with linked evidence. The owner must select the actual license, add `plugins/ohmyorch/LICENSE` and manifest SPDX metadata, review upstream notices, and pass authenticated role identity/denial and full-story lifecycle tests on the preferred/latest CLI.
2. Increment the plugin manifest version and root maintainer package version together; update the changelog and readiness version. Catalog entries deliberately omit a duplicate version. Every changed payload needs a new SemVer version; schema changes require an explicit upgrade path and rollback rehearsal.
3. Run `npm ci --ignore-scripts`, `npm run check`, `npm test`, `npm run test:marketplace`, both strict validators, `npm run check:release`, and `npm run package:plugin`. Check artifact checksums/allowlist and clean external installation from the intended immutable ref. Observe the Linux/macOS CI matrix; do not equate configured CI with a passing run.
4. The owner reviews the concrete diff, evidence and artifacts, then creates an immutable `<plugin-version>` tag without a `v` prefix and release. The release workflow prepares gated artifacts; it does not publish automatically. While recorded evidence is pending, it reports that status and skips packaging/upload. Repository/tag/Pages publication does not mark those gates passed. Promote support claims only with actual validation, and communicate breaking command/reset behavior and known acceptance limitations.
5. Recheck Anthropic's current [publication guidance](https://code.claude.com/docs/en/plugins/publish) before requesting an official listing. Official marketplace admission is separate from this self-hosted catalog and is not required for consumers to install it.

`npm run package:plugin -- --development` builds a clearly named unreleased zip for local testing while public release gates are unresolved. The reproducible zip is an optional artifact; marketplace/Git installation remains primary. The allowlist excludes local `.claude` configuration, project state, tests, tools, snapshots, caches and generated pages. The old curl installer/uninstaller and copier packaging were removed; use Claude's plugin commands.

On 2026-10-07 the owner explicitly directed consolidation of published history into one root commit and replacement of the previous `v1.0.0` release with **0.0.1**, using the sole literal tag `0.0.1`. The prior history and release metadata were retained in an external recovery copy. This authorized reset is separate from normal updates and rollback; future release tags remain immutable.

Existing publisher clones should retain any local work and use a fresh checkout of the rewritten main branch. A catalog pinned to the retired tag must change its ref to `0.0.1`. Installed consumers should refresh the marketplace and update at their existing scope; the plugin identity and project schema remain unchanged. Claude Code detects hosted plugin updates from a changed version string, as described in [official version/update guidance](https://code.claude.com/docs/en/plugins/host-marketplace#release-a-new-version).

The publisher guide is maintained in `docs/OhMyOrch.md`. `npm run docs:build` uses the pinned development-only Markdown renderer to regenerate `docs/OhMyOrch.html`; `npm run check` verifies it is current. Pages stages that HTML, `docs/assets/`, `docs/images/`, and the root redirect. Publisher documentation and rendering dependencies do not enter the plugin payload or change its consumer prerequisites.

## Support and compatibility

The first preferred CLI is 2.1.292. Local 2.1.285 and 2.1.292 pass metadata/cache lifecycle tests; live agent identity/lifecycle validation is still pending by user direction. OpenSpec 1.13.2 is the dependency target; jq >=1.6 and Bash >=3.2 are required. Linux and macOS are CI targets; local results in this migration are macOS only. Native Windows and custom OpenSpec schemas are unsupported. Versions before Claude Code 2.1.139 lack the required exec-form hook arguments. No weaker legacy mode is advertised as equivalent enforcement.
