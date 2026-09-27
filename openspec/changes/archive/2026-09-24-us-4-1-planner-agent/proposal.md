# Proposal — US-4.1: Create Planner Agent

Story: US-4.1
Epic: EPIC-4 — Planning

> Backfilled record (2026-09-24). The work was delivered during EPIC-4; its execution log
> is `SPEC-LOGS/README-EPIC-4.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As an Implementer, I want a dedicated Planner, so that implementation starts from an explicit, repository-aware handoff.

## What Changes

- Create `.claude/agents/planner.md`.
- Create `.claude/skills/plan-feature/SKILL.md`.
- Define `implementation-plan.md` template.

## Capabilities

### New Capabilities

- `planning-handoff`: Create Planner Agent — the 2 acceptance scenario(s) of US-4.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-4.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/planner.md`
- `.claude/skills/plan-feature/SKILL.md`
- `scripts/templates/implementation-plan.md`
- `scripts/validate-implementation-plan.sh`
- `scripts/fixtures/plans/*/implementation-plan.md`

Source:
- PRD.md FR-007
