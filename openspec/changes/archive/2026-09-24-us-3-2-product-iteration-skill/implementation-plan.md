# Implementation Plan — us-3-2-product-iteration-skill

Story: US-3.2
Change: us-3-2-product-iteration-skill

## Selected Story

US-3.2 — Create Product Iteration Skill. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-3.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-3.2
- `specs/product-iteration/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/skills/product-iteration/SKILL.md`.
2. Define fresh-start flow.
3. Define resume flow.
4. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/skills/product-iteration/SKILL.md` | Scenario: Start iteration from a story identifier |
| 1.2 Define fresh-start flow | Scenario: Start iteration from a story identifier |
| 1.3 Define resume flow | Scenario: Resume an existing iteration |

## Affected Files

- `.claude/skills/product-iteration/SKILL.md`
- `scripts/workflow-status.sh`
- `SPEC-LOGS/README-EPIC-3.md` — the delivery record for EPIC-3

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Start iteration from a story identifier — inspection: fresh start establishes one change and walks every role's gate in order.
2. Scenario: Resume an existing iteration — resume reads repository state and names the first incomplete gate.

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
