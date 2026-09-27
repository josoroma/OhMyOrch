# Implementation Plan — us-2-4-generate-prd-skill

Story: US-2.4
Change: us-2-4-generate-prd-skill

## Selected Story

US-2.4 — Create Generate PRD Skill. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.4
- `specs/prd-generation/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/skills/generate-prd/SKILL.md`.
2. Define input source handling.
3. Define create-vs-update behavior for PRD.md.
4. Define CODEBASE.md preflight behavior.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/skills/generate-prd/SKILL.md` | Scenario: Generate PRD after considering repository context |
| 1.2 Define input source handling | Scenario: Generate PRD after considering repository context |
| 1.3 Define create-vs-update behavior for PRD.md | Scenario: Generate PRD after considering repository context |
| 1.4 Define CODEBASE.md preflight behavior | Scenario: Existing codebase has not yet been analyzed |

## Affected Files

- `.claude/skills/generate-prd/SKILL.md`
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Generate PRD after considering repository context — inspection: the skill preflights CODEBASE.md and requires a CODEBASE Context marker.
2. Scenario: Existing codebase has not yet been analyzed — the missing-analysis guard blocks brownfield generation and accepts a recorded skip.
3. Scenario: Stale CODEBASE.md is surfaced — the stale-context condition is surfaced before CODEBASE.md is trusted.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-1

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
