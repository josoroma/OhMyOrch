# Harness agent definitions

One Markdown file per harness role, named after the role. Frontmatter follows the
Claude Code subagent format (`name`, `description`, `tools`, `model`).

| File | Role | Status | Owner |
|---|---|---|---|
| `codebase-analyst.md` | Inspect a repository, produce `CODEBASE.md` | delivered | EPIC-2 / US-2.1 |
| `product-specifier.md` | Generate/update `PRD.md` | delivered | EPIC-2 / US-2.3 |
| `spec-ingestor.md` | Generate/update `SPECS.md` | delivered | EPIC-2 / US-2.5 |
| `product-manager.md` | Select work, orchestrate, control gates | delivered | EPIC-3 / US-3.1 |
| `planner.md` | Produce `implementation-plan.md` | delivered | EPIC-4 / US-4.1 |
| `implementer.md` | Implement the approved change | delivered | EPIC-5 / US-5.1 |
| `reviewer.md` | Verify, write `review.md` | delivered | EPIC-6 / US-6.1 |
| `tester.md` | Validate acceptance, write `test-report.md` | delivered | EPIC-7 / US-7.1 |

## Write access by role

Read-only is enforced by the tool allowlist, not only by prompt text.

| Agent | Tools | Can edit product code? |
|---|---|---|
| `codebase-analyst` | Read, Grep, Glob, Bash | No |
| `product-specifier` | Read, Grep, Glob, Bash | No |
| `spec-ingestor` | Read, Grep, Glob, Bash | No |
| `planner` | Read, Grep, Glob, Bash | No |
| `product-manager` | Read, Grep, Glob, Bash, Write, Edit, Agent | No product code |
| `implementer` | Read, Grep, Glob, Bash, Write, Edit | **Yes — sole role** |
| `reviewer` | Read, Grep, Glob, Bash, Write, Edit | No — hook-blocked |
| `tester` | Read, Grep, Glob, Bash, Write, Edit | No — hook-blocked |

`product-manager` carries `Write`/`Edit` only because it must update `SPECS.md` story
state and `status.md`. The **Implementer** is the only role whose job is to modify
product code.

`reviewer` and `tester` carry `Write`/`Edit` because each authors its own evidence
artifact, but their hooks block every product-code write — the mechanism, not the tool
list, is what enforces "must not repair".

## Hook-enforced separation of duties

Agent prompts alone cannot stop a role from writing outside its boundary. Three
definitions carry a `PreToolUse` hook running `scripts/check-write-scope.sh`:

| Agent | Role checked | Blocks |
|---|---|---|
| `implementer` | `--role ohmyorch-implementer` | `review.md`, `test-report.md` (self-approval) |
| `reviewer` | `--role ohmyorch-reviewer` | product code (repairing what it reviews) |
| `tester` | `--role ohmyorch-tester` | product code (repairing failing behavior) |

```yaml
hooks:
  PreToolUse:
    - matcher: "Write|Edit|MultiEdit"
      hooks:
        - type: command
          command: "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/check-write-scope.sh\" && exec \"$d/scripts/check-write-scope.sh\" --role <role> --hook --quiet; exit 0'"
```

The other roles are covered by the same script when invoked directly; their `tools`
allowlists already preclude product-code writes.

See `scripts/README.md` for the full matrix and `scripts/test-write-scope.sh` for the
36-case regression suite. Run `node scripts/check-frontmatter.js` after editing any
definition — a malformed file is skipped silently by Claude Code.

## Goal-driven delivery (`/ohmyorch-deliver`)

The `/ohmyorch-deliver <target>` skill (`.claude/skills/ohmyorch-deliver/SKILL.md`, US-12.2) runs the
roles as a loop over an epic, story, or task. The main session acts as the Product
Manager. It derives the next action with `scripts/delivery.sh next` and delegates it:

| Action | Agent |
|---|---|
| `propose`, `plan` | `planner` |
| `implement` | `implementer` |
| `review` | `reviewer` |
| `test` | `tester` |
| `select`, `reopen`, `archive`, `mark-done` | main session (Product Manager) |

Perform Product Manager actions in the main session. Never delegate them to a
`product-manager` subagent: `scripts/guard-delivery-loop.sh` blocks only
*main-session* writes to `review.md` / `test-report.md`, and the `product-manager`
definition carries no write-scope hook. See `.claude/rules/ohmyorch-delivery-loop.md`.

## Conventions

- Keep `description` short — Claude Code warns when combined subagent descriptions
  exceed 15,000 tokens.
- Put detail in the system prompt body, not the description.
- State the role's boundary explicitly and repeat it in a `## Boundaries` section.
- Cross-reference the owning user story under `metadata.implements` where useful.

Role boundaries and the prohibition on self-approval are defined in `CLAUDE.md` and,
from EPIC-8, `.claude/rules/ohmyorch-team-responsibilities.md`.
