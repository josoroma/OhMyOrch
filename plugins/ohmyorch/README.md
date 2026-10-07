# OhMyOrch Claude Code plugin

OhMyOrch coordinates OpenSpec delivery through independent planning, implementation, review and testing. Its installed code stays in Claude's plugin cache; documents and workflow state stay in your project.

Version `0.0.1` is the plugin distribution published in this repository. Marketplace installation, cache updates and uninstall have been exercised on Claude Code 2.1.292. Live delegated-agent identity and full story lifecycle tests remain gates for public packaged artifacts and support claims. The owner has not selected the distribution license. See the repository's implementation evidence for the scope of validation.

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

Prerequisites: Bash 3.2 or later, jq 1.6 or later, Git, shasum and standard Unix utilities. OpenSpec 1.13.2 is the current validation target and must be installed separately. Claude Code 2.1.292 is the preferred CLI target; 2.1.285 passes format/cache tests, and versions before 2.1.139 cannot use the exec-form hooks. Native Windows and custom OpenSpec schemas are not supported by this implementation; WSL/Linux requires the same Unix prerequisites.

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

The main session coordinates one story/change and persists read-only specialists' handoffs. `ohmyorch:implementer` edits product code and selected tasks; `ohmyorch:reviewer` writes the selected review; `ohmyorch:tester` writes the selected test report. Verdict authors never repair the code. Seven ordered gates and four separate completion conditions drive resumption. Reopen preserves verdict history and adds remediation tasks. Archive precedes DONE.

Three unchanged blocked stop attempts precede the fourth unchanged stop, which records BLOCKED and allows stopping. `delivery.maxStalls` configures the project default; `DELIVERY_MAX_STALLS` remains an explicit environment override. A session owns the delivery lease; another session must use `--takeover`. Nonowner Stop events do nothing. No lease expiry is inferred. If the gate reporter could not report, an unmapped gate appears, or human clarification is needed, the loop records BLOCKED.

The public CLI requires an explicit root:

```bash
# plugin_dir is your installed or development plugin location.
"$plugin_dir/bin/ohmyorch" --project-root "$(pwd -P)" doctor --json
"$plugin_dir/bin/ohmyorch" --project-root "$(pwd -P)" --session-id "$session_id" delivery start US-1.1
"$plugin_dir/bin/ohmyorch" --project-root "$(pwd -P)" --session-id "$session_id" status --change selected
```

Inside skills, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PROJECT_DIR}` and `${CLAUDE_SESSION_ID}` are supported substitutions. They are not automatically Bash environment variables in ordinary tool calls. Use the concrete substituted paths, escape literal arguments, and never evaluate user arguments as shell code. Bin PATH exposure is a convenience, not the source of project identity.

## Update, migration and recovery

```text
/plugin marketplace update ohmyorch-marketplace
/plugin update ohmyorch@ohmyorch-marketplace
/ohmyorch:upgrade-project --dry-run
```

Plugin updates do not rewrite project state. Project upgrade is explicit, schema-aware and backed up. This release supports schema 1 and preserves the durable goal when moving old loop counters to ignored runtime state. Uninstall keeps project documents and state; select the same scope used to install. Recovery is separate from plugin uninstall.

```text
/ohmyorch:migrate-legacy --dry-run
/ohmyorch:migrate-legacy --apply --plan-id <reviewed hash>
/ohmyorch:harness-reset --scope managed --dry-run
/ohmyorch:harness-reset --scope workflow --dry-run
```

Migration deletes only fingerprinted legacy files and exact owned hook registrations. Unknown customizations remain. Edited legacy files require `--include-edited` in a separately reviewed plan. Never run both legacy and plugin hooks in the same project. Workflow reset requires the exact reviewed plan hash and resets only mapped PRD/SPECS and the enumerated OpenSpec files; it preserves CODEBASE, host scripts, nested human guidance and unrelated docs.

Each applied operation reports its recovery ID. Inspect with `upgrade-project --dry-run --rollback <id>`, then apply with `--apply --rollback <id>`. Recovery verifies backups and current hashes; it refuses to overwrite edits made since apply. A failed transaction rolls back its own writes. Empty directories and private recovery records may remain. A process killed during apply leaves a journal and operation lock: inspect the journal, confirm the original process is gone, remove only that empty lock directory, and run hash-guarded rollback. Never wipe runtime/backups wholesale.

## Security and limitations

Hook stdout contains protocol JSON only; diagnostics use stderr. Role checks trust Claude's top-level identity fields, not prompt text. Reviewer/tester writes are restricted to the selected change. Paths outside the project, traversal, symlinks and malformed payloads are refused. Inactive projects are no-ops. Activated projects with invalid configuration or missing validators block protected writes; project.json retains a repair route.

These are workflow guardrails, not process confinement. Arbitrary Bash/MCP writes, renamed archive executables and other extensions can bypass file-tool checks. Archive interception supports a standalone literal `openspec archive <id> -y` invocation; dynamic/chained forms are refused when detected. For stronger isolation, use Claude permissions and OS isolation separately. Existing partial/mixed PASS/UNVERIFIED acceptance and verification-text substring ambiguity are preserved and documented; a passing legacy gate does not assert complete verified coverage.

Host fast validation is disabled by default. Explicitly enable it in project config, review the actual script, and run `run-project-validation --approve-current`. The approval must be Git-ignored and records the current SHA-256. A changed script is skipped until reapproved. No install hook installs dependencies, executes project scripts or reads local credentials. Runtime, affected-file backups and approval are ignored; the plugin payload contains none of them.

For debugging, run doctor, strict plugin validation and Claude with `--debug`; inspect isolated logs without publishing credentials or transcripts. Live role identity tests are still required before public support claims.
