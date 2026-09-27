# Tasks — us-12-4-delivery-loop-followups

Story: US-12.4

## 1. Deliverables (SPECS.md US-12.4 Tasks)

- [x] 1.1 Correct the stall-limit wording in `README.md` §18 and `.claude/rules/delivery-loop.md`; name the default and the override — Scenario: The stall limit is described accurately
- [x] 1.2 Add the two missing escalation causes to `README.md` §18 — Scenario: Every escalation cause is documented
- [x] 1.3 Make `delivery.sh stop` record the halt when the target no longer resolves — Scenario: Stop records a halt when the target no longer resolves
- [x] 1.4 Correct the `guard-archive.sh` row in `scripts/README.md` — Scenario: The script index describes the archive guard accurately

## 2. Implementation tests (Implementer-owned; acceptance evidence is the Tester's)

- [x] 2.1 Regression case for Scenario: Stop records a halt when the target no longer resolves
- [x] 2.2 Regression case for Scenario: The stall limit is described accurately (the wording is asserted, not just present)
- [x] 2.3 Regression case for Scenario: Every escalation cause is documented
- [x] 2.4 Regression case for Scenario: The script index describes the archive guard accurately
