# Proposal — US-10.1: Enforce Definition of Done

Story: US-10.1
Epic: EPIC-10 — Completion and Archival

> Backfilled record (2026-09-24). The work was delivered during EPIC-10; its execution log
> is `SPEC-LOGS/README-EPIC-10.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want an explicit completion gate, so that only accepted changes are archived.

## What Changes

- Implement completion-gate check.
- Document `/opsx:archive` usage.
- Update SPECS.md story state to DONE only after successful completion.

## Capabilities

### New Capabilities

- `completion-gate`: Enforce Definition of Done — the 2 acceptance scenario(s) of US-10.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-10.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `scripts/completion-gate.sh`
- `scripts/validate-verification.sh`
- `scripts/guard-story-done.sh`
- `scripts/test-completion.sh`
- `scripts/templates/completion.md`
- `scripts/fixtures/completion/*/completion.md`

Source:
- PRD.md sections 14 and FR-010
