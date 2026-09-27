# codebase-analysis

## Purpose

As a Product Manager, I want a reusable codebase-analysis command, so that brownfield projects can establish durable technical context before product artifacts are generated (SPECS.md US-2.2).

## ADDED Requirements

### Requirement: Generate CODEBASE.md from an existing repository

When the Product Manager invokes the codebase-analysis skill, the skill MUST delegate repository analysis to the Codebase Analyst.

#### Scenario: Generate CODEBASE.md from an existing repository

- **GIVEN** a meaningful codebase exists
- **WHEN** the Product Manager invokes the codebase-analysis skill
- **THEN** the skill MUST delegate repository analysis to the Codebase Analyst
- **AND** CODEBASE.md MUST be created or refreshed
- **AND** the result MUST include an analyzed revision or other available snapshot identifier
- **AND** the result MUST identify important evidence paths

### Requirement: Do not fabricate a brownfield context for a greenfield project

When codebase analysis runs, the skill MUST report that no meaningful codebase was found.

#### Scenario: Do not fabricate a brownfield context for a greenfield project

- **GIVEN** the project does not yet contain a meaningful application codebase
- **WHEN** codebase analysis runs
- **THEN** the skill MUST report that no meaningful codebase was found
- **AND** it MUST NOT fabricate architecture, integrations, commands, or existing behavior

### Requirement: Refresh stale codebase understanding

When codebase analysis is invoked again, CODEBASE.md MUST be refreshed against the current repository evidence.

#### Scenario: Refresh stale codebase understanding

- **GIVEN** CODEBASE.md exists
- **AND** material repository changes make its recorded snapshot stale
- **WHEN** codebase analysis is invoked again
- **THEN** CODEBASE.md MUST be refreshed against the current repository evidence

### Requirement: CODEBASE.md uses a stable current-state schema

When CODEBASE.md is written, it MUST identify the analyzed revision or snapshot when available.

#### Scenario: CODEBASE.md uses a stable current-state schema

- **GIVEN** codebase analysis succeeds
- **WHEN** CODEBASE.md is written
- **THEN** it MUST identify the analyzed revision or snapshot when available
- **AND** it MUST contain a system summary
- **AND** it MUST contain a repository map
- **AND** it MUST document runtime and tooling
- **AND** it MUST document architecture and entry points when discoverable
- **AND** it MUST document data, integrations, tests, quality gates, and common commands when discoverable
- **AND** it MUST contain evidence paths
- **AND** it MUST contain unknowns for material facts that could not be verified
