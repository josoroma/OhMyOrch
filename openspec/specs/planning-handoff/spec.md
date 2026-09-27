# planning-handoff Specification

## Purpose
As an Implementer, I want a dedicated Planner, so that implementation starts from an explicit, repository-aware handoff (SPECS.md US-4.1).

## Requirements

### Requirement: Explore without modifying product code

When the Planner performs exploration, it MUST inspect relevant code, specifications, dependencies, and risks.

#### Scenario: Explore without modifying product code

- **GIVEN** a story has been selected
- **WHEN** the Planner performs exploration
- **THEN** it MUST inspect relevant code, specifications, dependencies, and risks
- **AND** it MUST NOT modify application source code

### Requirement: Produce implementation plan

When planning completes, "implementation-plan.md" MUST exist for the active change.

#### Scenario: Produce implementation plan

- **GIVEN** OpenSpec proposal artifacts exist
- **WHEN** planning completes
- **THEN** "implementation-plan.md" MUST exist for the active change
- **AND** it MUST identify the selected story
- **AND** it MUST reference relevant OpenSpec artifacts
- **AND** it MUST map tasks to acceptance criteria
- **AND** it MUST identify likely affected files and expected tests when determinable from repository evidence
