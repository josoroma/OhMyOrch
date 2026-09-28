# Implementation Plan — <change-id>

Story: US-<n>.<m>
Change: <change-id>

<!--
Planner handoff template. Copy this file to
openspec/changes/<change-id>/implementation-plan.md and fill every section.

Rules:
- Every section must be present. Use "None identified." rather than deleting one,
  so a reader can tell "checked, found nothing" from "not considered".
- Scope claims are "likely", not certain: the Planner has not made the change.
  Cite the evidence for each one.
- Never invent product behavior or weaken an acceptance criterion. Record the
  concern under Open Questions instead.
- Validate before handing off:
    scripts/validate-implementation-plan.sh --plan <path> --story <story-id> --change <change-id>
-->

## Selected Story

<!-- The story id and title this change implements, and why this change is the
     one that delivers it. Exactly one story. -->

US-<n>.<m> — <title> (Status: READY)

## OpenSpec Artifacts

<!-- The artifacts read, with paths. planning cannot begin without them. -->

- `proposal.md` — <what it establishes>
- `specs/<path>/spec.md` — <the delta this change must satisfy>
- `tasks.md` — <the checklist elaborated below>
- `design.md` — <the chosen approach, when present>

## Implementation Order

<!-- What must exist before what, and what each step unblocks. -->

1. <step> — unblocks <what>
2. <step> — unblocks <what>

## Task to Acceptance Mapping

<!-- Every task from tasks.md, mapped to the acceptance scenario it satisfies.
     A task with no criterion is a finding, not something to invent around. -->

| Task | Acceptance criterion | Notes |
|---|---|---|
| <task from tasks.md> | Scenario: <scenario name> | <why this task serves it> |

## Affected Files

<!-- Likely files or modules, each with the evidence that led you there. -->

| Path | Expected change | Evidence |
|---|---|---|
| `<path>` | <what changes> | <how you determined this> |

## Test Strategy

<!-- How each acceptance criterion will be demonstrated. Name the tests, checks,
     or commands. If verification is by inspection, say so and say why. -->

<describe the approach>

Expected test artifacts: <paths or commands>

## Dependencies

<!-- Internal or external prerequisites, or "None identified." -->

- <dependency, or "None identified.">

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| <risk> | low/medium/high | low/medium/high | <action> |

## Open Questions

<!-- Questions requiring a Product Manager decision. Do not resolve them here. -->

- <question, or "None.">
