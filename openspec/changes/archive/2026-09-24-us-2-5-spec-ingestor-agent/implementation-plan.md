# Implementation Plan — us-2-5-spec-ingestor-agent

Story: US-2.5
Change: us-2-5-spec-ingestor-agent

## Selected Story

US-2.5 — Create Spec Ingestor Agent. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.5
- `specs/spec-ingestor/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/agents/spec-ingestor.md`.
2. Define read/write boundaries.
3. Define source-traceability rules.
4. Define CODEBASE.md consumption rules.
5. Define ambiguity and conflict handling.
6. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/agents/spec-ingestor.md` | Scenario: Convert product artifacts into structured requirements |
| 1.2 Define read/write boundaries | Scenario: Convert product artifacts into structured requirements |
| 1.3 Define source-traceability rules | Scenario: Conflicting source requirements are preserved |
| 1.4 Define CODEBASE.md consumption rules | Scenario: Consume CODEBASE.md when it exists |
| 1.5 Define ambiguity and conflict handling | Scenario: Missing product behavior is not invented |

## Affected Files

- `.claude/agents/spec-ingestor.md`
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Convert product artifacts into structured requirements — the ingestor is read-only by tool allowlist and defines an extraction method.
2. Scenario: Consume CODEBASE.md when it exists — inspection: the required preflight reads CODEBASE.md.
3. Scenario: Missing product behavior is not invented — inspection: an undefined success condition yields NEEDS CLARIFICATION with an Open Question.
4. Scenario: Conflicting source requirements are preserved — inspection: conflicting sources stay traceable and the story is BLOCKED.

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
