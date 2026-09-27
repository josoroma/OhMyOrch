# acceptance-testing Specification

## Purpose
As a Product Manager, I want an independent Tester, so that acceptance is based on observable evidence rather than implementation claims (SPECS.md US-7.1).

## Requirements

### Requirement: Map acceptance criteria to executable evidence

When the Tester starts validation, every acceptance scenario MUST be mapped to one or more executable checks or explicit evidence.

#### Scenario: Map acceptance criteria to executable evidence

- **GIVEN** review has passed
- **WHEN** the Tester starts validation
- **THEN** every acceptance scenario MUST be mapped to one or more executable checks or explicit evidence

### Requirement: Produce test report

When the Tester reports results, test-report.md MUST list every evaluated acceptance criterion.

#### Scenario: Produce test report

- **GIVEN** acceptance validation has completed
- **WHEN** the Tester reports results
- **THEN** test-report.md MUST list every evaluated acceptance criterion
- **AND** MUST record PASS or FAIL
- **AND** MUST identify the command, test, or evidence used

### Requirement: Failed acceptance returns to implementation

When testing completes, the change MUST NOT be accepted.

#### Scenario: Failed acceptance returns to implementation

- **GIVEN** at least one acceptance criterion fails
- **WHEN** testing completes
- **THEN** the change MUST NOT be accepted
- **AND** control MUST return to the Implementer
- **AND** subsequent code changes MUST be reviewed before failed acceptance criteria are retested
