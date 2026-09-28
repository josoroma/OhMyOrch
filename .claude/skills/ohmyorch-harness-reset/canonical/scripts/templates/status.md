# Change Status — <change-id>

<!--
Durable workflow state for one active OpenSpec change (US-9.1).

Written by scripts/status.sh. The gates table is DERIVED from
scripts/workflow-status.sh and must not be hand-edited — refresh it instead.
The Blockers section between the AUTHORED markers is hand-written by the Product
Manager and is preserved verbatim across refreshes.

Validate before relying on it:
  scripts/validate-status.sh --status <path> --change <change-id>
-->

| Field | Value |
|---|---|
| Story | US-<n>.<m> |
| Change | <change-id> |
| State | <CHANGE_STATE> |
| Current owner | <role> |
| Updated | <YYYY-MM-DD> |
| Derived from | `scripts/workflow-status.sh` |

## Gates

| # | Gate | Status | Detail | Owner |
|---|---|---|---|---|
| 1 | selection | <pass/fail> | <detail> | ohmyorch-product-manager |
| 2 | planning | <pass/fail> | <detail> | ohmyorch-planner |
| 3 | plan-handoff | <pass/fail> | <detail> | ohmyorch-planner |
| 4 | implementation | <pass/fail> | <detail> | ohmyorch-implementer |
| 5 | review | <pass/fail> | <detail> | ohmyorch-reviewer |
| 6 | testing | <pass/fail> | <detail> | ohmyorch-tester |
| 7 | acceptance | <pass/fail> | <detail> | ohmyorch-product-manager |

## Resume

First incomplete gate: <gate-name / none — archive-eligible>
Next owner: <role>

<!-- BEGIN AUTHORED: blockers -->
## Blockers

None.
<!-- END AUTHORED: blockers -->
