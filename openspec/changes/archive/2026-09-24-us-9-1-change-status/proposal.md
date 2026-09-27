# Proposal — US-9.1: Persist Change Status

Story: US-9.1
Epic: EPIC-9 — Durable Workflow State

> Backfilled record (2026-09-24). The work was delivered during EPIC-9; its execution log
> is `SPEC-LOGS/README-EPIC-9.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want active change status persisted, so that a new session can resume from the correct gate.

## What Changes

- Define `status.md` format.
- Add status updates to orchestration skill.
- Add resume logic.

## Capabilities

### New Capabilities

- `workflow-state`: Persist Change Status — the 2 acceptance scenario(s) of US-9.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-9.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `scripts/status.sh`
- `scripts/validate-status.sh`
- `scripts/test-status.sh`
- `scripts/templates/status.md`
- `scripts/fixtures/status/*/status.md`

Source:
- PRD.md FR-011 and NFR-003
