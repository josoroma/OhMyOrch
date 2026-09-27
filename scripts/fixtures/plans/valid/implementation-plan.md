# Implementation Plan — add-codebase-analyst

Story: US-2.1
Change: add-codebase-analyst

## Selected Story

US-2.1 — Create Codebase Analyst Agent (Status: READY)

## OpenSpec Artifacts

- `proposal.md` — scope and non-goals for this change
- `specs/codebase-analysis/spec.md` — delta spec for the analyst capability
- `tasks.md` — the implementation checklist this plan elaborates

## Implementation Order

1. Author the agent definition.
2. Define read boundaries and evidence rules.
3. Define the CODEBASE.md schema.

## Task to Acceptance Mapping

| Task | Acceptance criterion |
|---|---|
| Author the agent definition | Scenario: Analyze an existing codebase |
| Define read boundaries | Scenario: Keep codebase claims evidence-backed |
| Define the schema | Scenario: Existing behavior is not promoted to product intent |

## Affected Files

- `.claude/agents/codebase-analyst.md` — new agent definition
- `.claude/agents/README.md` — role table update

## Test Strategy

Verification is by inspection, since this change adds no executable code:

1. Parse the frontmatter as YAML and confirm `name` and `description` are present.
2. Confirm the `tools` list omits `Write` and `Edit`.
3. Cross-check every `Given`/`When`/`Then` in the Spec Ingestor schema against the
   acceptance scenarios above.

Expected test artifacts: a scripted grep check plus a manual read-through.

## Dependencies

- US-2.2 depends on this change; nothing blocks it.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Agent prompt drifts from the spec | Medium | Map each rule to a scenario above |
| Frontmatter silently skipped by Claude Code | Low | Parse it in the test strategy |

## Open Questions

- None.
