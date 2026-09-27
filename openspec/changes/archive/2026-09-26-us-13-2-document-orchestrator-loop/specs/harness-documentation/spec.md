# harness-documentation

## ADDED Requirements

### Requirement: README opens with a table of contents

README.md MUST contain a table of contents near the top, listing every numbered section with a link to its heading.

#### Scenario: README opens with a table of contents

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks for a section
- **THEN** README.md MUST contain a table of contents near the top
- **AND** every numbered section MUST be listed with a link to its heading

### Requirement: README explains the orchestrator loop and the plan handoff

README.md MUST name the agents and skills the delivery loop uses at each step, MUST show the loop as a diagram, and MUST explain the plan-to-implement handoff with a diagram.

#### Scenario: README explains the orchestrator loop

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how a delivery target is delivered
- **THEN** it MUST name the agents and skills the loop uses at each step
- **AND** it MUST show the loop as a diagram

#### Scenario: README explains the plan-to-implement handoff

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how the plan reaches the Implementer
- **THEN** it MUST explain that the Planner writes `implementation-plan.md` into the change directory
- **AND** it MUST explain that the Implementer reads that file
- **AND** it MUST explain the mechanical gate that blocks implementation until the plan exists
- **AND** it MUST show the handoff as a diagram
