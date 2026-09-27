# harness-documentation

## ADDED Requirements

### Requirement: The stall limit is described accurately

README.md and .claude/rules/delivery-loop.md MUST state that the no-progress stop is allowed after the configured number of blocked stop attempts, and MUST name the default and the override.

#### Scenario: The stall limit is described accurately

- **GIVEN** README.md and .claude/rules/delivery-loop.md describe the no-progress stop
- **WHEN** a developer reads the stall limit
- **THEN** the documentation MUST state that the stop is allowed after the configured number of blocked stop attempts
- **AND** it MUST name the default and the override

### Requirement: Every escalation cause is documented

README.md MUST list every reason the delivery loop halts for a human decision, including the gate reporter failing to report and an unmapped gate.

#### Scenario: Every escalation cause is documented

- **GIVEN** README.md lists the reasons the loop halts for a human decision
- **WHEN** a developer reads that list
- **THEN** it MUST include the gate reporter failing to report
- **AND** it MUST include an unmapped gate
