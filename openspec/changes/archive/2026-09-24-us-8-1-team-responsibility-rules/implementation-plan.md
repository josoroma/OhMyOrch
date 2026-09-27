# Implementation Plan — us-8-1-team-responsibility-rules

Story: US-8.1
Change: us-8-1-team-responsibility-rules

## Selected Story

US-8.1 — Define Team Responsibility Rules. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-8.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-8.1
- `specs/team-rules/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `team-responsibilities.md`.
2. Create `codebase-context.md`.
3. Create `openspec.md`.
4. Create `gherkin.md`.
5. Create `testing.md`.
6. Create `specification-ingestion.md`.
7. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `team-responsibilities.md` | Scenario: Responsibility rules are installed |
| 1.2 Create `codebase-context.md` | Scenario: Responsibility rules are installed |
| 1.3 Create `openspec.md` | Scenario: Responsibility rules are installed |
| 1.4 Create `gherkin.md` | Scenario: Responsibility rules are installed |
| 1.5 Create `testing.md` | Scenario: Responsibility rules are installed |
| 1.6 Create `specification-ingestion.md` | Scenario: Responsibility rules are installed |

## Affected Files

- `.claude/rules/*.md`
- `SPEC-LOGS/README-EPIC-8.md` — the delivery record for EPIC-8

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Responsibility rules are installed — all six rule files exist; the eight roles and the three prohibitions are defined.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-3 through EPIC-7

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
