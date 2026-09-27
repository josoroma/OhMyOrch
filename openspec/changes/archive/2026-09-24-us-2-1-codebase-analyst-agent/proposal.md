# Proposal — US-2.1: Create Codebase Analyst Agent

Story: US-2.1
Epic: EPIC-2 — Codebase Understanding and Product Specification

> Backfilled record (2026-09-24). The work was delivered during EPIC-2; its execution log
> is `SPEC-LOGS/README-EPIC-2.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As an Engineering Lead, I want a Codebase Analyst agent, so that an existing repository can be understood once and its current-state architecture can be reused by later agents.

## What Changes

- Create `.claude/agents/codebase-analyst.md`.
- Define repository read boundaries and prohibit product-code edits.
- Define evidence and unknown-handling rules.
- Define the `CODEBASE.md` schema.

## Capabilities

### New Capabilities

- `codebase-analyst`: Create Codebase Analyst Agent — the 3 acceptance scenario(s) of US-2.1.

### Modified Capabilities

- None.

## Out of Scope

- US-2.2 — Create Analyze Codebase Skill (its own change)
- US-2.3 — Create Product Specifier Agent (its own change)
- US-2.4 — Create Generate PRD Skill (its own change)
- US-2.5 — Create Spec Ingestor Agent (its own change)
- US-2.6 — Create Ingest Spec Skill (its own change)
- US-2.7 — Validate Product Artifacts and Context (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-2.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/codebase-analyst.md`

Source:
- PRD.md sections 5 and 6
- PRD.md FR-013 through FR-018
