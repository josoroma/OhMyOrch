# Proposal — US-1.2: Create Harness Repository Structure

Story: US-1.2
Epic: EPIC-1 — Harness Bootstrap

> Backfilled record (2026-09-24). The work was delivered during EPIC-1; its execution log
> is `SPEC-LOGS/README-EPIC-1.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As an Engineering Lead, I want a predictable harness directory layout, so that every project exposes the same control surfaces.

## What Changes

- Create top-level `CLAUDE.md` contract.
- Create `.claude/agents/`.
- Create `.claude/skills/`.
- Create `.claude/rules/`.
- Create `.claude/settings.json`.

## Capabilities

### New Capabilities

- `harness-structure`: Create Harness Repository Structure — the 1 acceptance scenario(s) of US-1.2.

### Modified Capabilities

- None.

## Out of Scope

- US-1.1 — Initialize OpenSpec for Claude Code (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-1.2 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `CLAUDE.md`
- `.claude/agents/README.md`
- `.claude/rules/README.md`
- `.claude/settings.json`
- `.claude/settings.local.example.json`
- `.gitignore`

Source:
- PRD.md section 11
