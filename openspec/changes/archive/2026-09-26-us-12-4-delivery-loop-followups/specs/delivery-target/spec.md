# delivery-target

## ADDED Requirements

### Requirement: Stop records a halt when the target no longer resolves

When a recorded goal is stopped and its target no longer resolves in SPECS.md, the harness MUST record the goal as STOPPED and MUST exit zero.

#### Scenario: Stop records a halt when the target no longer resolves

- **GIVEN** a recorded goal whose target no longer resolves in SPECS.md
- **WHEN** the goal is stopped
- **THEN** the goal MUST be recorded as STOPPED
- **AND** the command MUST exit zero
