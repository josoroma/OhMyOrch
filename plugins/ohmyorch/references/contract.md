# OhMyOrch operational contract

Human decisions and approved source documents govern intent. CODEBASE is descriptive evidence, never a source of requirements. Missing behavior becomes NEEDS CLARIFICATION or BLOCKED, never a fabricated requirement.

Resolve the explicit project root and `.claude/ohmyorch/project.json` before acting. `doctor --json` reports the document mapping; PRD, SPECS and CODEBASE always mean those mapped paths, never a root-only layout. OpenSpec (CLI 1.13.2) uses the local `spec-driven` schema under `openspec/`.

The main session delivers one SPECS story as one OpenSpec change: propose, apply, verify, archive, then the story is marked DONE. It performs every step itself. The codebase-analyst, product-specifier and spec-ingestor agents are read-only: they return authored content and the caller persists it.

A change's only artifacts are OpenSpec's own: `proposal.md`, delta `specs/`, `design.md` (only when needed) and `tasks.md`. `tasks.md` is the only progress record. Do not create plan, review, test-report, status or completion files.

The next action is derived from SPECS and the change directory on every call (`delivery next`); never act on memory. `openspec/delivery/goal.md` is a record for human readers. Goal states: ACTIVE, BLOCKED, STOPPED, COMPLETE. A task-targeted goal still delivers the parent story with its full acceptance.

Two guards are mechanical. `openspec archive` is refused while `tasks.md` has an unticked task. A story cannot become DONE while its change is still active: archive before DONE. Verify is advisory and writes no file: each CRITICAL finding becomes an unticked task in `tasks.md`, which returns the change to apply. A story acceptance scenario that is unimplemented, contradicted by its observed result or lacking observed evidence, and a project test that fails because of the change, are CRITICAL whatever rank verify gives them. Never report a scenario as passing without evidence you observed.

Start or resume delivery with the actual `${CLAUDE_SESSION_ID}` via `--session-id`. One session owns the goal; another session must pass `--takeover` explicitly. Only the owner's Stop hook continues delivery. A session that needs a human decision mid-change records it with `delivery block --reason '<decision needed>'`, then stops. Three unchanged blocks precede the fourth unchanged stop, which records BLOCKED. Platform continuation limits still apply.

The rule references are under `references/rules/`: codebase-context, specification-ingestion, gherkin, openspec, delivery-loop, team-responsibilities. Read the ones the task at hand needs; plugin rules are not automatically project memory.

Installation and updates never initialize or upgrade project data. Bootstrap, adaptation, upgrade, reset and migration are explicit and previewable. Product documents, project history and host scripts survive plugin updates and uninstall. Runtime state, backups and local approvals are private and ignored. Credentials and provider settings are user-owned. Hook checks are workflow guardrails, not OS confinement: arbitrary Bash or MCP writes can bypass Write/Edit checks.
