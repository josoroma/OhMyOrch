# independent-review

## Purpose

As a Product Manager, I want an independent Reviewer, so that implementation is evaluated against requirements rather than implementation intent (SPECS.md US-6.1).

## ADDED Requirements

### Requirement: Review implementation against specification

When the Reviewer starts review, it MUST inspect the active OpenSpec proposal, specs, design when present, tasks, implementation plan, and implementation diff.

#### Scenario: Review implementation against specification

- **GIVEN** implementation is reported complete
- **WHEN** the Reviewer starts review
- **THEN** it MUST inspect the active OpenSpec proposal, specs, design when present, tasks, implementation plan, and implementation diff
- **AND** it MUST evaluate every relevant acceptance criterion

### Requirement: Produce actionable review findings

When review completes, review.md MUST identify the affected requirement.

#### Scenario: Produce actionable review findings

- **GIVEN** a blocking issue is found
- **WHEN** review completes
- **THEN** review.md MUST identify the affected requirement
- **AND** MUST describe observed behavior
- **AND** MUST describe expected behavior
- **AND** MUST request concrete remediation
- **AND** control MUST return to the Implementer

### Requirement: Reviewer does not repair product code

When remediation is required, the Reviewer MUST NOT silently modify application source code.

#### Scenario: Reviewer does not repair product code

- **GIVEN** the Reviewer identifies a product-code defect
- **WHEN** remediation is required
- **THEN** the Reviewer MUST NOT silently modify application source code
- **AND** MUST return the finding to the Implementer
