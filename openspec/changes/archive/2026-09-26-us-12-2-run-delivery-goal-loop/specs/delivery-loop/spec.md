# delivery-loop

## Purpose

As a Product Manager, I want one command that keeps working a delivery goal until it is done or needs me, so that an epic, story, or task is planned, implemented, reviewed, tested, and archived without manual stage-by-stage prompting (SPECS.md US-12.2).

## ADDED Requirements

### Requirement: Start a delivery goal

When the delivery skill is invoked with a READY epic, story, or task, the harness MUST record a delivery goal with the target, its stories, and status ACTIVE. It MUST delegate each next action to the role that owns it, and the orchestrator MUST NOT author review.md or test-report.md.

#### Scenario: Start a delivery goal

- **GIVEN** SPECS.md contains a READY epic, story, or task
- **WHEN** the delivery skill is invoked with that target
- **THEN** a delivery goal MUST be recorded with the target, its stories, and status ACTIVE
- **AND** each next action MUST be delegated to the role that owns it
- **AND** the orchestrator MUST NOT author review.md or test-report.md

### Requirement: Continue while work remains

While a delivery goal is ACTIVE and its next action is not "escalate", a Stop hook MUST block the main session from stopping and MUST name the next action and its owner.

#### Scenario: Continue while work remains

- **GIVEN** an ACTIVE delivery goal whose next action is not "escalate"
- **WHEN** the main session attempts to stop
- **THEN** a Stop hook MUST block the stop
- **AND** it MUST name the next action and its owner

### Requirement: Halt for a human decision

When an ACTIVE delivery goal's next action is "escalate", the Stop hook MUST allow the stop and MUST record the goal as BLOCKED with the escalation reason.

#### Scenario: Halt for a human decision

- **GIVEN** an ACTIVE delivery goal whose next action is "escalate"
- **WHEN** the main session attempts to stop
- **THEN** the Stop hook MUST allow the stop
- **AND** the goal MUST be recorded as BLOCKED with the escalation reason

### Requirement: Halt when the loop stops making progress

When an ACTIVE delivery goal's derived state has not changed across the configured number of stop attempts, the Stop hook MUST allow the stop and MUST record the goal as BLOCKED for lack of progress.

#### Scenario: Halt when the loop stops making progress

- **GIVEN** an ACTIVE delivery goal whose derived state has not changed across the configured number of stop attempts
- **WHEN** the main session attempts to stop again
- **THEN** the Stop hook MUST allow the stop
- **AND** the goal MUST be recorded as BLOCKED for lack of progress

### Requirement: Complete the goal

When every story of an ACTIVE delivery goal is DONE, the Stop hook MUST allow the stop and MUST record the goal as COMPLETE.

#### Scenario: Complete the goal

- **GIVEN** every story of an ACTIVE delivery goal is DONE
- **WHEN** the main session attempts to stop
- **THEN** the Stop hook MUST allow the stop
- **AND** the goal MUST be recorded as COMPLETE

### Requirement: The loop cannot bypass a gate

When the loop requests archival of a change that is not archive-eligible, the existing archive guard MUST still reject it.

#### Scenario: The loop cannot bypass a gate

- **GIVEN** an ACTIVE delivery goal whose current change is not archive-eligible
- **WHEN** the loop requests archival
- **THEN** the existing archive guard MUST still reject it
