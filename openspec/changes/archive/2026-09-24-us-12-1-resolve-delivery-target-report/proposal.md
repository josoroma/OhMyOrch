# Proposal — US-12.1: Resolve a Delivery Target and Report the Next Action

Story: US-12.1
Epic: EPIC-12 — Goal-Driven Delivery Orchestration

## Why

As a Product Manager, I want an epic, story, or task resolved into ordered stories with a
derived next action, so that a delivery loop always knows what to do next from repository
state alone (PRD.md FR-019).

The harness can already move one story through its gates (`/product-iteration`), but a
human has to prompt every stage and has to split an epic into stories by hand. A loop
needs a deterministic answer to "what is the next action, and who owns it?" that is
computed from the repository, never from the transcript (BR-004, NFR-003).

## What Changes

- Create `scripts/delivery.sh` with subcommands `resolve`, `start`, `next`, `refresh`,
  `reopen`, and `stop`.
- Define the `openspec/delivery/goal.md` format: a derived story table plus an authored
  notes section preserved across refreshes.
- Map every workflow gate and completion condition to exactly one next action and owner.
- Add `scripts/test-delivery.sh`, a regression suite run in a throwaway copy.

## Capabilities

### New Capabilities

- `delivery-target`: resolving an epic, story, or task into ordered stories and deriving
  the next action for a delivery goal — the 6 acceptance scenarios of US-12.1.

### Modified Capabilities

- None.

## Out of Scope

- US-12.2 — the goal loop itself (skill, rule, Stop hook). This change only computes
  the next action; it does not run it.
- US-12.3 — documentation of the orchestrator.
- Changing any existing gate, validator, or guard. `delivery.sh` reads their verdicts
  and never recomputes them (one source of truth per verdict).
- Authoring review or acceptance verdicts. `reopen` preserves a failing artifact and
  appends remediation tasks; it never writes a new `review.md` or `test-report.md`.

## Impact

- `scripts/delivery.sh` (new)
- `scripts/test-delivery.sh` (new)
- `.claude/settings.json` (permission allow-list entries only)
- `.gitignore` (the per-machine `loop.state` counter file)

Source:
- PRD.md FR-019
- Human Product Manager decision, 2026-09-24
