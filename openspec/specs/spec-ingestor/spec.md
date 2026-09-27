# spec-ingestor Specification

## Purpose
As a Product Manager, I want a Spec Ingestor agent, so that PRD and source documents become structured requirements without silently fabricated behavior (SPECS.md US-2.5).

## Requirements

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

### Requirement: The Spec Ingestor defines the SPECS.md structure

The Spec Ingestor MUST require a generated SPECS.md to open with a table of contents, a work-item status table, and a dependency diagram, and MUST define the section order of the file.

#### Scenario: SPECS.md opens with a table of contents

- **GIVEN** the Spec Ingestor generates or updates SPECS.md
- **WHEN** a reader opens the file
- **THEN** it MUST contain a table of contents listing every epic and user story
- **AND** each entry MUST link to that work item's heading

#### Scenario: SPECS.md carries a work-item status table

- **GIVEN** SPECS.md contains epics, user stories, and tasks
- **WHEN** a reader opens the file
- **THEN** it MUST contain a table listing every epic, user story, and task
- **AND** each row MUST show the work item's identifier, title, status, and parent

#### Scenario: SPECS.md carries a dependency diagram

- **GIVEN** SPECS.md contains work items with declared dependencies
- **WHEN** a reader opens the file
- **THEN** it MUST contain a Mermaid diagram of the epics, user stories, and tasks as nested parents and children
- **AND** the diagram MUST show the declared dependencies between them

#### Scenario: The Spec Ingestor defines the SPECS.md structure

- **GIVEN** the Spec Ingestor agent definition
- **WHEN** a reader inspects it
- **THEN** it MUST require the table of contents, the work-item status table, and the dependency diagram
- **AND** it MUST define the section order of a generated SPECS.md
