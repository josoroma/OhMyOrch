# Proposal — US-12.4: Close the Delivery Loop Follow-Ups

Story: US-12.4
Epic: EPIC-12 — Goal-Driven Delivery Orchestration

## Why

US-12.2 and US-12.3 were approved with non-blocking observations. They were recorded
in `SPEC-LOGS/README-EPIC-12.md` §6 as follow-ups, and the human Product Manager has
scheduled them. Three are documentation accuracy, and one is a small behavior gap.

## What Changes

- **Stall-limit wording.** `README.md` §18 and `.claude/rules/delivery-loop.md` say the
  loop halts "across N stop attempts". The guard actually allows the stop on attempt
  N+1. Reword to "after N blocked stop attempts", and name the default and the override.
- **Two missing escalation causes.** `README.md` §18 lists example causes for the
  `escalate` stop. Add the two `derive_next` cases it omits: the gate reporter could not
  report, and an unmapped gate.
- **`delivery.sh stop` fallback.** `stop` calls `load_goal`, which exits non-zero when
  the recorded target no longer resolves. `block` already falls back to an in-place
  rewrite. Give `stop` the same fallback, so a halt is always recorded.
- **`scripts/README.md` archive-guard row.** It says the guard checks "workflow gate /
  US-8.2". It checks the completion conditions, and it is US-8.2 and US-10.1.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `delivery-target`: adds one requirement — `stop` records the halt when the target no
  longer resolves.
- `harness-documentation`: adds two requirements — the stall limit is described
  accurately, and every escalation cause is documented.

## Out of Scope

- Any change to the Stop hook's decision logic, the stall limit itself, or the gate
  chain. Only the wording and the `stop` fallback change.
- The `guard-archive.sh` behavior. Only its index row is corrected.

## Impact

- `README.md` (§18 wording and escalation causes)
- `.claude/rules/delivery-loop.md` (stall-limit wording)
- `scripts/delivery.sh` (`stop` fallback)
- `scripts/README.md` (archive-guard row)
- `scripts/test-delivery.sh` (one regression case)

Source:
- US-12.2 review observations O-1, O-2, O-3
- US-12.3 review observations O-1, O-2, O-3, O-4
- Human Product Manager decision, 2026-09-26
