# Proposal — US-13.3: Document Every Artifact Handoff Between Roles

Story: US-13.3
Epic: EPIC-13 — Backlog Navigation and Structure

## Why

README.md §19 explains how the plan reaches the Implementer, but the plan is only one
of five handoffs. A reader still cannot see how the proposal reaches the Planner, how
the implementation reaches the Reviewer, how the review reaches the Tester, or how the
acceptance evidence reaches the Product Manager's archive decision.

Every one of those is the same mechanism: a role writes an artifact into the change
directory, the next role reads it, and a gate blocks the next role until the artifact
exists. Documenting only the plan leaves the reader to guess the rest.

## What Changes

- **README.md §19** gains a subsection covering every artifact handoff: the artifact,
  the role that writes it, the role that reads it, and the gate that enforces it.
- **README.md §19** gains a diagram of the handoffs, showing the change directory as
  the medium.
- **scripts/test-guards.sh** gains regression cases for the new explanation.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `harness-documentation`: adds one requirement — README explains every artifact
  handoff between roles, with a diagram and the gate on each handoff.

## Out of Scope

- Changing any handoff, gate, or agent. This change documents what exists.
- Replacing the plan-handoff subsection. It stays; the new subsection generalises it.

## Impact

- `README.md` (§19)
- `scripts/test-guards.sh` (regression cases)

Source:
- Human Product Manager decision, 2026-09-26
