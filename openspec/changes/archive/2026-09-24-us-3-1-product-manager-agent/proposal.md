# Proposal — US-3.1: Create Product Manager Agent

Story: US-3.1
Epic: EPIC-3 — Product Manager Orchestration

> Backfilled record (2026-09-24). The work was delivered during EPIC-3; its execution log
> is `SPEC-LOGS/README-EPIC-3.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Human Product Manager, I want a Product Manager agent to orchestrate specialized agents, so that work progresses through controlled gates rather than autonomous coding.

## What Changes

- Create `.claude/agents/product-manager.md`.
- Define story-selection rules.
- Define state-transition rules.
- Define completion gate.

## Capabilities

### New Capabilities

- `product-manager`: Create Product Manager Agent — the 3 acceptance scenario(s) of US-3.1.

### Modified Capabilities

- None.

## Out of Scope

- US-3.2 — Create Product Iteration Skill (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-3.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/product-manager.md`

Source:
- PRD.md sections 5, 7, 12, 13, and 14
