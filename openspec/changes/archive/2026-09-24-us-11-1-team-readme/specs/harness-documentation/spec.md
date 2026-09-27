# harness-documentation

## Purpose

As a new team member, I want a concise operational README, so that I know how to install, ingest requirements, start work, resume work, review, test, and archive changes (SPECS.md US-11.1).

## ADDED Requirements

### Requirement: README explains installation

When the developer follows it to install the harness, it MUST explain OpenSpec installation.

#### Scenario: README explains installation

- **GIVEN** a developer opens README.md
- **WHEN** the developer follows it to install the harness
- **THEN** it MUST explain OpenSpec installation
- **AND** it MUST explain OpenSpec initialization for Claude Code
- **AND** it MUST explain how to confirm installed workflows

### Requirement: README explains brownfield context and document-to-delivery flow

When the developer follows it from product sources to a delivered change, it MUST explain how an existing codebase becomes CODEBASE.md.

#### Scenario: README explains brownfield context and document-to-delivery flow

- **GIVEN** a developer opens README.md
- **WHEN** the developer follows it from product sources to a delivered change
- **THEN** it MUST explain how an existing codebase becomes CODEBASE.md
- **AND** it MUST explain how CODEBASE.md is consumed when generating PRD.md and SPECS.md
- **AND** it MUST explain how product source documents become PRD.md and SPECS.md
- **AND** it MUST explain how one READY story is selected
- **AND** it MUST explain explore, propose, apply, verify, and archive commands
- **AND** it MUST explain review and test loops

### Requirement: README explains resumption

When a developer returns in a new Claude session, README.md MUST explain how the harness resumes from repository artifacts.

#### Scenario: README explains resumption

- **GIVEN** work is interrupted
- **WHEN** a developer returns in a new Claude session
- **THEN** README.md MUST explain how the harness resumes from repository artifacts
