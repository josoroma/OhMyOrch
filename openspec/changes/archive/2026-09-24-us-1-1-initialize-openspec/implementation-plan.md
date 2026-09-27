# Implementation Plan — us-1-1-initialize-openspec

Story: US-1.1
Change: us-1-1-initialize-openspec

## Selected Story

US-1.1 — Initialize OpenSpec for Claude Code. Backfilled plan: it describes the delivery recorded in
`SPEC-LOGS/README-EPIC-1.md` so that each task traces to an acceptance scenario.

## OpenSpec Artifacts

- `proposal.md` — scope, out-of-scope list, and impact for US-1.1
- `specs/openspec-integration/spec.md` — delta spec; one requirement per acceptance scenario
- `tasks.md` — the checklist this plan orders

## Implementation Order

1. Document OpenSpec installation command.
2. Document `openspec init --tools claude`.
3. Configure a custom OpenSpec workflow profile that includes `verify`, or document the exact equivalent supported by the installed OpenSpec version.
4. Add `openspec/config.yaml` project guidance.
5. Record acceptance evidence for every scenario.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| 1.1 Document OpenSpec installation command | Scenario: Initialize OpenSpec in a project |
| 1.2 Document `openspec init --tools claude` | Scenario: Initialize OpenSpec in a project |
| 1.3 Configure a custom OpenSpec workflow profile that includes `verify`, or document the exact equivalent supported by the installed OpenSpec version | Scenario: Enable verification workflow |
| 1.4 Add `openspec/config.yaml` project guidance | Scenario: Initialize OpenSpec in a project |

## Affected Files

- `openspec/config.yaml`
- `.claude/commands/opsx/*.md`
- `.claude/skills/openspec-*/SKILL.md`
- `README.md` (sections 1-3)
- `SPEC-LOGS/README-EPIC-1.md` — the delivery record for EPIC-1

## Test Strategy

Each scenario is demonstrated by one executable check, recorded in `test-report.md`:

1. Scenario: Initialize OpenSpec in a project — OpenSpec project structure, Claude workflow files, and change creation observed.
2. Scenario: Enable verification workflow — the custom workflow profile includes verify, and its Claude command and skill are installed.

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
