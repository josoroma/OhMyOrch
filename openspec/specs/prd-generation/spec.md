# prd-generation Specification

## Purpose
As a Product Manager, I want a reusable PRD-generation command, so that project product intent can be normalized consistently for both greenfield and brownfield repositories (SPECS.md US-2.4).

## Requirements

### Requirement: Generate PRD after considering repository context

When the Product Manager invokes the PRD-generation skill, the skill MUST determine whether CODEBASE.md exists.

#### Scenario: Generate PRD after considering repository context

- **GIVEN** one or more product source documents are supplied
- **WHEN** the Product Manager invokes the PRD-generation skill
- **THEN** the skill MUST determine whether CODEBASE.md exists
- **AND** when CODEBASE.md exists it MUST be included in the Product Specifier context
- **AND** PRD.md MUST be created or incrementally updated

### Requirement: Existing codebase has not yet been analyzed

When PRD generation is requested, the workflow MUST run codebase analysis first or explicitly record that codebase analysis was intentionally skipped.

#### Scenario: Existing codebase has not yet been analyzed

- **GIVEN** a meaningful existing codebase is detected
- **AND** CODEBASE.md does not exist
- **WHEN** PRD generation is requested
- **THEN** the workflow MUST run codebase analysis first or explicitly record that codebase analysis was intentionally skipped
- **AND** PRD generation MUST NOT silently pretend that repository context was considered

### Requirement: Stale CODEBASE.md is surfaced

When PRD generation is requested, the workflow MUST surface the stale-context condition before treating CODEBASE.md as current.

#### Scenario: Stale CODEBASE.md is surfaced

- **GIVEN** CODEBASE.md exists
- **AND** the harness can determine that its recorded repository snapshot is materially stale
- **WHEN** PRD generation is requested
- **THEN** the workflow MUST surface the stale-context condition before treating CODEBASE.md as current
