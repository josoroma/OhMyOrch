# Completion Gate — false-certificate

<!--
INVALID FIXTURE — the Verdict is a false certificate.

Two conditions FAIL (acceptance and openspec-verification), yet the identity table
declares Verdict: eligible and the prose says "eligible — all four conditions pass".

This is the most dangerous completion record there is. A Product Manager reads the
Verdict, not the table, and would archive a change whose acceptance criteria are
failing. The validator must reject it.
-->

| Field | Value |
|---|---|
| Story | US-2.1 |
| Change | false-certificate |
| Verdict | eligible |
| Evaluated | 2026-09-24 |
| Derived from | `scripts/completion-gate.sh` |

## Conditions

| # | Condition | Status | Evidence | Source |
|---|---|---|---|---|
| 1 | tasks | pass | 2/2 tasks complete | tasks.md |
| 2 | review | pass | verdict 'pass', blocking: none | review.md |
| 3 | acceptance | fail | 2 acceptance criterion/criteria FAIL | test-report.md |
| 4 | openspec-verification | fail | 3 OpenSpec validation error(s) | openspec validate |

## Verdict

eligible — all four conditions pass

<!-- BEGIN AUTHORED: notes -->
## Notes

None.
<!-- END AUTHORED: notes -->
