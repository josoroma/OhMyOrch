# artifact-validation Specification

## Purpose
As a Product Manager, I want automated specification and context validation, so that malformed stories or ignored brownfield context cannot quietly enter implementation (SPECS.md US-2.7).

## Requirements

### Requirement: Validate unique story identifiers

When specification validation runs, every Epic identifier MUST be unique.

#### Scenario: Validate unique story identifiers

- **GIVEN** SPECS.md has been modified
- **WHEN** specification validation runs
- **THEN** every Epic identifier MUST be unique
- **AND** every User Story identifier MUST be unique

### Requirement: Validate READY story acceptance criteria

When specification validation runs, the story MUST contain at least one acceptance scenario.

#### Scenario: Validate READY story acceptance criteria

- **GIVEN** a User Story is marked "READY"
- **WHEN** specification validation runs
- **THEN** the story MUST contain at least one acceptance scenario
- **AND** every acceptance scenario MUST contain Given, When, and Then

### Requirement: Unsupported generated requirement cannot be ready

When readiness is evaluated, that requirement MUST NOT be treated as a ready product requirement.

#### Scenario: Unsupported generated requirement cannot be ready

- **GIVEN** a requirement cannot be traced to product source material or an explicit Product Manager decision
- **WHEN** readiness is evaluated
- **THEN** that requirement MUST NOT be treated as a ready product requirement

### Requirement: PRD generation acknowledges existing CODEBASE.md

When PRD.md is generated or materially updated through the harness, the workflow MUST record or otherwise make verifiable that CODEBASE.md was part of the generation context.

#### Scenario: PRD generation acknowledges existing CODEBASE.md

- **GIVEN** CODEBASE.md exists
- **WHEN** PRD.md is generated or materially updated through the harness
- **THEN** the workflow MUST record or otherwise make verifiable that CODEBASE.md was part of the generation context

### Requirement: SPECS generation acknowledges existing CODEBASE.md

When SPECS.md is generated or materially updated through the harness, the workflow MUST record or otherwise make verifiable that CODEBASE.md was part of the generation context.

#### Scenario: SPECS generation acknowledges existing CODEBASE.md

- **GIVEN** CODEBASE.md exists
- **WHEN** SPECS.md is generated or materially updated through the harness
- **THEN** the workflow MUST record or otherwise make verifiable that CODEBASE.md was part of the generation context
