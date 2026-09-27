# Implementation Plan — us-8-2-workflow-hooks

Story: US-8.2
Change: us-8-2-workflow-hooks

## Selected Story

US-8.2 — Add Workflow Hooks. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-8.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-8.2
- `specs/workflow-guards/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Define `.claude/settings.json` hook configuration.
2. Add PRD/SPECS CODEBASE-context preflight guards.
3. Define portable hook scripts or project-adaptation strategy.
4. Add archive gate validation.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Define `.claude/settings.json` hook configuration | Scenario: Prevent source implementation before planning handoff |
| 1.2 Add PRD/SPECS CODEBASE-context preflight guards | Scenario: Require CODEBASE context before PRD generation |
| 1.3 Define portable hook scripts or project-adaptation strategy | Scenario: Validate modified implementation |
| 1.4 Add archive gate validation | Scenario: Prevent premature archive |

## Affected Files

- `.claude/settings.json`
- `scripts/guard-planning-handoff.sh`
- `scripts/guard-context-preflight.sh`
- `scripts/guard-archive.sh`
- `scripts/run-project-validation.sh`
- `scripts/test-guards.sh`
- `SPEC-LOGS/README-EPIC-8.md` — the delivery record for EPIC-8

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Prevent source implementation before planning handoff — product-code writes are rejected until implementation-plan.md exists.
2. Scenario: Prevent premature archive — archival is rejected with blocking review findings or failing acceptance tests.
3. Scenario: Require CODEBASE context before PRD generation — PRD.md generation is guarded: stale context blocks, current context passes, missing marker is rejected.
4. Scenario: Require CODEBASE context before SPECS generation — SPECS.md generation is guarded the same way, including the post-write marker check.
5. Scenario: Detect missing brownfield analysis — a brownfield repository without CODEBASE.md requires analysis or a recorded skip.
6. Scenario: Validate modified implementation — configured fast validation runs after a product-code write and reports failure.

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
