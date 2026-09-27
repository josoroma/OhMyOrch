# Review — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: fail
Blocking: 2 findings
Coverage: 7/7 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-14-1-themed-html-pages --strict` reports "Change 'us-14-1-themed-html-pages' is valid"; no spec/task/design mismatch. The blocking findings below are behavioural and come from probes, not from the verify step.

## Summary

This is **round 3**, and it **supersedes `history/review-r2.md`**. Round 2 raised one
blocking finding, F-3: the `self-contained` rule missed padded `=`, `/` separators, and
`>` inside quoted values. R2.1 replaced the regex match with an awk tokenizer,
`tag_findings` (`scripts/validate-html-page.sh` lines 392–438). All 12 round-2 bypasses
are now rejected. So are my own variants: tabs, newlines, CRLF, mixed case, unquoted
values, `href` before `rel`, and `modulepreload`. There are no false positives. Every
suite and validator passes. The template and the example page load nothing external,
and the example page's figures match the repository.

The rule still does not follow HTML parsing where it matters. I loaded each probe page
in headless Chrome against a local request-logging server. **Twenty pages fetched an
external stylesheet, script, or font, and the validator accepted every one (exit 0)**
(F-4, F-5). F-4 covers form feed as attribute whitespace, character references and
duplicate attributes in `rel`, comment syntax that HTML ends earlier than the validator
does, raw-text bodies read as markup, SVG `<script href>`, and CSS escapes. F-5 covers
remote scripts loaded by inline JavaScript. The spec's `MUST NOT load an external
script, stylesheet, or font` makes both blocking. Scenario 7 therefore fails, and the
other six pass.

## Blocking Issues

### Finding F-4: `self-contained` accepts markup and CSS that load an external stylesheet, script, or font

Requirement: Scenario "The page is a self-contained single file": a generated page `MUST NOT load an external script, stylesheet, or font`. Scenario "The validator rejects a non-conforming page": for a page that violates any rule, the validator `MUST exit 1` and `MUST name the rule that failed`.
Observed: Each tag was inserted into a copy of `scripts/fixtures/html-pages/valid/page.html`. For every probe below, `scripts/validate-html-page.sh` exits 0 with `PASS  self-contained`, and headless Chrome fetched the named resource from `127.0.0.1` (see Verification Detail). The causes:
  (a) **Form feed is HTML whitespace but not validator whitespace.** `ws()` at line 394 accepts only space and tab. The tag-name pattern at line 397 is `[ \t\/>]`. `FLAT` at line 176 translates only `\n\t\r`. These probes each loaded: `<link\frel=stylesheet href=…>`, `<script\fsrc=…>`, `<script src\f=…>`, `<link rel=\fstylesheet …>`, and `<link rel="alternate\fstylesheet" …>`.
  (b) **Character references in `rel` are not decoded.** `rel="style&#115;heet"` and `rel="alternate&Tab;stylesheet"` both loaded.
  (c) **Duplicate attributes are resolved the wrong way.** Line 426 (`if (name == "rel") rel = val`) keeps the *last* `rel`, but HTML keeps the *first*. `<link rel="stylesheet" rel="icon" href=…>` loaded.
  (d) **Comment stripping (lines 176–186) does not follow HTML comment syntax.** `<!-->` and `<!--->` end a comment at once, and `--!>` also closes one. The validator strips everything up to the next `-->`, so a `<link>` placed after these forms is hidden. Three probes loaded: `<!--> <link rel="stylesheet" …> -->`, `<!---> …`, and `<!-- x --!> …`. The stripper also treats `<!--` as a comment inside a script body, an attribute value (`<div title="<!--">`), and `<textarea>` text, where HTML does not. All three hid a real `<link>` that loaded. In CSS, `<!--` and `-->` are ignored, so `<style><!-- @import "…"; --></style>` loaded its import. `CSS` (line 191) is built from `FLAT` after the import has already been removed.
  (e) **Raw-text bodies are tokenized as markup.** `tag_findings` scans the whole flattened page (lines 397 and 436). A `<script t='` inside a JavaScript string opens a pseudo-tag, and its quote runs past a real `<link rel="stylesheet">`. Both the `<script>` body variant and the `<textarea>` body variant loaded.
  (f) **SVG script `href`.** Line 425 flags only `src`. `<svg …><script href="http://…/x.js"></script></svg>` and the `xlink:href` form both loaded and ran an external script.
  (g) **CSS escapes.** Lines 445–447 match literal text. `<style>@\69mport "http://…/x.css";</style>` loaded a stylesheet, and `@import u\72l(…)` did too. `@\66ont-face { src: u\72l(http://…/f.woff2) }` loaded a font.
None of the 34 invalid fixtures uses any of these forms, so `scripts/test-html-page.sh` (106 passed) does not catch them. `scripts/README.md` lines 1336–1341 say `<script>` and `<link>` start tags "are tokenized by HTML attribute rules". That overstates what the tokenizer does for (a), (b), and (c).
Expected: The validator exits 1 with `FAIL  self-contained: …` for every page above. HTML treats each of them as loading an external stylesheet, script, or font.
Remediation: Choose one approach and cover every cause (a)–(g) with a fixture.
  **Option A, parser fixes.** Treat `\f` as whitespace in `ws()`, in the tag-name pattern, and in the `FLAT` translation. Decode character references in `rel` values, or reject any `&` in a `<link>` `rel`. Keep the first occurrence of each attribute. Make comment stripping follow HTML: `<!-->` and `<!--->` end at once, `--!>` closes, and `<!--` is not a comment inside `<script>`, `<style>`, `<textarea>`, `<title>`, or a quoted attribute value. Skip `<script>`, `<style>`, `<textarea>`, and `<title>` bodies when tokenizing tags. Flag `href` and `xlink:href` on `<script>`. Decode CSS escapes (`\hex` and `\char`), or reject any `\` in an at-keyword or before `url(`, and keep `<!--`/`-->` inside `<style>` as CSS.
  **Option B, a Content-Security-Policy rule.** Require the template and every page to carry `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">` right after `<meta charset>`, before any other element. The validator checks that the meta is present, placed there, and has exactly this value. In Chrome, adding this meta cut the fetches from 12 representative bypass pages to 0. Those pages covered (c), (d), (e), (f), and (g), plus both F-5 pages. The example page with the meta also made 0 requests. Option B also resolves F-5, and Option A does not.
  With either option, add one invalid fixture per cause to `make-fixtures.py`, with matching `rejects … self-contained` cases in `scripts/test-html-page.sh`. Correct `scripts/README.md` lines 1336–1341 and the validator header (lines 27–31). Then update the case and fixture counts in `README.md` (lines 1543, 1590) and `scripts/README.md` (lines 32, 1357, 1359), and the suite row and total on `docs/pages/harness-overview.html` (lines 565, 328).

### Finding F-5: a page whose inline script loads an external script passes `self-contained`

Requirement: Scenario "The page is a self-contained single file": `MUST NOT load an external script`. Scenario "The validator rejects a non-conforming page": `MUST exit 1`.
Observed: In headless Chrome, each of these pages fetched a remote script, and the validator exits 0 on both. First, `<script type="module">import "http://127.0.0.1:18731/x.js";</script>`. Second, `<script>var s = document.createElement("script"); s.src = "http://…/x.js"; document.head.appendChild(s);</script>`. The validator reads only `<script>` and `<link>` attributes plus `<style>` bodies (lines 383–452). Inline script bodies are checked only for the toggle rule (line 280 onward). Neither the validator header nor `README.md` lines 1619–1622 nor `scripts/README.md` lists script-mediated loads as a limit.
Expected: A page that loads an external script fails `self-contained`. If script-mediated loads are out of the validator's scope, the spec, design, and docs must say so as a decided limit.
Remediation: Adopt Option B from F-4. The CSP meta blocked both pages in Chrome (0 requests), and the validator can check it statically. Otherwise, ask the human Product Manager for a decision that the validator's `self-contained` rule covers declarative markup and CSS only. Record that decision in `implementation-plan.md` and `design.md`, and list script-mediated loads as a limit in the validator header, `README.md` line 1621, and `scripts/README.md` line 1341. A heuristic that searches script bodies for `import`, `createElement`, or `fetch` is not a remediation: it is incomplete, and it would wrongly reject harmless inline scripts.

## Observations

These are not blocking. Each is recorded for the Implementer or the Product Manager.

- **O-23: R2.1 is resolved for every form it named (verified independently).**
  `tag_findings` is at `scripts/validate-html-page.sh` lines 392–438. The new fixtures
  are `scripts/fixtures/html-pages/make-fixtures.py` lines 79–82, and their suite cases
  are `scripts/test-html-page.sh` lines 172–175. All 12 round-2 F-3 probes now exit 1
  with `FAIL  self-contained: …`: the three padded-`=` link forms, the padded preload,
  both padded script forms, the padded module script, `/` separators on link and script,
  and `>` in a quoted value on link and script. Chrome confirmed that all 12 really load,
  so these results are true positives.
- **O-24: My own variants are rejected** (exit 1, `self-contained`). They are
  `<link\trel\n=\t"stylesheet"\nhref=…>`, a CRLF-split `<script src>`, `<LINK REL="STYLESHEET">`,
  `<ScRiPt SrC=…>`, unquoted `rel=stylesheet href=…`, `href` before `rel` with `type`
  between them, `rel=stylesheet href=…/` (self-closing), `rel="\t alternate \t stylesheet "`,
  and `rel="modulepreload"`. Chrome loaded each one.
- **O-25: No false positives.** These all exit 0, and Chrome fetched nothing:
  `<link rel="icon" href="data:,">`, `data-rel="stylesheet" rel="icon"`, and
  `<script data-src="https://…">` with an inline body. So did `rel="nostylesheet"`,
  inline script text containing `src` (`var src = "x"; { src: 1 } // src=`), and
  `<script srcset=…>`. The rest are `<!-- <link rel="stylesheet" …> -->`, escaped
  `&lt;link …&gt;` text, and the non-tags `<scriptx src=…>` and `<linked rel="stylesheet">`.
  An unterminated quote (`<link title="x rel=stylesheet href=…>`) exits 0, and Chrome
  loads nothing, because HTML consumes the rest of the file into the attribute value.
  That result is correct.
- **O-26: The rule is stricter than necessary in three cases.** `<script src="">`, a bare
  `<script src>`, and `<link rel="DNS-Prefetch" href="…">` without a scheme are rejected
  (exit 1), although Chrome made no request for them. This is consistent with the rule
  as documented at `scripts/README.md` line 1331. The round-2 O-14 cases still apply.
  None affects a page built from the template.
- **O-27: Other resource kinds load and pass, as documented limits.** In Chrome these
  all exit 0 and fetch a remote resource: `<img src>`, and `<iframe srcdoc>` with a
  nested `<script src>` (the nested script was fetched). The others are
  `<link rel="prefetch">`, `<link rel="icon">` with a remote href, and CSS
  `image-set("http://…" 1x)`. The validator header (lines 28–31), `README.md`
  lines 1621–1622, and `scripts/README.md` lines 1341–1343 name `<img>`, `<iframe>`,
  SVG `<image>`, and `style=""`. They do **not** name `prefetch`, `icon`, or `manifest`
  links, or `image-set()` with a bare string. Consider listing them, or covering them
  with F-4 Option B. Under the scoring note these are not MUST failures.
- **O-28: Round-2 O-15 is resolved.** `modulepreload` is rejected at
  `scripts/validate-html-page.sh` line 433, and it is documented at `scripts/README.md`
  line 1331.
- **O-29: Round-2 O-18 is resolved.** `.claude/skills/generate-html-page/SKILL.md`
  lines 142–144 and the template comment (`scripts/templates/html-page.html` lines
  12–13) now say that Appendix A moves under `openspec/changes/archive/` once the change
  is archived.
- **O-30: The counts are consistent.** `README.md` lines 1543 and 1590 read `106 cases`.
  `scripts/README.md` reads `106 cases` at lines 32 and 1357, and `34 invalid fixtures`
  at line 1359. `docs/pages/harness-overview.html` line 565 reads 106, and the total at
  line 328 reads 533 = 36 + 103 + 46 + 63 + 179 + 106. A `grep` for `98 cases`,
  `30 invalid`, or `525` in `README.md`, `scripts/README.md`, `CLAUDE.md`, the skill,
  and `docs/pages/` finds nothing.
- **O-31: The example page's figures match the repository** (see Verification Detail).
  They are 27 / 28 stories (line 323), 14 epics (324), 27 archived (325), 22 specs
  (326), and 24 definitions (327). The per-epic rows (lines 534–547) run from EPIC-1 2/2
  to EPIC-14 0/1. The page has 10 sources entries. After archival, US-14.1
  `IN PROGRESS` and EPIC-14 `0 / 1` will go stale, as the plan's Risks table expects.
- **O-32: The fixtures match their generator.** Running `make-fixtures.py` in a temporary
  tree and diffing with `diff -r` shows no difference. `invalid/` holds 34 fixtures,
  each exiting 1 with exactly one `FAIL`, and the 3 valid fixtures exit 0.
- **O-33: Scope is unchanged from round 2 (O-21).** `check-scope.sh` over git and untracked files
  reports 9 unpredicted files, all under
  `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/`. With `--diff`
  over `git diff --name-only` plus untracked files (70 paths), the only other unpredicted
  file is `openspec/delivery/goal.md`, which `delivery.sh` derives. The R2 edits touched
  predicted files only: the validator, `make-fixtures.py` and `invalid/`, the suite,
  `README.md`, `scripts/README.md`, `docs/pages/harness-overview.html`, the skill, the
  template, and `tasks.md`.
- **O-34: The tasks are honest.** `workflow-status.sh` reports `16/16 tasks complete`. R2.1
  is ticked, and every change its text requests is present: the tokenizer, four fixtures,
  four suite cases, and the counts. F-4 and F-5 cover forms and mechanisms that R2.1's
  text did not name.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The page uses the Luma theme in light and dark | PASS | I extracted the tokens from design.md Appendix A, from the validator's `LIGHT_TOKENS`/`DARK_TOKENS`, and from the template. Each source has 32 light and 31 dark tokens, and `cmp` finds all three identical. The validator prints `PASS  tokens-light: all 32 :root tokens match` and `PASS  tokens-dark: all 31 .dark tokens match` on both the template and `docs/pages/harness-overview.html`. The four `invalid/tokens-*` fixtures exit 1, each naming its own rule. |
| The reader can switch between light and dark | PASS | I ran the inline scripts of both files against a `document`/`localStorage`/`matchMedia` shim, with the same results for each. No stored choice with system light gives `dark=false`, and with system dark gives `dark=true`. A click sets `dark=true, stored=dark`. A stored `dark` with system light gives `dark=true`, and a stored `light` with system dark gives `dark=false`. With no stored choice, a system change to dark gives `dark=true`. After a click, a later system change does not override the stored choice. The four `invalid/toggle-*` fixtures exit 1 on `toggle`. |
| The page opens with a table of contents | PASS | The validator prints `PASS  toc` and `PASS  toc-links` on the template and on the example page. `toc-missing`, `toc-after-section`, and `toc-unlinked-section` fail on `toc`, and `toc-links-dangling` fails on `toc-links` (`#nowhere`). |
| The page presents content through the supported components | PASS | The template carries all 7 `data-component` markers: `stats`, `table`, `list`, `svg-overlay`, `svg-er`, `svg-infra`, and `sources`. The validator prints `PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative`, and the three `invalid/svg-a11y-*` fixtures fail on `svg-a11y`. Visual rendering is for the Tester. |
| The page is a self-contained single file | PASS | The template and `docs/pages/harness-overview.html` each print `PASS  self-contained`. Neither contains `<link`, a remote `src`/`href`, `@import`, or `@font-face`. The template has 0 backslashes and the example page has 1, which sits in a `<code>` grep pattern at line 576. Every `url()` is a fragment (`url(#flow-arrow)` and similar). With the F-4 Option B CSP added, Chrome made 0 requests for the example page. The shipped pages load nothing. The validator's gaps are F-4 and F-5, under the next row. |
| The page cites the evidence behind its content | PASS | `section#sources` on the example page (lines 574–585) holds 10 `<li>` entries naming commands and files. Every figure I recomputed matches (O-31). `sources-missing` and `sources-empty` fail on `sources`. |
| The validator rejects a non-conforming page | FAIL | All 34 invalid fixtures exit 1 with exactly one `FAIL  <rule>:`, and all 3 valid fixtures exit 0. But 20 probe pages that Chrome shows fetching an external stylesheet, script, or font exit 0 with `PASS  self-contained` (F-4: 18 probes; F-5: 2 probes). |

## Verification Detail

**Suites and validators.**

```text
scripts/test-html-page.sh     passed: 106  failed: 0  rc=0
scripts/test-write-scope.sh   passed: 36   failed: 0  rc=0
scripts/test-guards.sh        passed: 103  failed: 0  rc=0
scripts/test-status.sh        passed: 46   failed: 0  rc=0
scripts/test-completion.sh    passed: 63   failed: 0  rc=0
scripts/test-delivery.sh      passed: 179  failed: 0  rc=0
node scripts/check-frontmatter.js      RESULT: PASS — all definitions valid.
scripts/validate-product-artifacts.sh  warnings: 0  RESULT: PASS — all required checks passed, 0 warning(s).
openspec validate --all --strict       Totals: 23 passed, 0 failed (23 items)
openspec validate us-14-1-themed-html-pages --strict   Change 'us-14-1-themed-html-pages' is valid
scripts/workflow-status.sh --change us-14-1-themed-html-pages
  PASS  plan-handoff   implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation 16/16 tasks complete
  First incomplete gate: review
```

**Validator on the shipped pages.**

```text
$ NO_COLOR=1 scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources
  PASS  doctype / lang / tokens-light (32) / tokens-dark (31) / toggle / toc / toc-links
  PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative
  PASS  self-contained: no external script, stylesheet, import, url(), or font
  --    sources: skipped (--no-sources)
  RESULT: PASS — the page satisfies the harness page contract.   rc=0
$ NO_COLOR=1 scripts/validate-html-page.sh --page docs/pages/harness-overview.html
  … all 10 rules PASS, including "PASS  sources: the page cites its evidence"
  RESULT: PASS — the page satisfies the harness page contract.   rc=0
```

**Fixture loop.** `ls scripts/fixtures/html-pages/invalid | wc -l` gives 34. Every
invalid fixture exits 1 with exactly one `FAIL`, including the four new ones:

```text
self-contained-link-spaced-equals.html    rc=1 nfail=1 self-contained: … <link rel=stylesheet>
self-contained-script-spaced-equals.html  rc=1 nfail=1 self-contained: … <script src>
self-contained-slash-separator.html       rc=1 nfail=1 self-contained: … <link rel=stylesheet>
self-contained-quoted-gt.html             rc=1 nfail=1 self-contained: … <link rel=stylesheet>
doctype.html rc=1 nfail=1 doctype … tokens-light.html rc=1 nfail=1 tokens-light   (all 34: rc=1 nfail=1)
page-compact-tokens.html rc=0   page-mentions-markup.html rc=0   page.html rc=0
```

**Probe method.** A Python script under `/tmp` inserted each tag into a copy of
`valid/page.html`, before `</head>`, before `</body>`, or into the CSS. Each page was
checked with `scripts/validate-html-page.sh`. It was then loaded with
`"Google Chrome" --headless=new --virtual-time-budget=2000 --dump-dom file://…`
against a local `http.server` on `127.0.0.1:18731` that logs every requested path. Each
URL path names its probe, so a logged path proves that the page fetched the resource.
All probe files, logs, and the server are deleted.

```text
round-2 F-3 bypasses — now rejected; Chrome fetched each (true positives)
rc=1 LOADED  r2-link-sp-eq-both / -after / -before   <link rel = "stylesheet" …>, rel= "…", rel ="…"
rc=1 LOADED  r2-preload-sp-eq                        <link rel = 'preload' as='font' …>
rc=1 LOADED  r2-script-sp-eq-both / -before          <script src = "…">, <script src ="…">
rc=1 LOADED  r2-module-sp-eq                         <script type="module" src = "…">
rc=1 LOADED  r2-link-slash / r2-script-slash         <link/rel="stylesheet"/href=…>, <script/src=…>
rc=1 LOADED  r2-link-quoted-gt / r2-script-quoted-gt title="a>b" / data-x="a>b"
rc=1 LOADED  r2-modulepreload                        <link rel="modulepreload" …>   (O-15 resolved)
own variants — rejected (O-24)
rc=1 LOADED  v-tab-newline v-crlf-script v-upper-link v-mixed-script v-unquoted-link
             v-order-href-first v-self-close-slash v-multi-space-rel
rc=1 none    v-empty-src v-bare-src v-dns-prefetch-upper                 (O-26: stricter)
false positives / non-tags — accepted, nothing fetched (O-25)
rc=0 none    fp-icon-data fp-data-rel fp-data-src fp-nostylesheet fp-inline-src-text fp-script-srcset
rc=0 none    n-link-in-comment n-link-escaped n-scriptx n-linked v-unterminated-quote
BYPASSES — accepted, and Chrome fetched an external stylesheet/script/font (F-4, F-5)
rc=0 LOADED  b-ff-tagname-link      <link\frel=stylesheet href=…>                F-4 (a)
rc=0 LOADED  b-ff-tagname-script    <script\fsrc=…>                              F-4 (a)
rc=0 LOADED  b-ff-before-eq         <script src\f=…>                             F-4 (a)
rc=0 LOADED  b-ff-after-eq          <link rel=\fstylesheet …>                    F-4 (a)
rc=0 LOADED  b-ff-in-rel            rel="alternate\fstylesheet"                  F-4 (a)
rc=0 LOADED  b-charref-rel          rel="style&#115;heet"                        F-4 (b)
rc=0 LOADED  b-charref-rel-named    rel="alternate&Tab;stylesheet"               F-4 (b)
rc=0 LOADED  b-dup-rel              <link rel="stylesheet" rel="icon" …>         F-4 (c)
rc=0 LOADED  b-abrupt-comment       <!--> <link rel="stylesheet" …> -->          F-4 (d)
rc=0 LOADED  b-abrupt-comment2      <!---> <link rel="stylesheet" …> -->         F-4 (d)
rc=0 LOADED  b-bang-close           <!-- x --!> <link rel="stylesheet" …> -->    F-4 (d)
rc=0 LOADED  b-comment-in-rawtext   <script>/* <!-- */</script><link …><script>/* --> */</script>  F-4 (d)
rc=0 LOADED  b-comment-in-attr      <div title="<!--"></div><link …><div title="-->"></div>        F-4 (d)
rc=0 LOADED  b-cdo-import           <style><!-- @import "…"; --></style>         F-4 (d)
rc=0 LOADED  b-script-body-quote    <script>var a = "<script t='";</script><link …><script>…'</script>  F-4 (e)
rc=0 LOADED  b-textarea-quote       <textarea><script x='</textarea><link …><textarea>'</textarea>  F-4 (e)
rc=0 LOADED  b-svg-script-href      <svg …><script href="…/x.js"></script></svg> F-4 (f)
rc=0 LOADED  b-svg-script-xlink     <svg …><script xlink:href="…/x.js"></script></svg>  F-4 (f)
rc=0 LOADED  b-module-import        <script type="module">import "…/x.js";</script>    F-5
rc=0 LOADED  b-dynamic-script       document.createElement("script").src = "…"        F-5
CSS escapes in a fresh <style> block (F-4 (g))
rc=1 LOADED  c2-plain-import        <style>@import "…";</style>           (control)
rc=0 LOADED  c2-escaped-import      <style>@\69mport "…";</style>
rc=0 LOADED  c2-escaped-import-url  <style>@\69mport u\72l(…);</style>
rc=0 LOADED  c2-escaped-url-fn      @\66ont-face { src: u\72l(…/f.woff2) } + font-family use
rc=1 LOADED  c2-escaped-fontface    @font-f\61 ce { src: url(…) }         (caught by remote url())
other resource kinds — documented or undocumented limits (O-27)
rc=0 LOADED  o-img o-iframe-srcdoc o-prefetch o-icon-remote o-image-set
```

The escaped-CSS probes appended in round 3's first batch, placed after the existing
`/* ---- Base` comment, did not load in Chrome. The `c2-*` batch placed them at the
start of a new `<style>` block, where `@import` is valid, and they loaded.

**Option B check.** I added the CSP meta from F-4 to 12 pages: `b-abrupt-comment`,
`b-ff-tagname-script`, `b-charref-rel`, `b-dup-rel`, `b-svg-script-href`,
`b-module-import`, `b-dynamic-script`, `b-script-body-quote`, `o-img`, `o-iframe-srcdoc`,
`c2-escaped-import`, and `docs/pages/harness-overview.html`. I loaded each in Chrome:

```text
requests with CSP:        0
```

**Token fidelity.**

```text
32 a-l  31 a-d  32 v-l  31 v-d  32 t-l  31 t-d
appendix==validator light   appendix==validator dark
template==appendix light    template==appendix dark
```

**Toggle behaviour** (the template and the example page gave identical results):

```text
none/light          dark=false stored=-
none/dark           dark=true stored=-
none/light +click   dark=true stored=dark
stored dark/light   dark=true stored=dark
stored light/dark   dark=false stored=light
none/light +sysdark dark=true stored=-
click then sysdark  dark=false stored=light
```

**Fixtures match their generator.**

```text
$ (temp tree) python3 scripts/fixtures/html-pages/make-fixtures.py; diff -r … && echo "fixtures in sync with generator"
fixtures in sync with generator
34
```

**Repository figures behind the example page.**

```text
epics 14 (grep -cE '^### EPIC-[0-9]+' SPECS.md)  stories 28  done 27  inprog 1  archived 27  specs 22
agents 8  skills 16  rules 7   suite sum 106+36+103+46+63+179 = 533
SPECS.md: EPIC-1 2/2 EPIC-2 7/7 EPIC-3 2/2 EPIC-4 1/1 EPIC-5 1/1 EPIC-6 1/1 EPIC-7 1/1
          EPIC-8 2/2 EPIC-9 1/1 EPIC-10 1/1 EPIC-11 1/1 EPIC-12 4/4 EPIC-13 3/3 EPIC-14 0/1
page l.534–547: identical per-epic values; l.323 27 / 28; l.324 14; l.325 27; l.326 22; l.327 24; l.328 533
page l.560–565: test-write-scope 36, test-guards 103, test-status 46, test-completion 63, test-delivery 179, test-html-page 106
```

**Documentation and O-18.**

```text
README.md:1543          | `test-html-page.sh` | Regression suite for themed HTML pages (106 cases) | US-14.1 |
README.md:1590          scripts/test-html-page.sh      # 106 cases — themed HTML pages
scripts/README.md:32    | `test-html-page.sh` | Regression suite for themed HTML pages (106 cases) | US-14.1 |
scripts/README.md:1331  | `self-contained` | no `<script src>`, `stylesheet` or `preload`/`modulepreload`/`preconnect`/`dns-prefetch` link, …
scripts/README.md:1357  `106` cases across one section per acceptance scenario of US-14.1, plus the skill.
scripts/README.md:1359  … Each of the 34 invalid fixtures is the valid
SKILL.md:143            Appendix A, under `openspec/changes/archive/` once archived), and the template
html-page.html:13       Appendix A, under openspec/changes/archive/ once archived). scripts/validate-html-page.sh checks every token …
```

**Scope.**

```text
$ scripts/check-scope.sh --plan openspec/changes/us-14-1-themed-html-pages/implementation-plan.md
  Changed: 60 file(s)   Predicted: 129 path(s) named in the plan
  9 unpredicted — all openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/*
  RESULT: OUT OF PLAN SCOPE — 9 file(s) unaccounted for.
$ … --diff <git diff --name-only + untracked, 70 paths>
  unpredicted outside the US-13.3 archive: openspec/delivery/goal.md
  RESULT: OUT OF PLAN SCOPE — 10 file(s) unaccounted for.
```

## Handoff

Control returns to the Implementer to remediate F-4 and F-5. F-5 may instead be
resolved by a recorded human Product Manager decision (see its Remediation). Adopting
F-4 Option B resolves both findings with one rule. Then `/review-feature
us-14-1-themed-html-pages` runs again (round 4). Acceptance testing does not proceed
while F-4 or F-5 is open.
