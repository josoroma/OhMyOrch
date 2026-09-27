# workflow-guards

## Purpose

As a Product Manager, I want mechanical workflow guards, so that critical gates do not rely exclusively on prompt compliance (SPECS.md US-8.2).

## ADDED Requirements

### Requirement: Prevent source implementation before planning handoff

When an Implementer attempts to modify product source code, the operation SHOULD be rejected by a deterministic guard where Claude Code hook capabilities permit it. Normative strength follows the THEN clauses below; SHOULD and MAY clauses MUST NOT be read as MUST (`.claude/rules/gherkin.md`).

#### Scenario: Prevent source implementation before planning handoff

- **GIVEN** an active product change requires the harness workflow
- **AND** implementation-plan.md does not exist
- **WHEN** an Implementer attempts to modify product source code
- **THEN** the operation SHOULD be rejected by a deterministic guard where Claude Code hook capabilities permit it

### Requirement: Prevent premature archive

When archive is requested through the harness, the harness MUST reject archival.

#### Scenario: Prevent premature archive

- **GIVEN** review has blocking findings or acceptance tests are failing
- **WHEN** archive is requested through the harness
- **THEN** the harness MUST reject archival

### Requirement: Require CODEBASE context before PRD generation

When the harness attempts to generate or materially update PRD.md, a pre-generation guard MUST require CODEBASE.md to be included in the Product Specifier context.

#### Scenario: Require CODEBASE context before PRD generation

- **GIVEN** CODEBASE.md exists
- **WHEN** the harness attempts to generate or materially update PRD.md
- **THEN** a pre-generation guard MUST require CODEBASE.md to be included in the Product Specifier context

### Requirement: Require CODEBASE context before SPECS generation

When the harness attempts to generate or materially update SPECS.md, a pre-generation guard MUST require CODEBASE.md to be included in the Spec Ingestor context.

#### Scenario: Require CODEBASE context before SPECS generation

- **GIVEN** CODEBASE.md exists
- **WHEN** the harness attempts to generate or materially update SPECS.md
- **THEN** a pre-generation guard MUST require CODEBASE.md to be included in the Spec Ingestor context

### Requirement: Detect missing brownfield analysis

When PRD or SPECS generation is requested through the harness, the guard MUST require codebase analysis first or an explicit recorded skip decision.

#### Scenario: Detect missing brownfield analysis

- **GIVEN** a meaningful existing codebase is detected
- **AND** CODEBASE.md does not exist
- **WHEN** PRD or SPECS generation is requested through the harness
- **THEN** the guard MUST require codebase analysis first or an explicit recorded skip decision

### Requirement: Validate modified implementation

When the modification phase completes, configured fast project validation SHOULD run before implementation is handed to review. Normative strength follows the THEN clauses below; SHOULD and MAY clauses MUST NOT be read as MUST (`.claude/rules/gherkin.md`).

#### Scenario: Validate modified implementation

- **GIVEN** the Implementer modifies application source code
- **WHEN** the modification phase completes
- **THEN** configured fast project validation SHOULD run before implementation is handed to review
