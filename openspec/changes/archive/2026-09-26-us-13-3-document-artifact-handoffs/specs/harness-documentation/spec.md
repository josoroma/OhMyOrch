# harness-documentation

## ADDED Requirements

### Requirement: README explains every artifact handoff between roles

README.md MUST explain the handoff for the proposal, the plan, the implementation, the review, and the acceptance evidence, naming for each the artifact, the role that writes it, and the role that reads it. It MUST show the handoffs as a diagram, and MUST name the gate that enforces each handoff.

#### Scenario: README explains every artifact handoff

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how work passes between the roles
- **THEN** it MUST explain the handoff for the proposal, the plan, the implementation, the review, and the acceptance evidence
- **AND** for each handoff it MUST name the artifact, the role that writes it, and the role that reads it

#### Scenario: README shows the handoffs as a diagram

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how work passes between the roles
- **THEN** it MUST show the handoffs as a diagram
- **AND** the diagram MUST show the change directory as the medium

#### Scenario: README explains the mechanical gate on each handoff

- **GIVEN** a developer opens README.md
- **WHEN** the developer reads how a handoff is enforced
- **THEN** it MUST name the gate that blocks the next role until the artifact exists
- **AND** it MUST explain that a failing verdict returns work to the Implementer
