# Proposal — US-14.1: Generate Themed HTML Documentation Pages

Story: US-14.1
Epic: EPIC-14 — Themed HTML Documentation Pages

## Why

The harness explains itself only in Markdown. That works for the people running it,
but it is a poor way to demo the codebase's status or explain spec-driven development
to developers who have not used the harness. A Mermaid block in `README.md` shows a
diagram; it cannot show an entity-relationship diagram with keys, an infrastructure
map with boundaries, or an overlay that explains one part of a figure.

The human Product Manager asked for a generator of single-page HTML documents in the
shadcn Luma theme, light and dark, and supplied the theme tokens verbatim.

## What Changes

- **`.claude/skills/generate-html-page/SKILL.md`** — the `/generate-html-page` skill.
  It gathers evidence from the repository, fills the page template, and validates the
  result. It never invents a figure: every number on a page cites the file or command
  it came from.
- **`scripts/templates/html-page.html`** — the page template. It carries the supplied
  Luma light and dark tokens verbatim, a theme toggle, a table of contents, and one
  example of every supported component: a table, a list, an SVG diagram with an
  overlay, an SVG entity-relationship diagram, and an SVG infrastructure diagram.
- **`scripts/validate-html-page.sh`** — checks a page against the contract: the tokens,
  the toggle, the table of contents and its links, SVG accessibility, no external
  resources, and a sources section. It exits 1 and names the rule on a violation.
- **`scripts/test-html-page.sh`** — the regression suite, with conforming and
  non-conforming fixture pages.
- **`docs/pages/harness-overview.html`** — an example page that explains the harness
  and reports its status from repository evidence.
- **`README.md`, `scripts/README.md`** — document the skill and the scripts.

## Capabilities

### New Capabilities

- `html-pages`: generating and validating themed single-page HTML documents. Covers the
  7 acceptance scenarios of US-14.1.

### Modified Capabilities

- None.

## Out of Scope

- A build step, a framework, or a package manifest. The page is a single static file
  with inline CSS and a few lines of inline script, and it opens from disk.
- Loading Tailwind, shadcn components, or web fonts. The page uses the Luma *tokens*
  and plain CSS; loading anything external would break the single-file requirement.
- Rendering Mermaid. Diagrams are hand-authored inline SVG, so they need no runtime.
- Generating pages automatically on every change. The skill is invoked on request.

## Impact

- `.claude/skills/generate-html-page/SKILL.md` (new)
- `scripts/templates/html-page.html` (new)
- `scripts/validate-html-page.sh` (new)
- `scripts/test-html-page.sh` (new)
- `scripts/fixtures/html-pages/` (new fixtures)
- `docs/pages/harness-overview.html` (new example page)
- `.claude/settings.json` (allow-list entries only)
- `README.md`, `scripts/README.md`, `CLAUDE.md` (references)

Source:
- Human Product Manager decision, 2026-09-26 (theme tokens supplied verbatim)
