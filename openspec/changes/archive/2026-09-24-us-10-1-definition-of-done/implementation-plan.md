# Implementation Plan — us-10-1-definition-of-done

Story: US-10.1
Change: us-10-1-definition-of-done

## Selected Story

US-10.1 — Enforce Definition of Done. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-10.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-10.1
- `specs/completion-gate/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Implement completion-gate check.
2. Document `/opsx:archive` usage.
3. Update SPECS.md story state to DONE only after successful completion.
4. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Implement completion-gate check | Scenario: Change is not eligible for archive |
| 1.2 Document `/opsx:archive` usage | Scenario: Change is eligible for archive |
| 1.3 Update SPECS.md story state to DONE only after successful completion | Scenario: Change is eligible for archive |

## Affected Files

- `scripts/completion-gate.sh`
- `scripts/validate-verification.sh`
- `scripts/guard-story-done.sh`
- `scripts/test-completion.sh`
- `scripts/templates/completion.md`
- `scripts/fixtures/completion/*/completion.md`
- `SPEC-LOGS/README-EPIC-10.md` — the delivery record for EPIC-10

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Change is eligible for archive — with every condition satisfied the change is eligible and the archive guard allows it.
2. Scenario: Change is not eligible for archive — each unmet condition rejects archival: task, review, acceptance, verification.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-6
- EPIC-7
- EPIC-8
- EPIC-9

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
