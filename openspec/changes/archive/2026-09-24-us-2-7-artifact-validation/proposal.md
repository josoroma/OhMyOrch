# Proposal — US-2.7: Validate Product Artifacts and Context

Story: US-2.7
Epic: EPIC-2 — Codebase Understanding and Product Specification

> Backfilled record (2026-09-24). The work was delivered during EPIC-2; its execution log
> is `SPEC-LOGS/README-EPIC-2.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want automated specification and context validation, so that malformed stories or ignored brownfield context cannot quietly enter implementation.

## What Changes

- Define `CODEBASE.md` validation contract.
- Define `PRD.md` context-consumption validation.
- Define `SPECS.md` readiness validation contract.
- Add hook or validation-script integration.
- Make validation failures actionable.

## Capabilities

### New Capabilities

- `artifact-validation`: Validate Product Artifacts and Context — the 5 acceptance scenario(s) of US-2.7.

### Modified Capabilities

- None.

## Out of Scope

- US-2.1 — Create Codebase Analyst Agent (its own change)
- US-2.2 — Create Analyze Codebase Skill (its own change)
- US-2.3 — Create Product Specifier Agent (its own change)
- US-2.4 — Create Generate PRD Skill (its own change)
- US-2.5 — Create Spec Ingestor Agent (its own change)
- US-2.6 — Create Ingest Spec Skill (its own change)
- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-2.7 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `scripts/validate-product-artifacts.sh`
- `scripts/fixtures/valid/*.md`
- `scripts/fixtures/invalid/*.md`
- `scripts/test-guards.sh` (context-marker cases)
- `.claude/settings.json` (PostToolUse hook)

Source:
- PRD.md FR-003, FR-004, FR-014, and FR-017
