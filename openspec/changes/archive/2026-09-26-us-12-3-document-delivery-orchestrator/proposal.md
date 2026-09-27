# Proposal — US-12.3: Document the Delivery Orchestrator

Story: US-12.3
Epic: EPIC-12 — Goal-Driven Delivery Orchestration

## Why

As a new team member, I want the delivery orchestrator documented alongside the rest
of the harness, so that I know how to hand the harness an epic, story, or task and how
the loop stops and resumes (PRD.md FR-019).

US-12.1 and US-12.2 delivered `scripts/delivery.sh`, `scripts/guard-delivery-loop.sh`,
the `/deliver` skill, and the `delivery-loop` rule. The operational handbook and the
indexes do not yet mention any of them. A new team member reading `README.md` today
would find only the one-story `/product-iteration` flow.

## What Changes

- Add a goal-driven delivery section to `README.md`. It covers the delivery command for
  each target kind, every way the loop stops, and how an interrupted goal resumes. It
  also brings the cookbook, the script inventory, the guard table, and the suite
  listing up to date.
- Reference the orchestrator in `CLAUDE.md`, `.claude/rules/README.md`,
  `.claude/agents/README.md`, and `scripts/README.md`.
- Write `SPEC-LOGS/README-EPIC-12.md`, the per-epic delivery record.
- Tighten one regression assertion in `scripts/test-delivery.sh`: "1 stop attempts"
  must be absent. This was review observation O-1 from US-12.2, carried here because
  that change was already archived.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `harness-documentation`: adds the two US-12.3 requirements (README explains
  goal-driven delivery; contracts and indexes list the orchestrator).

## Out of Scope

- Any behavior change to `delivery.sh`, `guard-delivery-loop.sh`, or any gate.
- Documentation of epics other than EPIC-12, beyond updating shared tables (suite
  counts, script inventory) so they stay accurate.

## Impact

- `README.md`, `CLAUDE.md`, `.claude/rules/README.md`, `.claude/agents/README.md`,
  `scripts/README.md` (edits)
- `SPEC-LOGS/README-EPIC-12.md` (new)
- `scripts/test-delivery.sh` (one assertion)

Source:
- PRD.md FR-019
- Human Product Manager decision, 2026-09-24
