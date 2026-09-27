# completion-gate Specification

## Purpose
As a Product Manager, I want an explicit completion gate, so that only accepted changes are archived (SPECS.md US-10.1).

## Requirements

### Requirement: Change is eligible for archive

When the Product Manager evaluates completion, the change MAY proceed to archive. Normative strength follows the THEN clauses below; SHOULD and MAY clauses MUST NOT be read as MUST (`.claude/rules/gherkin.md`).

#### Scenario: Change is eligible for archive

- **GIVEN** all required tasks are complete
- **AND** review has no blocking findings
- **AND** all required acceptance criteria pass
- **AND** OpenSpec verification has no blocking mismatch
- **WHEN** the Product Manager evaluates completion
- **THEN** the change MAY proceed to archive

### Requirement: Change is not eligible for archive

When archive is requested, archival MUST be rejected by the harness.

#### Scenario: Change is not eligible for archive

- **GIVEN** at least one required task remains incomplete
- **OR** review has a blocking finding
- **OR** an acceptance criterion is failing
- **OR** OpenSpec verification reports a blocking mismatch
- **WHEN** archive is requested
- **THEN** archival MUST be rejected by the harness
