# Proposal — US-13.2: Document the Orchestrator Loop and the Plan Handoff

Story: US-13.2
Epic: EPIC-13 — Backlog Navigation and Structure

## Why

`README.md` is 1,400 lines with 26 numbered sections and no table of contents, so a
reader cannot find a section without scrolling. It also explains the orchestrator in
prose (§18) but never shows the loop, never names which agent and skill runs each step,
and never explains how the plan reaches the Implementer.

The plan handoff is the part most easily misunderstood. It is not a message passed
between agents: the Planner writes `implementation-plan.md` into the change directory,
the Implementer reads that file, and `guard-planning-handoff.sh` blocks product-code
writes until the plan exists. A reader who assumes a conversational handoff will not
understand why an implementation write is rejected.

## What Changes

- **`README.md`** gains a table of contents near the top, listing every numbered
  section with a link.
- **`README.md`** gains a section explaining the orchestrator loop: the agents and
  skills at each step, a diagram of the loop, and a detailed diagram of the
  plan-to-implement handoff.
- **`scripts/test-guards.sh`** gains regression cases for the table of contents and the
  new section.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `harness-documentation`: adds two requirements — README opens with a table of
  contents, and README explains the orchestrator loop and the plan-to-implement
  handoff.

## Out of Scope

- Changing the loop, the agents, the skills, or the handoff. This change documents
  what exists. If the documentation reveals a defect, it is recorded as a finding.
- A table of contents for any file other than `README.md`.

## Impact

- `README.md` (table of contents, new section, section renumbering)
- `scripts/test-guards.sh` (regression cases)

Source:
- Human Product Manager decision, 2026-09-26
