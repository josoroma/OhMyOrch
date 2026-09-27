# Tasks — us-12-2-run-delivery-goal-loop

Story: US-12.2

## 1. Deliverables (SPECS.md US-12.2 Tasks)

- [x] 1.1 Create `.claude/skills/deliver/SKILL.md` (start or resume, derive, delegate by owner, refresh, never author verdicts) — Scenario: Start a delivery goal
- [x] 1.2 Create `.claude/rules/delivery-loop.md` — Scenario: Start a delivery goal; Scenario: Continue while work remains; Scenario: Halt for a human decision; Scenario: Halt when the loop stops making progress; Scenario: Complete the goal; Scenario: The loop cannot bypass a gate
- [x] 1.3 Add `delivery.sh block --reason` (records BLOCKED, preserves target, started date, and notes) — Scenario: Halt for a human decision; Scenario: Halt when the loop stops making progress
- [x] 1.4 Create `scripts/guard-delivery-loop.sh` Stop mode (continue, escalate, no-progress, complete, fail-open) — Scenario: Continue while work remains; Scenario: Halt for a human decision; Scenario: Halt when the loop stops making progress; Scenario: Complete the goal
- [x] 1.5 Add the `guard-delivery-loop.sh` PreToolUse mode blocking main-session writes to review.md / test-report.md during an ACTIVE goal — Scenario: Start a delivery goal
- [x] 1.6 Wire the `Stop` hook and the `PreToolUse` entry in `.claude/settings.json`; allow-list the guard — Scenario: Continue while work remains; Scenario: Start a delivery goal
- [x] 1.7 Add goal-driven delivery to `.claude/agents/product-manager.md` — Scenario: Start a delivery goal; Scenario: The loop cannot bypass a gate

## 2. Implementation tests (Implementer-owned; acceptance evidence is the Tester's)

- [x] 2.1 Regression cases for Scenario: Start a delivery goal
- [x] 2.2 Regression cases for Scenario: Continue while work remains
- [x] 2.3 Regression cases for Scenario: Halt for a human decision
- [x] 2.4 Regression cases for Scenario: Halt when the loop stops making progress
- [x] 2.5 Regression cases for Scenario: Complete the goal
- [x] 2.6 Regression cases for Scenario: The loop cannot bypass a gate

## R1. Follow-ups — non-blocking observations from review round 1

Preserved: history/review-r1.md (verdict approved; re-review required because the code changes)

- [x] R1.1 Resolve observation O-1: `delivery.sh stop`, `block`, and `start` clear `openspec/delivery/loop.state`, so a resumed goal counts stalls from zero (design §2) — Scenario: Halt when the loop stops making progress
- [x] R1.2 Resolve observation O-2: when `delivery.sh block` cannot record the halt, the Stop hook must say so rather than claim "recorded BLOCKED" (it still allows the stop) — Scenario: Halt for a human decision
- [x] R1.3 Resolve observation O-3: document the verdict-guard limits (shell redirects, case-variant paths, a product-manager subagent) in `.claude/rules/delivery-loop.md` and the deliver skill — Scenario: Start a delivery goal
- [x] R1.4 Resolve observation O-5: fix "1 stop attempts" pluralisation — Scenario: Halt when the loop stops making progress
