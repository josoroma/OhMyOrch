# Proposal — US-7.1: Create Tester Agent

Story: US-7.1
Epic: EPIC-7 — Independent Acceptance Testing

> Backfilled record (2026-09-24). The work was delivered during EPIC-7; its execution log
> is `SPEC-LOGS/README-EPIC-7.md`. This change records that delivery in OpenSpec form so the canonical
> specs and the per-story audit trail exist (NFR-001, NFR-004).

## Why

As a Product Manager, I want an independent Tester, so that acceptance is based on observable evidence rather than implementation claims.

## What Changes

- Create `.claude/agents/tester.md`.
- Create `.claude/skills/test-feature/SKILL.md`.
- Define `test-report.md` schema.

## Capabilities

### New Capabilities

- `acceptance-testing`: Create Tester Agent — the 3 acceptance scenario(s) of US-7.1.

### Modified Capabilities

- None.

## Out of Scope

- Any externally observable behavior not stated in the SPECS.md acceptance criteria for US-7.1 (BR-001).
- Stories in other epics; each is its own bounded change (BR-003).

## Impact

- `.claude/agents/tester.md`
- `.claude/skills/test-feature/SKILL.md`
- `scripts/validate-test-report.sh`
- `scripts/fixtures/test-reports/*/test-report.md`
- `scripts/check-frontmatter.js`

Source:
- PRD.md FR-009
