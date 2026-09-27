# Implementation Plan — us-2-2-analyze-codebase-skill

Story: US-2.2
Change: us-2-2-analyze-codebase-skill

## Selected Story

US-2.2 — Create Analyze Codebase Skill. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-2.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-2.2
- `specs/codebase-analysis/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Create `.claude/skills/analyze-codebase/SKILL.md`.
2. Define codebase-detection guidance.
3. Define snapshot metadata and evidence-path format.
4. Define refresh behavior.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Create `.claude/skills/analyze-codebase/SKILL.md` | Scenario: Generate CODEBASE.md from an existing repository |
| 1.2 Define codebase-detection guidance | Scenario: Do not fabricate a brownfield context for a greenfield project |
| 1.3 Define snapshot metadata and evidence-path format | Scenario: CODEBASE.md uses a stable current-state schema |
| 1.4 Define refresh behavior | Scenario: Refresh stale codebase understanding |

## Affected Files

- `.claude/skills/analyze-codebase/SKILL.md`
- `SPEC-LOGS/README-EPIC-2.md` — the delivery record for EPIC-2

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Generate CODEBASE.md from an existing repository — inspection: the skill delegates to the Codebase Analyst and requires a revision and evidence paths.
2. Scenario: Do not fabricate a brownfield context for a greenfield project — inspection: greenfield reports no codebase and forbids a fabricated CODEBASE.md.
3. Scenario: Refresh stale codebase understanding — the skill defines staleness reconciliation, and the stale-revision guard case blocks.
4. Scenario: CODEBASE.md uses a stable current-state schema — the schema validator accepts the complete fixture and names the sections missing from the incomplete one.

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
