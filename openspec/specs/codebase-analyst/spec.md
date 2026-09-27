# codebase-analyst Specification

## Purpose
As an Engineering Lead, I want a Codebase Analyst agent, so that an existing repository can be understood once and its current-state architecture can be reused by later agents (SPECS.md US-2.1).

## Requirements

### Requirement: Analyze an existing codebase

When the Codebase Analyst inspects the repository, it MUST identify repository structure, runtime configuration, entry points, major modules, data flows, persistence, external integrations, tests, quality tooling, common commands, and material conventions when supported by repository evidence.

#### Scenario: Analyze an existing codebase

- **GIVEN** the target project contains a meaningful existing codebase
- **WHEN** the Codebase Analyst inspects the repository
- **THEN** it MUST identify repository structure, runtime configuration, entry points, major modules, data flows, persistence, external integrations, tests, quality tooling, common commands, and material conventions when supported by repository evidence
- **AND** it MUST persist the resulting current-state understanding in "CODEBASE.md"
- **AND** it MUST NOT modify application source code

### Requirement: Keep codebase claims evidence-backed

When the claim describes the repository, the claim MUST be supported by inspected files, configuration, tests, commands, or other repository evidence.

#### Scenario: Keep codebase claims evidence-backed

- **GIVEN** the Codebase Analyst writes a claim into CODEBASE.md
- **WHEN** the claim describes the repository
- **THEN** the claim MUST be supported by inspected files, configuration, tests, commands, or other repository evidence
- **AND** unsupported assumptions MUST be recorded as unknowns rather than facts

### Requirement: Existing behavior is not promoted to product intent

When the Codebase Analyst documents that behavior, it MUST NOT label that behavior as a desired product requirement unless a product source explicitly requires it.

#### Scenario: Existing behavior is not promoted to product intent

- **GIVEN** the codebase currently implements a behavior
- **WHEN** the Codebase Analyst documents that behavior
- **THEN** CODEBASE.md MAY describe it as current behavior
- **BUT** it MUST NOT label that behavior as a desired product requirement unless a product source explicitly requires it
