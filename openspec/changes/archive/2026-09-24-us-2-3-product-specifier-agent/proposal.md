# Proposal — US-2.3: Create Product Specifier Agent

Story: US-2.3
Epic: EPIC-2 — Codebase Understanding and Product Specification

> Backfilled record (2026-09-24). The work was delivered during EPIC-2; its execution log
> is `SPEC-LOGS/README-EPIC-2.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want a Product Specifier agent, so that product source material and existing-system context can be turned into a PRD without confusing current implementation with desired behavior.

## What Changes

- Create `.claude/agents/product-specifier.md`.
- Define source precedence rules.
- Define current-state vs target-state language.
- Define ambiguity and conflict handling.

## Capabilities

### New Capabilities

- `product-specifier`: Create Product Specifier Agent — the 3 acceptance scenario(s) of US-2.3.

### Modified Capabilities

- None.

## Out of Scope

- US-2.1 — Create Codebase Analyst Agent (its own change)
- US-2.2 — Create Analyze Codebase Skill (its own change)
- US-2.4 — Create Generate PRD Skill (its own change)
- US-2.5 — Create Spec Ingestor Agent (its own change)
- US-2.6 — Create Ingest Spec Skill (its own change)
- US-2.7 — Validate Product Artifacts and Context (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-2.3 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/product-specifier.md`

Source:
- PRD.md sections 5 and 6
- PRD.md FR-015, FR-017, and FR-018
