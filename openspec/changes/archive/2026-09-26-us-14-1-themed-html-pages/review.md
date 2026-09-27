# Review — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: pass
Blocking: None
Coverage: 7/7 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-14-1-themed-html-pages --strict` reports "Change 'us-14-1-themed-html-pages' is valid", and `openspec validate --all --strict` reports "Totals: 23 passed, 0 failed (23 items)". No spec/task/design mismatch.

## Summary

This is **round 6**, and it **supersedes `history/review-r5.md`**. Round 5 raised F-7:
a NUL byte in the policy tag passed `csp`, because `grep` and `awk` stop at NUL. Only 8
unrelated rules failed, and none of them was the rule the page broke. R5.1 maps NUL to
`\001` with `LC_ALL=C tr` before any tool reads the bytes, in all three places the
validator reads the page: `FLAT` (line 183), the doctype check (line 269), and the `csp`
`raw` prefix (line 483). It also adds three fixtures and three suite cases. **F-7 is
resolved.** I verified this independently. Each round-5 NUL probe now exits 1 with exactly
`FAIL  csp` under both `LC_ALL=C` and `LC_ALL=en_US.UTF-8`. So do four new NUL
placements, and all round-4 and round-5 lookalike probes I re-ran. The result holds with
a NUL-stripping awk. Every suite and validator passes. All 7 scenarios pass, and there
are no blocking findings.

## Blocking Issues

None.

## Observations

These are not blocking. Each is recorded for the Implementer or the Product Manager.

- **O-55: F-7 is resolved (verified independently).** `scripts/validate-html-page.sh`
  reads the page file in exactly three places, and each one now starts with a NUL
  mapping:
  - line 183: `FLAT=$(LC_ALL=C tr '\000\n\t\r' '\001   ' < "$PAGE" | awk …)`;
  - line 269: `head -c 200 "$PAGE" | LC_ALL=C tr '\000A-Z' '\001a-z' | …`;
  - line 483: `raw=$(head -c 4096 "$PAGE" | LC_ALL=C tr '\000\n\r\t\f' '\001    ' | …)`.

  (`grep -n '"$PAGE"'` finds no other reads.) The existing `[^ -~]` byte check at line
  491 then sees `\001`. `make-fixtures.py` lines 119–121 add `csp-nul-in-tag`,
  `csp-nul-in-attr`, and `csp-nul-in-policy`. `od -c` shows a real `\0` in each, at
  `me\0ta`, `http-eq\0uiv`, and `'no\0ne'`. `scripts/test-html-page.sh` lines 193–195
  add three `rejects … csp` cases. Each fixture exits 1 with a single
  `FAIL  csp: <head> does not open with the self-contained Content-Security-Policy`.
  The three round-5 Chrome-bypassing probes (`nul-meta-tagname`, `nul-attr-name`,
  `nul-policy-value`) now fail only `csp` under both locales. In round 5 they failed 8
  other rules.
- **O-56: The fix does not depend on how the platform's awk handles NUL.** Round 5 used a
  PATH shim to model a NUL-tolerant awk. It strips NUL before `/usr/bin/awk`, the way
  gawk and mawk, and bash ≥ 4.4 command substitution, treat NUL. Under that shim, the
  pages `nul-meta-tagname`, `nul-attr-name`, `nul-policy-value`, `nul-in-policy-name`,
  and `nul-in-head-tag` each exit 1 with exactly `FAIL  csp`. In round 5 the first three
  exited 0. This is still a model; I did not observe it on a Linux host. It is
  consistent, though: the NUL becomes `\001` before awk runs, so the awk implementation
  no longer matters.
- **O-57: New NUL placements are rejected by the rule they break.** Each of these exits 1
  and names `csp` under both locales:
  - `nul-in-head-tag` (`<he\0ad>`), `nul-in-policy-name` (`Content-Security\0-Policy`),
    and `nul-plus-soh` (`<me\0\001ta`): only `csp` fails.
  - `nul-before-doctype`: `doctype` and `csp` fail.
  - `nul-in-html-tag` (`<ht\0ml`): `lang` and `csp` fail.

  In the last two, the NUL really does break the second named rule as well, so naming
  both is correct.
- **O-58: A NUL outside the checked prefix is accepted, and that is correct.** Two pages
  exit 0 with every rule `PASS` under both locales:
  - `nul-after-policy`, with `\0` right after the policy tag;
  - `nul-in-body`, with `\0` after `</head>`.

  I loaded both in headless Chrome with the round-5 payload: a module import, a
  `style&#115;heet` link, an escaped `@\69mport`, and an escaped `@font-face` with
  `u\72l(`. Chrome made **0 requests** for each, so the policy applied. The controls
  behaved as expected. `control-csp-intact` made 0 requests. `control-csp-removed`
  made 4 (`font.woff2 import.css module.js sheet.css`) and fails `csp`.
- **O-59: One rejection is stricter than the browser.** `nul-after-charset` (`\0` right
  after `<meta charset>`) now fails `csp`, yet round 5 observed Chrome applying the
  policy (0 requests). This is the same class as O-46: SOH, a BOM, or a vertical tab in
  the doctype. A page built from the template contains none of these, so it is not a
  defect.
- **O-60: Round-4 and round-5 probes still fail `csp`.** Each of these exits 1 with
  exactly `FAIL  csp` under both locales:
  - `vt-meta-tagname`, `vt-before-content`, `vt-html-tag`, `vt-head-tag`;
  - `dotted-I-attr`, `dotted-I-policy-name`;
  - `del-in-meta`, `nbsp-before-content`, `long-s-policy-name`, `fullwidth-lt-meta`,
    `zwsp-in-attr`, `esc-before-head`.

  The legitimate variants still exit 0 under both locales: `uppercase-policy` and
  `ff-in-meta`.
- **O-61: The validator comment is now accurate.** Lines 475–477 say "A NUL, a control
  character, or a non-ASCII lookalike there fails the rule". Round 5 found that untrue
  for NUL, and it is now true (O-55). Lines 181–182 and 481–482 record why NUL is
  mapped, and each cites review r5 F-7.
- **O-62: The counts are consistent.** The suite reports `passed: 151`. `README.md` lines
  1543 and 1590 and `scripts/README.md` line 32 read `151 cases`. `scripts/README.md`
  line 1374 reads `55 invalid fixtures`, and `ls scripts/fixtures/html-pages/invalid | wc
  -l` gives 55. `docs/pages/harness-overview.html` line 1002 reads 151, and line 365
  reads 578 = 36 + 103 + 46 + 63 + 179 + 151, which matches the six suites run here.
- **O-63: The fixtures match their generator.** I ran `make-fixtures.py` in a temporary
  tree under `/tmp` holding only the template and the generator, then ran `diff -r`
  against `scripts/fixtures/html-pages`. There is no difference. All 55 invalid
  fixtures exit 1 with exactly one `FAIL` line naming their rule, and the 3 valid
  fixtures exit 0.
- **O-64: Scope is unchanged from rounds 4 and 5 (O-42, O-53).** `check-scope.sh` reports
  the same 9 unpredicted files, all under
  `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/`. They are
  the archived trail of a previous story, not work of this change. The R5 work touched
  only files the plan already names: the validator, generator, fixtures, suite,
  `README.md`, `scripts/README.md`, the example page, and `tasks.md`.
- **O-65: Task honesty.** `workflow-status.sh` reports `20/20 tasks complete`, and
  `tasks.md` has no unticked box. Every claim in R5.1 holds: the three mapped pipelines,
  the three fixtures, three cases, the counts, and the example page.
- **Carried forward, not re-probed this round:**
  - **O-48:** outside `csp`, rule output still depends on the locale. A Kelvin sign in
    `lang` also fails `tokens-light` under UTF-8. R5.1 does not touch this.
  - **O-49:** a `<meta http-equiv="refresh">` after the policy navigates to a remote URL.
    That is navigation, which the spec does not name. The Product Manager may still
    decide whether the contract should cover it.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The page uses the Luma theme in light and dark | PASS | `validate-html-page.sh` prints `PASS  tokens-light: all 32 :root tokens match the Luma palette` and `PASS  tokens-dark: all 31 .dark tokens match the Luma palette` on `docs/pages/harness-overview.html`, and the template run passes. The four `invalid/tokens-*` fixtures exit 1 with exactly that rule named. The `FLAT` NUL mapping leaves NUL-free pages byte-identical, so these results are unchanged. |
| The reader can switch between light and dark | PASS | The example page prints `PASS  toggle: #theme-toggle flips the dark class, persists it, and follows the system`. The four `invalid/toggle-*` fixtures exit 1 with `FAIL  toggle`. The toggle script is unchanged since round 4, where it rendered under the policy. |
| The page opens with a table of contents | PASS | The example page prints `PASS  toc` and `PASS  toc-links: every in-page link resolves`. `toc-missing`, `toc-after-section`, `toc-unlinked-section`, and `toc-links-dangling` exit 1 with the matching rule. |
| The page presents content through the supported components | PASS | The example page prints `PASS  svg-a11y: all 6 SVG(s) are labelled or marked decorative`. The three `invalid/svg-a11y-*` fixtures exit 1 with `FAIL  svg-a11y`. The template's component set is unchanged from round 5. |
| The page is a self-contained single file | PASS | The example page and the template print `PASS  self-contained` and `PASS  csp`. The 15 `self-contained-*` fixtures and the 21 `csp-*` fixtures (including the 9 `csp-bypass-*` forms) exit 1 with their rule. In Chrome, `control-csp-intact` made 0 requests, and `control-csp-removed` made 4. |
| The page cites the evidence behind its content | PASS | The example page prints `PASS  sources: the page cites its evidence`. `sources-missing` and `sources-empty` exit 1 with `FAIL  sources`. The template run skips `sources` with `--no-sources`. |
| The validator rejects a non-conforming page | PASS | All 55 invalid fixtures exit 1 with exactly one `FAIL  <rule>:`, and the three `csp-nul-*` fixtures name `csp`. All 3 valid fixtures exit 0. Every NUL, vertical-tab, dotted-I, and lookalike probe that breaks the policy exits 1 and names `csp` under both `LC_ALL=C` and `LC_ALL=en_US.UTF-8` (O-55–O-60). This also holds under a NUL-tolerant awk (O-56). F-7 is resolved. |

## Verification Detail

**Suites and validators.**

```text
$ scripts/test-html-page.sh | tail -4
  passed: 151
  failed: 0

  RESULT: PASS — the html page contract holds.
$ for s in write-scope guards status completion delivery; do scripts/test-$s.sh | tail -3; done
  failed: 0
  RESULT: PASS — separation of duties holds across all roles.      (passed: 36)
  failed: 0
  RESULT: PASS — all guard behaviours hold.                         (passed: 103)
  failed: 0
  RESULT: PASS — durable workflow state holds.                      (passed: 46)
  failed: 0
  RESULT: PASS — the definition of done holds.                      (passed: 63)
  failed: 0
  RESULT: PASS — goal-driven delivery holds.                        (passed: 179)
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
  PASS  implementation   20/20 tasks complete
  ----  review           review.md missing
```

**Fixture loop.** Each line gives the exit code, the fixture, and the rule named by its
single `FAIL` line.

```text
$ for f in scripts/fixtures/html-pages/invalid/*.html; do scripts/validate-html-page.sh --page "$f" --quiet >/dev/null; echo "$? $(basename $f)"; done
1 csp-bypass-char-ref        csp        1 self-contained-font                  self-contained
1 csp-bypass-comment-quirk   csp        1 self-contained-import                self-contained
1 csp-bypass-create-element  csp        1 self-contained-link-multi-token      self-contained
1 csp-bypass-css-escape      csp        1 self-contained-link-single-quote     self-contained
1 csp-bypass-duplicate-rel   csp        1 self-contained-link-spaced-equals    self-contained
1 csp-bypass-form-feed       csp        1 self-contained-link                  self-contained
1 csp-bypass-module-import   csp        1 self-contained-preconnect            self-contained
1 csp-bypass-script-body     csp        1 self-contained-preload-single-quote  self-contained
1 csp-bypass-svg-script      csp        1 self-contained-protocol-relative     self-contained
1 csp-commented              csp        1 self-contained-quoted-gt             self-contained
1 csp-dotted-i-attr          csp        1 self-contained-script-spaced-equals  self-contained
1 csp-dotted-i-value         csp        1 self-contained-script                self-contained
1 csp-late                   csp        1 self-contained-slash-separator       self-contained
1 csp-missing                csp        1 self-contained-uppercase             self-contained
1 csp-nul-in-attr            csp        1 self-contained-url                   self-contained
1 csp-nul-in-policy          csp        1 sources-empty / sources-missing      sources
1 csp-nul-in-tag             csp        1 svg-a11y-dangling-label / -no-name / -no-role   svg-a11y
1 csp-vt-before-content      csp        1 toc-after-section / toc-missing / toc-unlinked-section  toc
1 csp-vt-in-html             csp        1 toc-links-dangling                   toc-links
1 csp-vt-in-meta             csp        1 toggle-no-button / -no-class / -no-storage / -no-system  toggle
1 csp-weakened               csp        1 tokens-dark / tokens-dark-scoped     tokens-dark
1 doctype                    doctype    1 tokens-light / tokens-light-missing  tokens-light
1 lang                       lang
(55 fixtures, all exit 1, each with exactly one FAIL line naming its rule)
valid/: 0 page-compact-tokens.html   0 page-mentions-markup.html   0 page.html
```

**The NUL fixtures.**

```text
$ for f in scripts/fixtures/html-pages/invalid/csp-nul-*.html; do scripts/validate-html-page.sh --page "$f" --quiet; done
  FAIL  csp: <head> does not open with the self-contained Content-Security-Policy
  fix: make the first element in <head> (after <meta charset="utf-8">) exactly:
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">
  RESULT: FAIL — 1 rule(s) failed.                    (rc=1; identical for all three)
$ od -c <fixture> | grep -m1 '\\0'
csp-nul-in-attr:    m e t a   h t t p - e q \0 u i v
csp-nul-in-policy:  n o \0 n e ' ;   s c r i p t - s
csp-nul-in-tag:     m e \0 t a   h t t p - e q u i v
```

**Validator on the shipped pages.**

```text
$ scripts/validate-html-page.sh --page docs/pages/harness-overview.html
HTML page — docs/pages/harness-overview.html
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
$ scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources | tail -3
  --    sources: skipped (--no-sources)
  RESULT: PASS — the page satisfies the harness page contract.
```

**The NUL mapping as implemented.**

```text
scripts/validate-html-page.sh:183  FLAT=$(LC_ALL=C tr '\000\n\t\r' '\001   ' < "$PAGE" | awk '…')
scripts/validate-html-page.sh:269  if head -c 200 "$PAGE" | LC_ALL=C tr '\000A-Z' '\001a-z' | LC_ALL=C grep -q '^[[:space:]]*<!doctype html>'; then
scripts/validate-html-page.sh:483  raw=$(head -c 4096 "$PAGE" | LC_ALL=C tr '\000\n\r\t\f' '\001    ' | LC_ALL=C tr 'A-Z' 'a-z')
scripts/validate-html-page.sh:491    if [ -n "$head_part" ] && ! printf '%s' "$head_part" | LC_ALL=C tr -d '\n' | LC_ALL=C grep -q '[^ -~]'; then
$ printf 'a\0b' | LC_ALL=C tr '\000' '\001' | od -c   ->  a 001 b
```

**Probe method.** A Python script under `/tmp/r6probe` copied
`scripts/fixtures/html-pages/valid/page.html`, which carries the policy, and applied one
byte edit per probe. Each page was checked with
`NO_COLOR=1 LC_ALL=<locale> LANG=<locale> scripts/validate-html-page.sh`, under `C` and
under `en_US.UTF-8`.

The four Chrome probes followed the round-5 method:
- the payload went before `</head>`: a module `import`, a `rel="style&#115;heet"` link,
  an escaped `@\69mport`, and an escaped `@font-f\61 ce` using `u\72l(`;
- each page was loaded with `"Google Chrome" --headless=new --virtual-time-budget=3000
  --dump-dom file://…`;
- a local HTTP server on `127.0.0.1:18761` logged every requested path;
- Chrome was killed after 6 s.

The NUL-tolerant awk was modelled with a PATH shim that ran
`LC_ALL=C tr -d '\000' | /usr/bin/awk "$@"`. All probe pages, profiles, the shim, and
the server were deleted afterwards (`ls -d /tmp/r6probe` → "No such file or directory").
The fixture regeneration tree `/tmp/r6gen` was also deleted.

```text
probe                  class               C: rc csp  FAIL rules      | UTF-8: rc csp  FAIL rules
control-csp-intact     control                0  PASS none            |        0  PASS none
nul-meta-tagname       r5 F-7                 1  FAIL csp             |        1  FAIL csp
nul-attr-name          r5 F-7                 1  FAIL csp             |        1  FAIL csp
nul-policy-value       r5 F-7                 1  FAIL csp             |        1  FAIL csp
nul-after-charset      r5 F-7 (O-59)          1  FAIL csp             |        1  FAIL csp
nul-after-policy       r5 (O-58)              0  PASS none            |        0  PASS none
nul-before-doctype     new                    1  FAIL doctype,csp     |        1  FAIL doctype,csp
nul-in-html-tag        new                    1  FAIL lang,csp        |        1  FAIL lang,csp
nul-in-head-tag        new                    1  FAIL csp             |        1  FAIL csp
nul-in-policy-name     new                    1  FAIL csp             |        1  FAIL csp
nul-plus-soh           new                    1  FAIL csp             |        1  FAIL csp
nul-in-body            new (O-58)             0  PASS none            |        0  PASS none
vt-meta-tagname        r4 F-6(a)              1  FAIL csp             |        1  FAIL csp
vt-before-content      r4 F-6(a)              1  FAIL csp             |        1  FAIL csp
vt-html-tag            r4 F-6(a)              1  FAIL csp             |        1  FAIL csp
vt-head-tag            r4 F-6(a)              1  FAIL csp             |        1  FAIL csp
dotted-I-attr          r4 F-6(b)              1  FAIL csp             |        1  FAIL csp
dotted-I-policy-name   r4 F-6(b)              1  FAIL csp             |        1  FAIL csp
del-in-meta            r5 O-45                1  FAIL csp             |        1  FAIL csp
nbsp-before-content    r5 O-45                1  FAIL csp             |        1  FAIL csp
long-s-policy-name     r5 O-45                1  FAIL csp             |        1  FAIL csp
fullwidth-lt-meta      r5 O-45                1  FAIL csp             |        1  FAIL csp
zwsp-in-attr           r5 O-45                1  FAIL csp             |        1  FAIL csp
esc-before-head        r5 O-45                1  FAIL csp             |        1  FAIL csp
uppercase-policy       r5 O-47 (legit)        0  PASS none            |        0  PASS none
ff-in-meta             r5 O-47 (legit)        0  PASS none            |        0  PASS none

Chrome (payload inserted before </head>):
control-csp-intact     validator rc=0 csp=PASS  chrome requests=0 -
control-csp-removed    validator rc=1 csp=FAIL  chrome requests=4 font.woff2 import.css module.js sheet.css
nul-after-policy       validator rc=0 csp=PASS  chrome requests=0 -
nul-in-body            validator rc=0 csp=PASS  chrome requests=0 -

NUL-stripping awk shim (PATH=/tmp/r6probe/nulawk:$PATH):
shim nul-meta-tagname   rc=1 FAIL  csp
shim nul-attr-name      rc=1 FAIL  csp
shim nul-policy-value   rc=1 FAIL  csp
shim nul-in-policy-name rc=1 FAIL  csp
shim nul-in-head-tag    rc=1 FAIL  csp
```

**Counts and fixture fidelity.**

```text
README.md:1543          | `test-html-page.sh` | Regression suite for themed HTML pages (151 cases) | US-14.1 |
README.md:1590          scripts/test-html-page.sh      # 151 cases — themed HTML pages
scripts/README.md:32    | `test-html-page.sh` | Regression suite for themed HTML pages (151 cases) | US-14.1 |
scripts/README.md:1374  … Each of the 55 invalid fixtures is the valid …
docs/pages/harness-overview.html:1002  scripts/test-html-page.sh … 151 … 0 … PASS
docs/pages/harness-overview.html:365   Suite assertions 578 across 6 regression suites   (36+103+46+63+179+151 = 578)
$ ls scripts/fixtures/html-pages/invalid | wc -l   ->  55
$ diff -r /tmp/r6gen/scripts/fixtures/html-pages scripts/fixtures/html-pages   ->  (no output) generator: no diff
```

**Scope.**

```text
$ scripts/check-scope.sh --plan openspec/changes/us-14-1-themed-html-pages/implementation-plan.md | tail -1
  RESULT: OUT OF PLAN SCOPE — 9 file(s) unaccounted for.
  (all 9 under openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/ — unchanged from rounds 4 and 5; O-64)
```

## Handoff

No remediation requested. Control proceeds to the Tester for acceptance testing
(`test-report.md`).
