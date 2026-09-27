# product-iteration

## Purpose

As a Product Manager, I want one orchestration entry point, so that a selected story can move through the complete harness workflow (SPECS.md US-3.2).

## ADDED Requirements

### Requirement: Start iteration from a story identifier

When the product iteration skill is invoked with its identifier, the skill MUST establish or locate the corresponding OpenSpec change.

#### Scenario: Start iteration from a story identifier

- **GIVEN** SPECS.md contains a READY story
- **WHEN** the product iteration skill is invoked with its identifier
- **THEN** the skill MUST establish or locate the corresponding OpenSpec change
- **AND** MUST coordinate Planner, Implementer, Reviewer, and Tester responsibilities
- **AND** MUST enforce workflow gates

### Requirement: Resume an existing iteration

When product iteration is invoked again, the harness MUST inspect current repository state.

#### Scenario: Resume an existing iteration

- **GIVEN** an active change already contains workflow artifacts
- **WHEN** product iteration is invoked again
- **THEN** the harness MUST inspect current repository state
- **AND** MUST resume from the first incomplete required gate
