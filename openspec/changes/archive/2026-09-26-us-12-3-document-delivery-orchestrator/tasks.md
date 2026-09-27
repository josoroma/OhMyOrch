# Tasks — us-12-3-document-delivery-orchestrator

Story: US-12.3

## 1. Deliverables (SPECS.md US-12.3 Tasks)

- [x] 1.1 Add a goal-driven delivery section to `README.md`: commands per target kind, every stop condition, resume — Scenario: README explains goal-driven delivery
- [x] 1.2 Update `README.md` cookbook, resume section, script inventory, guard table, and suite list for the delivery scripts — Scenario: README explains goal-driven delivery
- [x] 1.3 Reference the orchestrator in `CLAUDE.md` (workflow, document map, validation commands) — Scenario: Contracts and indexes list the orchestrator
- [x] 1.4 Index `delivery-loop.md` in `.claude/rules/README.md` (index + rule-to-gate mapping) — Scenario: Contracts and indexes list the orchestrator
- [x] 1.5 Index `delivery.sh`, `guard-delivery-loop.sh`, `test-delivery.sh` in `scripts/README.md` — Scenario: Contracts and indexes list the orchestrator
- [x] 1.6 Add the `/deliver` orchestration to `.claude/agents/README.md` — Scenario: Contracts and indexes list the orchestrator
- [x] 1.7 Write `SPEC-LOGS/README-EPIC-12.md` — Scenario: README explains goal-driven delivery

## 2. Implementation checks (Implementer-owned; acceptance evidence is the Tester's)

- [x] 2.1 Tighten `scripts/test-delivery.sh` "one attempt is singular" to also assert "1 stop attempts" is absent (US-12.2 review r2 O-1) — Scenario: README explains goal-driven delivery
- [x] 2.2 Every command documented in the new README section runs as documented (`--help`, `resolve`, `next`) — Scenario: README explains goal-driven delivery
- [x] 2.3 `grep` evidence that each of the three indexes references the orchestrator — Scenario: Contracts and indexes list the orchestrator
