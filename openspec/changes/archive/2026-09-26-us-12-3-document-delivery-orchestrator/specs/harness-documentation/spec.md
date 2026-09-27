# harness-documentation

## ADDED Requirements

### Requirement: README explains goal-driven delivery

When a developer looks up how to deliver an epic, story, or task, README.md MUST explain the delivery command for each target kind, every way the loop stops, and how an interrupted goal resumes.

#### Scenario: README explains goal-driven delivery

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how to deliver an epic, story, or task
- **THEN** it MUST explain the delivery command for each target kind
- **AND** it MUST explain every way the loop stops
- **AND** it MUST explain how an interrupted goal resumes

### Requirement: Contracts and indexes list the orchestrator

CLAUDE.md, .claude/rules/README.md, and scripts/README.md MUST each reference the delivery skill, the delivery-loop rule, or the delivery scripts it indexes.

#### Scenario: Contracts and indexes list the orchestrator

- **GIVEN** CLAUDE.md, .claude/rules/README.md, and scripts/README.md
- **WHEN** a developer inspects them
- **THEN** each MUST reference the delivery skill, the delivery-loop rule, or the delivery scripts it indexes
