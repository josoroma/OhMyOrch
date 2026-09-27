# Test Report — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: pass
Coverage: 7/7 acceptance criteria evaluated

Independent acceptance record (2026-09-26, working tree). The Tester did not write this
change. The criteria are the seven scenarios of the change's
`specs/html-pages/spec.md`, quoted below; the token reference is `design.md` Appendix A
(the human Product Manager's palette decision), not the validator's embedded copy.

- **Method: mixed.** Criterion 2 was observed at runtime in headless Chrome, driven over
  the DevTools protocol by a Tester-written Node script (E-2). Criteria 1, 3, 4, 5 and 6
  rest on Tester-written Python parsers (`html.parser`, not the shipped validator) that
  compare the shipped files with the spec and Appendix A, plus mutation probes that show
  `scripts/validate-html-page.sh` rejects a broken copy. Criterion 7 rests on 24 probe
  pages (23 non-conforming, 1 conforming) run through the validator (E-7).
- **The checks are mine.** `scripts/test-html-page.sh` was run only as supplementary
  regression (E-8); no row rests on it.
- **Real repository untouched.** Every probe was a copy in
  `mktemp -d /tmp/us141-tester.XXXXXX` (`/tmp/us141-tester.SV4dsS`), removed with
  `rm -rf` afterwards; Chrome ran with a throwaway `--user-data-dir` inside it and was
  confirmed stopped. The only file written in the repository is this report.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | The page uses the Luma theme in light and dark — "its ":root" block MUST define every Luma light token with its supplied value" and "its ".dark" block MUST define every Luma dark token with its supplied value" | PASS | E-1: Tester-written parser extracted Appendix A (32 light, 31 dark) and compared it with the single `:root` and `.dark` block of both `scripts/templates/html-page.html` and `docs/pages/harness-overview.html`: 32/32 and 31/31 match, 0 mismatched, 0 extra, in both files. Mutation (E-7 p02, p03, p04, t1): changing `--primary`, deleting `--radius`, changing dark `--border`, or changing the template's dark `--ring` each exits 1 naming `tokens-light` / `tokens-dark`. |
| 2 | The reader can switch between light and dark — "the "dark" class MUST be toggled on the root element", "the choice MUST persist when the page is reloaded", "with no stored choice the page MUST follow the system color scheme" | PASS | E-2: observed at runtime in headless Chrome on copies of both files. With storage cleared, emulated `prefers-color-scheme: light` → `dark=false`; `dark` + reload → `dark=true`; switching live to `light` → `dark=false` (no reload). Clicking `#theme-toggle` → `dark=true`, `localStorage.theme=dark`; reload → still `dark=true`; second click → `dark=false`, stored `light`; with system `dark` and stored `light`, reload keeps `dark=false` (stored choice wins). Computed `--background` switched between `oklch(1 0 0)` and `oklch(0.145 0 0)` with the class. Identical results for the template. |
| 3 | The page opens with a table of contents — "a table of contents MUST appear before the first section", "every section MUST be linked from it", "every table-of-contents link MUST resolve to an element on the page" | PASS | E-3: Tester-written parser. Example page: 1 `nav.toc` at element 25, first `<section>` at element 56; 14 sections, 14 TOC links, 0 sections unlinked; 15 in-page links, 0 unresolved. Template: TOC at 25, first section at 42; 7/7 sections linked; 8 in-page links, 0 unresolved. Mutation (E-7): removing the `#backlog` TOC link (p07) exits 1 naming `toc: … not linked … backlog`; moving the TOC after the first section (p08) exits 1 naming `toc: … comes after the first <section>`; a dangling `#no-such-id` link (p09) exits 1 naming `toc-links`. |
| 4 | The page presents content through the supported components — "it MUST provide a table, a list, an SVG diagram with an overlay, an SVG entity-relationship diagram, and an SVG infrastructure diagram" and "every SVG MUST be labelled for assistive technology or marked decorative" | PASS | E-4: inspection of `scripts/templates/html-page.html` by Tester-written parser. `section#table` (`data-component="table"`) holds a `<table>`; `section#lists` (`list`) holds `<ul>` and `<ol>`; `section#flow` (`svg-overlay`) holds an `<svg>` plus `details.overlay-toggle` → `div.overlay-layer` with numbered `overlay-note`s and 2 `svg-pin`s; `section#data-model` (`svg-er`) holds an `<svg>` with 2 entity heads/bodies, PK/FK badges and 3 edges; `section#infrastructure` (`svg-infra`) holds an `<svg>` with a zone, 4 nodes, solid and dashed edges, and a legend. All 4 SVGs: 3 have `role="img"` + `aria-labelledby` whose `<title>`/`<desc>` ids all exist; the 4th (legend swatch) is `aria-hidden="true"`. Mutation (E-7 p10): removing `role="img"` exits 1 naming `svg-a11y`. |
| 5 | The page is a self-contained single file — "it MUST NOT load an external script, stylesheet, or font" | PASS | E-5: Tester-written parser on both files: 0 `<script src>`, 0 `<link>`, 0 `@import`, 0 `@font-face`, 0 `url(…)`, 0 remote `src`/`href`. `<head>` order is `meta[charset]`, then `meta[http-equiv=Content-Security-Policy]` with `default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:`. Mutation (E-7): external `<script src>` (p11, t2), `<link rel="stylesheet">` (p12), `@font-face` (p13), `@import` (p14), a remote `url()` font (t3) each exit 1 naming `self-contained`; moving the CSP meta after `<title>` (p15) exits 1 naming `csp`. |
| 6 | The page cites the evidence behind its content — "it MUST contain a sources section listing the files and commands its figures came from" | PASS | E-6: example page `docs/pages/harness-overview.html` has `section#sources` with 16 `<li>` and 31 `<code>` entries naming files (`SPECS.md`, `.claude/settings.json`, `CLAUDE.md`, …) and commands (`grep -cE '^# EPIC-[0-9]+:' SPECS.md`, `ls openspec/changes/archive \| wc -l`, …), each paired with the figure it produced. Mutation (E-7): removing the section and every link to it (p21) exits 1 naming `sources: no <section id="sources">`; emptying it (p17) exits 1 naming `sources: … lists no file or command`. |
| 7 | The validator rejects a non-conforming page — "it MUST exit 1" and "it MUST name the rule that failed" | PASS | E-7: 23 non-conforming probes, each breaking one rule (doctype, lang, tokens-light ×2, tokens-dark ×2, toggle ×2, toc ×2, toc-links, svg-a11y, self-contained ×6, csp, sources ×4): all 23 exit 1, and every one prints a `FAIL` line whose prefix is the broken rule. The unmodified copy (p01) exits 0. Usage errors (no `--page`, missing file, unknown option, `--page` without value) each exit 2. |

## Evidence Commands

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-14-1-themed-html-pages --quiet
```

```text
  PASS  selection        change 'us-14-1-themed-html-pages' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   20/20 tasks complete
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
  PASS  acceptance       artifact contracts satisfied
  First incomplete gate: testing
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Luma tokens against design.md Appendix A (Tester-written parser)

```bash
python3 - <<'PY'   # strips /* */, extracts "--name: value" of each exact ":root {" / ".dark {" rule,
PY                 # reference = the css fence between "## Appendix A" and "## Appendix B" of design.md
```

```text
appendix: light 32 dark 31
scripts/templates/html-page.html :root blocks: 1 tokens: 32 matching: 32 mismatched: [] extra: []
scripts/templates/html-page.html .dark blocks: 1 tokens: 31 matching: 31 mismatched: [] extra: []
docs/pages/harness-overview.html :root blocks: 1 tokens: 32 matching: 32 mismatched: [] extra: []
docs/pages/harness-overview.html .dark blocks: 1 tokens: 31 matching: 31 mismatched: [] extra: []
```

Baseline validator runs on the shipped files:

```bash
scripts/validate-html-page.sh --page docs/pages/harness-overview.html            # exit=0, 11 rules pass, 6 SVGs
scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources  # exit=0, 10 rules pass, sources skipped
```

### E-2 — Theme toggle at runtime (headless Chrome, Tester-written CDP script)

```bash
T=$(mktemp -d /tmp/us141-tester.XXXXXX)
cp docs/pages/harness-overview.html scripts/templates/html-page.html "$T/"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --remote-debugging-port=9333 --user-data-dir="$T/profile" --no-first-run --disable-gpu about:blank &
node "$T/cdp.mjs" 9333 "file://$T/harness-overview.html"   # Node 22 fetch + WebSocket, no dependencies
node "$T/cdp.mjs" 9333 "file://$T/html-page.html"
```

The script uses `Emulation.setEmulatedMedia` for `prefers-color-scheme`, `Page.reload`
for reloads, and `document.getElementById("theme-toggle").click()` for the reader's
action; after each step it reads `classList.contains("dark")`,
`localStorage.getItem("theme")`, and the computed `--background`.

```text
== harness-overview.html
A no stored choice, system=light             dark=false  stored=null  --background=oklch(1 0 0)
B no stored choice, system=dark (reload)     dark=true  stored=null  --background=oklch(0.145 0 0)
C no stored choice, system->light live       dark=false  stored=null  --background=oklch(1 0 0)
D after 1st toggle click                     dark=true  stored=dark  --background=oklch(0.145 0 0)
E after reload                               dark=true  stored=dark  --background=oklch(0.145 0 0)
F after 2nd toggle click                     dark=false  stored=light  --background=oklch(1 0 0)
G reload, system=dark, stored=light          dark=false  stored=light  --background=oklch(1 0 0)
H cleared, system=light                      dark=false  stored=null  --background=oklch(1 0 0)
exit=0
== html-page.html
(identical rows A–H)
exit=0
```

A/B/C show the system preference is followed with no stored choice (at load and live);
D/F show the toggle flips `dark` on `<html>`; E/G show the choice persists across reload
and overrides the system preference.

### E-3 — Table of contents (Tester-written parser)

```bash
python3 - <<'PY'   # html.parser: element order of nav.toc vs first <section>, TOC hrefs vs section ids, all href="#…" vs all ids
PY
```

```text
== docs/pages/harness-overview.html
 toc navs: 1  toc position: 25  first section position: 56  toc before first section: True
 sections: 14 ['overview', 'idea', 'workflows', 'harness', 'roles', 'loop', 'senior', 'steps', 'example', 'artifacts', 'enforcement', 'backlog', 'suites', 'sources']
 toc links: 14
 sections not linked from toc: []
 in-page links: 15  unresolved: []
== scripts/templates/html-page.html
 toc navs: 1  toc position: 25  first section position: 42  toc before first section: True
 sections: 7 ['overview', 'table', 'lists', 'flow', 'data-model', 'infrastructure', 'sources']
 toc links: 7
 sections not linked from toc: []
 in-page links: 8  unresolved: []
```

### E-4 — Template components and SVG labels (Tester-written parser + inspection)

```bash
python3 - <<'PY'   # element kinds inside each section; every <svg>'s role / aria-hidden / aria-labelledby targets
PY
grep -n 'data-component' scripts/templates/html-page.html
awk '/<section id="data-model"/,/<\/section>/' scripts/templates/html-page.html | grep -oE 'class="[^"]*"' | sort | uniq -c
awk '/<section id="infrastructure"/,/<\/section>/' scripts/templates/html-page.html | grep -oE 'class="[^"]*"' | sort | uniq -c
```

```text
section#table: ['table']
section#lists: ['ol', 'ul']
section#flow: ['details.overlay-toggle', 'div.overlay-layer', 'p', 'svg']
section#data-model: ['svg']
section#infrastructure: ['svg']
 svg in flow role= img labelledby= flow-title flow-desc -> [('flow-title', True), ('flow-desc', True)]
 svg in data-model role= img labelledby= er-title er-desc -> [('er-title', True), ('er-desc', True)]
 svg in infrastructure role= img labelledby= infra-title infra-desc -> [('infra-title', True), ('infra-desc', True)]
 svg in infrastructure role= None aria-hidden= true   (legend swatch, decorative)

371:  <section id="table" data-component="table">
387:  <section id="lists" data-component="list">
396:  <section id="flow" data-component="svg-overlay">
431:  <section id="data-model" data-component="svg-er">
469:  <section id="infrastructure" data-component="svg-infra">
data-model: 2 svg-er-head, 2 svg-er-body, 2 svg-badge-pk, 1 svg-badge-fk, 3 svg-edge
infrastructure: 1 svg-zone, 1 svg-node-primary, 1 svg-node, 2 svg-node-muted, 2 svg-edge, 2 svg-edge-dash, 1 svg-arrow, 1 legend
flow: 2 svg-pin, overlay-note paragraphs numbered 1, 2 (template lines 418–422)
```

### E-5 — Self-contained and CSP (Tester-written parser)

```bash
python3 - <<'PY'   # <head> element order; <script src>, <link>, remote src/href; @import, @font-face, url() in <style>
PY
```

```text
== docs/pages/harness-overview.html
 <head> elements in order: ['meta[charset]', 'meta[http-equiv=Content-Security-Policy]', 'meta', 'title']
 external script/link tags: []
 css @import: 0  @font-face: 0  url(: []
 http(s) URLs anywhere in markup attributes: []
== scripts/templates/html-page.html
 <head> elements in order: ['meta[charset]', 'meta[http-equiv=Content-Security-Policy]', 'meta', 'title']
 external script/link tags: []
 css @import: 0  @font-face: 0  url(: []
 http(s) URLs anywhere in markup attributes: []
```

Head line 5 of the example page, inspected:
`<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">`.

### E-6 — Sources section (Tester-written parser + inspection)

```bash
awk '/<section id="sources"/,/<\/section>/' docs/pages/harness-overview.html
```

```text
 sources li/code count: 16 31
<li><code>grep -cE '^# EPIC-[0-9]+:' SPECS.md</code> — 14 epics</li>
<li><code>grep -cE '^### US-[0-9]+\.[0-9]+:' SPECS.md</code> — 28 stories</li>
<li><code>ls openspec/changes/archive | wc -l</code> — 27 archived changes</li>
<li><code>.claude/settings.json</code> — the hook wiring in Hooks and guards</li>
… (16 entries, each a file or command paired with the figure it produced)
```

### E-7 — Validator rejection probes (copies in the temp directory)

Each probe is a copy of `harness-overview.html` (p01–p21) or `html-page.html` (t1–t3)
with one rule broken. `t1`–`t3` were run with `--no-sources` (template).

```bash
for p in "$T"/probes/*.html; do scripts/validate-html-page.sh --page "$p" --quiet; echo "exit=$?"; done
```

```text
p01-conforming             exit=0
p02-tokens-light           exit=1  tokens-light: 1 of 32 :root tokens missing or changed (first: '--primary: oklch(0.488 0.243 264.376)')
p03-tokens-light-missing   exit=1  tokens-light: 1 of 32 :root tokens missing or changed (first: '--radius: 0.625rem')
p04-tokens-dark            exit=1  tokens-dark: 1 of 31 .dark tokens missing or changed (first: '--border: oklch(1 0 0 / 10%)')
p05-toggle-no-id           exit=1  toggle: no element with id="theme-toggle"
p06-toggle-no-storage      exit=1  toggle: the script does not persist the choice in localStorage
p07-toc-link-removed       exit=1  toc: section(s) not linked from the table of contents: backlog
p08-toc-after-section      exit=1  toc: the table of contents comes after the first <section>
p09-toc-dangling           exit=1  toc: … not linked … backlog ; toc-links: link(s) to no element on the page: #no-such-id
p10-svg-unlabelled         exit=1  svg-a11y: svg #1 has no role="img"
p11-external-script        exit=1  self-contained: the page loads external resources: <script src>
p12-external-stylesheet    exit=1  self-contained: the page loads external resources: <link rel=stylesheet>
p13-font-face              exit=1  self-contained: the page loads external resources: @font-face
p14-import                 exit=1  tokens-light: 32 of 32 … ; self-contained: the page loads external resources: @import
p15-csp-not-first          exit=1  csp: <head> does not open with the self-contained Content-Security-Policy
p16-sources-removed        exit=1  toc-links: … #sources ; sources: no <section id="sources"> citing the evidence behind the page
p17-sources-empty          exit=1  sources: section#sources lists no file or command (<li> or <code>)
p18-no-doctype             exit=1  doctype: the file does not start with <!doctype html>
p19-no-lang                exit=1  lang: <html> has no lang attribute
p20-sources-removed-clean  exit=1  toc-links: … #sources (header meta link remains) ; sources: no <section id="sources"> …
p21-sources-removed-isolated exit=1  sources: no <section id="sources"> citing the evidence behind the page
t1-template-token          exit=1  tokens-dark: 1 of 31 .dark tokens missing or changed (first: '--ring: oklch(0.556 0 0)')
t2-template-ext-script     exit=1  self-contained: the page loads external resources: <script src>
t3-template-ext-font       exit=1  self-contained: the page loads external resources: remote url()
```

Usage errors:

```bash
scripts/validate-html-page.sh                          # exit=2  (error: --page is required)
scripts/validate-html-page.sh --page "$T/nope.html"    # exit=2  error: page not found: /tmp/us141-tester.SV4dsS/nope.html
scripts/validate-html-page.sh --bogus                  # exit=2  error: unknown option '--bogus'
scripts/validate-html-page.sh --page                   # exit=2  error: --page needs a value
```

Each failing run ended with the validator's summary line reporting the count of failed
rules (e.g. "2 rule(s) failed" for p20); p01 ended with its contract-satisfied summary.

Observation (not a failure): in p14, an `@import` placed directly before `:root` also
made `tokens-light` report 32/32 changed, because the validator reads the text from the
previous `}` as the selector. The rule that actually broke (`self-contained`) is still
named, so criterion 7 holds; the extra `tokens-light` line is noise a page author might
find misleading.

### E-8 — Supplementary regression (implementer's suite; no row rests on it)

```bash
scripts/test-html-page.sh | tail -4
```

```text
  passed: 151
  failed: 0

  (closing line: the html page contract holds — overall pass)
```

### Cleanup

```bash
pgrep -f "user-data-dir=$T/profile"   # no process
rm -rf "$T"                           # temp directory removed; ls -d /tmp/us141-tester.* matched nothing
```

## Failures

None.

## Result

All seven criteria were evaluated, and all seven passed. Criterion 2 was observed at
runtime in headless Chrome rather than inferred from the script text. Criteria 1, 3, 4,
5 and 6 were established by Tester-written parsers against `design.md` Appendix A and
the spec, and each was confirmed to be enforced by a mutation the validator rejected.
Criterion 7 held across 23 single-rule probes (exit 1, rule named), 1 conforming copy
(exit 0), and 4 usage errors (exit 2). One non-blocking observation is recorded under
E-7 (p14).

## Handoff

All criteria pass. Gate 6 (testing) can now pass. The Product Manager evaluates the
completion gate (`scripts/completion-gate.sh --change us-14-1-themed-html-pages`) and
decides archival (`/opsx:archive`). Acceptance alone does not archive the change.
