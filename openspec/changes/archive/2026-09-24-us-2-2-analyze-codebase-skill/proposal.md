# Proposal — US-2.2: Create Analyze Codebase Skill

Story: US-2.2
Epic: EPIC-2 — Codebase Understanding and Product Specification

> Backfilled record (2026-09-24). The work was delivered during EPIC-2; its execution log
> is `SPEC-LOGS/README-EPIC-2.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want a reusable codebase-analysis command, so that brownfield projects can establish durable technical context before product artifacts are generated.

## What Changes

- Create `.claude/skills/analyze-codebase/SKILL.md`.
- Define codebase-detection guidance.
- Define snapshot metadata and evidence-path format.
- Define refresh behavior.

## Capabilities

### New Capabilities

- `codebase-analysis`: Create Analyze Codebase Skill — the 4 acceptance scenario(s) of US-2.2.

### Modified Capabilities

- None.

## Out of Scope

- US-2.1 — Create Codebase Analyst Agent (its own change)
- US-2.3 — Create Product Specifier Agent (its own change)
- US-2.4 — Create Generate PRD Skill (its own change)
- US-2.5 — Create Spec Ingestor Agent (its own change)
- US-2.6 — Create Ingest Spec Skill (its own change)
- US-2.7 — Validate Product Artifacts and Context (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-2.2 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/skills/analyze-codebase/SKILL.md`

Source:
- PRD.md FR-013, FR-014, and FR-017
