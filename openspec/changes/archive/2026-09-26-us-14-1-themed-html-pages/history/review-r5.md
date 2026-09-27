# Review — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: fail
Blocking: 1 finding (F-7)
Coverage: 7/7 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-14-1-themed-html-pages --strict` reports "Change 'us-14-1-themed-html-pages' is valid", and `openspec validate --all --strict` reports "Totals: 23 passed, 0 failed (23 items)". No spec/task/design mismatch. The blocking finding comes from validator and browser probes, not from the verify step.

## Summary

This is **round 5**, and it **supersedes `history/review-r4.md`**. Round 4 raised F-6:
the `csp` rule accepted a policy meta that the browser ignores, because of a vertical tab
or a locale-folded `İ` (U+0130). R4.1 changes `scripts/validate-html-page.sh` lines
479–490 in three ways. It normalises only tab, LF, FF, CR, and space. It folds case with
`LC_ALL=C tr 'A-Z' 'a-z'`. It then rejects any byte outside `[ -~]` up to the end of the
policy tag. It also adds five fixtures and seven suite cases. **F-6 is resolved.** Every
round-4 probe (five vertical-tab and two dotted-I forms) now exits 1 with `FAIL  csp` under
both `LC_ALL=C` and `LC_ALL=en_US.UTF-8`. So do 13 new lookalike and control-byte forms
that Chrome does not honour. Every suite and validator passes, and O-37 is resolved.

One class is still open. R4.1 and the validator comment at lines 473–474 both say a
**NUL** byte before the end of the policy tag fails `csp`. It does not. In four NUL
probes, `csp` prints `PASS`. In three of them Chrome did not apply the policy and
fetched an external script, stylesheet, import, and font. Those pages still exit 1 on
this machine, but only because 8 unrelated rules fail. The validator never names `csp`,
which is the rule the page actually breaks (F-7). Scenario 7 fails, and the other six
pass.

## Blocking Issues

### Finding F-7: `csp` passes a policy tag that contains a NUL byte, and the browser ignores that policy

Requirement: Scenario "The validator rejects a non-conforming page": for a page that violates any rule, the validator `MUST exit 1` and `MUST name the rule that failed`. R4.1, as ticked in `tasks.md`, states that `csp` fails when "the prefix before the end of the policy meta contains any byte other than printable ASCII and HTML whitespace". The validator comment at `scripts/validate-html-page.sh` lines 473–474 says: "A NUL, a control character, or a non-ASCII lookalike there fails the rule."
Observed: The byte check at line 487 (`LC_ALL=C grep -q '[^ -~]'`) never sees a NUL:
  - Line 479 builds `raw` from `head -c 4096 | tr … | tr …`, and the NUL survives that step. But `grep` (line 480) and `awk` (line 485) treat NUL as a string terminator, so neither one ever reads the NUL. In `<me\0ta http-equiv=…>`, the byte check reads the cut-off `head_part` without it.
  - `FLAT` (line 181) is built with `/usr/bin/awk`, which stops each record at the NUL. The rest of the page is lost, so `tokens-light`, `tokens-dark`, `toggle` (×4), `toc`, and `sources` fail instead.
  I applied each edit to `valid/page.html`, which carries the policy, and added the payload below. Results were identical under `LC_ALL=C` and `LC_ALL=en_US.UTF-8`:

  | probe | `csp` | exit | named failures | Chrome requests |
  |---|---|---|---|---|
  | `<me\0ta http-equiv=…>` | PASS | 1 | 8 unrelated rules | 4 (`module.js sheet.css import.css font.woff2`) |
  | `http-eq\0uiv=` | PASS | 1 | 8 unrelated rules | 4 |
  | `'no\0ne'` in the policy | PASS | 1 | 8 unrelated rules | 1 (`font.woff2`) |
  | `\0` after `<meta charset>` | PASS | 1 | 8 unrelated rules | 0 (policy applied) |

  The first three pages break the `csp` rule: Chrome did not apply the policy as written. Yet `csp` prints `PASS`, and the output names only rules the author did not break. Exit 1 on this machine comes from the `FLAT` truncation, not from `csp`. That depends on this platform's awk. I modelled a NUL-tolerant awk with a PATH shim under `/tmp` that strips NUL before `/usr/bin/awk`, matching how gawk/mawk and bash ≥ 4.4 command substitution treat NUL. The same three pages then exit **0** with every rule `PASS`. That second result is modelled, not observed on a real Linux host. None of the 52 invalid fixtures contains a NUL.
Expected: For each of these pages the validator exits 1 with `FAIL  csp: …`, on every platform, as R4.1 and the comment at lines 473–474 claim. The result does not depend on whether `awk` or `$(…)` keeps NUL.
Remediation: Map NUL to a byte the check can see before any tool reads it. On line 479, add NUL to the first `tr`, for example `LC_ALL=C tr '\000' '\001' | LC_ALL=C tr '\n\r\t\f' '    '`. BSD `tr` maps `\000` to `\001`, and the existing `[^ -~]` test then rejects it. Do the same in the `FLAT` pipeline on line 181 (`tr '\n\t\r\000' '   \001'`), so the rest of the page survives and `csp` is the only rule that fails. Add invalid fixtures to `make-fixtures.py` for NUL in the `<meta>` tag name, in `http-equiv`, and in the policy value. Add matching `rejects … csp` cases to `scripts/test-html-page.sh`. Then update the case and fixture counts in `README.md` (lines 1543, 1590) and `scripts/README.md` (lines 32, 1374). Also update the suite row and total on `docs/pages/harness-overview.html` (lines 1002 and 365).

## Observations

These are not blocking. Each is recorded for the Implementer or the Product Manager.

- **O-44: F-6 is resolved for every form round 4 named (verified independently).** Line 479
  maps only `\n\r\t\f` and leaves `\v` in place. It lowercases with `LC_ALL=C tr 'A-Z' 'a-z'`,
  and lines 480 and 485 run `grep` and `awk` under `LC_ALL=C`. `make-fixtures.py` lines
  113–117 add `csp-vt-in-meta`, `csp-vt-before-content`, `csp-vt-in-html`,
  `csp-dotted-i-attr`, and `csp-dotted-i-value`. `scripts/test-html-page.sh` lines 188–194
  add five `rejects … csp` cases and two cases under `LC_ALL=en_US.UTF-8`. All seven
  round-4 probes (`vt-meta-tagname`, `vt-before-content`, `vt-html-tag`, `vt-head-tag`,
  `vt-attr-name`, `dotted-I-attr`, `dotted-I-policy-name`) exit 1 with exactly one
  `FAIL  csp` under both locales. Chrome fetched all 4 payload resources for each, so the
  rejection is correct.
- **O-45: New lookalike and control-byte forms are rejected.** Each of these exits 1 with
  exactly `FAIL  csp` under both locales, and Chrome did not apply the policy:
  - vertical tab before `<head>`, after `<meta charset>`, and inside the policy value;
  - DEL (0x7F) in the tag;
  - NBSP and NEL (U+0085) before `content`, and NBSP after `<meta charset>`;
  - `ſ` (U+017F, which folds to `s` in Unicode) in the policy name;
  - fullwidth `＜` for `<`;
  - a zero-width space in `http-equiv`;
  - ESC before `<head>`.
- **O-46: Some rejections are stricter than the browser.** A vertical tab in the doctype,
  SOH in the policy value, a UTF-8 BOM (O-39), and a Kelvin sign `K` in `lang` all fail
  `csp`, yet Chrome applied the policy and made 0 requests. A page built from the template
  contains none of these, so none is a defect.
- **O-47: Legitimate variants still pass.** Chrome applied the policy (0 requests), and the
  validator exits 0, for each of these: an upper-case policy value, a form feed as the
  separator in `<meta\fhttp-equiv`, CR-only line endings, and no leading `<meta charset>`
  with a later `iso-2022-jp` charset meta.
- **O-48: The rule output still depends on the locale outside `csp`.** With a Kelvin sign
  `K` (U+212A) in `lang="…"`, `LC_ALL=C` fails only `csp`. `en_US.UTF-8` also fails
  `tokens-light: 32 of 32 :root tokens missing`. The exit code is 1 in both cases, and
  `csp` is named in both, so the scenario holds. The locale fix in R4.1 covers the `csp`
  pipeline only.
- **O-49: A `<meta http-equiv="refresh">` after the policy navigates to a remote URL.**
  The page passes every rule, and Chrome requested `nav.html`. CSP `default-src` does not
  govern top-level navigation. The spec's `MUST NOT load an external script, stylesheet,
  or font` does not name navigation, so this is not a finding. The Product Manager may
  still want to decide whether the contract should cover it.
- **O-37 is resolved.** `make-fixtures.py` line 110 now inserts
  `<style>@\69mport "https://cdn.example.com/x.css";</style>` before `</head>`, so the
  `@import` is the first rule in its own `<style>` (`invalid/csp-bypass-css-escape.html`
  line 327). The fixture exits 1 with exactly `FAIL  csp`.
- **O-50: The stale comment is gone.** `grep -n 'appear to be there'
  scripts/validate-html-page.sh` returns nothing. Lines 460–475 now describe the HTML
  whitespace set, ASCII-only folding, and the byte check. Lines 473–474 overstate that
  check, which is F-7.
- **O-51: The counts are consistent.** The suite reports `passed: 145`. `README.md` lines
  1543 and 1590 and `scripts/README.md` line 32 read `145 cases`. `scripts/README.md`
  line 1374 reads `52 invalid fixtures`, and `ls scripts/fixtures/html-pages/invalid | wc
  -l` gives 52. `docs/pages/harness-overview.html` line 1002 reads 145, and line 365
  reads 572 = 36 + 103 + 46 + 63 + 179 + 145, which matches the six suites run here.
- **O-52: The fixtures match their generator.** I ran `make-fixtures.py` in a temporary
  tree holding only the template and the generator, then compared with `diff -r`. There is
  no difference (52 invalid). All 52 invalid fixtures exit 1 with exactly one `FAIL`
  line, and it names the fixture's rule. The 3 valid fixtures exit 0.
- **O-53: Scope is unchanged from round 4 (O-42).** `check-scope.sh` reports the same 9
  unpredicted files, all under
  `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/`. The R4 work
  touched only files the plan already names: the validator, generator, fixtures, suite,
  `README.md`, `scripts/README.md`, the example page, and `tasks.md`.
- **O-54: Task honesty.** `workflow-status.sh` reports `19/19 tasks complete`. R4.1 is
  ticked, and every form it names by example (`\v`, `İ`) is covered. Its broader claim,
  that any non-printable byte fails, is not true for NUL. That is recorded under F-7, not
  as a separate finding.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The page uses the Luma theme in light and dark | PASS | `validate-html-page.sh` prints `PASS  tokens-light: all 32 :root tokens match the Luma palette` and `PASS  tokens-dark: all 31 .dark tokens match the Luma palette` on both `docs/pages/harness-overview.html` and `scripts/templates/html-page.html`. The four `invalid/tokens-*` fixtures exit 1 with exactly that rule named. |
| The reader can switch between light and dark | PASS | Both files print `PASS  toggle: #theme-toggle flips the dark class, persists it, and follows the system`. The four `invalid/toggle-*` fixtures exit 1 with `FAIL  toggle`. The toggle script is unchanged since round 4, where it rendered under the policy (`script-src 'unsafe-inline'`). |
| The page opens with a table of contents | PASS | Both files print `PASS  toc` and `PASS  toc-links: every in-page link resolves`. `toc-missing`, `toc-after-section`, `toc-unlinked-section`, and `toc-links-dangling` exit 1 with the matching rule. |
| The page presents content through the supported components | PASS | The template prints `PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative`, and the example page prints the same for 6 SVGs. The three `invalid/svg-a11y-*` fixtures exit 1. The component set is unchanged from round 4. |
| The page is a self-contained single file | PASS | The template and the example page print `PASS  self-contained` and `PASS  csp`. Each opens `<head>` with `<meta charset="utf-8">` and then the exact policy meta, which contains no NUL, `\v`, or non-ASCII byte. In Chrome, the `control-csp-intact` probe, built from `valid/page.html` with all four payload loads, made 0 requests. The validator gap is F-7, under the next row. |
| The page cites the evidence behind its content | PASS | The example page prints `PASS  sources: the page cites its evidence`. `sources-missing` and `sources-empty` exit 1 with `FAIL  sources`. The template run skips `sources` with `--no-sources`. |
| The validator rejects a non-conforming page | FAIL | All 52 invalid fixtures exit 1 with exactly one `FAIL  <rule>:`, and all 3 valid fixtures exit 0. The round-4 F-6 probes and 13 new ones exit 1 with `FAIL  csp` under both locales. Three NUL probes break `csp`: Chrome ignored the policy and fetched 4, 4, and 1 external resources. The validator still prints `PASS  csp` for them, and names only 8 rules the page did not break (F-7). |

## Verification Detail

**Suites and validators.**

```text
$ scripts/test-html-page.sh | tail -4
  passed: 145
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
  PASS  implementation   19/19 tasks complete
  ----  review           review.md missing
```

**Fixture loop** (exit code, fixture, and the rule named by the single `FAIL` line).

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
1 csp-vt-before-content      csp        1 self-contained-url                   self-contained
1 csp-vt-in-html             csp        1 sources-empty / sources-missing      sources
1 csp-vt-in-meta             csp        1 svg-a11y-dangling-label / -no-name / -no-role   svg-a11y
1 csp-weakened               csp        1 toc-after-section / toc-missing / toc-unlinked-section  toc
1 doctype                    doctype    1 toc-links-dangling                   toc-links
1 lang                       lang       1 toggle-no-button / -no-class / -no-storage / -no-system  toggle
                                        1 tokens-dark / tokens-dark-scoped     tokens-dark
                                        1 tokens-light / tokens-light-missing  tokens-light
(52 fixtures, all exit 1, each with exactly one FAIL line naming its rule)
valid/: 0 page-compact-tokens.html   0 page-mentions-markup.html   0 page.html
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
$ scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources | tail -4
  PASS  csp: the first element in <head> is the self-contained Content-Security-Policy
  --    sources: skipped (--no-sources)
  RESULT: PASS — the page satisfies the harness page contract.
```

**The `csp` rule as implemented.**

```text
scripts/validate-html-page.sh:479  raw=$(head -c 4096 "$PAGE" | LC_ALL=C tr '\n\r\t\f' '    ' | LC_ALL=C tr 'A-Z' 'a-z')
scripts/validate-html-page.sh:480  if printf '%s' "$raw" | LC_ALL=C grep -qE "$csp_re"; then
scripts/validate-html-page.sh:485    head_part=$(printf '%s' "$raw" | LC_ALL=C awk -v tag="content=\"$CSP_POLICY\">" '…index(buf, tag)…')
scripts/validate-html-page.sh:487    if [ -n "$head_part" ] && ! printf '%s' "$head_part" | LC_ALL=C tr -d '\n' | LC_ALL=C grep -q '[^ -~]'; then
```

**Probe method.** A Python script under `/tmp/r5probe` copied
`scripts/fixtures/html-pages/valid/page.html`, which carries the policy. It applied one
edit to the policy prefix and inserted this payload before `</head>`:
- a module `import`;
- a `rel="style&#115;heet"` link;
- an escaped `@\69mport` at the start of its own `<style>`;
- an escaped `@font-f\61 ce` whose `src` uses an escaped `u\72l(`, with the font used by
  `body`.

Every payload escapes the static `self-contained` rule, so `csp` is the only guard. Every
URL points at `http://127.0.0.1:18751/<probe>-…`. Each page was checked with
`NO_COLOR=1 LC_ALL=<locale> LANG=<locale> scripts/validate-html-page.sh`, under both `C`
and `en_US.UTF-8`. It was then loaded with `"Google Chrome" --headless=new
--virtual-time-budget=3000 --dump-dom file://…`, against a local `http.server` that logs
every requested path. Chrome was killed once the DOM was written, because headless Chrome
did not exit on its own on this host. A logged path proves the page fetched that
resource. All probe pages, profiles, the awk shim, and the server were deleted
afterwards (`ls -d /tmp/r5probe` → "No such file or directory").

```text
probe                  class             C: rc csp  sc   F | UTF-8: rc csp  sc   F | req fetched
control-csp-intact     control              0  PASS PASS 0 |        0  PASS PASS 0 | 0   -
control-csp-removed    control              1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
vt-meta-tagname        r4 F-6(a)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
vt-before-content      r4 F-6(a)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
vt-html-tag            r4 F-6(a)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
vt-head-tag            r4 F-6(a)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
vt-attr-name           r4 F-6(a)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
dotted-I-attr          r4 F-6(b)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
dotted-I-policy-name   r4 F-6(b)            1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
nul-meta-tagname       r4 O-38 -> F-7       1  PASS PASS 8 |        1  PASS PASS 8 | 4   font.woff2 import.css module.js sheet.css
nul-attr-name          r4 O-38 -> F-7       1  PASS PASS 8 |        1  PASS PASS 8 | 4   font.woff2 import.css module.js sheet.css
nul-policy-value       r4 O-38 -> F-7       1  PASS PASS 8 |        1  PASS PASS 8 | 1   font.woff2
bom-prefix             r4 O-39              1  FAIL PASS 2 |        1  FAIL PASS 2 | 0   -
vt-doctype             new                  1  FAIL PASS 2 |        1  FAIL PASS 2 | 0   -
vt-before-head         new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
vt-in-policy           new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 1   font.woff2
vt-after-charset       new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
del-in-meta            new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
nbsp-before-content    new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
nbsp-after-charset     new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
nel-before-content     new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
long-s-policy-name     new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
fullwidth-lt-meta      new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
zwsp-in-attr           new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
esc-before-head        new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 4   font.woff2 import.css module.js sheet.css
soh-in-policy          new                  1  FAIL PASS 1 |        1  FAIL PASS 1 | 0   -
kelvin-in-lang         new (O-48)           1  FAIL PASS 1 |        1  FAIL PASS 2 | 0   -
uppercase-policy       new                  0  PASS PASS 0 |        0  PASS PASS 0 | 0   -
ff-in-meta             new                  0  PASS PASS 0 |        0  PASS PASS 0 | 0   -
cr-only-lines          new                  0  PASS PASS 0 |        0  PASS PASS 0 | 0   -
no-charset-late-2022   new                  0  PASS PASS 0 |        0  PASS PASS 0 | 0   -
nul-after-charset      new (F-7)            1  PASS PASS 8 |        1  PASS PASS 8 | 0   -
nul-after-policy       new                  1  PASS PASS 8 |        1  PASS PASS 8 | 0   -
meta-refresh-after     new (O-49, nav)      0  PASS PASS 0 |        0  PASS PASS 0 | 1   nav.html
(sc = self-contained; F = number of FAIL rules)
```

**Where the NUL is lost (F-7).**

```text
$ raw=$(head -c 4096 nul-meta-tagname.html | LC_ALL=C tr '\n\r\t\f' '    ' | LC_ALL=C tr 'A-Z' 'a-z')
$ printf '%s' "$raw" | od -c        ->  … <   m   e  \0   t   a       h   t   t   p …   (NUL still present in $raw)
$ printf '%s' "$raw" | LC_ALL=C awk '{print length($0); exit}'   ->  66              (awk stops at the NUL)
$ scripts/validate-html-page.sh --page nul-meta-tagname.html
  FAIL  tokens-light / tokens-dark / toggle (x4) / toc / sources      (FLAT truncated at the NUL)
  PASS  csp: the first element in <head> is the self-contained Content-Security-Policy
  RESULT: FAIL — 8 rule(s) failed.
$ printf 'a\0b' | LC_ALL=C tr '\000' '\001' | od -c   ->  a 001 b                    (remediation primitive works with BSD tr)
```

**Modelled NUL-tolerant awk (inference, not observed on Linux).** A PATH shim
`/tmp/r5probe/nulawk/awk` ran `LC_ALL=C tr -d '\000' | /usr/bin/awk "$@"` for piped input.

```text
nul-meta-tagname   C / en_US.UTF-8   rc=0 csp=PASS sc=PASS fails=0
nul-attr-name      C / en_US.UTF-8   rc=0 csp=PASS sc=PASS fails=0
nul-policy-value   C / en_US.UTF-8   rc=0 csp=PASS sc=PASS fails=0
vt-meta-tagname    C / en_US.UTF-8   rc=1 csp=FAIL sc=PASS fails=1   (F-6 fix unaffected)
dotted-I-attr      C / en_US.UTF-8   rc=1 csp=FAIL sc=PASS fails=1
$ PATH=/tmp/r5probe/nulawk:$PATH scripts/test-html-page.sh   ->  failed: 0
```

**Fixtures match their generator.**

```text
$ (temp tree with scripts/templates/html-page.html and make-fixtures.py) python3 scripts/fixtures/html-pages/make-fixtures.py
$ diff -r scripts/fixtures/html-pages <temp>/scripts/fixtures/html-pages && echo "fixtures in sync"
fixtures in sync
52
```

**Scope.**

```text
$ scripts/check-scope.sh --plan openspec/changes/us-14-1-themed-html-pages/implementation-plan.md
  9 unpredicted — all openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/*
  RESULT: OUT OF PLAN SCOPE — 9 file(s) unaccounted for.   (unchanged from rounds 3 and 4)
```

## Handoff

Control returns to the Implementer to remediate F-7. Then `/review-feature
us-14-1-themed-html-pages` runs again (round 6). Acceptance testing does not proceed
while F-7 is open.
