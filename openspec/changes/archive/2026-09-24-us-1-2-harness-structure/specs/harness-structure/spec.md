# harness-structure

## Purpose

As an Engineering Lead, I want a predictable harness directory layout, so that every project exposes the same control surfaces (SPECS.md US-1.2).

## ADDED Requirements

### Requirement: Required harness files exist

When the repository root is inspected, "CLAUDE.md" MUST exist.

#### Scenario: Required harness files exist

- **GIVEN** the harness has been installed into a project
- **WHEN** the repository root is inspected
- **THEN** "CLAUDE.md" MUST exist
- **AND** ".claude/agents/" MUST exist
- **AND** ".claude/skills/" MUST exist
- **AND** ".claude/rules/" MUST exist
- **AND** ".claude/settings.json" MUST exist
- **AND** "SPECS.md" MUST exist
