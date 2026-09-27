# product-specifier

## Purpose

As a Product Manager, I want a Product Specifier agent, so that product source material and existing-system context can be turned into a PRD without confusing current implementation with desired behavior (SPECS.md US-2.3).

## ADDED Requirements

### Requirement: Generate PRD with codebase context when available

When the Product Specifier creates or materially updates PRD.md, it MUST read CODEBASE.md before writing PRD.md.

#### Scenario: Generate PRD with codebase context when available

- **GIVEN** product source material is available
- **AND** CODEBASE.md exists
- **WHEN** the Product Specifier creates or materially updates PRD.md
- **THEN** it MUST read CODEBASE.md before writing PRD.md
- **AND** it MUST consider relevant existing capabilities, compatibility constraints, integrations, technical boundaries, migration concerns, and known gaps
- **AND** desired product behavior MUST remain grounded in explicit product sources or Product Manager decisions

### Requirement: Generate PRD for a greenfield project

When the Product Specifier creates PRD.md, PRD.md MUST be generated from the product source material.

#### Scenario: Generate PRD for a greenfield project

- **GIVEN** product source material is available
- **AND** no meaningful existing codebase is present
- **WHEN** the Product Specifier creates PRD.md
- **THEN** PRD.md MUST be generated from the product source material
- **AND** it MUST NOT invent a nonexistent current architecture

### Requirement: Product intent conflicts with current implementation

When PRD.md is generated, the desired behavior MUST remain represented as product intent.

#### Scenario: Product intent conflicts with current implementation

- **GIVEN** a product source requires behavior that differs from behavior documented in CODEBASE.md
- **WHEN** PRD.md is generated
- **THEN** the desired behavior MUST remain represented as product intent
- **AND** the current-state difference SHOULD be recorded as a gap, constraint, migration consideration, or open question
- **AND** current code MUST NOT silently override the product requirement
