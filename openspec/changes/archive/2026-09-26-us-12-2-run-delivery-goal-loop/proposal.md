# Proposal — US-12.2: Run the Delivery Goal Loop

Story: US-12.2
Epic: EPIC-12 — Goal-Driven Delivery Orchestration

## Why

As a Product Manager, I want one command that keeps working a delivery goal until it
is done or needs me, so that an epic, story, or task is planned, implemented, reviewed,
tested, and archived without manual stage-by-stage prompting (PRD.md FR-019).

US-12.1 made the next action derivable from repository state (`scripts/delivery.sh
next`). Nothing yet *runs* that action repeatedly, and nothing stops the main session
from ending its turn while work remains. A Claude Code session stops whenever the model
decides it is finished. A goal loop therefore needs a mechanical `Stop` gate, not a
prompt instruction.

## What Changes

- Create `.claude/skills/deliver/SKILL.md`: the `/deliver <target>` orchestrator. It
  records the goal, then repeatedly derives the next action and delegates it to the
  owning role until the goal is complete or escalated.
- Create `.claude/rules/delivery-loop.md`: the durable rules of the loop (who does
  what, when it stops, what it must never do).
- Create `scripts/guard-delivery-loop.sh` and wire it into `.claude/settings.json`:
  - as a `Stop` hook, it blocks the main session from stopping while an ACTIVE goal has
    a non-escalating next action. It allows the stop and records `BLOCKED` on
    escalation or on lack of progress, and `COMPLETE` when every story is `DONE`;
  - as a `PreToolUse` hook on `Write|Edit|MultiEdit`, it blocks the main session (the
    orchestrator) from authoring `review.md` or `test-report.md` while a goal is ACTIVE.
- Add `delivery.sh block --reason <text>`, which records the goal as `BLOCKED`. This is
  the only change to US-12.1's script.
- Add a goal-driven delivery section to `.claude/agents/product-manager.md`.
- Extend `scripts/test-delivery.sh` with Stop-hook, write-guard, and archive-guard cases.

## Capabilities

### New Capabilities

- `delivery-loop`: running a recorded delivery goal to completion or escalation under a
  `Stop` gate. Covers the 6 acceptance scenarios of US-12.2.

### Modified Capabilities

- None. `delivery-target` (US-12.1) gains a `block` subcommand. That subcommand is
  consumed only by this capability, and it changes none of the `delivery-target`
  requirements.

## Out of Scope

- US-12.3: README and index documentation for the orchestrator.
- Changing any gate, validator, or the archive guard. The loop must be *unable* to
  bypass them; it does not get its own bypass.
- Running several changes concurrently. The loop keeps US-12.1's one-active-change rule.
- Resolving product ambiguity. Escalation halts the loop and hands the decision to the
  human Product Manager.

## Impact

- `.claude/skills/deliver/SKILL.md` (new)
- `.claude/rules/delivery-loop.md` (new)
- `scripts/guard-delivery-loop.sh` (new)
- `scripts/delivery.sh` (new `block` subcommand)
- `scripts/test-delivery.sh` (new cases)
- `.claude/agents/product-manager.md` (new section)
- `.claude/settings.json` (`Stop` hook, one `PreToolUse` entry, allow-list entries)

Source:
- PRD.md FR-019
- Human Product Manager decision, 2026-09-24
