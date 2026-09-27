# Proposal — US-11.1: Publish Team README

Story: US-11.1
Epic: EPIC-11 — Harness Documentation and Adoption

> Backfilled record (2026-09-24). The work was delivered during EPIC-11; its execution log
> is `SPEC-LOGS/README-EPIC-11.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a new team member, I want a concise operational README, so that I know how to install, ingest requirements, start work, resume work, review, test, and archive changes.

## What Changes

- Write installation section.
- Write role model.
- Write command cookbook.
- Write greenfield-project workflow.
- Write brownfield codebase-analysis and product-generation workflow.
- Document `/analyze-codebase`, `/generate-prd`, and CODEBASE-aware `/ingest-spec`.
- Write recovery/resume workflow.

## Capabilities

### New Capabilities

- `harness-documentation`: Publish Team README — the 3 acceptance scenario(s) of US-11.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-11.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `README.md`
- `scripts/README.md`
- `SPEC-LOGS/README-EPIC-*.md`

Source:
- PRD.md initial delivery scope
