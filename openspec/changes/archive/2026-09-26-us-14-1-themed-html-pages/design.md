# Design — us-14-1-themed-html-pages

Story: US-14.1

This change adds a new artifact format (the HTML page), a new external contract
(`validate-html-page.sh` and its exit codes), and a new template. `openspec/config.yaml`
requires a design artifact for that.

## Decisions

### 1. A skill, not an agent

Generating a page is one bounded task that the invoking session can do with its own
tools: read the repository, fill a template, validate. It needs no independent
judgement and no separate write scope, which is what the harness's agents exist for.
A skill is also invocable by name (`/generate-html-page`), which is how the Product
Manager asked to use it.

Rejected: a `page-writer` agent. It would add a ninth role with no authority of its own,
and the write-scope matrix in `check-write-scope.sh` has no place for it.

### 2. One self-contained file

Every style is inline in a `<style>` block, the theme toggle is a few lines of inline
script, and every diagram is inline SVG. The page loads nothing: no `<script src>`, no
`<link rel="stylesheet">`, no web font, no CDN. It opens from disk, can be attached to
an email, and still renders years later.

Rejected: Tailwind from a CDN plus shadcn components. It needs network access at view
time and a build to be reproducible, and the page would no longer be one file.

**Enforcement (R3, from review r3 F-4 and F-5).** A static reading of HTML and CSS
cannot be complete. Form feeds, character references, duplicate attributes, comment
quirks, and CSS escapes all spell a load the reader does not decode, and an inline
script can load code at run time. Every page therefore opens `<head>` with
`<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src
'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">`. The browser then refuses
every network load, and the validator's `csp` rule checks the policy is the first
element in `<head>`. The static `self-contained` rule stays as a readable first
diagnosis. Rejected: a heuristic scan of script bodies for `import` or
`createElement`, which is incomplete and would wrongly reject harmless inline script.

### 3. The Luma tokens are the contract, verbatim

The template carries the supplied `:root` and `.dark` blocks exactly. Components refer
only to `var(--token)`, never to a literal colour, so the two modes cannot drift.
The validator checks every token and its value, so a page that edits the palette fails.

Two derived values are needed that the palette does not define, and both are expressed
in terms of the tokens rather than as new colours:

| Need | Expression |
|---|---|
| a subtle table-row stripe | `color-mix(in oklch, var(--muted) 50%, transparent)` |
| a translucent overlay backdrop | `color-mix(in oklch, var(--background) 80%, transparent)` |

### 4. Light, dark, and system

The theme follows the shadcn convention: the `dark` class on `<html>` selects `.dark`.
A small inline script runs in `<head>`, before first paint, so there is no flash of the
wrong theme:

```text
stored choice in localStorage ("theme": "light" | "dark")  -> use it
no stored choice                                            -> follow prefers-color-scheme
toggle clicked                                              -> flip, store the choice
```

### 5. Diagrams are inline SVG, drawn from tokens

Each diagram is an `<svg role="img" aria-labelledby="…">` with a `<title>` and a
`<desc>`, so a screen reader announces what it shows. Fills and strokes use the tokens
(`var(--card)`, `var(--border)`, `var(--primary)`, `var(--chart-N)`), so every diagram
switches with the theme.

| Component | How |
|---|---|
| diagram with overlay | the SVG sits in a `.figure-canvas` sized exactly to it; a `<details>` "Explain" control reveals a callout layer over the canvas. Each callout is anchored beside its numbered pin: `--x`/`--y` are the pin's viewBox position as percentages, and `data-side` sets which side a caret points from. When the overlay opens, a layout pass keeps each callout on its own pin. It tries the authored side, then the other sides and narrower widths, and the callout must stay inside the canvas without overlapping another callout or covering another pin. If a callout still cannot fit, all callouts are listed under the diagram. A click anywhere but the control closes the callouts, and so does Escape (human PM request, 2026-09-26). The layer opens without script, and the callouts are real text |
| entity-relationship | tables as `<g>` groups with a header row and one row per column; `PK`/`FK` badges; crow's-foot relationship lines drawn as paths with markers |
| infrastructure | dashed boundary rectangles for trust zones, nodes as rounded rectangles with a type label, directed edges with markers and protocol labels |

Rejected: Mermaid. It needs a runtime script, which breaks decision 2.

### 6. Evidence, not invention

A page that reports repository status is a claim about the repository. The skill
gathers every figure with a command, and the page ends with a `Sources` section listing
the files and commands behind it. This follows the Codebase Analyst's rule: an
observation is traceable, an unknown is marked unknown (NFR-005).

### 7. Where pages live

Generated pages go under `docs/pages/<slug>.html`. The template lives with the other
harness templates in `scripts/templates/`.

## Validator contract

`scripts/validate-html-page.sh --page <file> [--quiet] [--no-sources]`

| Rule | Check |
|---|---|
| `doctype` | the file starts with `<!doctype html>` |
| `lang` | `<html>` carries a `lang` attribute |
| `tokens-light` | every Luma light token is defined in `:root` with its supplied value |
| `tokens-dark` | every Luma dark token is defined in `.dark` with its supplied value |
| `toggle` | a theme toggle exists, the script toggles the `dark` class, uses `localStorage`, and reads `prefers-color-scheme` |
| `toc` | a `nav.toc` precedes the first `<section>`, and every `<section id>` is linked from it |
| `toc-links` | every `href="#…"` resolves to an element `id` on the page |
| `svg-a11y` | every `<svg>` has `role="img"` with an accessible name, or `aria-hidden="true"` |
| `self-contained` | no `<script src>`, no `<link rel="stylesheet">`, no `@import`, no `url(http…)`, no `@font-face` with a remote source |
| `csp` | the first element in `<head>`, after an optional `<meta charset>`, is the self-contained Content-Security-Policy (§2, Enforcement) |
| `sources` | a `section#sources` exists (skipped with `--no-sources`, for the template) |

Exit codes: `0` pass, `1` a rule failed (each failure names its rule), `2` usage error.

## Appendix A — The Luma palette (human Product Manager decision, 2026-09-26)

These are the tokens supplied verbatim by the human Product Manager. The pasted text
carried HTML-escaping artefacts (`&#x20;` for a space, `\--` for `--`); those were
removed, and no value was changed. This appendix is the source of truth for the
`tokens-light` and `tokens-dark` rules: `--radius` is defined in `:root` only, so the
light block has 32 tokens and the dark block 31.

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.488 0.243 264.376);
  --primary-foreground: oklch(0.97 0.014 254.604);
  --secondary: oklch(0.967 0.001 286.375);
  --secondary-foreground: oklch(0.21 0.006 285.885);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --chart-1: oklch(0.845 0.143 164.978);
  --chart-2: oklch(0.696 0.17 162.48);
  --chart-3: oklch(0.596 0.145 163.225);
  --chart-4: oklch(0.508 0.118 165.612);
  --chart-5: oklch(0.432 0.095 166.913);
  --radius: 0.625rem;
  --sidebar: oklch(0.985 0 0);
  --sidebar-foreground: oklch(0.145 0 0);
  --sidebar-primary: oklch(0.546 0.245 262.881);
  --sidebar-primary-foreground: oklch(0.97 0.014 254.604);
  --sidebar-accent: oklch(0.97 0 0);
  --sidebar-accent-foreground: oklch(0.205 0 0);
  --sidebar-border: oklch(0.922 0 0);
  --sidebar-ring: oklch(0.708 0 0);
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.205 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.205 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.424 0.199 265.638);
  --primary-foreground: oklch(0.97 0.014 254.604);
  --secondary: oklch(0.274 0.006 286.033);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.704 0.191 22.216);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.556 0 0);
  --chart-1: oklch(0.845 0.143 164.978);
  --chart-2: oklch(0.696 0.17 162.48);
  --chart-3: oklch(0.596 0.145 163.225);
  --chart-4: oklch(0.508 0.118 165.612);
  --chart-5: oklch(0.432 0.095 166.913);
  --sidebar: oklch(0.205 0 0);
  --sidebar-foreground: oklch(0.985 0 0);
  --sidebar-primary: oklch(0.623 0.214 259.815);
  --sidebar-primary-foreground: oklch(0.97 0.014 254.604);
  --sidebar-accent: oklch(0.269 0 0);
  --sidebar-accent-foreground: oklch(0.985 0 0);
  --sidebar-border: oklch(1 0 0 / 10%);
  --sidebar-ring: oklch(0.556 0 0);
}
```

## Appendix B — Planner open questions, resolved (human Product Manager, 2026-09-26)

| # | Question | Decision |
|---|---|---|
| 1 | Where is the palette recorded? | Appendix A above |
| 2 | Toggle marker | `id="theme-toggle"` |
| 3 | Task 1.6 has no scenario of its own | Keep it as a supporting task |
| 4 | Must `sources` contain content? | Yes: at least one `<li>` or `<code>` |
| 5 | Add `SPEC-LOGS/README-EPIC-14.md`? | Yes, by the Product Manager after archival, as for every epic |
