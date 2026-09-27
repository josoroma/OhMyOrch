# Implementation Plan — us-5-1-implementer-agent

Story: US-5.1
Change: us-5-1-implementer-agent

## Selected Story

US-5.1 — Create Implementer Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-5.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-5.1
- `specs/implementation-scope/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/implementer.md`.
2. Define allowed write scope.
3. Define required handoff to Reviewer.
4. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/implementer.md` | Scenario: Implement from OpenSpec tasks |
| 1.2 Define allowed write scope | Scenario: Scope expansion is prohibited |
| 1.3 Define required handoff to Reviewer | Scenario: Implementer cannot approve itself |

## Affected Files

- `.claude/agents/implementer.md`
- `scripts/check-write-scope.sh`
- `scripts/check-scope.sh`
- `scripts/test-write-scope.sh`
- `SPEC-LOGS/README-EPIC-5.md` — the delivery record for EPIC-5

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Implement from OpenSpec tasks — inspection: tasks are ticked only when complete and validation runs before completion.
2. Scenario: Scope expansion is prohibited — unrelated work becomes follow-up, and check-scope.sh reports an unpredicted file.
3. Scenario: Implementer cannot approve itself — the Implementer's hook blocks it from writing review.md or test-report.md.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-4

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
