# Changelog

## 0.0.1 — 2026-10-07

- Convert 18 standalone workflows to 24 plugin skills and eight scoped agents.
- Bundle runtime, generic contracts, validators and templates behind explicit project roots.
- Replace ignored agent hooks with one identity-aware root dispatcher.
- Preserve seven gates, four completion conditions, verdict history and bounded delivery continuation.
- Add session ownership, schema 1 project configuration, create-only bootstrap, managed adaptation, reviewed legacy migration and affected-file recovery.
- Add a colocated marketplace, isolated cache lifecycle tests and allowlisted release tooling.
- Publish the plugin source, marketplace catalog, human-readable overview and visual delivery guide as version 0.0.1.
- Add the standalone SPECS Kanban/document workspace, coherent project examples, original screenshots and local setup instructions.
- Consolidate published history into one root commit with the sole literal release tag 0.0.1 by explicit owner direction.
- Keep live agent/lifecycle validation and the owner-approved license as gates for public packaged artifacts and support claims.
- Parse recorded CODEBASE revisions portably with BSD/GNU awk so stale-context checks retain the same gate behavior on Linux and macOS.
- Consume HTML validator predicate input completely under pipefail; preserve security checks and cover large pages in regression tests.

Breaking invocation changes: `ohmyorch-*` standalone skills become `/ohmyorch:<short-name>`; nested `opsx:*` commands become flat `/ohmyorch:opsx-*`. No compatibility command aliases are shipped. Reset no longer wipes scripts or arbitrary nested CLAUDE files. Existing acceptance ambiguities are retained.
