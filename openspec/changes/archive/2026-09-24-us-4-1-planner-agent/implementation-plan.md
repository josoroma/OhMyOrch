# Implementation Plan — us-4-1-planner-agent

Story: US-4.1
Change: us-4-1-planner-agent

## Selected Story

US-4.1 — Create Planner Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-4.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-4.1
- `specs/planning-handoff/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/planner.md`.
2. Create `.claude/skills/plan-feature/SKILL.md`.
3. Define `implementation-plan.md` template.
4. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/planner.md` | Scenario: Explore without modifying product code |
| 1.2 Create `.claude/skills/plan-feature/SKILL.md` | Scenario: Produce implementation plan |
| 1.3 Define `implementation-plan.md` template | Scenario: Produce implementation plan |

## Affected Files

- `.claude/agents/planner.md`
- `.claude/skills/plan-feature/SKILL.md`
- `scripts/templates/implementation-plan.md`
- `scripts/validate-implementation-plan.sh`
- `scripts/fixtures/plans/*/implementation-plan.md`
- `SPEC-LOGS/README-EPIC-4.md` — the delivery record for EPIC-4

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Explore without modifying product code — the Planner cannot modify product code: no Write/Edit tools, and the write-scope matrix blocks it.
2. Scenario: Produce implementation plan — this change's own implementation-plan.md satisfies the plan contract, and the invalid fixture is rejected.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-1
- EPIC-3

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
