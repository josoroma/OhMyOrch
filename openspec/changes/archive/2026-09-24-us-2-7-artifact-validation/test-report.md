# Test Report — us-2-7-artifact-validation

Change: us-2-7-artifact-validation
Story: US-2.7
Verdict: pass
Coverage: 5/5 acceptance criteria evaluated

Backfilled acceptance record (2026-09-24, revision `ae11530`). Every row below was produced by
executing the command shown under Evidence Commands; the output is what was observed.
Regression-suite rows grep the output of one full suite run at this revision.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Validate unique story identifiers | PASS | E-1 — duplicate Epic and User Story identifiers are both rejected. Command and observed output under Evidence Commands. |
| 2 | Validate READY story acceptance criteria | PASS | E-2 — a READY story with an incomplete Given/When/Then scenario is rejected. Command and observed output under Evidence Commands. |
| 3 | Unsupported generated requirement cannot be ready | PASS | E-3 — a READY story with no source reference is not treated as ready. Command and observed output under Evidence Commands. |
| 4 | PRD generation acknowledges existing CODEBASE.md | PASS | E-4 — a PRD.md that does not record consuming an existing CODEBASE.md is rejected. Command and observed output under Evidence Commands. |
| 5 | SPECS generation acknowledges existing CODEBASE.md | PASS | E-5 — a SPECS.md that does not record consuming an existing CODEBASE.md is rejected in CLI and hook mode. Command and observed output under Evidence Commands. |

## Evidence Commands

### E-1 — Validate unique story identifiers

```bash
T=$(mktemp -d) && printf '# EPIC-1: A\n\n# EPIC-1: B\n' > "$T/SPECS.md" && scripts/validate-product-artifacts.sh --specs "$T/SPECS.md" --prd "$T/none" --codebase "$T/none" 2>&1 | grep -E 'duplicate Epic identifier' && scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --prd scripts/fixtures/invalid/PRD.md --codebase scripts/fixtures/invalid/CODEBASE.md 2>&1 | grep -E 'duplicate User Story identifier'
```

```text
FAIL  duplicate Epic identifier: EPIC-1:
  FAIL  duplicate User Story identifier: US-1.1:
```

### E-2 — Validate READY story acceptance criteria

```bash
scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --prd scripts/fixtures/invalid/PRD.md --codebase scripts/fixtures/invalid/CODEBASE.md 2>&1 | grep -E 'lack Given/When/Then'
```

```text
FAIL  US-1.1: 1 of 2 scenario(s) lack Given/When/Then
```

### E-3 — Unsupported generated requirement cannot be ready

```bash
scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --prd scripts/fixtures/invalid/PRD.md --codebase scripts/fixtures/invalid/CODEBASE.md 2>&1 | grep -E "READY but has no 'Source:' reference"
```

```text
FAIL  US-1.2: READY but has no 'Source:' reference
```

### E-4 — PRD generation acknowledges existing CODEBASE.md

```bash
scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --prd scripts/fixtures/invalid/PRD.md --codebase scripts/fixtures/invalid/CODEBASE.md 2>&1 | grep -E 'PRD.md does not record consuming it'
```

```text
FAIL  scripts/fixtures/invalid/CODEBASE.md exists but scripts/fixtures/invalid/PRD.md does not record consuming it
```

### E-5 — SPECS generation acknowledges existing CODEBASE.md

```bash
scripts/test-guards.sh | grep -E 'SPECS.md (with|without) context marker|SPECS.md hook blocks'
scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --prd scripts/fixtures/invalid/PRD.md --codebase scripts/fixtures/invalid/CODEBASE.md 2>&1 | grep -E 'SPECS.md does not record consuming it'
```

```text
ok    SPECS.md without context marker fails                exit=1
  ok    SPECS.md hook blocks missing marker                  exit=2
  ok    SPECS.md with context marker passes                  exit=0
  FAIL  scripts/fixtures/invalid/CODEBASE.md exists but scripts/fixtures/invalid/SPECS.md does not record consuming it
```

## Result

All 5 criteria were exercised and passed. No criterion was scored without evidence.

## Handoff

All criteria pass. The change is eligible for the completion gate.
