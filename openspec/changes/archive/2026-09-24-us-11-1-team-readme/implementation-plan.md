# Implementation Plan — us-11-1-team-readme

Story: US-11.1
Change: us-11-1-team-readme

## Selected Story

US-11.1 — Publish Team README. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-11.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-11.1
- `specs/harness-documentation/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Write installation section.
2. Write role model.
3. Write command cookbook.
4. Write greenfield-project workflow.
5. Write brownfield codebase-analysis and product-generation workflow.
6. Document `/analyze-codebase`, `/generate-prd`, and CODEBASE-aware `/ingest-spec`.
7. Write recovery/resume workflow.
8. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Write installation section | Scenario: README explains installation |
| 1.2 Write role model | Scenario: README explains brownfield context and document-to-delivery flow |
| 1.3 Write command cookbook | Scenario: README explains brownfield context and document-to-delivery flow |
| 1.4 Write greenfield-project workflow | Scenario: README explains brownfield context and document-to-delivery flow |
| 1.5 Write brownfield codebase-analysis and product-generation workflow | Scenario: README explains brownfield context and document-to-delivery flow |
| 1.6 Document `/analyze-codebase`, `/generate-prd`, and CODEBASE-aware `/ingest-spec` | Scenario: README explains brownfield context and document-to-delivery flow |
| 1.7 Write recovery/resume workflow | Scenario: README explains resumption |

## Affected Files

- `README.md`
- `scripts/README.md`
- `SPEC-LOGS/README-EPIC-*.md`
- `SPEC-LOGS/README-EPIC-11.md` — the delivery record for EPIC-11

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: README explains installation — inspection: README explains OpenSpec install, init for Claude Code, and workflow confirmation.
2. Scenario: README explains brownfield context and document-to-delivery flow — inspection: README covers CODEBASE.md, PRD/SPECS generation, story selection, the opsx commands, and review/test loops.
3. Scenario: README explains resumption — inspection: README explains resumption from repository artifacts.

The harness is Markdown plus bash, so a check is either a regression-suite case, a
validator run against a fixture, or a `grep` inspection of the governing definition.

## Dependencies

Epic dependencies from SPECS.md:

- EPIC-1 through EPIC-10

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A definition drifts from its acceptance scenario | Medium | Each scenario is bound to a re-runnable check |
| A backfilled record overstates independent judgement | Medium | Review and test report are labelled as backfilled and cite only re-run evidence |

## Open Questions

- None.
