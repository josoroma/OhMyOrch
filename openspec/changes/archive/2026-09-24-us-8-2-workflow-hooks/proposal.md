# Proposal — US-8.2: Add Workflow Hooks

Story: US-8.2
Epic: EPIC-8 — Workflow Rules and Mechanical Gates

> Backfilled record (2026-09-24). The work was delivered during EPIC-8; its execution log
> is `SPEC-LOGS/README-EPIC-8.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want mechanical workflow guards, so that critical gates do not rely exclusively on prompt compliance.

## What Changes

- Define `.claude/settings.json` hook configuration.
- Add PRD/SPECS CODEBASE-context preflight guards.
- Define portable hook scripts or project-adaptation strategy.
- Add archive gate validation.

## Capabilities

### New Capabilities

- `workflow-guards`: Add Workflow Hooks — the 6 acceptance scenario(s) of US-8.2.

### Modified Capabilities

- None.

## Out of Scope

- US-8.1 — Define Team Responsibility Rules (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-8.2 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/settings.json`
- `scripts/guard-planning-handoff.sh`
- `scripts/guard-context-preflight.sh`
- `scripts/guard-archive.sh`
- `scripts/run-project-validation.sh`
- `scripts/test-guards.sh`

Source:
- PRD.md NFR-002 and FR-010
