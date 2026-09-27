# Review — us-14-1-themed-html-pages

Change: us-14-1-themed-html-pages
Story: US-14.1
Verdict: fail
Blocking: 2 finding(s)
Coverage: 7/7 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-14-1-themed-html-pages --strict` reports "Change 'us-14-1-themed-html-pages' is valid"; `openspec validate --all --strict` reports "Totals: 23 passed, 0 failed (23 items)". Advisory only: it checks artifact structure, not the validator's behaviour, so it does not surface F-1 or F-2.

## Summary

Most of the implementation meets the specification. The template, the validator's
embedded lists, and the example page all carry the Luma tokens from design.md
Appendix A byte for byte: 32 light and 31 dark. The toggle behaves as specified when
run. The template ships every component. The example page's figures match the
repository today. All 27 shipped invalid fixtures exit 1 and name their rule, and
every suite passes.

Two blocking issues remain:

- **F-1.** The `self-contained` rule accepts a page that loads an external stylesheet
  or font when the `rel` attribute uses single quotes or holds more than one token. In
  those cases "The validator rejects a non-conforming page" (MUST) fails.
- **F-2.** The working tree deletes `README-OPENSPEC-COMMANDS.md`, a file the plan did
  not predict. `CLAUDE.md` and `README.md` still reference it.

## Blocking Issues

### Finding F-1: `self-contained` misses single-quoted and multi-token `rel` on `<link>`

Requirement: Scenario "The validator rejects a non-conforming page" — "Given a page that violates any of the rules above, When the page validator runs on it, Then it MUST exit 1 And it MUST name the rule that failed". The rule being violated is Scenario "The page is a self-contained single file" — "it MUST NOT load an external script, stylesheet, or font". design.md line 99 states the check as "no `<link rel="stylesheet">`".
Observed: `scripts/validate-html-page.sh` line 381 matches `<link[^>]*rel="?stylesheet`, and line 382 matches `<link[^>]*rel="?(preload|preconnect|dns-prefetch)`. Both accept only a double quote or no quote. Both also require the `rel` value to *start* with the keyword. So the validator passes a page that loads a remote stylesheet or font through valid HTML. To reproduce, insert the tag before `</head>` in `scripts/fixtures/html-pages/valid/page.html` and run `scripts/validate-html-page.sh --page <copy> --quiet`:
- `<link rel='stylesheet' href='https://cdn.example.com/x.css'>` → `RESULT: PASS`, exit 0
- `<link rel="alternate stylesheet" href="https://cdn.example.com/x.css">` → `RESULT: PASS`, exit 0
- `<link rel='preload' as='font' href='https://cdn.example.com/f.woff2'>` → `RESULT: PASS`, exit 0
- control: `<link rel="stylesheet" href="https://cdn.example.com/x.css">` → `FAIL  self-contained: …`, exit 1

The plan predicted the quote gap. Its §E pattern is `<link[^>]*rel=["']?stylesheet`, which allows either quote. The fixture `invalid/self-contained-link.html` (make-fixtures.py line 69) tests only the double-quoted form, so the suite does not catch the regression.
Expected: For any `<link>` whose `rel` contains the token `stylesheet`, or `preload`/`preconnect`/`dns-prefetch`, the validator exits 1 and prints `FAIL  self-contained: …`. That holds for single, double, or no quotes, and wherever the token falls in a space-separated `rel` list.
Remediation: On lines 381–382, accept `["']?` before the value, and match the keyword as a token inside the `rel` value (for example `rel=["']?([^"'>]*[[:space:]])?stylesheet`). Add invalid fixtures for the single-quoted, multi-token (`alternate stylesheet`), and single-quoted `preload` forms to `make-fixtures.py`. Add matching `rejects … self-contained` cases to `scripts/test-html-page.sh`. Then update the "(92 cases)" counts in `README.md` and `scripts/README.md`, and the suite row on `docs/pages/harness-overview.html`.

### Finding F-2: Unpredicted deletion of `README-OPENSPEC-COMMANDS.md`, still referenced

Requirement: Scope discipline (BR-003; `.claude/rules/openspec.md` "Scope discipline"): "A file outside the prediction means either the plan was incomplete or the work has drifted; in both cases, stop and re-plan". The implementation-plan's "Expected to stay unchanged" list and proposal.md Impact name no removal of this file.
Observed: `git diff --name-status -- README-OPENSPEC-COMMANDS.md` → `D`. The index holds 2109 lines (`git show :README-OPENSPEC-COMMANDS.md | wc -l` → `2109`), and the working tree has no file (`ls` → "No such file or directory"). Running `scripts/check-scope.sh --plan openspec/changes/us-14-1-themed-html-pages/implementation-plan.md --diff <git diff --name-only + untracked>` lists `README-OPENSPEC-COMMANDS.md` as unpredicted. `CLAUDE.md` line 29 (the document map, which this change edits on line 33) and `README.md` line 761 still point to the file. The session history does not show who deleted it, so attribution is unknown.
Expected: The change touches only predicted files. The document map in `CLAUDE.md`, a normative contract, names no missing file.
Remediation: If the deletion was unintended, restore the file (`git restore README-OPENSPEC-COMMANDS.md`). If it was intended, get a human Product Manager decision, record it in the plan's Affected Files, and remove the references at `CLAUDE.md` line 29 and `README.md` line 761 in the same change.

## Observations

Non-blocking. Each is recorded for the Implementer or Product Manager to consider.

- **O-1 — The other out-of-plan files are accounted for.** Running `check-scope.sh`
  with no `--diff` reports 9 unpredicted files, all under
  `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/`. With
  tracked modifications included, it reports those 9 plus `openspec/delivery/goal.md`
  and F-2's file. The US-13.3 archive files and the US-13.3 edits (`scripts/test-guards.sh`
  lines 337–364, the `README.md` §19 handoff subsection, `openspec/specs/harness-documentation/spec.md`,
  `SPECS-EPICS/README-EPIC-13.md`, and the SPECS.md US-13.3 rows) have mtimes from
  09:47 to 09:59. That is before this change's `proposal.md` (10:34). They show up only
  because the repository has no commits, so the baseline is the index. They carry over
  from US-13.3 and are outside this change. `goal.md` is derived by `scripts/delivery.sh`,
  which the Product Manager runs, so it is outside the Implementer's scope and expected.
- **O-2 — The validator does not check remote images, iframes, or inline `style=""` `url()`.**
  A remote `<img src>`, `<iframe src>`, SVG `<image href>`, and
  `<div style="background:url(https://…)">` all pass (exit 0). The scenario names only
  "script, stylesheet, or font", so this is not a spec defect. Still, `SKILL.md` line
  141 says "no remote image", `README.md` lines 1620–1621 say "Nothing is loaded from
  the network", and the plan's §E said to scan `style="…"` attributes. The CSS scan at
  `scripts/validate-html-page.sh` lines 383–386 reads only `<style>` bodies.
- **O-3 — `@font-face` is rejected outright.** Line 386 rejects every
  `@font-face`, including `src: local('Arial')`. design.md line 99 says "`@font-face`
  with a remote source". This is stricter than designed. It is consistent with the
  `scripts/README.md` rule table and does no harm to a page generated from the template.
- **O-4 — A later override of a token is not detected.** A second `:root { --primary:
  oklch(0.6 0.2 30); }`, or an `html.dark { --background: … }` rule after the palette,
  changes what the reader sees, yet the page still passes. `declarations()` (lines
  202–224) checks that the expected line is present, not that it is the last one. The
  plan's Risks table asked for this limit to be recorded in the header comment. Lines
  202–204 record only the `@media` and `.dark .card` cases.
- **O-5 — The Appendix A pointer will move.** Line 244 of the validator
  ("copy the block from design.md Appendix A"), `SKILL.md` line 142, and
  `scripts/README.md` line 1308 all point at a `design.md` that moves under
  `openspec/changes/archive/` on archival. The template carries the blocks too, so the
  pointer still works in practice.
- **O-6 — The page's "Harness definitions" card could be misread.** `docs/pages/harness-overview.html` line 327 shows
  `24` with the note "8 agents · 16 skills · 7 rules". 24 = 8 + 16, so the 7 rules are
  not in the total. That is correct, but a reader could take 24 as covering all three.
  The Sources command `ls .claude/agents .claude/skills .claude/rules` (line 580) also
  lists `README.md` in two of the directories. The page's counts leave it out, which is
  correct.
- **O-7 — The example page is a correct snapshot.** It shows US-14.1 `IN PROGRESS`,
  27/28 delivered, and EPIC-14 `0 / 1`. That matches `SPECS.md` line 2215
  (`Status: IN PROGRESS`) before archival. The page states its generation date and says
  no revision is recorded (no commits). The figures will go stale on archival, as the
  plan's Risks table expects.
- **O-8 — The toggle was checked at runtime, not only by the static rule.** Both inline
  scripts in the template and the example page were run against a
  `document`/`localStorage`/`matchMedia` shim. Visual rendering in a real browser was
  not checked. That belongs to the Tester.
- **O-9 — The skill writes under `docs/`, which the planning guard treats as product code.**
  While a change is active without a plan, `guard-planning-handoff.sh` (lines 94–100
  exclude only `.claude/`, `scripts/`, `openspec/`, and the change artifacts) would
  block `/generate-html-page` from writing `docs/pages/<slug>.html`. With no active
  change, the guard fails open (line 117). This is an operating note, not a defect.
- **O-10 — The fixture set goes beyond the plan.** There are 27 invalid fixtures
  against 24 in §H. The additions are `toc-missing`, `toggle-no-button`,
  `tokens-light-missing`, and `self-contained-preconnect`. The suite's `only_rule`
  loop (`scripts/test-html-page.sh` lines 190–194) asserts that each fixture fails
  exactly one rule, which keeps the fixtures isolated.
- **O-11 — The skill frontmatter is valid and the skill follows the rules.**
  `node scripts/check-frontmatter.js` prints `OK    skill  generate-html-page`, with 24
  `OK` lines. `SKILL.md` lines 29–33 forbid invented figures and require
  `section#sources`. Lines 139–145 forbid external loads, token edits, literal colours,
  and edits to product code, `SPECS.md`, or change artifacts. No instruction conflicts
  with the repository rules.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| The page uses the Luma theme in light and dark | PASS | Byte-for-byte `cmp` of the extracted blocks: Appendix A (design.md) == template == validator heredocs == example page, 32 `:root` and 31 `.dark` lines. The validator prints `PASS  tokens-light: all 32 :root tokens match` and `PASS  tokens-dark: all 31 .dark tokens match` for the template and the example page. `invalid/tokens-light*.html` and `invalid/tokens-dark*.html` exit 1. (O-4 notes the override limit.) |
| The reader can switch between light and dark | PASS | Template lines 20–29 and 489–501, identical in the example page. Shim run: no stored choice with system light → not dark; system dark → dark; one click → dark, `localStorage.theme = "dark"`; stored `light` with system dark → not dark (the stored choice wins across reload); a system change with nothing stored → follows it; a system change after a click → the stored choice holds. Static rule: the 4 `invalid/toggle-*.html` fixtures exit 1. |
| The page opens with a table of contents | PASS | Template `nav.toc` (line 315) comes before the first `<section>` (line 329). The example page's `nav.toc` (line 304) links all 9 section ids. The validator prints `PASS  toc` and `PASS  toc-links` on both. `toc-missing`, `toc-after-section`, `toc-unlinked-section` → `FAIL  toc:`; `toc-links-dangling` → `FAIL  toc-links: … #nowhere`. |
| The page presents content through the supported components | PASS | The template has `data-component="table"` (line 339), `"list"` (355), `"svg-overlay"` (364, `<details class="overlay-toggle">`), `"svg-er"` (396, PK/FK badges and a crow's-foot path), and `"svg-infra"` (434, `.svg-zone` boundary). `PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative` (three `role="img"` + `aria-labelledby` resolving to `<title>`/`<desc>`; one `aria-hidden="true"` legend). Suite: no literal colour in the template's `<style>`. Visual rendering is the Tester's (O-8). |
| The page is a self-contained single file | PASS | `grep -noiE 'https?://…\|<link…\|@import\|url(…)\|<script…src\|<img\|<iframe\|@font-face'` finds only in-document `url(#…-arrow)` marker references in the template (lines 379–464) and the example page (lines 390–509). Neither file loads any external script, stylesheet, or font. The validator prints `PASS  self-contained` on both. (The validator's own gap is F-1.) |
| The page cites the evidence behind its content | PASS | `docs/pages/harness-overview.html` `section#sources` (lines 571–584) lists 10 `<li>` entries naming commands and files. Recomputed now: epics `14`, stories `28`, DONE `27`, IN PROGRESS `1`, archived `27`, capabilities `22`, agents 8 / skills 16 / rules 7, suites 36/103/46/63/179/92 (sum `519`), and per-epic done/total rows 2/2, 7/7, 2/2, 1/1 ×7, 2/2 (EPIC-8), 4/4, 3/3, 0/1. All match the page. The hook diagram matches `.claude/settings.json` (PreToolUse Write/Edit/MultiEdit: planning-handoff, context-preflight, story-done, delivery-loop; PreToolUse Bash: archive; PostToolUse: validate-product-artifacts, run-project-validation; Stop: delivery-loop). The guard usage exit `3` is confirmed for all 5 guards. `sources-missing` and `sources-empty` → `FAIL  sources:`. |
| The validator rejects a non-conforming page | FAIL | All 27 shipped invalid fixtures exit 1 with `FAIL  <rule>:` naming their own rule, and exactly one rule fails per fixture. Usage: no `--page` → 2, missing file → 2. But pages that break the self-contained rule through a single-quoted or multi-token `rel` exit 0 (F-1). |

## Verification Detail

**Token fidelity.** The `:root { … }` and `.dark { … }` bodies were extracted from design.md,
the template, and the example page. The validator's `LIGHT_TOKENS` and `DARK_TOKENS`
heredocs were extracted too. After stripping indentation and the trailing `;`, the
files compared:

```text
32 a-light  32 t-light  32 v-light   31 a-dark  31 t-dark  31 v-dark
appendix==template light   appendix==validator light
appendix==template dark    appendix==validator dark
page light ok              page dark ok
```

**Validator on the shipped pages.**

```text
$ scripts/validate-html-page.sh --page scripts/templates/html-page.html --no-sources
  PASS  doctype / lang / tokens-light (32) / tokens-dark (31) / toggle / toc / toc-links
  PASS  svg-a11y: all 4 SVG(s) are labelled or marked decorative
  PASS  self-contained
  --    sources: skipped (--no-sources)
  RESULT: PASS — exit=0
$ scripts/validate-html-page.sh --page docs/pages/harness-overview.html
  … all 10 rules PASS, including "sources: the page cites its evidence" — exit=0
```

**Invalid fixtures** (`for f in scripts/fixtures/html-pages/invalid/*.html`). All 27
exit 1, and each prints exactly one `FAIL` line naming its rule. Examples:
`doctype.html rc=1 FAIL doctype:`, `self-contained-uppercase.html rc=1 FAIL self-contained: … <script src>`,
`tokens-dark.html rc=1 FAIL tokens-dark: 1 of 31 … '--border: oklch(1 0 0 / 10%)'`,
`toc-links-dangling.html rc=1 FAIL toc-links: … #nowhere`. The valid fixtures
`page.html`, `page-compact-tokens.html`, and `page-mentions-markup.html` each exit 0.

**Self-contained probes** (each tag inserted before `</head>` of a copy of `valid/page.html`):

```text
<script src='https://…'>                  rc=1   <script type="module" src=…>   rc=1
<script src=https://… (unquoted)>         rc=1   <link href=… rel="stylesheet"> rc=1
<link rel=stylesheet (unquoted)>          rc=1   @IMPORT "https://…" in <style>  rc=1
url('https://…') in <style>               rc=1   @font-face remote / local       rc=1
<link rel='stylesheet' …>                 rc=0   <- F-1
<link rel="alternate stylesheet" …>       rc=0   <- F-1
<link rel='preload' as='font' …>          rc=0   <- F-1
<link rel="icon"/"modulepreload" …>       rc=0   <img src=https://…>             rc=0 (O-2)
<iframe src=…>, <svg><image href=…>       rc=0   style="background:url(https://…)" rc=0 (O-2)
```

**Suites and validators.**

```text
scripts/test-html-page.sh     passed: 92   failed: 0   rc=0
scripts/test-write-scope.sh   passed: 36   failed: 0   rc=0
scripts/test-guards.sh        passed: 103  failed: 0   rc=0
scripts/test-status.sh        passed: 46   failed: 0   rc=0
scripts/test-completion.sh    passed: 63   failed: 0   rc=0
scripts/test-delivery.sh      passed: 179  failed: 0   rc=0
node scripts/check-frontmatter.js   RESULT: PASS — all definitions valid. (24 OK lines, incl. generate-html-page)
scripts/validate-product-artifacts.sh   failures: 0  warnings: 0  RESULT: PASS
openspec validate us-14-1-themed-html-pages --strict   Change 'us-14-1-themed-html-pages' is valid
openspec validate --all --strict   Totals: 23 passed, 0 failed (23 items)
```

**Repository figures behind the example page.**

```text
grep -cE '^# EPIC-[0-9]+:' SPECS.md          14
grep -cE '^### US-[0-9]+\.[0-9]+:' SPECS.md  28
grep -c '^Status: DONE' SPECS.md             27
grep -c '^Status: IN PROGRESS' SPECS.md      1
ls openspec/changes/archive | wc -l          27
ls openspec/specs | wc -l                    22
ls .claude/skills | wc -l                    16   (.claude/agents: 8 + README.md; .claude/rules: 7 + README.md)
per-epic DONE/total (awk over SPECS.md)      EPIC-1 2/2 … EPIC-13 3/3, EPIC-14 0/1
```

**Hook wiring** (`.claude/settings.json`, parsed): `PostToolUse Write|Edit|MultiEdit` →
validate-product-artifacts and run-project-validation. `PreToolUse Write|Edit|MultiEdit` →
guard-planning-handoff, guard-context-preflight, guard-story-done, and guard-delivery-loop.
`PreToolUse Bash` → guard-archive. `Stop` → guard-delivery-loop. The only settings diff
is the 4 allow-list entries `Bash([bash ]scripts/{validate,test}-html-page.sh:*)`. No
hook was added.

**Scope.** `scripts/check-scope.sh --plan …/implementation-plan.md` (git + untracked) →
`OUT OF PLAN SCOPE — 9 file(s)`, all from the US-13.3 archive (O-1). With `--diff` over
`git diff --name-only` + untracked (61 paths), the unpredicted set outside the US-13.3
archive is `openspec/delivery/goal.md` (O-1) and `README-OPENSPEC-COMMANDS.md` (F-2).
The predicted US-14.1 files are the skill, template, validator, suite, fixtures,
example page, `README.md`, `scripts/README.md`, `CLAUDE.md`, `.claude/settings.json`,
and the `tasks.md` ticks. All are present.

**Task honesty.** All 13 tasks are ticked, and each maps to a delivered artifact.
Task 2.5 ("Regression cases for … self-contained") exists, but it lacks the quote
variants that F-1 exposes.

## Handoff

Control returns to the Implementer to remediate F-1 and F-2. Then `/review-feature
us-14-1-themed-html-pages` runs again. Acceptance testing does not proceed while
these blocking findings are open.
