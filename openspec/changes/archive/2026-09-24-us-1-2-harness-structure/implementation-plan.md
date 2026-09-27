# Implementation Plan — us-1-2-harness-structure

Story: US-1.2
Change: us-1-2-harness-structure

## Selected Story

US-1.2 — Create Harness Repository Structure. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-1.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-1.2
- `specs/harness-structure/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create top-level `CLAUDE.md` contract.
2. Create `.claude/agents/`.
3. Create `.claude/skills/`.
4. Create `.claude/rules/`.
5. Create `.claude/settings.json`.
6. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create top-level `CLAUDE.md` contract | Scenario: Required harness files exist |
| 1.2 Create `.claude/agents/` | Scenario: Required harness files exist |
| 1.3 Create `.claude/skills/` | Scenario: Required harness files exist |
| 1.4 Create `.claude/rules/` | Scenario: Required harness files exist |
| 1.5 Create `.claude/settings.json` | Scenario: Required harness files exist |

## Affected Files

- `CLAUDE.md`
- `.claude/agents/README.md`
- `.claude/rules/README.md`
- `.claude/settings.json`
- `.claude/settings.local.example.json`
- `.gitignore`
- `SPEC-LOGS/README-EPIC-1.md` — the delivery record for EPIC-1

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Required harness files exist — every required harness path exists at the repository root.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

None.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
