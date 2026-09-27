# workflow-state

## Purpose

As a Product Manager, I want active change status persisted, so that a new session can resume from the correct gate (SPECS.md US-9.1).

## ADDED Requirements

### Requirement: Persist workflow state

When the harness moves to another workflow stage, the active state SHOULD be recorded in status.md. Normative strength follows the THEN clauses below; SHOULD and MAY clauses MUST NOT be read as MUST (`.claude/rules/gherkin.md`).

#### Scenario: Persist workflow state

- **GIVEN** an active OpenSpec change exists
- **WHEN** the harness moves to another workflow stage
- **THEN** the active state SHOULD be recorded in status.md
- **AND** the current owner SHOULD be recorded
- **AND** unresolved blockers SHOULD be recorded

### Requirement: Resume after session restart

When a new session is asked to continue the same change, the Product Manager MUST inspect repository artifacts.

#### Scenario: Resume after session restart

- **GIVEN** a previous Claude session has ended
- **WHEN** a new session is asked to continue the same change
- **THEN** the Product Manager MUST inspect repository artifacts
- **AND** MUST identify the first incomplete required gate
- **AND** MUST continue from that point instead of restarting completed work without cause
