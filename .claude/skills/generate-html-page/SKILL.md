---
name: generate-html-page
description: Generate a self-contained single-page HTML document in the shadcn Luma theme, light and dark, to demo codebase status or explain the codebase and spec-driven development to developers. The page opens with a table of contents and presents content through tables, lists, SVG diagrams with overlays, SVG entity-relationship diagrams, and SVG infrastructure diagrams. Use when the user says "generate an HTML page", "make a status page", "explain the codebase as a page", or "create a demo page".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
license: MIT
compatibility: Requires scripts/templates/html-page.html and scripts/validate-html-page.sh. No build, framework, or network access.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-14.1"
argument-hint: <topic or page slug>
---

Generate one **self-contained HTML page** in the shadcn Luma theme, with light and dark
modes. The page opens from disk, loads nothing from the network, and can be shared as
a single file.

Use it to:

- **demo codebase status** — backlog progress, gate state, suite results;
- **explain a codebase** — modules, data model, infrastructure, request flow;
- **explain spec-driven development** — the roles, the artifacts, the gates, the loop.

**Start with `$ARGUMENTS`**: the topic, and optionally the slug. The page is written to
`docs/pages/<slug>.html`.

## The rule that matters: never invent a figure

A page that reports on a repository is a claim about that repository. Every number,
status, name, and relationship on the page MUST come from a file you read or a command
you ran, and the page MUST list those sources in `section#sources`. When a fact cannot
be determined, say so on the page ("unknown") rather than guessing. This is the same
rule the Codebase Analyst follows (NFR-005).

For an explanatory page with no repository figures, the sources section still lists
the documents the explanation came from.

## Step 1 — Decide the sections

Pick the sections the topic needs, in reading order. Each becomes one
`<section id="…">` with an `<h2>`. Typical shapes:

| Page | Sections |
|---|---|
| status | overview (stats), backlog table, gates table, suites table, what's next, sources |
| codebase explainer | overview, module map (SVG), data model (ER), infrastructure (SVG), request flow (overlay), conventions (lists), sources |
| spec-driven development | the idea, the roles (table), the artifacts (table), the loop (overlay), the gates (list), sources |

Keep section ids short and lowercase: `overview`, `data-model`, `infrastructure`.

## Step 2 — Gather the evidence

Collect every figure with a command before writing any HTML, and keep the list of
commands: it becomes the sources section. In a harness repository:

```bash
grep -cE '^# EPIC-[0-9]+:' SPECS.md                     # epics
grep -cE '^### US-[0-9]+\.[0-9]+:' SPECS.md             # stories
grep -c '^Status: DONE' SPECS.md                        # delivered stories
ls openspec/changes/archive | wc -l                     # archived changes
ls openspec/specs | wc -l                               # canonical capabilities
scripts/workflow-status.sh                              # gate state of the active change
scripts/test-<suite>.sh | tail -3                       # suite results
git rev-parse --short HEAD 2>/dev/null || echo "no commits yet"
```

For another codebase, read `CODEBASE.md` when it exists: it is the evidence-backed
map of the repository. Otherwise read the manifests, entry points, schema files, and
infrastructure definitions directly, and cite each file.

## Step 3 — Fill the template

Copy `scripts/templates/html-page.html` to `docs/pages/<slug>.html`, then:

1. **Keep the `:root` and `.dark` blocks exactly as they are.** They are the Luma
   palette, verbatim. The validator checks every token and its value.
1. **Keep the `Content-Security-Policy` meta as the first element in `<head>`**, right
   after `<meta charset>`. It lets the browser run the inline script and style and
   show `data:` images, and refuse everything else. The validator requires it.
2. **Replace every `{{PLACEHOLDER}}`.** None may remain.
3. **Keep the components you need, and delete the rest.** Each is marked with a
   `data-component` attribute.
4. **Rebuild the table of contents** so it lists every section, in order.
5. **Colour only through tokens.** Use the template's classes (`svg-node`,
   `svg-edge`, `badge-success`, …) or `var(--token)`. Never write a literal colour:
   it would not switch with the theme.

### The components

| Component | Use it for | How |
|---|---|---|
| stats | headline figures | `.stats` of `.card`s; `.progress` for a ratio |
| table | anything with rows and columns | `.table-wrap > table`, with `<caption>`, `th scope="col"`, `td.num` for numbers, `.badge` for statuses |
| list | points, checklists, ordered steps | `.list`, `.list.checklist`, `ol.steps` |
| callout | one important note | `.callout`, `.callout-danger` |
| SVG diagram with overlay | a flow or architecture that needs explaining | an `<svg>` in `.figure`, numbered `.svg-pin`s, and a `<details class="overlay-toggle">` whose `.overlay-note`s are positioned over the figure |
| SVG ER diagram | a data model | one `<g>` per table: `.svg-er-head` + `.svg-er-body`, `PK`/`FK` badges, crow's-foot relationship paths |
| SVG infrastructure diagram | deployment, services, trust boundaries | `.svg-zone` dashed boundaries, typed nodes, directed edges labelled with the protocol, a `.legend` |

### Every SVG

- has `role="img"` and `aria-labelledby` pointing at its own `<title>` and `<desc>`,
  so a screen reader announces what it shows; a purely decorative SVG takes
  `aria-hidden="true"` instead;
- uses a `viewBox` and no fixed width, so it scales;
- gives each `<marker>` and `<title>` a unique `id` on the page.

The overlay is a `<details>` element: it opens without script, and the notes are real
text. Keep the `<svg>` and the `<details>` together inside `.figure-canvas`, so the
canvas is exactly the diagram's size. Anchor each `.overlay-note` to its pin:

- `--x` is the pin's `cx` divided by the viewBox width, as a percentage;
- `--y` is the pin's `cy` divided by the viewBox height, as a percentage;
- `data-side` is `right` (the default), `left`, `below`, or `above`, and a caret
  points at the pin. Use `left` for pins near the right edge.

For a pin at `cx=650 cy=166` in a `0 0 720 250` viewBox, write
`style="--x: 90.28%; --y: 66.4%" data-side="left"`. `--note-w` (default `15rem`)
sets a note's width.

When the overlay opens, the template's script keeps each note on its pin. It tries
the authored side first, then the other sides and narrower widths, until the note
stays inside the diagram without overlapping another note or covering another pin.
If a note still cannot fit, the numbered notes are listed under the diagram instead.
A click anywhere except the *Explain* control closes the notes, and so does Escape.
On narrow screens the notes always stack below the diagram.

## Step 4 — Validate

```bash
scripts/validate-html-page.sh --page docs/pages/<slug>.html
```

It checks the doctype and language, all 32 light and 31 dark Luma tokens, the theme
toggle, the table of contents and every in-page link, SVG labelling, that nothing is
loaded from the network (statically, and through the Content-Security-Policy), and
the sources section. Fix every failure; do not remove a
check's subject to silence it.

Then confirm no placeholder remains:

```bash
grep -n '{{' docs/pages/<slug>.html && echo "placeholders remain"
```

The template itself is validated with `--no-sources`, because it has no evidence of
its own.

## Step 5 — Report

Return:

- the path written;
- the sections and components used;
- the commands and files the figures came from;
- anything that could not be determined, and how the page shows it;
- the validator result.

## Boundaries

- Never invent a figure, a status, or a relationship. Cite it, or mark it unknown.
- Never load anything external: no CDN, no web font, no `<script src>`, no remote image.
- Never edit the Luma tokens. They are the product decision (US-14.1 `design.md`
  Appendix A, under `openspec/changes/archive/` once archived), and the template
  carries them verbatim.
- Never write a literal colour; use a token.
- Never modify product code, `SPECS.md`, or any change artifact. The skill writes one
  page under `docs/pages/`.
