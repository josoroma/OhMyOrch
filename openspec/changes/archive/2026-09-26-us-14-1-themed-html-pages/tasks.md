# Tasks — us-14-1-themed-html-pages

Story: US-14.1

## 1. Deliverables (SPECS.md US-14.1 Tasks)

- [x] 1.1 Create `.claude/skills/generate-html-page/SKILL.md` (evidence gathering, template fill, validation, report) — Scenario: The page cites the evidence behind its content; Scenario: The page opens with a table of contents
- [x] 1.2 Create `scripts/templates/html-page.html` with the Luma light and dark tokens verbatim and the theme toggle — Scenario: The page uses the Luma theme in light and dark; Scenario: The reader can switch between light and dark
- [x] 1.3 Add every supported component to the template: table, list, SVG diagram with overlay, SVG ER diagram, SVG infrastructure diagram — Scenario: The page presents content through the supported components
- [x] 1.4 Create `scripts/validate-html-page.sh` implementing every rule of the validator contract — Scenario: The validator rejects a non-conforming page; Scenario: The page is a self-contained single file; Scenario: The page opens with a table of contents
- [x] 1.5 Generate `docs/pages/harness-overview.html` from repository evidence — Scenario: The page cites the evidence behind its content
- [x] 1.6 Allow-list the new scripts in `.claude/settings.json`; document the skill and scripts in `README.md`, `scripts/README.md`, and `CLAUDE.md` — Scenario: The page presents content through the supported components

## 2. Implementation tests (Implementer-owned; acceptance evidence is the Tester's)

- [x] 2.1 Regression cases for Scenario: The page uses the Luma theme in light and dark
- [x] 2.2 Regression cases for Scenario: The reader can switch between light and dark
- [x] 2.3 Regression cases for Scenario: The page opens with a table of contents
- [x] 2.4 Regression cases for Scenario: The page presents content through the supported components
- [x] 2.5 Regression cases for Scenario: The page is a self-contained single file
- [x] 2.6 Regression cases for Scenario: The page cites the evidence behind its content
- [x] 2.7 Regression cases for Scenario: The validator rejects a non-conforming page

## R1. Remediation — reopened 2026-09-26 from review

Preserved: history/review-r1.md

- [x] R1.1 Resolve review finding F-1: `self-contained` misses single-quoted and multi-token `rel` on `<link>` — On lines 381–382, accept `["']?` before the value, and match the keyword as a token inside the `rel` value (for example `rel=["']?([^"'>]*[[:space:]])?stylesheet`). Add invalid fixtures for the single-quoted, multi-token (`alternate stylesheet`), and single-quoted `preload` forms to `make-fixtures.py`. Add matching `rejects … self-contained` cases to `scripts/test-html-page.sh`. Then update the "(92 cases)" counts in `README.md` and `scripts/README.md`, and the suite row on `docs/pages/harness-overview.html`.
- [x] R1.2 Resolve review finding F-2: Unpredicted deletion of `README-OPENSPEC-COMMANDS.md`, still referenced — If the deletion was unintended, restore the file (`git restore README-OPENSPEC-COMMANDS.md`). If it was intended, get a human Product Manager decision, record it in the plan's Affected Files, and remove the references at `CLAUDE.md` line 29 and `README.md` line 761 in the same change.

## R2. Remediation — reopened 2026-09-26 from review

Preserved: history/review-r2.md

- [x] R2.1 Resolve review finding F-3: `self-contained` misses valid attribute syntax on `<link>` and `<script>` — Change both patterns on lines 387 and 391 to allow `[[:space:]]*=[[:space:]]*` and to take `[[:space:]/]` before the attribute name. The `[^>]*` prefix should skip quoted values, for example `([^>"']|"[^"]*"|'[^']*')*`. An alternative is one awk pass that extracts each `<link`/`<script` start tag with quotes respected, then reads `rel` and `src` from it. Add invalid fixtures to `make-fixtures.py` for the spaced-`=` link, the spaced-`=` script, the `/`-separated link, and the `>`-in-value link. Add matching `rejects … self-contained` cases to `scripts/test-html-page.sh`. Then update the case and fixture counts in `README.md` (lines 1543, 1590), `scripts/README.md` (lines 32, 1352, 1354), and the suite row and total on `docs/pages/harness-overview.html` (lines 328, 565).

## R3. Remediation — reopened 2026-09-26 from review

Preserved: history/review-r3.md

- [x] R3.1 Resolve review finding F-4: `self-contained` accepts markup and CSS that load an external stylesheet, script, or font — Choose one approach and cover every cause (a)–(g) with a fixture.
- [x] R3.2 Resolve review finding F-5: a page whose inline script loads an external script passes `self-contained` — Adopt Option B from F-4. The CSP meta blocked both pages in Chrome (0 requests), and the validator can check it statically. Otherwise, ask the human Product Manager for a decision that the validator's `self-contained` rule covers declarative markup and CSS only. Record that decision in `implementation-plan.md` and `design.md`, and list script-mediated loads as a limit in the validator header, `README.md` line 1621, and `scripts/README.md` line 1341. A heuristic that searches script bodies for `import`, `createElement`, or `fetch` is not a remediation: it is incomplete, and it would wrongly reject harmless inline scripts.

## R4. Remediation — reopened 2026-09-26 from review

Preserved: history/review-r4.md

- [x] R4.1 Resolve review finding F-6: `csp` accepts a policy meta that the browser does not apply — On line 469, normalise only HTML whitespace (`\t\n\f\r` and space) and leave `\v` in place so the regex fails on it. Lowercase ASCII only, in a fixed locale: for example `LC_ALL=C tr 'A-Z' 'a-z'`, and run the `grep -qE "$csp_re"` on line 471 under `LC_ALL=C` too. A stricter alternative also covers NUL and other control or non-ASCII bytes: fail `csp` when the prefix before the end of the policy meta contains any byte other than printable ASCII and HTML whitespace. Add invalid fixtures to `make-fixtures.py` for `\v` in the `<meta>` tag name, `\v` before `content`, `\v` in `<html>`, and `İ` in `http-equiv` and in the `http-equiv` value. Add matching `rejects … csp` cases to `scripts/test-html-page.sh`, including one that runs the `İ` fixture under `LANG=en_US.UTF-8`. Update the validator comment at lines 465–467, which says no attribute value can make the policy "only appear to be there". Then update the case and fixture counts in `README.md` (lines 1543, 1590) and `scripts/README.md` (lines 32, 1365, 1367). Also update the suite row and total on `docs/pages/harness-overview.html` (lines 1002 and 365).

## R5. Remediation — reopened 2026-09-26 from review

Preserved: history/review-r5.md

- [x] R5.1 Resolve review finding F-7: `csp` passes a policy tag that contains a NUL byte, and the browser ignores that policy — Map NUL to a byte the check can see before any tool reads it. On line 479, add NUL to the first `tr`, for example `LC_ALL=C tr '\000' '\001' | LC_ALL=C tr '\n\r\t\f' '    '`. BSD `tr` maps `\000` to `\001`, and the existing `[^ -~]` test then rejects it. Do the same in the `FLAT` pipeline on line 181 (`tr '\n\t\r\000' '   \001'`), so the rest of the page survives and `csp` is the only rule that fails. Add invalid fixtures to `make-fixtures.py` for NUL in the `<meta>` tag name, in `http-equiv`, and in the policy value. Add matching `rejects … csp` cases to `scripts/test-html-page.sh`. Then update the case and fixture counts in `README.md` (lines 1543, 1590) and `scripts/README.md` (lines 32, 1374). Also update the suite row and total on `docs/pages/harness-overview.html` (lines 1002 and 365).
