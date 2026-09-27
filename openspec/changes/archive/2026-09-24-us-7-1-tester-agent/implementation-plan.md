# Implementation Plan — us-7-1-tester-agent

Story: US-7.1
Change: us-7-1-tester-agent

## Selected Story

US-7.1 — Create Tester Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-7.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-7.1
- `specs/acceptance-testing/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/tester.md`.
2. Create `.claude/skills/test-feature/SKILL.md`.
3. Define `test-report.md` schema.
4. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/tester.md` | Scenario: Failed acceptance returns to implementation |
| 1.2 Create `.claude/skills/test-feature/SKILL.md` | Scenario: Map acceptance criteria to executable evidence |
| 1.3 Define `test-report.md` schema | Scenario: Produce test report |

## Affected Files

- `.claude/agents/tester.md`
- `.claude/skills/test-feature/SKILL.md`
- `scripts/validate-test-report.sh`
- `scripts/fixtures/test-reports/*/test-report.md`
- `scripts/check-frontmatter.js`
- `SPEC-LOGS/README-EPIC-7.md` — the delivery record for EPIC-7

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Map acceptance criteria to executable evidence — a report must map criteria to evidence: the valid report passes, the evidence-free report is rejected.
2. Scenario: Produce test report — a well-formed report lists each criterion with PASS/FAIL and the evidence used.
3. Scenario: Failed acceptance returns to implementation — a failing criterion blocks acceptance and archival, and the Tester routes back through review.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-6

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
