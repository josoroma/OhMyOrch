# Implementation Plan — us-2-3-product-specifier-agent

Story: US-2.3
Change: us-2-3-product-specifier-agent

## Selected Story

US-2.3 — Create Product Specifier Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.3
- `specs/product-specifier/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/product-specifier.md`.
2. Define source precedence rules.
3. Define current-state vs target-state language.
4. Define ambiguity and conflict handling.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/product-specifier.md` | Scenario: Generate PRD with codebase context when available |
| 1.2 Define source precedence rules | Scenario: Generate PRD with codebase context when available |
| 1.3 Define current-state vs target-state language | Scenario: Product intent conflicts with current implementation |
| 1.4 Define ambiguity and conflict handling | Scenario: Product intent conflicts with current implementation |

## Affected Files

- `.claude/agents/product-specifier.md`
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Generate PRD with codebase context when available — the specifier is read-only and its preflight reads CODEBASE.md for capabilities, constraints, migration concerns, and gaps.
2. Scenario: Generate PRD for a greenfield project — inspection: greenfield generation must not invent a current architecture.
3. Scenario: Product intent conflicts with current implementation — inspection: product intent wins and the current-state difference is recorded as a gap.

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
