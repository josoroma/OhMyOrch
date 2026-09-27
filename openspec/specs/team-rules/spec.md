# team-rules Specification

## Purpose
As an Engineering Lead, I want explicit repository-level rules, so that each agent consistently stays within its role (SPECS.md US-8.1).

## Requirements

### Requirement: Responsibility rules are installed

When Claude loads project instructions, rules MUST define Codebase Analyst, Product Specifier, Spec Ingestor, Product Manager, Planner, Implementer, Reviewer, and Tester responsibilities.

#### Scenario: Responsibility rules are installed

- **GIVEN** the harness is installed
- **WHEN** Claude loads project instructions
- **THEN** rules MUST define Codebase Analyst, Product Specifier, Spec Ingestor, Product Manager, Planner, Implementer, Reviewer, and Tester responsibilities
- **AND** rules MUST prohibit self-approval by the Implementer
- **AND** rules MUST prohibit the Reviewer from silently fixing reviewed product code
- **AND** rules MUST prohibit the Tester from silently repairing failed implementation behavior
