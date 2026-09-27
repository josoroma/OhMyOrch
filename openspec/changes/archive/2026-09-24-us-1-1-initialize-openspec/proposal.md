# Proposal — US-1.1: Initialize OpenSpec for Claude Code

Story: US-1.1
Epic: EPIC-1 — Harness Bootstrap

> Backfilled record (2026-09-24). The work was delivered during EPIC-1; its execution log
> is `SPEC-LOGS/README-EPIC-1.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want OpenSpec initialized for Claude Code, so that each product change follows a consistent specification workflow.

## What Changes

- Document OpenSpec installation command.
- Document `openspec init --tools claude`.
- Configure a custom OpenSpec workflow profile that includes `verify`, or document the exact equivalent supported by the installed OpenSpec version.
- Add `openspec/config.yaml` project guidance.

## Capabilities

### New Capabilities

- `openspec-integration`: Initialize OpenSpec for Claude Code — the 2 acceptance scenario(s) of US-1.1.

### Modified Capabilities

- None.

## Out of Scope

- US-1.2 — Create Harness Repository Structure (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-1.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `openspec/config.yaml`
- `.claude/commands/opsx/*.md`
- `.claude/skills/openspec-*/SKILL.md`
- `README.md` (sections 1-3)

Source:
- PRD.md sections 8 and 11
