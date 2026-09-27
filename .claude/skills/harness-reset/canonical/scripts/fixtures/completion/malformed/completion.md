# Completion Gate — malformed

<!--
INVALID FIXTURE — several independent contract violations:

  * Verdict is "probably-fine", which is not eligible or not-eligible.
  * The Conditions table has three rows, not four: condition 2 (review) is
    missing, so the table cannot be read positionally.
  * There is no ## Verdict section at all.
  * The Story field is not a story identifier.
-->

| Field | Value |
|---|---|
| Story | some-story |
| Change | malformed |
| Verdict | probably-fine |
| Evaluated | 2026-09-24 |

## Conditions

| # | Condition | Status | Evidence | Source |
|---|---|---|---|---|
| 1 | tasks | pass | 2/2 tasks complete | tasks.md |
| 3 | acceptance | pass | 3 acceptance criterion/criteria PASS | test-report.md |
| 4 | openspec-verification | pass | openspec validate clean | openspec validate |
