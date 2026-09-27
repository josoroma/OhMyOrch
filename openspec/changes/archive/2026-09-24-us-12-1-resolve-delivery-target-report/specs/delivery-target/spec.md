# delivery-target

## Purpose

As a Product Manager, I want an epic, story, or task resolved into ordered stories with a derived next action, so that a delivery loop always knows what to do next from repository state alone (SPECS.md US-12.1).

## ADDED Requirements

### Requirement: Resolve an epic into its stories

When an epic identifier is resolved as a delivery target, the harness MUST list every story of that epic in SPECS.md order, each mapped to its own OpenSpec change identifier.

#### Scenario: Resolve an epic into its stories

- **GIVEN** SPECS.md contains an epic with more than one user story
- **WHEN** the epic identifier is resolved as a delivery target
- **THEN** every story of that epic MUST be listed in SPECS.md order
- **AND** each listed story MUST map to its own OpenSpec change identifier

### Requirement: Resolve a task to its parent story

When a task is resolved as a delivery target, the harness MUST resolve it to the parent user story and MUST record the task as the focus of the goal.

#### Scenario: Resolve a task to its parent story

- **GIVEN** SPECS.md contains a task under a user story
- **WHEN** that task is resolved as a delivery target
- **THEN** the target MUST resolve to the parent user story
- **AND** the selected task MUST be recorded as the focus of the goal

### Requirement: Reject an unknown target

When a target that SPECS.md does not contain is resolved, resolution MUST exit non-zero, name the unknown target, and record no delivery goal.

#### Scenario: Reject an unknown target

- **GIVEN** SPECS.md does not contain the requested epic, story, or task
- **WHEN** the target is resolved
- **THEN** resolution MUST exit non-zero and name the unknown target
- **AND** no delivery goal MUST be recorded

### Requirement: Derive the next action from repository artifacts

The next action for a goal MUST be derived from the workflow gates and the completion gate, and MUST name the owning role and the command that performs it.

#### Scenario: Derive the next action from repository artifacts

- **GIVEN** the first undelivered story of a goal has an active OpenSpec change
- **WHEN** the next action is requested
- **THEN** the action MUST be derived from the workflow gates and the completion gate
- **AND** it MUST name the owning role and the command that performs it

### Requirement: Escalate a story that cannot proceed

When the first undelivered story is not READY or IN PROGRESS, or depends on a story that is not DONE, the next action MUST be "escalate" with the reason, and no OpenSpec change MUST be created for it.

#### Scenario: Escalate a story that cannot proceed

- **GIVEN** the first undelivered story is not READY or IN PROGRESS, or depends on a story that is not DONE
- **WHEN** the next action is requested
- **THEN** the action MUST be "escalate" with the reason
- **AND** no OpenSpec change MUST be created for that story

### Requirement: Reopen a change after a failed review or acceptance test

Reopening a change with blocking review findings or a failing test report MUST preserve the failing artifact under the change's history directory, append one unticked remediation task per finding, and return the next action to implementation.

#### Scenario: Reopen a change after a failed review or acceptance test

- **GIVEN** a change whose review reports blocking findings or whose test report records a FAIL
- **WHEN** the change is reopened
- **THEN** the failing artifact MUST be preserved under the change's history directory
- **AND** one unticked remediation task per finding MUST be appended to tasks.md
- **AND** the next action MUST return to implementation
