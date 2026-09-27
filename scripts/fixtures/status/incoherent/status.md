# Change Status — incoherent-change

<!--
INVALID FIXTURE — the Resume line contradicts the Gates table.

The table shows gate 4 (implementation) passing and gate 5 (review) failing, so
the first incomplete gate is "review". The Resume line claims "implementation".

This is the most dangerous status.md defect, because a resuming session reads the
Resume line and would redo completed work while skipping the gate that is
actually blocking. The validator must catch it.
-->

| Field | Value |
|---|---|
| Story | US-2.1 |
| Change | incoherent-change |
| State | REVIEWING |
| Current owner | reviewer |
| Updated | 2026-09-24 |
| Derived from | `scripts/workflow-status.sh` |

## Gates

| # | Gate | Status | Detail | Owner |
|---|---|---|---|---|
| 1 | selection | pass | change 'incoherent-change' exists | product-manager |
| 2 | planning | pass | proposal.md, specs/, tasks.md present | planner |
| 3 | plan-handoff | pass | plan satisfies the contract | planner |
| 4 | implementation | pass | 2/2 tasks complete | implementer |
| 5 | review | fail | review.md missing | reviewer |
| 6 | testing | fail | test-report.md missing | tester |
| 7 | acceptance | fail | artifact contracts not yet satisfied | product-manager |

## Resume

First incomplete gate: implementation
Next owner: implementer

<!-- BEGIN AUTHORED: blockers -->
## Blockers

None.
<!-- END AUTHORED: blockers -->
