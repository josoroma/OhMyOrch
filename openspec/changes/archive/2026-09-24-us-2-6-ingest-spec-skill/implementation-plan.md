# Implementation Plan — us-2-6-ingest-spec-skill

Story: US-2.6
Change: us-2-6-ingest-spec-skill

## Selected Story

US-2.6 — Create Ingest Spec Skill. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.6
- `specs/spec-ingestion/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/skills/ingest-spec/SKILL.md`.
2. Define create-vs-update behavior.
3. Define ingestion summary format.
4. Define CODEBASE.md preflight behavior.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/skills/ingest-spec/SKILL.md` | Scenario: Ingest product artifacts into SPECS.md |
| 1.2 Define create-vs-update behavior | Scenario: Incrementally merge a new source document |
| 1.3 Define ingestion summary format | Scenario: Ingest product artifacts into SPECS.md |
| 1.4 Define CODEBASE.md preflight behavior | Scenario: Existing codebase lacks CODEBASE.md |

## Affected Files

- `.claude/skills/ingest-spec/SKILL.md`
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Ingest product artifacts into SPECS.md — inspection: the skill delegates to the Spec Ingestor, provides CODEBASE.md, and returns an ingestion summary.
2. Scenario: Incrementally merge a new source document — inspection: incremental merges do not duplicate and flag changed or conflicting requirements.
3. Scenario: Existing codebase lacks CODEBASE.md — inspection: a brownfield repository without CODEBASE.md requires analysis or a recorded skip.

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
