# Completion Gate — <change-id>

<!--
US-10.1 completion record. Evaluates the four conditions the harness requires
before a change may be archived, and records the evidence for each.

Written by scripts/completion-gate.sh --change <id> --record. The four rows are
DERIVED from the repository and must not be hand-edited; the Notes section
between the AUTHORED markers is preserved across refreshes.

Validate before relying on it:
  scripts/validate-verification.sh --verification <path> --change <change-id>
-->

| Field | Value |
|---|---|
| Story | US-<n>.<m> |
| Change | <change-id> |
| Verdict | <eligible / not-eligible> |
| Evaluated | <YYYY-MM-DD> |
| Derived from | `scripts/completion-gate.sh` |

## Conditions

| # | Condition | Status | Evidence | Source |
|---|---|---|---|---|
| 1 | All required tasks complete | <pass/fail> | <detail> | `tasks.md` |
| 2 | Review has no blocking findings | <pass/fail> | <detail> | `review.md` |
| 3 | All required acceptance criteria pass | <pass/fail> | <detail> | `test-report.md` |
| 4 | OpenSpec verification has no blocking mismatch | <pass/fail> | <detail> | `openspec validate` |

## Verdict

<eligible / not-eligible — with the first failing condition named>

<!-- BEGIN AUTHORED: notes -->
## Notes

None.
<!-- END AUTHORED: notes -->
