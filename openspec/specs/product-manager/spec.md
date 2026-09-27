# product-manager Specification

## Purpose
As a Human Product Manager, I want a Product Manager agent to orchestrate specialized agents, so that work progresses through controlled gates rather than autonomous coding (SPECS.md US-3.1).

## Requirements

### Requirement: Select one manageable unit of work

When a new product iteration starts, the Product Manager MUST select exactly one manageable story or cohesive feature.

#### Scenario: Select one manageable unit of work

- **GIVEN** SPECS.md contains one or more READY stories
- **WHEN** a new product iteration starts
- **THEN** the Product Manager MUST select exactly one manageable story or cohesive feature
- **AND** it MUST record the selected story identifier
- **AND** it MUST establish a corresponding OpenSpec change identifier

### Requirement: Do not treat the entire backlog as one OpenSpec change

When the Product Manager creates implementation work, those stories MUST NOT be collapsed into one project-sized OpenSpec change.

#### Scenario: Do not treat the entire backlog as one OpenSpec change

- **GIVEN** SPECS.md contains multiple independently verifiable stories
- **WHEN** the Product Manager creates implementation work
- **THEN** those stories MUST NOT be collapsed into one project-sized OpenSpec change

### Requirement: Product Manager owns archive decision

When archive eligibility is evaluated, the Product Manager MUST verify all completion gates before invoking archive.

#### Scenario: Product Manager owns archive decision

- **GIVEN** implementation, review, and testing have completed
- **WHEN** archive eligibility is evaluated
- **THEN** the Product Manager MUST verify all completion gates before invoking archive
