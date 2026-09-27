# Proposal — US-2.4: Create Generate PRD Skill

Story: US-2.4
Epic: EPIC-2 — Codebase Understanding and Product Specification

> Backfilled record (2026-09-24). The work was delivered during EPIC-2; its execution log
> is `SPEC-LOGS/README-EPIC-2.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want a reusable PRD-generation command, so that project product intent can be normalized consistently for both greenfield and brownfield repositories.

## What Changes

- Create `.claude/skills/generate-prd/SKILL.md`.
- Define input source handling.
- Define create-vs-update behavior for PRD.md.
- Define CODEBASE.md preflight behavior.

## Capabilities

### New Capabilities

- `prd-generation`: Create Generate PRD Skill — the 3 acceptance scenario(s) of US-2.4.

### Modified Capabilities

- None.

## Out of Scope

- US-2.1 — Create Codebase Analyst Agent (its own change)
- US-2.2 — Create Analyze Codebase Skill (its own change)
- US-2.3 — Create Product Specifier Agent (its own change)
- US-2.5 — Create Spec Ingestor Agent (its own change)
- US-2.6 — Create Ingest Spec Skill (its own change)
- US-2.7 — Validate Product Artifacts and Context (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-2.4 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/skills/generate-prd/SKILL.md`

Source:
- PRD.md FR-015, FR-017, and FR-018
