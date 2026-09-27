# Proposal — US-8.1: Define Team Responsibility Rules

Story: US-8.1
Epic: EPIC-8 — Workflow Rules and Mechanical Gates

> Backfilled record (2026-09-24). The work was delivered during EPIC-8; its execution log
> is `SPEC-LOGS/README-EPIC-8.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As an Engineering Lead, I want explicit repository-level rules, so that each agent consistently stays within its role.

## What Changes

- Create `team-responsibilities.md`.
- Create `codebase-context.md`.
- Create `openspec.md`.
- Create `gherkin.md`.
- Create `testing.md`.
- Create `specification-ingestion.md`.

## Capabilities

### New Capabilities

- `team-rules`: Define Team Responsibility Rules — the 1 acceptance scenario(s) of US-8.1.

### Modified Capabilities

- None.

## Out of Scope

- US-8.2 — Add Workflow Hooks (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-8.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/rules/*.md`

Source:
- PRD.md sections 6 and 7
