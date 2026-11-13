# Changelog

## 0.1.0 — 2026-11-12 (untagged)

Breaking simplification: delivery now follows the upstream OpenSpec 1.13.2 flow and nothing else. Each READY story in SPECS is one OpenSpec change that the main session takes through propose, apply, verify and archive; then the story is marked DONE.

- A change's only artifacts are OpenSpec's own: `proposal.md`, delta `specs/`, optional `design.md` and `tasks.md`. `tasks.md` is the only progress tracker.
- `delivery next` derives one of six actions: `propose`, `apply`, `verify`, `mark-done`, `escalate`, `complete`. Its output no longer has an owner field. `delivery refresh --json` prints the derived action.
- `mark-done` is derived only when the story's change is archived, no active directory has its id and none is named for the story (`us-<n>-<m>-*`). An active change wins over an archive of the same id, and a `Change:` line that names an archived change does not close a story whose own change directory is still active: that state derives `escalate`. To redo a DONE story, set it back to READY with a new `Change:` id.
- Planning is complete when the change has `proposal.md`, a `tasks.md` with at least one checkbox and at least one `.md` file under `specs/`. `specs/` is not required when the change's `.openspec.yaml` sets `skip_specs` to `true`, `True` or `TRUE`; a trailing comment is allowed. `design.md` is never required.
- Tasks are counted the way OpenSpec 1.13.2 counts them. A `-`, `*`, `+` or numbered list item with a checkbox is a task, and any marker other than `x` or `X` is unfinished: `- [ ]`, `- [~]`, `- [-]`, `- []`, `* [ ]` and `1. [ ]` all keep the change in apply.
- Verify is advisory and writes no file. A CRITICAL finding is recorded as a new unticked task in `tasks.md`, which returns the change to apply.
- When a human decision is missing in the middle of a change, the session records it with `delivery block --reason '<story id: the decision needed>'` and stops. The goal becomes BLOCKED with that reason, and `/ohmyorch:deliver <same target>` resumes it once the decision is made.
- The seven `opsx-*` skills match the prompts OpenSpec 1.13.2 generates, apart from the plugin namespace and one boundary paragraph. They no longer run `doctor`, re-read the contract or delegate to a role agent on every invocation.
- The plugin now has 18 skills (17 public commands and the internal `contract`), three read-only authoring agents (`codebase-analyst`, `product-specifier`, `spec-ingestor`), six rule references and 13 CLI operations.

Guards that remain, with their new predicates:

- Archive: `openspec archive <id> -y` is refused while the change's `tasks.md` has an unfinished task. A change with every task ticked, or with no task checklist, is allowed. The id may be bare or in one pair of quotes. OpenSpec itself validates and merges the delta specs.
- DONE: a SPECS write that newly sets a story to `Status: DONE` is refused while that story's change is still an active directory under `openspec/changes/`. The guard judges the `Change:` id in the write and the one already on disk. It also judges every active `us-<n>-<m>-*` directory. This is stricter than 0.0.1, which allowed DONE for an unarchived change that only looked eligible. Archive first.
- Any `ohmyorch:*` agent is read-only: its file-tool writes are refused. Other subagents cannot write the mapped SPECS or `openspec/delivery/`.
- Outside targets: a Write, Edit or MultiEdit whose target is physically outside the project and Claude's plugin directory (its `data` directory excepted) is no longer refused, so Claude's own plan, memory and scratch files can be written in an activated project. An `ohmyorch:*` agent is still refused there. No other route to a file inside the project or the installed plugin skips a guard, and a target that is itself a symbolic link or contains `..` is still refused. In 0.0.1 every target outside the project was refused.

Faster hooks:

- A Write or Edit to an ordinary file no longer spawns any guard script. Only the mapped PRD and SPECS reach the CODEBASE-staleness preflight, and only the mapped SPECS reaches the DONE guard.
- A SPECS edit that is only delivery bookkeeping skips the CODEBASE-staleness preflight: `Status:` lines, `Change:` lines, the story and task rows of the `## Work Item Status` table, and the tick of a task checkbox. Adding, rewording, moving or deleting a task line is a material edit and runs the preflight. Blank lines added or removed with them are ignored. The check uses `diff`; if `diff` is unavailable, the preflight runs.
- The Stop hook derives the next action once instead of twice when it keeps the session working. A stop that records BLOCKED derives again through `delivery block`.
- Refreshing the goal record starts no process per story. The change directories are listed once, and the ids of stories without a `Change:` line are derived in the same pass as the rows.
- Host fast validation is not spawned after a write unless it is enabled in project configuration.
- The hook dispatcher initializes the runtime once instead of twice, and each initialization reads project configuration with a single `jq` call. A script that a hook spawns still initializes on its own.

Fixed:

- The DONE guard and the archive detection no longer miss a match in a SPECS document or a Bash command larger than the pipe buffer. In 0.0.1 such a write or command could be allowed.
- The hook dispatcher hands the prospective SPECS to the DONE guard as a file (`guard-story-done --content-file`), not as one argument. Linux refuses a single argument of 128 KiB or more, which blocked every write to a SPECS of that size.
- A `project.json` that holds more than one JSON document is rejected as invalid configuration. In 0.0.1 it was accepted with unusable values.
- `delivery` no longer leaves a temporary `goal.*` file behind when the goal record cannot be written.
- The CODEBASE preflight honours the two decisions it offers. A `CODEBASE Context: skipped (<reason>)` line, or `CODEBASE Context: consumed (<revision>, staleness accepted)` for the recorded revision, in the PRD or SPECS being written lets that write proceed. In 0.0.1 the write that added either line was itself refused. A commit that touches only the mapped PRD, SPECS or CODEBASE no longer makes the analysis stale.
- Archive interception refuses a global option before `archive`, such as `openspec --no-color archive <id> -y`, and any command of more than one line. In 0.0.1 the `--no-color` form reached OpenSpec without the task check.
- A SPECS document with CRLF line endings is parsed. In 0.0.1 every story in it escalated as not READY.
- A story title with no ASCII letter or digit, or made only of stop words, derives the change id `us-<n>-<m>-story`. In 0.0.1 the derived id ended in a hyphen, which OpenSpec refuses.
- A derived change id is the same in every locale: a byte outside ASCII separates words. In 0.0.1 the id depended on the locale of the process that derived it. On macOS under a UTF-8 locale, `İ` and the Kelvin sign became the letters `i` and `k`; under a legacy charset locale, other bytes could stay in the id.
- An archived change is recognised by its literal id. A `Change:` value with pattern characters, such as `us-1-1-*`, no longer counts as archived because some archive entry matches it.
- Every hook refusal names its reason on stderr. In 0.0.1 a malformed write payload, or a Bash payload whose command is not a string, was refused with no message.
- In an enabled project a missing or non-executable bundled `delivery.sh` or `validate-product-artifacts.sh` is reported as `missing bundled validator: <name>` and refused in every hook mode.
- With no `CODEBASE.md`, the product-artifact validator reports a `CODEBASE Context: skipped (<reason>)` line as a recorded skip decision. In 0.0.1 it advised removing the line.
- The CODEBASE check recognises a repository without a package manifest as a codebase whatever its listing of source files looks like. In 0.0.1 a listing longer than about 16 KiB, or one that `find` could not finish because of an unreadable directory, read as no source at all, and the check passed as for an empty project.

Removed:

- Skills: `plan-feature`, `review-feature`, `test-feature`, `product-iteration`, and `post-install`, which was only an alias: use `/ohmyorch:adapt-project`.
- Agents: `planner`, `implementer`, `reviewer`, `tester`, `product-manager`.
- CLI operations and their scripts (11): `workflow-status`, `status`, `completion-gate`, `validate-implementation-plan`, `validate-review`, `validate-test-report`, `validate-status`, `validate-verification`, `check-write-scope`, `check-scope`, `guard-planning-handoff`.
- The `migrate-legacy` skill and CLI operation, the `legacy` check of `doctor`, and the relocation of an old `openspec/delivery/loop.state` counter by `upgrade-project`. A setup from before OhMyOrch was a plugin is no longer detected or converted.
- `delivery reopen` and the `--change` option of `delivery`.
- Per-change artifacts: `implementation-plan.md`, `review.md`, `test-report.md`, `status.md`, `completion.md` and `history/`, together with their templates under `templates/artifacts/`.
- Rule reference `testing.md`.
- Scaffold `SPEC-LOGS/README.md`: `bootstrap --with-openspec` no longer creates it, because nothing writes epic logs.
- `templates/project/project.schema.json`, which no code read.
- Concepts: the seven gates, the four completion conditions, verdict history, reopen and remediation rounds, the predicted-files scope contract, change states and per-stage owners. The partial/UNVERIFIED acceptance exceptions that 0.0.1 retained are gone because the evaluators that had them were removed.

Upgrading from 0.0.1:

- Project schema 1 is unchanged. No `/ohmyorch:upgrade-project` run is required.
- Existing projects may still contain files such as `review.md`, `status.md` or `history/` in active or archived changes. They are left in place as project history; the plugin ignores them and never deletes or rewrites them.
- An in-flight 0.0.1 change with open review findings or a failed test report needs one manual step. Before resuming, turn each open finding into an unticked task in that change's `tasks.md`, because the old files are no longer read.
- The managed guidance text written by bootstrap and adaptation changed. After updating, run `/ohmyorch:adapt-project --dry-run`, then `--apply`. Until then the project's `CLAUDE.md` block and `.claude/rules/ohmyorch-*-standards.md` still describe the removed flow, and `/ohmyorch:upgrade-project` does not change them. Edited owned blocks still conflict instead of being overwritten.
- `/ohmyorch:adapt-project` also refreshes an `openspec/config.yaml` that is unchanged since bootstrap scaffolded it. An edited one is left alone and keeps the old `context:` line `OhMyOrch handles independent planning, implementation, review and testing.` Change that line by hand to `Each READY story is delivered as one OpenSpec change: propose, apply, verify, archive.`
- Lifecycle operations are refused while a session owns a delivery goal. If a goal from 0.0.1 is still owned, run `delivery stop` before `/ohmyorch:adapt-project`, then resume with `/ohmyorch:deliver <same target>`. When the session that owns the goal is not the current one, the stop needs an explicit takeover: `"<plugin-root>/bin/ohmyorch" --project-root /absolute/project --session-id <current session id> --takeover delivery stop`.
- Live agent/lifecycle validation and the owner-approved license remain gates for public packaged artifacts and support claims.

## 0.0.1 — 2026-10-07

- Convert 18 standalone workflows to 24 plugin skills and eight scoped agents.
- Bundle runtime, generic contracts, validators and templates behind explicit project roots.
- Replace ignored agent hooks with one identity-aware root dispatcher.
- Preserve seven gates, four completion conditions, verdict history and bounded delivery continuation.
- Add session ownership, schema 1 project configuration, create-only bootstrap, managed adaptation, reviewed legacy migration and affected-file recovery.
- Add a colocated marketplace, isolated cache lifecycle tests and allowlisted release tooling.
- Publish the plugin source, marketplace catalog, human-readable overview and visual delivery guide as version 0.0.1.
- Add the standalone SPECS Kanban/document workspace, coherent project examples, original screenshots and local setup instructions.
- Consolidate published history into one root commit with the sole literal release tag 0.0.1 by explicit owner direction.
- Keep live agent/lifecycle validation and the owner-approved license as gates for public packaged artifacts and support claims.
- Parse recorded CODEBASE revisions portably with BSD/GNU awk so stale-context checks retain the same gate behavior on Linux and macOS.
- Consume HTML validator predicate input completely under pipefail; preserve security checks and cover large pages in regression tests.

Breaking invocation changes: `ohmyorch-*` standalone skills become `/ohmyorch:<short-name>`; nested `opsx:*` commands become flat `/ohmyorch:opsx-*`. No compatibility command aliases are shipped. Reset no longer wipes scripts or arbitrary nested CLAUDE files. Existing acceptance ambiguities are retained.
