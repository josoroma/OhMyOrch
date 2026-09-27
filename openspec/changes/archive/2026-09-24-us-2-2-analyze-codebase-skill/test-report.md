# Test Report — us-2-2-analyze-codebase-skill

Change: us-2-2-analyze-codebase-skill
Story: US-2.2
Verdict: pass
Coverage: 4/4 acceptance criteria evaluated

Backfilled acceptance record (2026-09-24, revision `ae11530`). Every row below was produced by
executing the command shown under Evidence Commands; the output is what was observed.
Regression-suite rows grep the output of one full suite run at this revision.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Generate CODEBASE.md from an existing repository | PASS | E-1 — inspection: the skill delegates to the Codebase Analyst and requires a revision and evidence paths. Command and observed output under Evidence Commands. |
| 2 | Do not fabricate a brownfield context for a greenfield project | PASS | E-2 — inspection: greenfield reports no codebase and forbids a fabricated CODEBASE.md. Command and observed output under Evidence Commands. |
| 3 | Refresh stale codebase understanding | PASS | E-3 — the skill defines staleness reconciliation, and the stale-revision guard case blocks. Command and observed output under Evidence Commands. |
| 4 | CODEBASE.md uses a stable current-state schema | PASS | E-4 — the schema validator accepts the complete fixture and names the sections missing from the incomplete one. Command and observed output under Evidence Commands. |

## Evidence Commands

### E-1 — Generate CODEBASE.md from an existing repository

```bash
grep -nE 'Delegate analysis to the Codebase Analyst|Analyzed revision:|Evidence Paths' .claude/skills/analyze-codebase/SKILL.md
```

```text
49:## Step 2 — Delegate analysis to the Codebase Analyst
87:- an `Analyzed revision:` line with the Git revision or another snapshot identifier;
90:  `## Evidence Paths`, and `## Unknowns`;
```

### E-2 — Do not fabricate a brownfield context for a greenfield project

```bash
grep -nF 'fabricated `CODEBASE.md`' .claude/skills/analyze-codebase/SKILL.md && grep -nF 'Fabricating an architecture' .claude/skills/analyze-codebase/SKILL.md
```

```text
38:do **not** create a fabricated `CODEBASE.md`. Report:
46:A greenfield project legitimately has no `CODEBASE.md`. Fabricating an architecture
```

### E-3 — Refresh stale codebase understanding

```bash
scripts/test-guards.sh | grep -E 'CODEBASE.md stale'
grep -nF 'Reconcile staleness' .claude/skills/analyze-codebase/SKILL.md
```

```text
ok    CODEBASE.md stale                                    exit=2
63:## Step 3 — Reconcile staleness
```

### E-4 — CODEBASE.md uses a stable current-state schema

```bash
scripts/validate-product-artifacts.sh --specs scripts/fixtures/valid/SPECS.md --prd scripts/fixtures/valid/PRD.md --codebase scripts/fixtures/valid/CODEBASE.md --quiet >/dev/null && echo 'valid CODEBASE.md fixture: exit 0' && scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --prd scripts/fixtures/invalid/PRD.md --codebase scripts/fixtures/invalid/CODEBASE.md 2>&1 | grep -E 'missing required section'
```

```text
valid CODEBASE.md fixture: exit 0
  FAIL  missing required section: ## Runtime and Tooling
  FAIL  missing required section: ## Evidence Paths
```

## Result

All 4 criteria were exercised and passed. No criterion was scored without evidence.

## Handoff

All criteria pass. The change is eligible for the completion gate.
