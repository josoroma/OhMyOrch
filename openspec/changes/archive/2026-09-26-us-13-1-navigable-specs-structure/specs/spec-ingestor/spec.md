# spec-ingestor

## ADDED Requirements

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
