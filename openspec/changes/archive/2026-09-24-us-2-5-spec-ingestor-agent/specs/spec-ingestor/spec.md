# spec-ingestor

## Purpose

As a Product Manager, I want a Spec Ingestor agent, so that PRD and source documents become structured requirements without silently fabricated behavior (SPECS.md US-2.5).

## ADDED Requirements

### Requirement: Convert product artifacts into structured requirements

When the Spec Ingestor processes them, it MUST identify explicit goals, actors, requirements, constraints, dependencies, and acceptance information when present.

#### Scenario: Convert product artifacts into structured requirements

- **GIVEN** PRD.md or other product source documents are available
- **WHEN** the Spec Ingestor processes them
- **THEN** it MUST identify explicit goals, actors, requirements, constraints, dependencies, and acceptance information when present
- **AND** it MUST organize supported product information into SPECS.md
- **AND** it MUST NOT modify application source code

### Requirement: Consume CODEBASE.md when it exists

When the Spec Ingestor creates or materially updates SPECS.md, it MUST read CODEBASE.md.

#### Scenario: Consume CODEBASE.md when it exists

- **GIVEN** CODEBASE.md exists
- **WHEN** the Spec Ingestor creates or materially updates SPECS.md
- **THEN** it MUST read CODEBASE.md
- **AND** it SHOULD use relevant codebase evidence to identify existing capabilities, integration points, constraints, likely dependencies, and compatibility concerns
- **AND** acceptance criteria MUST remain grounded in explicit product requirements or Product Manager decisions

### Requirement: Missing product behavior is not invented

When the Spec Ingestor writes SPECS.md, the requirement MUST remain represented.

#### Scenario: Missing product behavior is not invented

- **GIVEN** the source contains a requirement whose success condition is not defined
- **WHEN** the Spec Ingestor writes SPECS.md
- **THEN** the requirement MUST remain represented
- **AND** the story MUST be marked "NEEDS CLARIFICATION" when the missing information blocks acceptance
- **AND** the missing decision MUST be listed under Open Questions

### Requirement: Conflicting source requirements are preserved

When the Spec Ingestor processes them, both source statements MUST remain traceable.

#### Scenario: Conflicting source requirements are preserved

- **GIVEN** two product source statements prescribe incompatible product behavior
- **WHEN** the Spec Ingestor processes them
- **THEN** both source statements MUST remain traceable
- **AND** the conflict MUST be recorded
- **AND** the affected story MUST be marked "BLOCKED"
