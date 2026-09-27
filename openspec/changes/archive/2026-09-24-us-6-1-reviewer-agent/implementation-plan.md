# Implementation Plan — us-6-1-reviewer-agent

Story: US-6.1
Change: us-6-1-reviewer-agent

## Selected Story

US-6.1 — Create Reviewer Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-6.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-6.1
- `specs/independent-review/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/reviewer.md`.
2. Create `.claude/skills/review-feature/SKILL.md`.
3. Define `review.md` schema.
4. Integrate `/opsx:verify` into review flow.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/reviewer.md` | Scenario: Reviewer does not repair product code |
| 1.2 Create `.claude/skills/review-feature/SKILL.md` | Scenario: Review implementation against specification |
| 1.3 Define `review.md` schema | Scenario: Produce actionable review findings |
| 1.4 Integrate `/opsx:verify` into review flow | Scenario: Review implementation against specification |

## Affected Files

- `.claude/agents/reviewer.md`
- `.claude/skills/review-feature/SKILL.md`
- `scripts/validate-review.sh`
- `scripts/fixtures/reviews/*/review.md`
- `SPEC-LOGS/README-EPIC-6.md` — the delivery record for EPIC-6

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Review implementation against specification — inspection: the Reviewer's required inputs are proposal, specs, design, tasks, plan, and the diff.
2. Scenario: Produce actionable review findings — a blocking review is well-formed with Requirement/Observed/Expected/Remediation and routes back; an incomplete one is rejected.
3. Scenario: Reviewer does not repair product code — the Reviewer's hook blocks product-code writes.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-5

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
