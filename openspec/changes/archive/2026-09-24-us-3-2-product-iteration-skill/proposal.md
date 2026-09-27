# Proposal — US-3.2: Create Product Iteration Skill

Story: US-3.2
Epic: EPIC-3 — Product Manager Orchestration

> Backfilled record (2026-09-24). The work was delivered during EPIC-3; its execution log
> is `SPEC-LOGS/README-EPIC-3.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want one orchestration entry point, so that a selected story can move through the complete harness workflow.

## What Changes

- Create `.claude/skills/product-iteration/SKILL.md`.
- Define fresh-start flow.
- Define resume flow.

## Capabilities

### New Capabilities

- `product-iteration`: Create Product Iteration Skill — the 2 acceptance scenario(s) of US-3.2.

### Modified Capabilities

- None.

## Out of Scope

- US-3.1 — Create Product Manager Agent (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-3.2 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/skills/product-iteration/SKILL.md`
- `scripts/workflow-status.sh`

Source:
- PRD.md section 7
