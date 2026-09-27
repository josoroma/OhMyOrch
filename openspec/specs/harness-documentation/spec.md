# harness-documentation Specification

## Purpose
As a new team member, I want a concise operational README, so that I know how to install, ingest requirements, start work, resume work, review, test, and archive changes (SPECS.md US-11.1).

## Requirements

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

### Requirement: README explains goal-driven delivery

When a developer looks up how to deliver an epic, story, or task, README.md MUST explain the delivery command for each target kind, every way the loop stops, and how an interrupted goal resumes.

#### Scenario: README explains goal-driven delivery

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how to deliver an epic, story, or task
- **THEN** it MUST explain the delivery command for each target kind
- **AND** it MUST explain every way the loop stops
- **AND** it MUST explain how an interrupted goal resumes

### Requirement: Contracts and indexes list the orchestrator

CLAUDE.md, .claude/rules/README.md, and scripts/README.md MUST each reference the delivery skill, the delivery-loop rule, or the delivery scripts it indexes.

#### Scenario: Contracts and indexes list the orchestrator

- **GIVEN** CLAUDE.md, .claude/rules/README.md, and scripts/README.md
- **WHEN** a developer inspects them
- **THEN** each MUST reference the delivery skill, the delivery-loop rule, or the delivery scripts it indexes

### Requirement: The stall limit is described accurately

README.md and .claude/rules/delivery-loop.md MUST state that the no-progress stop is allowed after the configured number of blocked stop attempts, and MUST name the default and the override.

#### Scenario: The stall limit is described accurately

- **GIVEN** README.md and .claude/rules/delivery-loop.md describe the no-progress stop
- **WHEN** a developer reads the stall limit
- **THEN** the documentation MUST state that the stop is allowed after the configured number of blocked stop attempts
- **AND** it MUST name the default and the override

### Requirement: Every escalation cause is documented

README.md MUST list every reason the delivery loop halts for a human decision, including the gate reporter failing to report and an unmapped gate.

#### Scenario: Every escalation cause is documented

- **GIVEN** README.md lists the reasons the loop halts for a human decision
- **WHEN** a developer reads that list
- **THEN** it MUST include the gate reporter failing to report
- **AND** it MUST include an unmapped gate

### Requirement: README opens with a table of contents

README.md MUST contain a table of contents near the top, listing every numbered section with a link to its heading.

#### Scenario: README opens with a table of contents

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks for a section
- **THEN** README.md MUST contain a table of contents near the top
- **AND** every numbered section MUST be listed with a link to its heading

### Requirement: README explains the orchestrator loop and the plan handoff

README.md MUST name the agents and skills the delivery loop uses at each step, MUST show the loop as a diagram, and MUST explain the plan-to-implement handoff with a diagram.

#### Scenario: README explains the orchestrator loop

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how a delivery target is delivered
- **THEN** it MUST name the agents and skills the loop uses at each step
- **AND** it MUST show the loop as a diagram

#### Scenario: README explains the plan-to-implement handoff

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how the plan reaches the Implementer
- **THEN** it MUST explain that the Planner writes `implementation-plan.md` into the change directory
- **AND** it MUST explain that the Implementer reads that file
- **AND** it MUST explain the mechanical gate that blocks implementation until the plan exists
- **AND** it MUST show the handoff as a diagram

### Requirement: README explains every artifact handoff between roles

README.md MUST explain the handoff for the proposal, the plan, the implementation, the review, and the acceptance evidence, naming for each the artifact, the role that writes it, and the role that reads it. It MUST show the handoffs as a diagram, and MUST name the gate that enforces each handoff.

#### Scenario: README explains every artifact handoff

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how work passes between the roles
- **THEN** it MUST explain the handoff for the proposal, the plan, the implementation, the review, and the acceptance evidence
- **AND** for each handoff it MUST name the artifact, the role that writes it, and the role that reads it

#### Scenario: README shows the handoffs as a diagram

- **GIVEN** a developer opens README.md
- **WHEN** the developer looks up how work passes between the roles
- **THEN** it MUST show the handoffs as a diagram
- **AND** the diagram MUST show the change directory as the medium

#### Scenario: README explains the mechanical gate on each handoff

- **GIVEN** a developer opens README.md
- **WHEN** the developer reads how a handoff is enforced
- **THEN** it MUST name the gate that blocks the next role until the artifact exists
- **AND** it MUST explain that a failing verdict returns work to the Implementer
