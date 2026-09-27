# spec-ingestion

## Purpose

As a Product Manager, I want a reusable specification-ingestion command, so that product artifacts can be normalized consistently into an iterable backlog (SPECS.md US-2.6).

## ADDED Requirements

### Requirement: Ingest product artifacts into SPECS.md

When the Product Manager invokes the harness ingestion skill, the skill MUST delegate extraction to the Spec Ingestor.

#### Scenario: Ingest product artifacts into SPECS.md

- **GIVEN** PRD.md or another product source document exists
- **WHEN** the Product Manager invokes the harness ingestion skill
- **THEN** the skill MUST delegate extraction to the Spec Ingestor
- **AND** when CODEBASE.md exists it MUST be provided as context
- **AND** SPECS.md MUST be created or incrementally updated
- **AND** an ingestion summary MUST be returned

### Requirement: Incrementally merge a new source document

When ingestion runs again, existing equivalent requirements MUST NOT be duplicated.

#### Scenario: Incrementally merge a new source document

- **GIVEN** SPECS.md already exists
- **AND** a new product source document is supplied
- **WHEN** ingestion runs again
- **THEN** existing equivalent requirements MUST NOT be duplicated
- **AND** newly supported requirements MUST be added
- **AND** changed or conflicting requirements MUST be flagged for Product Manager review
- **AND** relevant CODEBASE.md constraints MUST remain considered when CODEBASE.md exists

### Requirement: Existing codebase lacks CODEBASE.md

When SPECS generation is requested, the workflow MUST run codebase analysis first or explicitly record that codebase analysis was intentionally skipped.

#### Scenario: Existing codebase lacks CODEBASE.md

- **GIVEN** a meaningful codebase is detected
- **AND** CODEBASE.md does not exist
- **WHEN** SPECS generation is requested
- **THEN** the workflow MUST run codebase analysis first or explicitly record that codebase analysis was intentionally skipped
