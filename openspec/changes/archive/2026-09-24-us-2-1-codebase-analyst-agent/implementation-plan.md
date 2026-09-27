# Implementation Plan — us-2-1-codebase-analyst-agent

Story: US-2.1
Change: us-2-1-codebase-analyst-agent

## Selected Story

US-2.1 — Create Codebase Analyst Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.1
- `specs/codebase-analyst/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/codebase-analyst.md`.
2. Define repository read boundaries and prohibit product-code edits.
3. Define evidence and unknown-handling rules.
4. Define the `CODEBASE.md` schema.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/codebase-analyst.md` | Scenario: Analyze an existing codebase |
| 1.2 Define repository read boundaries and prohibit product-code edits | Scenario: Analyze an existing codebase |
| 1.3 Define evidence and unknown-handling rules | Scenario: Keep codebase claims evidence-backed |
| 1.4 Define the `CODEBASE.md` schema | Scenario: Existing behavior is not promoted to product intent |

## Affected Files

- `.claude/agents/codebase-analyst.md`
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Analyze an existing codebase — the analyst is read-only by tool allowlist and its schema covers structure, runtime, entry points, architecture, data, integrations, tests, commands, conventions.
2. Scenario: Keep codebase claims evidence-backed — inspection: the evidence-or-unknown rule and the Unknowns section are present.
3. Scenario: Existing behavior is not promoted to product intent — inspection: existing behavior is described as current state, never as product intent.

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
