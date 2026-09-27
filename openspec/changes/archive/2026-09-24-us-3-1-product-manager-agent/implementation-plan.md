# Implementation Plan — us-3-1-product-manager-agent

Story: US-3.1
Change: us-3-1-product-manager-agent

## Selected Story

US-3.1 — Create Product Manager Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-3.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-3.1
- `specs/product-manager/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/product-manager.md`.
2. Define story-selection rules.
3. Define state-transition rules.
4. Define completion gate.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/product-manager.md` | Scenario: Select one manageable unit of work |
| 1.2 Define story-selection rules | Scenario: Select one manageable unit of work |
| 1.3 Define state-transition rules | Scenario: Do not treat the entire backlog as one OpenSpec change |
| 1.4 Define completion gate | Scenario: Product Manager owns archive decision |

## Affected Files

- `.claude/agents/product-manager.md`
- `SPEC-LOGS/README-EPIC-3.md` — the delivery record for EPIC-3

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Select one manageable unit of work — inspection: exactly one story is selected and the story-to-change mapping is recorded.
2. Scenario: Do not treat the entire backlog as one OpenSpec change — inspection: the backlog is never collapsed into one change.
3. Scenario: Product Manager owns archive decision — inspection: the archive decision runs the completion gate first.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-1
- EPIC-2

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
