# Review — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: fail
Blocking: 1 finding(s)
Coverage: 7/7 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-14-1-themed-html-pages --strict` reports "Change 'us-14-1-themed-html-pages' is valid"; `openspec validate --all --strict` reports "Totals: 23 passed, 0 failed (23 items)". Advisory only: it checks artifact structure, not validator behaviour, so it does not surface F-3.

## Summary

This review is **round 2** and **supersedes `history/review-r1.md`**. Round 1 failed on
two blocking findings, F-1 and F-2. I verified both remediation tasks myself and both
are resolved. R1.1: every round-1 bypass (single-quoted `rel`, multi-token `rel`,
single-quoted `preload`) now exits 1 on `self-contained`, and three new fixtures and
suite cases cover them. R1.2: the deletion of `README-OPENSPEC-COMMANDS.md` is recorded
as a human Product Manager decision in the plan (`implementation-plan.md` line 182). No
live reference to the file remains.

I re-checked all seven scenarios against the current code. Six pass. The template, the
validator, and design.md Appendix A still carry the same 32 light and 31 dark tokens.
The toggle behaves as specified when run. The example page's figures match the
repository, and every suite passes (98 + 36 + 103 + 46 + 63 + 179).

One blocking finding remains. It is in the same rule as F-1 but has a different cause:

- **F-3.** Some attribute syntax is valid HTML but still gets past the `self-contained`
  rule. A page that loads an external stylesheet or script passes (exit 0) when it has
  whitespace around `=`, `/` as the attribute separator, or `>` inside an earlier
  quoted attribute value. For those pages, "The validator rejects a non-conforming page"
  (MUST) fails. The `<script src = …>` form was already in round 1's code; round 1 did
  not probe it.

## Blocking Issues

### Finding F-3: `self-contained` misses valid attribute syntax on `<link>` and `<script>`

Requirement: Scenario "The validator rejects a non-conforming page": "Given a page that violates any of the rules above, When the page validator runs on it, Then it MUST exit 1 And it MUST name the rule that failed". The rule being violated is from Scenario "The page is a self-contained single file": "it MUST NOT load an external script, stylesheet, or font".
Observed: `scripts/validate-html-page.sh` line 387 matches `<script[^>]*[[:space:]]src=`. Line 391 (`rel_has`) matches `<link[^>]*[[:space:]]rel=["']?…`. Both patterns require `=` to follow the attribute name directly. Both require whitespace before the name. Both use `[^>]*`, which stops at the first `>`, even when that `>` is inside a quoted value. HTML allows whitespace around `=` and treats `/` inside a tag as an attribute separator. Browsers load every tag below. To reproduce, insert the tag before `</head>` in a copy of `scripts/fixtures/html-pages/valid/page.html`, then run `scripts/validate-html-page.sh --page <copy> --quiet`:
- `<link rel = "stylesheet" href="https://x/x.css">` → exit 0
- `<link rel= "stylesheet" href="https://x/x.css">` → exit 0
- `<link rel ="stylesheet" href="https://x/x.css">` → exit 0
- `<link rel = 'preload' as='font' href='https://x/f.woff2'>` → exit 0
- `<script src = "https://x/x.js"></script>` and `<script src ="https://x/x.js"></script>` → exit 0
- `<script type="module" src = "https://x/m.js"></script>` → exit 0
- `<link/rel="stylesheet"/href="https://x/x.css">` and `<script/src="https://x/x.js"></script>` → exit 0
- `<link title="a>b" rel="stylesheet" href="https://x/x.css">` and `<script data-x="a>b" src="https://x/x.js"></script>` → exit 0
- controls: `<link rel="stylesheet" href="https://x/x.css">` and `<script src="https://x/x.js"></script>` → exit 1, `FAIL  self-contained: …`
None of the 30 invalid fixtures uses any of these forms, so `scripts/test-html-page.sh` (98 passed) does not catch the gap.
Expected: The validator exits 1 with `FAIL  self-contained: …` for any `<script>` that carries a `src` attribute, and for any `<link>` whose `rel` value contains `stylesheet`, `preload`, `preconnect`, or `dns-prefetch` as a token. This must hold regardless of whitespace around `=`, whether the attributes are separated by whitespace or `/`, and whether an earlier quoted attribute value contains `>`.
Remediation: Change both patterns on lines 387 and 391 to allow `[[:space:]]*=[[:space:]]*` and to take `[[:space:]/]` before the attribute name. The `[^>]*` prefix should skip quoted values, for example `([^>"']|"[^"]*"|'[^']*')*`. An alternative is one awk pass that extracts each `<link`/`<script` start tag with quotes respected, then reads `rel` and `src` from it. Add invalid fixtures to `make-fixtures.py` for the spaced-`=` link, the spaced-`=` script, the `/`-separated link, and the `>`-in-value link. Add matching `rejects … self-contained` cases to `scripts/test-html-page.sh`. Then update the case and fixture counts in `README.md` (lines 1543, 1590), `scripts/README.md` (lines 32, 1352, 1354), and the suite row and total on `docs/pages/harness-overview.html` (lines 328, 565).

## Observations

These are not blocking. Each is recorded for the Implementer or the Product Manager.

- **O-12: R1.1 is resolved for the forms it named (verified independently).**
  `scripts/validate-html-page.sh` lines 388–394 add `rel_has`, which matches the keyword
  as any token of a `rel` value, whether single-quoted, double-quoted, or unquoted. The
  new fixtures are `make-fixtures.py` lines 76–78. Their suite cases are
  `scripts/test-html-page.sh` lines 169–171, and each is rejected by `self-contained` and
  fails exactly one rule. The round-1 probes now all exit 1, as do `rel="STYLESHEET"`,
  `rel="  stylesheet  "`, `rel="stylesheet alternate"`, `href` before `rel`, `/>`
  closing, a tab or newline before `rel`, and `rel='preconnect dns-prefetch'`. I
  regenerated the fixtures from `make-fixtures.py` in a temporary tree, and
  `diff -r` against `scripts/fixtures/html-pages/` shows no difference. The committed
  fixtures match their generator.
- **O-13: No false positives on non-token `rel` values.** These pass (exit 0) when the
  href is a `data:` URL: `rel="icon"`, `rel="stylesheets-note"`, `rel="nostylesheet"`,
  `rel="x-stylesheet"`, `rel="stylesheet-x"`, `rel="preloaded"`,
  `data-rel="stylesheet" rel="icon"`, `rel="icon" title="x stylesheet"`,
  `rel="icon" data-note="preload"`, and `rel="canonical" href="https://…"`. The same
  probes with `href="#x"` exit 1, but on `toc-links` (a dangling in-page link), not on
  `self-contained`. That is correct, and it is an artefact of the probe.
- **O-14: The rule is stricter than necessary in three obscure cases.** Line 391 flags
  `<link rel="stylesheet" href="data:text/css,…">`, which loads nothing external.
  design.md line 99 ("no `<link rel="stylesheet">`") and `scripts/README.md` line 1331
  state the rule this strictly, so this is consistent. The line also flags unquoted
  `<link rel=icon stylesheet …>`, where HTML reads `stylesheet` as a separate boolean
  attribute. And it flags a JavaScript string such as `"<link rel=stylesheet>"` inside an
  inline `<script>` body. None of the three affects a page built from the template.
- **O-15: Open question on `<link>` loads beyond the listed `rel` values.**
  `rel="modulepreload"` with a remote href fetches an external module script and exits 0.
  So do `rel="prefetch"`, `rel="icon"`, and `rel="manifest"` with remote hrefs. design.md
  line 99 lists only `<script src>` and `<link rel="stylesheet">`. The implementation
  adds `preload`, `preconnect`, and `dns-prefetch`. I cannot tell whether "MUST NOT load
  an external script" covers a script that is preloaded but not executed. That is a
  product reading for the Product Manager, so I am not scoring it as a defect.
- **O-16: R1.2 is resolved (verified independently).** `git status --short
  README-OPENSPEC-COMMANDS.md` gives `AD`, and `implementation-plan.md` line 182 records
  the deletion as a human Product Manager decision. `CLAUDE.md` no longer has the
  document-map row, and `README.md` line 761 now reads "…links to its archived change,
  whose files record how it was delivered." A `grep -rn README-OPENSPEC-COMMANDS` over the
  repository, excluding `openspec/changes/archive/` and this change's directory, finds
  nothing. Inside this change, only `tasks.md`, `implementation-plan.md`, and
  `history/review-r1.md` mention the file, and all three are records of the decision.
- **O-17: Round-1 O-2, O-3, and O-4 are now documented as limits.** They appear in the
  validator header (lines 28–32), in `scripts/README.md` (lines 1335–1341), and in the
  README.md "Self-contained" bullet (lines 1619–1622). The bullet no longer says nothing
  is loaded, and it names the unchecked elements. After F-3 is remediated, that bullet
  and `scripts/README.md` line 1331 remain accurate.
- **O-18: Round-1 O-5 is partly addressed.** The validator header (lines 25–26) and
  `scripts/README.md` line 1308 now note that Appendix A moves under
  `openspec/changes/archive/`. The token-fix note (line 251) now points at
  `scripts/templates/html-page.html`. `.claude/skills/generate-html-page/SKILL.md` lines
  142–143 and the template comment (lines 12–13) still say only "design.md Appendix A".
  Both also say the template carries the tokens verbatim, so a reader is not stranded.
- **O-19: Round-1 O-6 is resolved.** `docs/pages/harness-overview.html` line 327 reads
  "8 agents + 16 skills; plus 7 rules", so the total of 24 no longer reads as covering
  the rules.
- **O-20: The example page's figures match the repository now** (see Verification
  Detail). The suite row reads 98 (line 565), and the total is 525 = 36 + 103 + 46 + 63
  + 179 + 98 (line 328). No stale `92` count remains in `README.md`,
  `scripts/README.md`, `CLAUDE.md`, the skill, or `docs/pages/`. After archival, the
  page's US-14.1 `IN PROGRESS` status and EPIC-14 `0 / 1` will go stale, as the plan's
  Risks table expects.
- **O-21: Scope carries over unchanged from round 1 O-1.** With git and untracked files
  only, `check-scope.sh` reports 9 unpredicted files, all in
  `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/`. With
  `--diff` over `git diff --name-only` plus untracked files (65 paths), the only other
  unpredicted file is `openspec/delivery/goal.md`, which is derived by `delivery.sh`.
  `README-OPENSPEC-COMMANDS.md` no longer appears as unpredicted, because the plan now
  names it. The R1 edits touched only predicted files: the validator, `make-fixtures.py`
  and `invalid/`, the suite, `README.md`, `scripts/README.md`, `CLAUDE.md`,
  `docs/pages/harness-overview.html`, and `implementation-plan.md` / `tasks.md`.
- **O-22: The tasks are honest.** `workflow-status.sh` reports `implementation 15/15
  tasks complete`. R1.1 is ticked, and the change its text requests was made (quote and
  token matching, three fixtures, counts). F-3 covers forms that R1.1's text did not
  name.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The page uses the Luma theme in light and dark | PASS | I extracted the `:root` and `.dark` bodies from design.md Appendix A, the validator's `LIGHT_TOKENS`/`DARK_TOKENS`, and the template. The counts are 32/32 and 31/31, and `cmp` finds them identical: appendix==validator and template==appendix, light and dark. The validator prints `PASS  tokens-light: all 32 :root tokens match` and `PASS  tokens-dark: all 31 .dark tokens match` for both the template and `docs/pages/harness-overview.html`. The four `invalid/tokens-*` fixtures exit 1 on their own rule. |
| The reader can switch between light and dark | PASS | I ran both inline scripts of the template and the example page against a `document`/`localStorage`/`matchMedia` shim, with identical results for both files. No stored choice with system light → `dark=false`. System dark → `dark=true`. A click → `dark=true, stored=dark`. Reload with stored `dark` and system light → `dark=true`. Stored `light` and system dark → `dark=false`. With no stored choice, a system change to dark → `dark=true`. After a click, a system change → the stored choice holds. The four `invalid/toggle-*` fixtures exit 1 on `toggle`. |
| The page opens with a table of contents | PASS | The validator prints `PASS  toc` and `PASS  toc-links` on the template and the example page. `toc-missing`, `toc-after-section`, and `toc-unlinked-section` fail with `FAIL  toc: …`. `toc-links-dangling` fails with `FAIL  toc-links: … #nowhere`. |
| The page presents content through the supported components | PASS | The template has 7 `data-component` markers (`grep -c`): stats, table, list, svg-overlay, svg-er, svg-infra, sources. It prints `PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative`. The three `invalid/svg-a11y-*` fixtures exit 1 on `svg-a11y`. The suite asserts that every component is present and that the template has no literal colour. Visual rendering is for the Tester. |
| The page is a self-contained single file | PASS | The template and `docs/pages/harness-overview.html` each print `PASS  self-contained`. Their only `<script>` tags are inline (template line 489 and the head script; example page lines 9 and 591). Neither file has a `<link>`, `@import`, remote `url()`, or `@font-face`. The pages the skill generates load nothing external. The validator's gap on other syntax is F-3, under the next scenario. |
| The page cites the evidence behind its content | PASS | `docs/pages/harness-overview.html` `section#sources` (lines 574–585) lists 10 `<li>` entries naming commands and files. I recomputed each figure: 14 epics, 28 stories, 27 DONE, 1 IN PROGRESS, 27 archived, 22 specs, 8 agents / 16 skills / 7 rules, suites 36/103/46/63/179/98 (sum 525), and per-epic done/total from EPIC-1 2/2 to EPIC-14 0/1. All match the page (lines 323–328, 534–547, 560–565). `sources-missing` and `sources-empty` fail with `FAIL  sources: …`. |
| The validator rejects a non-conforming page | FAIL | All 30 invalid fixtures exit 1, each with exactly one `FAIL  <rule>:` line naming its rule, and all 3 valid fixtures exit 0. But pages that break `self-contained` through valid attribute syntax exit 0: whitespace around `=`, `/` as the separator, or `>` inside a quoted value (F-3). |

## Verification Detail

**Suites and validators.**

```text
scripts/test-html-page.sh     passed: 98   failed: 0   rc=0
scripts/test-write-scope.sh   passed: 36   failed: 0   rc=0
scripts/test-guards.sh        passed: 103  failed: 0   rc=0
scripts/test-status.sh        passed: 46   failed: 0   rc=0
scripts/test-completion.sh    passed: 63   failed: 0   rc=0
scripts/test-delivery.sh      passed: 179  failed: 0   rc=0
node scripts/check-frontmatter.js      RESULT: PASS — all definitions valid.  (24 OK lines; "OK    skill  generate-html-page")
scripts/validate-product-artifacts.sh  failures: 0  warnings: 0  RESULT: PASS — all required checks passed, 0 warning(s).
openspec validate --all --strict       Totals: 23 passed, 0 failed (23 items)
openspec validate us-14-1-themed-html-pages --strict   Change 'us-14-1-themed-html-pages' is valid
scripts/workflow-status.sh --change us-14-1-themed-html-pages
  PASS selection / planning / plan-handoff / implementation (15/15 tasks complete) / acceptance
  First incomplete gate: review
```

The new suite cases (`/tmp` log of `scripts/test-html-page.sh`):

```text
  ok    self-contained-link-single-quote is rejected by rule 'self-contained' exit=1
  ok    self-contained-link-multi-token is rejected by rule 'self-contained' exit=1
  ok    self-contained-preload-single-quote is rejected by rule 'self-contained' exit=1
  ok    self-contained-link-multi-token fails exactly one rule         = 1
  ok    self-contained-link-single-quote fails exactly one rule        = 1
  ok    self-contained-preload-single-quote fails exactly one rule     = 1
```

**Validator on the shipped pages.**

```text
$ scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources
  PASS  doctype / lang / tokens-light (32) / tokens-dark (31) / toggle / toc / toc-links
  PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative
  PASS  self-contained: no external script, stylesheet, import, url(), or font
  --    sources: skipped (--no-sources)
  RESULT: PASS — the page satisfies the harness page contract.   rc=0
$ scripts/validate-html-page.sh --page docs/pages/harness-overview.html
  … all 10 rules PASS, including "PASS  sources: the page cites its evidence"
  RESULT: PASS — the page satisfies the harness page contract.   rc=0
```

**Fixture loop.** `ls scripts/fixtures/html-pages/invalid | wc -l` → 30. Every invalid
fixture exits 1 with exactly one `FAIL` line naming its rule, for example:

```text
self-contained-link-multi-token.html      rc=1 nfail=1 FAIL  self-contained: … <link rel=stylesheet>
self-contained-link-single-quote.html     rc=1 nfail=1 FAIL  self-contained: … <link rel=stylesheet>
self-contained-preload-single-quote.html  rc=1 nfail=1 FAIL  self-contained: … <link preload/preconnect>
self-contained-preconnect.html            rc=1 nfail=1 FAIL  self-contained: … <link preload/preconnect>
self-contained-uppercase.html             rc=1 nfail=1 FAIL  self-contained: … <script src>
tokens-dark-scoped.html                   rc=1 nfail=1 FAIL  tokens-dark: 31 of 31 .dark tokens missing or changed …
toc-links-dangling.html                   rc=1 nfail=1 FAIL  toc-links: link(s) to no element on the page: #nowhere
… (all 30: rc=1 nfail=1)
page-compact-tokens.html rc=0   page-mentions-markup.html rc=0   page.html rc=0
```

**Self-contained probes.** Each tag was inserted before `</head>` in a copy of
`valid/page.html` from a scratch script outside the repository:

```text
round-1 forms (now rejected, R1.1)
rc=1  <link rel='stylesheet' href='https://cdn.example.com/x.css'>
rc=1  <link rel="alternate stylesheet" href="https://cdn.example.com/x.css">
rc=1  <link rel='preload' as='font' href='https://cdn.example.com/f.woff2'>
rc=1  <link rel=stylesheet …> / rel="  stylesheet  " / rel="STYLESHEET" / rel="stylesheet alternate"
rc=1  <link href=… rel="stylesheet"> / …rel="stylesheet"/> / TAB or newline before rel
rc=1  <link rel='preconnect dns-prefetch' …> / rel="dns-prefetch" / rel="preconnect"
still accepted (F-3)
rc=0  <link rel = "stylesheet" href="https://x/x.css">
rc=0  <link rel= "stylesheet" href="https://x/x.css">
rc=0  <link rel ="stylesheet" href="https://x/x.css">
rc=0  <link rel = 'preload' as='font' href='https://x/f.woff2'>
rc=0  <script src = "https://x/x.js"></script>
rc=0  <script src ="https://x/x.js"></script>
rc=0  <script type="module" src = "https://x/m.js"></script>
rc=0  <link/rel="stylesheet"/href="https://x/x.css">
rc=0  <script/src="https://x/x.js"></script>
rc=0  <link title="a>b" rel="stylesheet" href="https://x/x.css">
rc=0  <script data-x="a>b" src="https://x/x.js"></script>
false-positive probes (expect rc=0)
rc=0  <link rel="icon" href="data:,">
rc=0  <link rel="stylesheets-note" href="data:,">   rc=0  rel="nostylesheet"   rc=0  rel="x-stylesheet"
rc=0  <link rel="stylesheet-x" href="data:,">       rc=0  rel="preloaded"
rc=0  <link data-rel="stylesheet" rel="icon" href="data:,">
rc=0  <link rel="icon" title="x stylesheet" href="data:,">   rc=0  data-note="preload"
rc=0  <link rel="canonical" href="https://example.com/">
rc=1  <link rel="stylesheet" href="data:text/css,body{}">    (O-14: stricter than needed)
rc=1  <link rel=icon stylesheet href="data:,">               (O-14)
outside the listed rel values (O-15)
rc=0  <link rel="modulepreload" href="https://x/m.js">   rc=0  rel="prefetch" / "icon" / "manifest" (remote)
```

**Token fidelity.**

```text
32 /tmp/a-l  31 /tmp/a-d  32 /tmp/v-l  31 /tmp/v-d
appendix==validator light   appendix==validator dark
template==appendix light    template==appendix dark
```

**Fixtures match their generator.** I copied the template and `fixtures/html-pages/` to a
temporary tree, deleted the `.html` files there, ran `make-fixtures.py`, and ran
`diff -r` against the repository: no differences ("fixtures in sync with generator").

**R1.2 references.**

```text
$ grep -rn README-OPENSPEC-COMMANDS . --exclude-dir=.git | grep -v '^./openspec/changes/archive/' | grep -v '^./openspec/changes/us-14-1-themed-html-pages/'
(no output; grep exit 1)
$ grep -rln README-OPENSPEC-COMMANDS openspec/changes/us-14-1-themed-html-pages
tasks.md  implementation-plan.md  history/review-r1.md
$ git status --short README-OPENSPEC-COMMANDS.md
AD README-OPENSPEC-COMMANDS.md
$ git diff -- CLAUDE.md   (document map)
-| `README-OPENSPEC-COMMANDS.md` | Every command, input, and output … | No — explanatory |
+| `docs/pages/` | Themed single-page HTML generated by `/generate-html-page` | No — explanatory |
```

**Repository figures behind the example page.**

```text
epics 14  stories 28  done 27  inprog 1  archived 27  specs 22  agents 8  skills 16  rules 7
suite sum 36+103+46+63+179+98 = 525
EPIC-1 2/2  EPIC-2 7/7  EPIC-3 2/2  EPIC-4 1/1  EPIC-5 1/1  EPIC-6 1/1  EPIC-7 1/1
EPIC-8 2/2  EPIC-9 1/1  EPIC-10 1/1  EPIC-11 1/1  EPIC-12 4/4  EPIC-13 3/3  EPIC-14 0/1
page: 27 / 28 (l.323), 14 (l.324), 27 (l.325), 22 (l.326), 24 "8 agents + 16 skills; plus 7 rules" (l.327),
      525 (l.328), per-epic rows l.534–547, suite rows l.560–565 (test-html-page.sh 98)
```

**Scope.**

```text
$ scripts/check-scope.sh --plan openspec/changes/us-14-1-themed-html-pages/implementation-plan.md
  Changed: 55 file(s)   Predicted: 129 path(s) named in the plan
  9 unpredicted — all openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/*
  RESULT: OUT OF PLAN SCOPE — 9 file(s) unaccounted for.
$ … --diff <git diff --name-only + untracked, 65 paths>
  unpredicted outside the US-13.3 archive: openspec/delivery/goal.md
  RESULT: OUT OF PLAN SCOPE — 10 file(s) unaccounted for.
```

## Handoff

Control returns to the Implementer to remediate F-3. Then `/review-feature
us-14-1-themed-html-pages` runs again (round 3). Acceptance testing does not proceed
while F-3 is open. O-15 is an open product question for the human Product Manager, and
it does not block this change.
