# Implementation Plan — us-9-1-change-status

Story: US-9.1
Change: us-9-1-change-status

## Selected Story

US-9.1 — Persist Change Status. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-9.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-9.1
- `specs/workflow-state/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Define `status.md` format.
2. Add status updates to orchestration skill.
3. Add resume logic.
4. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Define `status.md` format | Scenario: Persist workflow state |
| 1.2 Add status updates to orchestration skill | Scenario: Persist workflow state |
| 1.3 Add resume logic | Scenario: Resume after session restart |

## Affected Files

- `scripts/status.sh`
- `scripts/validate-status.sh`
- `scripts/test-status.sh`
- `scripts/templates/status.md`
- `scripts/fixtures/status/*/status.md`
- `SPEC-LOGS/README-EPIC-9.md` — the delivery record for EPIC-9

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Persist workflow state — status.md records state, owner, and blockers, and preserves blockers across refreshes.
2. Scenario: Resume after session restart — a new session reads status.md, names the first incomplete gate and owner, and detects staleness.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-3

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
