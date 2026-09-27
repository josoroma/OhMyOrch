# Proposal — US-5.1: Create Implementer Agent

Story: US-5.1
Epic: EPIC-5 — Implementation

> Backfilled record (2026-09-24). The work was delivered during EPIC-5; its execution log
> is `SPEC-LOGS/README-EPIC-5.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want a dedicated Implementer, so that source changes remain bounded by the approved specification.

## What Changes

- Create `.claude/agents/implementer.md`.
- Define allowed write scope.
- Define required handoff to Reviewer.

## Capabilities

### New Capabilities

- `implementation-scope`: Create Implementer Agent — the 3 acceptance scenario(s) of US-5.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-5.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/implementer.md`
- `scripts/check-write-scope.sh`
- `scripts/check-scope.sh`
- `scripts/test-write-scope.sh`

Source:
- PRD.md sections 5 and 7
