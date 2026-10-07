# OhMyOrch operational contract

Human decisions and approved source documents govern intent. CODEBASE is descriptive evidence. Missing behavior becomes NEEDS CLARIFICATION or BLOCKED, never a fabricated requirement.

Resolve the explicit project root and `.claude/ohmyorch/project.json` before acting. Doctor returns the per-document mapping; all PRD/SPECS/CODEBASE names mean those mapped paths. OpenSpec uses the local `spec-driven` schema under `openspec/`.

The main session coordinates one bounded story/change. Analyst/specifier/ingestor/planner return authored content; the caller persists their handoffs. Implementer edits product code/tests and selected tasks. Scoped reviewer/tester persist only their selected verdict and never repair product code. The coordinator reads/validates verdicts and owns goal/status/completion and backlog transitions. A caller cannot substitute for specialist evidence.

Read the applicable references under `references/rules/`: codebase-context, specification-ingestion, gherkin, openspec, team-responsibilities, testing, delivery-loop. Every entry skill/agent must load the relevant content explicitly; plugin rules/CLAUDE are not automatically project memory.

Derive next action after each result. Preserve seven ordered gates (selection, planning, plan-handoff, implementation, review, testing, acceptance) and four separate completion conditions (tasks, review, acceptance, openspec-verification). Archive before DONE. Reopen preserves prior verdict history, adds remediation tasks and requires fresh implementation/review/testing. Task focus still carries the parent story's acceptance. Goal states: ACTIVE, BLOCKED, STOPPED, COMPLETE.

Start/resume delivery with the actual `${CLAUDE_SESSION_ID}` via `--session-id`; another session must explicitly use --takeover. Only the owner Stop hook continues delivery. Three unchanged blocks precede the fourth unchanged stop, which records BLOCKED. Platform continuation limits still apply.

Current legacy acceptance permits some partial/mixed PASS/UNVERIFIED reports and verification text has known substring ambiguity. Preserve/report that behavior; never assert an unverified criterion passed or advertise complete coverage beyond evidence. Stronger policies require a separate versioned decision.

Installation/update never initializes or upgrades project data. Bootstrap/adaptation/reset/migration are explicit and previewable. Product documents/history and host scripts survive plugin updates/uninstall. Runtime/backups/local approvals are private and ignored. Credentials/provider settings are user-owned. Hook checks are workflow guardrails, not OS confinement; arbitrary Bash/MCP writes can bypass Write/Edit checks.
