# implementation-scope Specification

## Purpose
As a Product Manager, I want a dedicated Implementer, so that source changes remain bounded by the approved specification (SPECS.md US-5.1).

## Requirements

### Requirement: Implement from OpenSpec tasks

When the Implementer applies the change, it MUST implement work required by the active specification.

#### Scenario: Implement from OpenSpec tasks

- **GIVEN** proposal, specs, tasks, and implementation-plan artifacts exist
- **WHEN** the Implementer applies the change
- **THEN** it MUST implement work required by the active specification
- **AND** it MUST update task completion only for completed work
- **AND** it MUST run relevant project validation before declaring implementation complete

### Requirement: Scope expansion is prohibited

When that improvement is not required by the active change, the Implementer MUST NOT silently add it to the implementation.

#### Scenario: Scope expansion is prohibited

- **GIVEN** the Implementer discovers an unrelated improvement
- **WHEN** that improvement is not required by the active change
- **THEN** the Implementer MUST NOT silently add it to the implementation
- **AND** it MAY record it as follow-up work

### Requirement: Implementer cannot approve itself

When approval is required, the Implementer MUST hand control to the Reviewer.

#### Scenario: Implementer cannot approve itself

- **GIVEN** implementation is complete
- **WHEN** approval is required
- **THEN** the Implementer MUST hand control to the Reviewer
- **AND** MUST NOT author the approval decision in review.md
