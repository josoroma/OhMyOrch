# OhMyOrch Claude Code plugin

OhMyOrch delivers a SPECS backlog with OpenSpec: each READY story is one change that moves through propose, apply, verify and archive. Its installed code stays in Claude's plugin cache; documents and workflow state stay in your project.

Version `0.1.0` is the plugin source in this repository; it is not tagged, and the last tagged release is `0.0.1`. Marketplace installation, cache updates and uninstall were exercised on Claude Code 2.1.292 with the previous version. Live delegated-agent identity and full story lifecycle tests remain gates for public packaged artifacts and support claims. The owner has not selected the distribution license. See the repository's implementation evidence for the scope of validation.

## Install

Install from this repository's marketplace:

```text
/plugin marketplace add josoroma/OhMyOrch
/plugin install ohmyorch@ohmyorch-marketplace
```

Choose user, project or local scope in the plugin manager. The shell equivalent for a shared project is:

```bash
claude plugin marketplace add josoroma/OhMyOrch
claude plugin install ohmyorch@ohmyorch-marketplace --scope project
```

For local development, add a checkout's absolute path as the marketplace, or launch a development session from your project with `claude --plugin-dir /absolute/checkout/plugins/ohmyorch`. Installation, update and SessionStart create no product files. Generic rules are loaded through the common contract and scoped agents, not copied to `.claude/rules`.

## Initialize a project explicitly

Prerequisites: Bash 3.2 or later, jq 1.6 or later, Git, shasum and standard Unix utilities. OpenSpec 1.13.2 is the current validation target and must be installed separately. Claude Code 2.1.292 is the preferred CLI target; 2.1.285 passed format/cache tests with the previous version, and versions before 2.1.139 cannot use the exec-form hooks. Native Windows and custom OpenSpec schemas are not supported by this implementation; WSL/Linux requires the same Unix prerequisites.

```text
/ohmyorch:doctor --json
/ohmyorch:bootstrap --dry-run --with-openspec
/ohmyorch:bootstrap --apply --with-openspec
/ohmyorch:analyze-codebase
/ohmyorch:adapt-project --dry-run
/ohmyorch:adapt-project --apply
```

Bootstrap creates only missing neutral PRD/SPECS documents, local configuration and ownership/recovery records. CODEBASE is created by analysis, not fabricated. Existing CLAUDE, PRD, SPECS, README, OpenSpec configuration and host scripts are preserved. `--mode merge` adds an owned CLAUDE block; edited owned blocks cause a conflict. Root, docs and mixed document layouts work. Ambiguous duplicates require explicit `--prd`, `--specs`, and `--codebase` mappings. Once initialized, `.claude/ohmyorch/project.json` is authoritative; remap it explicitly and run doctor.

Adaptation writes four owned project rules with evidence paths/hashes and explicit unknowns, plus managed usage blocks. `--nested` is opt-in and requires CODEBASE evidence for each directory. It does not infer a stack or invent runnable commands.

## Deliver

```text
/ohmyorch:ingest-spec <approved source>
/ohmyorch:deliver US-1.1
```

Each story is one OpenSpec change, and the main session performs every step:

| Step | Command | Result |
|---|---|---|
| Propose | `/ohmyorch:opsx-propose <change>` | `proposal.md`, delta `specs/`, `tasks.md` and, only when needed, `design.md` |
| Apply | `/ohmyorch:opsx-apply <change>` | The implementation, with each finished task ticked in `tasks.md` |
| Verify | `/ohmyorch:opsx-verify <change>` | An advisory report; no file is written |
| Archive | `openspec archive <change> -y` | Delta specs merged into `openspec/specs/`; the change moved to `openspec/changes/archive/` |

After the archive, the story is marked DONE in SPECS. Those OpenSpec artifacts are the change's whole record, and `tasks.md` is the only progress tracker. A CRITICAL verify finding is recorded as a new unticked task, which returns the change to apply. In this loop two kinds of finding are always CRITICAL: an acceptance scenario of the story that is not implemented, is contradicted by its observed result or has no observed evidence, and a project test that fails because of the change. When a story needs a human decision, the session records it with `delivery block --reason` and stops. `/ohmyorch:opsx-explore` is optional, for a story or code that is unclear.

The next action is derived from SPECS and the change directory on every call; `openspec/delivery/goal.md` is a record for readers. Two guards are mechanical: `openspec archive` is refused while `tasks.md` has unticked tasks, and a story cannot become DONE while its change is still active. The three authoring agents (`ohmyorch:codebase-analyst`, `ohmyorch:product-specifier` and `ohmyorch:spec-ingestor`) are read-only and return content that the calling skill persists.

While a goal is ACTIVE, a Stop hook derives the next action and refuses to end the turn until the goal is COMPLETE or needs a human. Three unchanged blocked stop attempts precede the fourth unchanged stop, which records BLOCKED and allows stopping. `delivery.maxStalls` configures the project default; `DELIVERY_MAX_STALLS` remains an explicit environment override. A session owns the delivery lease; another session must use `--takeover`. Nonowner Stop events do nothing. No lease expiry is inferred. If the next action cannot be derived or a human decision is required, the loop records BLOCKED.

The public CLI requires an explicit root:

```bash
# plugin_dir is your installed or development plugin location.
"$plugin_dir/bin/ohmyorch" --project-root "$(pwd -P)" doctor --json
"$plugin_dir/bin/ohmyorch" --project-root "$(pwd -P)" --session-id "$session_id" delivery start US-1.1
"$plugin_dir/bin/ohmyorch" --project-root "$(pwd -P)" delivery next --json
```

Inside skills, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PROJECT_DIR}` and `${CLAUDE_SESSION_ID}` are supported substitutions. They are not automatically Bash environment variables in ordinary tool calls. Use the concrete substituted paths, escape literal arguments, and never evaluate user arguments as shell code. Bin PATH exposure is a convenience, not the source of project identity.

## Update, migration and recovery

```text
/plugin marketplace update ohmyorch-marketplace
/plugin update ohmyorch@ohmyorch-marketplace
/ohmyorch:upgrade-project --dry-run
/ohmyorch:adapt-project --dry-run
/ohmyorch:adapt-project --apply
```

Plugin updates do not rewrite project state. Project upgrade is explicit, schema-aware and backed up. This release supports schema 1 and preserves the durable goal when moving old loop counters to ignored runtime state. A change created by an earlier plugin version can hold extra per-change files that this version no longer produces; they stay in place as project history and are ignored. Managed guidance text changes only when you run `/ohmyorch:adapt-project` again. After updating from 0.0.1, run it with `--dry-run`, then `--apply`: until then the project's `CLAUDE.md` block and `.claude/rules/ohmyorch-*-standards.md` still describe the removed flow, and `/ohmyorch:upgrade-project` does not change them. Adaptation also refreshes an `openspec/config.yaml` that is unchanged since bootstrap scaffolded it; an edited one is left alone and its old `context:` line must be changed by hand. The [changelog](CHANGELOG.md) lists what changed and, under "Upgrading from 0.0.1", gives that line, the `delivery stop` step for a goal that is still owned, and the step for an in-flight change with open review findings. Uninstall keeps project documents and state; select the same scope used to install. Recovery is separate from plugin uninstall.

```text
/ohmyorch:migrate-legacy --dry-run
/ohmyorch:migrate-legacy --apply --plan-id <reviewed hash>
/ohmyorch:harness-reset --scope managed --dry-run
/ohmyorch:harness-reset --scope workflow --dry-run
```

Migration deletes only fingerprinted legacy files and exact owned hook registrations. Unknown customizations remain. Edited legacy files require `--include-edited` in a separately reviewed plan. Never run both legacy and plugin hooks in the same project. Workflow reset requires the exact reviewed plan hash and resets only mapped PRD/SPECS and the enumerated OpenSpec files; it preserves CODEBASE, host scripts, nested human guidance and unrelated docs.

Each applied operation reports its recovery ID. Inspect with `upgrade-project --dry-run --rollback <id>`, then apply with `--apply --rollback <id>`. Recovery verifies backups and current hashes; it refuses to overwrite edits made since apply. A failed transaction rolls back its own writes. Empty directories and private recovery records may remain. A process killed during apply leaves a journal and operation lock: inspect the journal, confirm the original process is gone, remove only that empty lock directory, and run hash-guarded rollback. Never wipe runtime/backups wholesale.

## Security and limitations

Hook stdout contains protocol JSON only; diagnostics use stderr. Role checks trust Claude's top-level identity fields, not prompt text. A file-tool write from any `ohmyorch:*` agent is refused, because those agents are read-only authors. Other subagents cannot write the mapped SPECS or `openspec/delivery/`. Paths outside the project, traversal, symlinks and malformed payloads are refused. Inactive projects are no-ops. Activated projects with invalid configuration or missing validators block protected writes; project.json retains a repair route.

These are workflow guardrails, not process confinement. Arbitrary Bash/MCP writes, renamed archive executables and other extensions can bypass file-tool checks. Archive interception supports a standalone literal `openspec archive <id> -y` invocation; dynamic/chained forms are refused when detected. For stronger isolation, use Claude permissions and OS isolation separately.

Verify is advisory and is not independent evidence: the session that wrote the code also checks it. The two guards confirm only that every task is ticked before archive and that the change is archived before DONE. Review the diff yourself before you rely on a delivered story.

Host fast validation is disabled by default. Explicitly enable it in project config, review the actual script, and run `run-project-validation --approve-current`. The approval must be Git-ignored and records the current SHA-256. A changed script is skipped until reapproved. No install hook installs dependencies, executes project scripts or reads local credentials. Runtime, affected-file backups and approval are ignored; the plugin payload contains none of them.

For debugging, run doctor, strict plugin validation and Claude with `--debug`; inspect isolated logs without publishing credentials or transcripts. Live role identity tests are still required before public support claims.
