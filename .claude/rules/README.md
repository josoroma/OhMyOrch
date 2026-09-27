# Harness Workflow Rules

Durable project rules that Claude loads as context. They hold the always-on
constraints that apply to every session, independent of which agent is running.

## Index

| File | Governs | Source |
|---|---|---|
| `team-responsibilities.md` | The eight roles, their boundaries, and the three separation-of-duties prohibitions | US-8.1, BR-002 |
| `codebase-context.md` | Use of `CODEBASE.md` as evidence, not intent | BR-006, NFR-005 |
| `openspec.md` | The change lifecycle, artifacts, archival, status vocabulary | US-8.2, BR-004 |
| `gherkin.md` | Writing testable acceptance criteria | FR-003, BR-005 |
| `testing.md` | The Tester role and what acceptance evidence must contain | US-7.1, NFR-004 |
| `specification-ingestion.md` | Turning intent into a bounded, testable backlog | BR-001, BR-003, BR-005 |
| `delivery-loop.md` | Goal-driven delivery (`/deliver`): derived next action, role delegation, stop conditions, no gate exceptions | US-12.1, US-12.2, FR-019 |

## Rules versus gates

Rules and gates answer different questions and are both required.

- **Rules** (this directory) tell an agent what it should do. They are context.
- **Gates** (`scripts/`, `.claude/settings.json` hooks) determine what an agent
  *can* do. They are enforcement.

A rule that matters is backed by a gate, because prompt compliance is not a
guarantee. The mapping:

| Rule | Mechanical enforcement |
|---|---|
| Separation of duties (`team-responsibilities.md`) | `scripts/check-write-scope.sh` via `PreToolUse` on each writing agent |
| No implementation before planning (`openspec.md`) | `scripts/guard-planning-handoff.sh` via `PreToolUse` |
| CODEBASE context required (`codebase-context.md`) | `scripts/guard-context-preflight.sh` (`PreToolUse`) + `scripts/validate-product-artifacts.sh` (`PostToolUse`) |
| No premature archive (`openspec.md`) | `scripts/guard-archive.sh` via `PreToolUse` |
| DONE only after archival (`openspec.md`) | `scripts/guard-story-done.sh` via `PreToolUse` |
| Testable acceptance criteria (`gherkin.md`) | `scripts/validate-product-artifacts.sh` |
| Keep working while a goal is ACTIVE (`delivery-loop.md`) | `scripts/guard-delivery-loop.sh` via `Stop` |
| Orchestrator never authors verdicts (`delivery-loop.md`) | `scripts/guard-delivery-loop.sh` via `PreToolUse` |
| Next action is derived, not remembered (`delivery-loop.md`) | `scripts/delivery.sh next` |

## Scope

These rules supplement the agent prompts in `.claude/agents/`; they do not
replace the gates described in `CLAUDE.md`. Where a rule and a prompt disagree,
the rule governs, and the prompt is corrected.
