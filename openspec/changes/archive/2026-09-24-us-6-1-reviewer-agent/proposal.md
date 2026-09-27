# Proposal — US-6.1: Create Reviewer Agent

Story: US-6.1
Epic: EPIC-6 — Independent Review

> Backfilled record (2026-09-24). The work was delivered during EPIC-6; its execution log
> is `SPEC-LOGS/README-EPIC-6.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want an independent Reviewer, so that implementation is evaluated against requirements rather than implementation intent.

## What Changes

- Create `.claude/agents/reviewer.md`.
- Create `.claude/skills/review-feature/SKILL.md`.
- Define `review.md` schema.
- Integrate `/opsx:verify` into review flow.

## Capabilities

### New Capabilities

- `independent-review`: Create Reviewer Agent — the 3 acceptance scenario(s) of US-6.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-6.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/reviewer.md`
- `.claude/skills/review-feature/SKILL.md`
- `scripts/validate-review.sh`
- `scripts/fixtures/reviews/*/review.md`

Source:
- PRD.md FR-008
