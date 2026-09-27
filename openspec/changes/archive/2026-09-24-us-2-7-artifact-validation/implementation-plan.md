# Implementation Plan — us-2-7-artifact-validation

Story: US-2.7
Change: us-2-7-artifact-validation

## Selected Story

US-2.7 — Validate Product Artifacts and Context. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.7
- `specs/artifact-validation/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Define `CODEBASE.md` validation contract.
2. Define `PRD.md` context-consumption validation.
3. Define `SPECS.md` readiness validation contract.
4. Add hook or validation-script integration.
5. Make validation failures actionable.
6. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Define `CODEBASE.md` validation contract | Scenario: PRD generation acknowledges existing CODEBASE.md |
| 1.2 Define `PRD.md` context-consumption validation | Scenario: PRD generation acknowledges existing CODEBASE.md |
| 1.3 Define `SPECS.md` readiness validation contract | Scenario: Validate READY story acceptance criteria |
| 1.4 Add hook or validation-script integration | Scenario: SPECS generation acknowledges existing CODEBASE.md |
| 1.5 Make validation failures actionable | Scenario: Validate unique story identifiers |

## Affected Files

- `scripts/validate-product-artifacts.sh`
- `scripts/fixtures/valid/*.md`
- `scripts/fixtures/invalid/*.md`
- `scripts/test-guards.sh` (context-marker cases)
- `.claude/settings.json` (PostToolUse hook)
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Validate unique story identifiers — duplicate Epic and User Story identifiers are both rejected.
2. Scenario: Validate READY story acceptance criteria — a READY story with an incomplete Given/When/Then scenario is rejected.
3. Scenario: Unsupported generated requirement cannot be ready — a READY story with no source reference is not treated as ready.
4. Scenario: PRD generation acknowledges existing CODEBASE.md — a PRD.md that does not record consuming an existing CODEBASE.md is rejected.
5. Scenario: SPECS generation acknowledges existing CODEBASE.md — a SPECS.md that does not record consuming an existing CODEBASE.md is rejected in CLI and hook mode.

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
