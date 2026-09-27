# Review — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: fail
Blocking: 1 finding (F-6)
Coverage: 7/7 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-14-1-themed-html-pages --strict` reports "Change 'us-14-1-themed-html-pages' is valid", and `openspec validate --all --strict` reports "Totals: 23 passed, 0 failed (23 items)". No spec/task/design mismatch. The blocking finding comes from browser probes, not from the verify step.

## Summary

This is **round 4**, and it **supersedes `history/review-r3.md`**. Round 3 raised F-4
(markup and CSS spellings that load a resource past the static `self-contained` rule)
and F-5 (inline scripts that load a remote script). R3.1 and R3.2 adopt F-4 Option B.
Every page must now open `<head>` with a fixed Content-Security-Policy meta, and the new
`csp` rule (`scripts/validate-html-page.sh` lines 460–477) checks for it. The template
and the example page carry the policy, and both pass all rules. There are 9 new
`csp-bypass-*` fixtures, one for each F-4 cause (a)–(g) plus two for F-5. With the
policy removed, each fixture exits 1 on `csp`. Every suite and validator passes. **F-4
and F-5 are resolved for every form they named.**

The `csp` rule normalises the page before matching, and the browser does not. At line
469 the validator maps vertical tab to a space, but HTML does not treat vertical tab
as whitespace. It also lowercases with a locale-aware `tr`, while HTML lowercases ASCII
only. I tested five probe pages in headless Chrome against a local request-logging
server. **Each one passed every rule (exit 0) and still fetched an external script,
stylesheet, import, and font**, because the browser never applied the policy (F-6).
The spec's `MUST NOT load an external script, stylesheet, or font` makes this blocking.
Scenario 7 fails, and the other six pass.

## Blocking Issues

### Finding F-6: `csp` accepts a policy meta that the browser does not apply

Requirement: Scenario "The page is a self-contained single file": a generated page `MUST NOT load an external script, stylesheet, or font`. Scenario "The validator rejects a non-conforming page": for a page that violates any rule, the validator `MUST exit 1` and `MUST name the rule that failed`.
Observed: `scripts/validate-html-page.sh` line 469 builds the text that `csp` matches as `head -c 4096 "$PAGE" | tr '\n\r\t\f\v' '     ' | tr '[:upper:]' '[:lower:]'`. This normalisation differs from HTML tokenization in two ways:
  (a) **Vertical tab (U+000B) is not HTML whitespace.** HTML treats only tab, LF, FF, CR, and space as whitespace, but line 469 also maps `\v` to a space. Three single-byte edits to `valid/page.html` each pass every rule (exit 0, `PASS  csp`). Headless Chrome fetched all four payload resources for each: `module.js`, `sheet.css`, `import.css`, and `font.woff2`.
    - `<meta\vhttp-equiv="Content-Security-Policy" content="…">`: the tag name becomes `meta\vhttp-equiv="content-security-policy"`, so the element is not a `<meta>`.
    - `<meta http-equiv="Content-Security-Policy"\vcontent="…">`: the attribute name becomes `\vcontent`, so the meta has no `content`.
    - `<html\vlang="en">`: the unknown start tag implicitly closes `<head>`, and the policy meta lands in `<body>`, where a CSP meta is ignored.
    The same class also holds `<head\v>` and `http-equiv\v="…"`. Chrome loaded all four resources for both, but the validator rejects them only because the regex expects `<head>` and `http-equiv="` with no space after the mapping. That rejection is accidental, not by design.
  (b) **Locale-dependent case folding.** In the repository's `en_US.UTF-8` locale, `tr '[:upper:]' '[:lower:]'` folds U+0130 `İ` to ASCII `i`. HTML lowercases ASCII letters only. `http-equİv="Content-Security-Policy"` and `http-equiv="Content-Security-Polİcy"` both pass every rule (exit 0), and Chrome fetched all four resources for each. Under `LC_ALL=C` the same two files fail `csp`, so the verdict on one file also depends on the caller's locale.
None of the 47 invalid fixtures uses `\v` or a non-ASCII letter in the prefix, so `scripts/test-html-page.sh` (133 passed) does not catch these.
Expected: The validator exits 1 with `FAIL  csp: …` for every page whose policy meta HTML would not parse as the first `<meta http-equiv="content-security-policy" content="<policy>">` in `<head>`, and the result does not depend on locale.
Remediation: On line 469, normalise only HTML whitespace (`\t\n\f\r` and space) and leave `\v` in place so the regex fails on it. Lowercase ASCII only, in a fixed locale: for example `LC_ALL=C tr 'A-Z' 'a-z'`, and run the `grep -qE "$csp_re"` on line 471 under `LC_ALL=C` too. A stricter alternative also covers NUL and other control or non-ASCII bytes: fail `csp` when the prefix before the end of the policy meta contains any byte other than printable ASCII and HTML whitespace. Add invalid fixtures to `make-fixtures.py` for `\v` in the `<meta>` tag name, `\v` before `content`, `\v` in `<html>`, and `İ` in `http-equiv` and in the `http-equiv` value. Add matching `rejects … csp` cases to `scripts/test-html-page.sh`, including one that runs the `İ` fixture under `LANG=en_US.UTF-8`. Update the validator comment at lines 465–467, which says no attribute value can make the policy "only appear to be there". Then update the case and fixture counts in `README.md` (lines 1543, 1590) and `scripts/README.md` (lines 32, 1365, 1367). Also update the suite row and total on `docs/pages/harness-overview.html` (lines 1002 and 365).

## Observations

These are not blocking. Each is recorded for the Implementer or the Product Manager.

- **O-35: F-4 and F-5 are resolved for every form they named (verified independently).**
  `scripts/fixtures/html-pages/make-fixtures.py` lines 95–111 add `csp-missing`,
  `csp-weakened`, `csp-late`, `csp-commented`, and 9 `csp-bypass-*` fixtures. They cover
  form feed (a), character reference (b), duplicate `rel` (c), comment quirk (d),
  script-body quote (e), SVG `<script href>` (f), CSS escape (g), module `import` (F-5),
  and `createElement` (F-5). `scripts/test-html-page.sh` lines 183–189 add the
  matching cases. All 13 exit 1 with exactly one `FAIL  csp`. In headless Chrome, a
  control page carrying the policy and all four payload loads (module import, char-ref
  stylesheet, escaped `@import`, escaped `@font-face`) made 0 requests. With the policy
  removed, the same page made 4 requests.
- **O-36: The policy placement matches the design.** `design.md` §2 "Enforcement" and
  the validator-contract row name the `csp` rule. `implementation-plan.md` line 182
  records the R3 amendment. `scripts/templates/html-page.html` lines 1–5 and
  `docs/pages/harness-overview.html` lines 1–5 put `<meta charset="utf-8">` and then
  the exact policy meta at the top of `<head>`. The rule matches the raw file with
  comments kept, so `csp-commented` fails as intended.
- **O-37: The `csp-bypass-css-escape` fixture does not load in a browser.**
  `invalid/csp-bypass-css-escape.html` line 100 places `@\69mport` after the `:root`
  and `.dark` rules. CSS ignores an `@import` that follows style rules, and round 3's
  Verification Detail shows Chrome did not load that placement. The fixture still
  proves the static rule misses the spelling, and it fails `csp` as designed. Moving
  the import to the start of a `<style>` block would make it a true positive.
- **O-38: NUL bytes are a validator blind spot, but not a bypass.** Bash command
  substitution drops NUL. In `<me\0ta …>`, `http-eq\0uiv`, and `'no\0ne'`, the `csp`
  line prints `PASS`, although Chrome did not apply the policy as written. It fetched
  4, 4, and 1 resources. Each page still exits 1, because `FLAT` loses the rest of the
  page and 8 other rules fail. F-6's stricter alternative would name the cause.
- **O-39: A UTF-8 byte-order mark fails `doctype` and `csp`** (exit 1). Chrome applied
  the policy and made 0 requests, so the rule is stricter than necessary here. A page
  built from the template carries no BOM.
- **O-40: The counts are consistent.** `README.md` lines 1543 and 1590 and
  `scripts/README.md` lines 32 and 1365 read `133 cases`. `scripts/README.md` line
  1367 reads `47 invalid fixtures`, and `ls scripts/fixtures/html-pages/invalid | wc -l`
  also gives 47. `docs/pages/harness-overview.html` line 1002 reads 133, and line 365
  reads 560 = 36 + 103 + 46 + 63 + 179 + 133, which matches the six suites run here.
- **O-41: The fixtures match their generator.** I ran `make-fixtures.py` in a
  temporary tree holding only the template and the generator, then diffed with
  `diff -r`. There is no difference (47 invalid). All 47 invalid fixtures exit 1 with
  exactly one `FAIL`, and the 3 valid fixtures exit 0.
- **O-42: Scope is unchanged from round 3 (O-33).** `check-scope.sh` reports the same 9
  unpredicted files, all under
  `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/`. The R3
  work touched files the plan names at line 182 and in its earlier rows: the
  validator, the template, the fixtures and generator, the suite, the docs, the
  example page, `design.md`, and `tasks.md`.
- **O-43: The tasks are honest.** `workflow-status.sh` reports `18/18 tasks complete`.
  R3.1 and R3.2 are ticked, and every cause they name has a fixture. F-6 concerns the
  new rule's own normalisation, which neither task text named.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The page uses the Luma theme in light and dark | PASS | `validate-html-page.sh` prints `PASS  tokens-light: all 32 :root tokens match the Luma palette` and `PASS  tokens-dark: all 31 .dark tokens match the Luma palette` on both `scripts/templates/html-page.html` and `docs/pages/harness-overview.html`. The four `invalid/tokens-*` fixtures (`tokens-light`, `tokens-light-missing`, `tokens-dark`, `tokens-dark-scoped`) exit 1. |
| The reader can switch between light and dark | PASS | Both files print `PASS  toggle: #theme-toggle flips the dark class, persists it, and follows the system`. The four `invalid/toggle-*` fixtures exit 1. In a Chrome load of the example page carrying the policy, the page rendered and made 0 requests, so the CSP does not block the inline toggle script (`script-src 'unsafe-inline'`). The behavioural shim results are in round 3's report. |
| The page opens with a table of contents | PASS | Both files print `PASS  toc` and `PASS  toc-links: every in-page link resolves`. `toc-missing`, `toc-after-section`, `toc-unlinked-section`, and `toc-links-dangling` exit 1. |
| The page presents content through the supported components | PASS | The template prints `PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative`, and the example page prints the same for 6 SVGs. The three `invalid/svg-a11y-*` fixtures exit 1. The component set is unchanged from round 3. |
| The page is a self-contained single file | PASS | The template and the example page each print `PASS  self-contained` and `PASS  csp`. Each opens `<head>` with `<meta charset="utf-8">` and then the exact policy meta, with no `\v` or non-ASCII byte in that prefix, so the browser applies the policy. The shipped pages load nothing. The validator gap is F-6, under the next row. |
| The page cites the evidence behind its content | PASS | The example page prints `PASS  sources: the page cites its evidence`. `sources-missing` and `sources-empty` exit 1. The template run skips `sources` with `--no-sources`. |
| The validator rejects a non-conforming page | FAIL | All 47 invalid fixtures exit 1 with exactly one `FAIL  <rule>:`, and all 3 valid fixtures exit 0. But five probe pages exit 0 with `PASS  csp` and `PASS  self-contained`, and Chrome shows each one fetching an external script, stylesheet, import, and font (F-6). |

## Verification Detail

**Suites and validators.**

```text
$ scripts/test-html-page.sh | tail -4
  passed: 133
  failed: 0

  RESULT: PASS — the html page contract holds.
$ for s in write-scope guards status completion delivery; do scripts/test-$s.sh | tail -3; done
  write-scope  passed: 36   failed: 0   RESULT: PASS — separation of duties holds across all roles.
  guards       passed: 103  failed: 0   RESULT: PASS — all guard behaviours hold.
  status       passed: 46   failed: 0   RESULT: PASS — durable workflow state holds.
  completion   passed: 63   failed: 0   RESULT: PASS — the definition of done holds.
  delivery     passed: 179  failed: 0   RESULT: PASS — goal-driven delivery holds.
$ node scripts/check-frontmatter.js | tail -1
RESULT: PASS — all definitions valid.
$ scripts/validate-product-artifacts.sh | tail -1
  RESULT: PASS — all required checks passed, 0 warning(s).
$ openspec validate --all --strict | tail -1
Totals: 23 passed, 0 failed (23 items)
$ openspec validate us-14-1-themed-html-pages --strict
Change 'us-14-1-themed-html-pages' is valid
$ scripts/workflow-status.sh --change us-14-1-themed-html-pages
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   18/18 tasks complete
  ----  review           review.md missing
```

**Fixture loop.**

```text
$ for f in scripts/fixtures/html-pages/invalid/*.html; do scripts/validate-html-page.sh --page "$f" --quiet >/dev/null; echo "$? $(basename $f)"; done
1 csp-bypass-char-ref.html          1 csp-bypass-comment-quirk.html     1 csp-bypass-create-element.html
1 csp-bypass-css-escape.html        1 csp-bypass-duplicate-rel.html     1 csp-bypass-form-feed.html
1 csp-bypass-module-import.html     1 csp-bypass-script-body.html       1 csp-bypass-svg-script.html
1 csp-commented.html                1 csp-late.html                     1 csp-missing.html
1 csp-weakened.html                 1 doctype.html                      1 lang.html
1 self-contained-font.html          1 self-contained-import.html        1 self-contained-link-multi-token.html
1 self-contained-link-single-quote.html  1 self-contained-link-spaced-equals.html  1 self-contained-link.html
1 self-contained-preconnect.html    1 self-contained-preload-single-quote.html  1 self-contained-protocol-relative.html
1 self-contained-quoted-gt.html     1 self-contained-script-spaced-equals.html  1 self-contained-script.html
1 self-contained-slash-separator.html  1 self-contained-uppercase.html  1 self-contained-url.html
1 sources-empty.html                1 sources-missing.html              1 svg-a11y-dangling-label.html
1 svg-a11y-no-name.html             1 svg-a11y-no-role.html             1 toc-after-section.html
1 toc-links-dangling.html           1 toc-missing.html                  1 toc-unlinked-section.html
1 toggle-no-button.html             1 toggle-no-class.html              1 toggle-no-storage.html
1 toggle-no-system.html             1 tokens-dark-scoped.html           1 tokens-dark.html
1 tokens-light-missing.html         1 tokens-light.html
(47 fixtures, all exit 1; a FAIL count per fixture shows exactly one FAIL each)
valid/: 0 page-compact-tokens.html   0 page-mentions-markup.html   0 page.html
```

**Validator on the shipped pages.**

```text
$ scripts/validate-html-page.sh --page docs/pages/harness-overview.html
  PASS  doctype: starts with <!doctype html>
  PASS  lang: <html> declares a language
  PASS  tokens-light: all 32 :root tokens match the Luma palette
  PASS  tokens-dark: all 31 .dark tokens match the Luma palette
  PASS  toggle: #theme-toggle flips the dark class, persists it, and follows the system
  PASS  toc: the table of contents precedes every section and links each one
  PASS  toc-links: every in-page link resolves
  PASS  svg-a11y: all 6 SVG(s) are labelled or marked decorative
  PASS  self-contained: no external script, stylesheet, import, url(), or font
  PASS  csp: the first element in <head> is the self-contained Content-Security-Policy
  PASS  sources: the page cites its evidence
  RESULT: PASS — the page satisfies the harness page contract.   rc=0
$ scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources
  PASS  doctype / lang / tokens-light (32) / tokens-dark (31) / toggle / toc / toc-links
  PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative
  PASS  self-contained: no external script, stylesheet, import, url(), or font
  PASS  csp: the first element in <head> is the self-contained Content-Security-Policy
  --    sources: skipped (--no-sources)
  RESULT: PASS — the page satisfies the harness page contract.   rc=0
```

**The `csp` rule and the template head.**

```text
scripts/validate-html-page.sh:468  CSP_POLICY="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:"
scripts/validate-html-page.sh:469  prefix=$(head -c 4096 "$PAGE" | tr '\n\r\t\f\v' '     ' | tr '[:upper:]' '[:lower:]')
scripts/validate-html-page.sh:470  csp_re="^ *(<!doctype html> *)?(<html( lang=\"[a-z0-9-]+\")?> *)?<head> *(<meta charset=\"utf-8\"> *)?<meta http-equiv=\"content-security-policy\" content=\"$CSP_POLICY\">"
scripts/templates/html-page.html:1-5
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">
```

**Probe method.** A Python script under `/tmp` copied
`scripts/fixtures/html-pages/valid/page.html`, which carries the policy. It applied one
edit to the policy prefix and inserted the same payload before `</head>`: a module
`import`, a `rel="style&#115;heet"` link, an escaped `@\69mport` at the start of its
own `<style>`, and an escaped `@font-f\61 ce` whose font is used by `body`. Every
payload URL points at `http://127.0.0.1:18741/<probe>-…`. Each page was checked with
`NO_COLOR=1 scripts/validate-html-page.sh`. It was then loaded with
`"Google Chrome" --headless=new --virtual-time-budget=3000 --dump-dom file://…`,
against a local `http.server` that logs every requested path. A logged path proves
the page fetched that resource. All probe pages, profiles, logs, and the server were
deleted afterwards.

```text
rc csp  self-contained requests probe                  fetched
0  PASS PASS           0        control-csp-intact     -                                         (policy applied)
1  FAIL PASS           4        control-csp-removed    font.woff2 import.css module.js sheet.css (control)
0  PASS PASS           4        vt-meta-tagname        font.woff2 import.css module.js sheet.css F-6 (a)
0  PASS PASS           4        vt-before-content      font.woff2 import.css module.js sheet.css F-6 (a)
0  PASS PASS           4        vt-html-tag            font.woff2 import.css module.js sheet.css F-6 (a)
1  FAIL PASS           4        vt-head-tag            font.woff2 import.css module.js sheet.css (caught incidentally)
1  FAIL PASS           4        vt-attr-name           font.woff2 import.css module.js sheet.css (caught incidentally)
0  PASS PASS           4        dotted-I-attr          font.woff2 import.css module.js sheet.css F-6 (b)
0  PASS PASS           4        dotted-I-policy-name   font.woff2 import.css module.js sheet.css F-6 (b)
1  PASS PASS           4        nul-meta-tagname       font.woff2 import.css module.js sheet.css O-38 (8 other rules fail)
1  PASS PASS           4        nul-attr-name          font.woff2 import.css module.js sheet.css O-38
1  PASS PASS           1        nul-policy-value       font.woff2                                O-38
1  FAIL PASS           0        bom-prefix             -                                         O-39 (doctype + csp fail)
```

**Locale dependence (F-6 b).**

```text
$ printf 'http-equ\xc4\xb0v' | tr '[:upper:]' '[:lower:]'            -> h t t p - e q u i v   (en_US.UTF-8)
$ printf 'http-equ\xc4\xb0v' | LC_ALL=C tr '[:upper:]' '[:lower:]'   -> h t t p - e q u İ v
dotted-I-attr         csp under en_US.UTF-8: PASS   under LC_ALL=C: FAIL
dotted-I-policy-name  csp under en_US.UTF-8: PASS   under LC_ALL=C: FAIL
vt-meta-tagname       csp under en_US.UTF-8: PASS   under LC_ALL=C: PASS
```

**Fixtures match their generator.**

```text
$ (temp tree with scripts/templates/html-page.html and make-fixtures.py) python3 scripts/fixtures/html-pages/make-fixtures.py
$ diff -r scripts/fixtures/html-pages <temp>/scripts/fixtures/html-pages && echo "fixtures in sync"
fixtures in sync
47
```

**Scope.**

```text
$ scripts/check-scope.sh --plan openspec/changes/us-14-1-themed-html-pages/implementation-plan.md
  9 unpredicted — all openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/*
  RESULT: OUT OF PLAN SCOPE — 9 file(s) unaccounted for.   (unchanged from round 3, O-33)
```

## Handoff

Control returns to the Implementer to remediate F-6. Then `/review-feature
us-14-1-themed-html-pages` runs again (round 5). Acceptance testing does not proceed
while F-6 is open.
