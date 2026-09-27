# Implementation Plan — us-12-2-run-delivery-goal-loop

Story: US-12.2
Change: us-12-2-run-delivery-goal-loop

## Selected Story

US-12.2 — Run the Delivery Goal Loop. In `SPECS.md` it is `Status: IN PROGRESS`, with `Change: openspec/changes/us-12-2-run-delivery-goal-loop/`, under `# EPIC-12: Goal-Driven Delivery Orchestration`.

This change delivers US-12.2 alone. It adds three things:

- a `/deliver <target>` orchestrator skill;
- a `Stop` gate that keeps the main session working while an ACTIVE goal has a non-escalating next action;
- a `PreToolUse` guard that stops the orchestrator from authoring `review.md` or `test-report.md`.

US-12.1 is out of scope except for one addition, `delivery.sh block`. US-12.3 (README and index documentation) is also out of scope, per `proposal.md` §Out of Scope.

The declared dependency is US-12.1. `SPECS.md` records it as `Status: DONE`, and the archive holds `openspec/changes/archive/2026-09-24-us-12-1-resolve-delivery-target-report/`.

`CODEBASE.md` is absent (greenfield), so nothing was consumed.

## OpenSpec Artifacts

- `proposal.md`: creates `.claude/skills/deliver/SKILL.md`, `.claude/rules/delivery-loop.md` and `scripts/guard-delivery-loop.sh` (Stop mode plus PreToolUse mode). It adds `delivery.sh block --reason <text>`, stated as "the only change to US-12.1's script". It also adds a goal-driven delivery section to `.claude/agents/product-manager.md`, extends `scripts/test-delivery.sh`, and wires `.claude/settings.json` (`Stop` hook, one `PreToolUse` entry, allow-list). The proposal forbids changes to any gate, validator, or the archive guard.
- `specs/delivery-loop/spec.md`: the new `delivery-loop` capability, with six ADDED requirements and one scenario each: Start a delivery goal; Continue while work remains; Halt for a human decision; Halt when the loop stops making progress; Complete the goal; The loop cannot bypass a gate. These match the six Gherkin scenarios in `SPECS.md` US-12.2 word for word.
- `tasks.md`: 13 unticked tasks. 1.1–1.7 are deliverables and 2.1–2.6 are regression cases, one per scenario. Each deliverable task already names its scenarios, and every task is mapped below.
- `design.md`: records five decisions.
  1. The loop is enforced by a `Stop` hook with exit 2 and stderr fed back to Claude, not by the prompt. `type: prompt` and `type: agent` hooks were rejected.
  2. Progress is fingerprinted on the full `delivery.sh next --json` output and stored in git-ignored `openspec/delivery/loop.state` as `target`, `fingerprint` and `count`. `max` defaults to 3 and can be changed with `DELIVERY_MAX_STALLS` or `--max-stalls`. Decision 2 rejects `stop_hook_active` as a progress signal.
  3. A main-session write to `review.md` or `test-report.md` during an ACTIVE goal is blocked. Subagent writes carry `agent_id` and are left to that subagent's hook. `"agent_id":` counts only when it is not preceded by a backslash. Decision 3 rejects a skill-frontmatter hook.
  4. The hook records outcomes through `delivery.sh` (`block` or `refresh`) so `goal.md` has a single writer.
  5. The hook fails open when `delivery.sh` is missing, `goal.md` is missing, the goal is not ACTIVE, the payload comes from a subagent, or the goal cannot be resolved (it records BLOCKED first).

  It also defines the transitions ACTIVE→COMPLETE, ACTIVE→BLOCKED, ACTIVE→STOPPED, and BLOCKED|STOPPED→ACTIVE on `start <same target>`.
- `status.md`: derived state, currently `PROPOSED` with owner planner. It is refreshed by `scripts/status.sh` and is not an Implementer artifact.

## Implementation Order

1. **`delivery.sh block --reason <text>` (task 1.3).** Stop mode depends on it for the escalate and no-progress outcomes, and on the resolver-failure fallback.
2. **`scripts/guard-delivery-loop.sh`, shared skeleton.** This covers:
   - argument parsing (`--hook`, `--quiet`, `--max-stalls <n>`, `-h`);
   - repository-root resolution from `$0`;
   - reading stdin once;
   - the `json_str` awk decoder copied from `scripts/guard-story-done.sh` lines 86–106;
   - the subagent test;
   - the goal `Status` reader.

   Steps 3 and 4 both depend on it.
3. **Stop mode (task 1.4)**, following design §2, §4 and §5. The order inside it is: fail-open exits, then fingerprinting, then the outcome table. It depends on step 1.
4. **PreToolUse mode (task 1.5)**, following design §3. It depends only on step 2.
5. **`scripts/test-delivery.sh` cases (tasks 2.1–2.6).** Write them next to steps 1–4 and run them after each step. Stage `guard-delivery-loop.sh` and `guard-archive.sh` into the throwaway copy.
6. **`.claude/settings.json` wiring and allow-list (task 1.6).** Do this after the suite passes. Wiring turns the Stop gate on in *this* repository, where `openspec/delivery/goal.md` is already `ACTIVE` for `EPIC-12` (see Risks).
7. **`.claude/rules/delivery-loop.md` (task 1.2).** Durable rules. Write them after the guard, so the rules describe the mechanism that exists.
8. **`.claude/skills/deliver/SKILL.md` (task 1.1).** The orchestrator. It references the rule and the guard.
9. **`.claude/agents/product-manager.md` goal-driven delivery section (task 1.7).** It references the skill and the rule.
10. **Full harness regression.** Run `scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh && scripts/test-completion.sh && scripts/test-delivery.sh`, then `node scripts/check-frontmatter.js`, `scripts/validate-product-artifacts.sh`, `openspec validate us-12-2-run-delivery-goal-loop --strict`, a JSON parse of `.claude/settings.json`, and `scripts/check-scope.sh` against a pre-implementation baseline.

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Create `.claude/skills/deliver/SKILL.md` (start or resume, derive, delegate by owner, refresh, never author verdicts) | Scenario: Start a delivery goal | "When the delivery skill is invoked", "each next action MUST be delegated to the role that owns it", and "the orchestrator MUST NOT author review.md or test-report.md" are all behaviours of this skill. The recording step is `scripts/delivery.sh start <target>`. |
| 1.2 Create `.claude/rules/delivery-loop.md` | Scenario: Start a delivery goal; Scenario: Continue while work remains; Scenario: Halt for a human decision; Scenario: Halt when the loop stops making progress; Scenario: Complete the goal; Scenario: The loop cannot bypass a gate | Durable context for all six scenarios. It states each one as a rule and names the gate that enforces it, following the `.claude/rules/README.md` "Rules versus gates" convention. It is verified by inspection. |
| 1.3 Add `delivery.sh block --reason` (records BLOCKED, preserves target, started date, and notes) | Scenario: Halt for a human decision; Scenario: Halt when the loop stops making progress | Both Then/And clauses say "the goal MUST be recorded as BLOCKED". `block` is the recorder (design §4). |
| 1.4 Create `scripts/guard-delivery-loop.sh` Stop mode (continue, escalate, no-progress, complete, fail-open) | Scenario: Continue while work remains; Scenario: Halt for a human decision; Scenario: Halt when the loop stops making progress; Scenario: Complete the goal | Each outcome row in the design §1 and §4 tables is one scenario. Fail-open is design §5 and the harness hook convention. |
| 1.5 Add the `guard-delivery-loop.sh` PreToolUse mode blocking main-session writes to review.md / test-report.md during an ACTIVE goal | Scenario: Start a delivery goal | The mechanical backing for "the orchestrator MUST NOT author review.md or test-report.md". |
| 1.6 Wire the `Stop` hook and the `PreToolUse` entry in `.claude/settings.json`; allow-list the guard | Scenario: Continue while work remains; Scenario: Start a delivery goal | Without the wiring, no Stop hook fires ("a Stop hook MUST block the stop") and the write guard never runs. The suite cannot exercise it end to end, so it is verified by inspection and a JSON check (see Test Strategy §G). |
| 1.7 Add goal-driven delivery to `.claude/agents/product-manager.md` | Scenario: Start a delivery goal; Scenario: The loop cannot bypass a gate | The Product Manager owns the archive decision and the `reopen` / `mark-done` actions. The section must say that `/deliver` archives only through the guarded `openspec archive` path. Verified by inspection. |
| 2.1 Regression cases for Scenario: Start a delivery goal | Scenario: Start a delivery goal | Test Strategy §A. |
| 2.2 Regression cases for Scenario: Continue while work remains | Scenario: Continue while work remains | Test Strategy §B. |
| 2.3 Regression cases for Scenario: Halt for a human decision | Scenario: Halt for a human decision | Test Strategy §C. |
| 2.4 Regression cases for Scenario: Halt when the loop stops making progress | Scenario: Halt when the loop stops making progress | Test Strategy §D. |
| 2.5 Regression cases for Scenario: Complete the goal | Scenario: Complete the goal | Test Strategy §E. |
| 2.6 Regression cases for Scenario: The loop cannot bypass a gate | Scenario: The loop cannot bypass a gate | Test Strategy §F. |

All 13 tasks are mapped, and none is unmapped. Tasks 1.2, 1.6 and 1.7 are satisfied partly by inspection, because a Markdown contract or a hook registration cannot be run by the suite. This is stated in Test Strategy so the Tester can score these parts `UNVERIFIED` rather than inferring `PASS`.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `scripts/delivery.sh` | Likely +30–50 lines. Changes: a `block)` branch in the main `case "$CMD"` dispatch; a `block` line in `usage()` and in the header `Usage:` block; `--reason` required and non-empty, with exit 2 when missing. The branch calls `load_goal`, then `refresh_goal BLOCKED "$REASON_ARG"`, and removes `openspec/delivery/loop.state`. It also needs a **fallback for a target that no longer resolves**: `load_goal` calls `die` when `resolve_target` fails (lines 507–513), which would stop `block` from recording the resolver error that design §5 requires. The fallback should rewrite only the `\| Status \|`, `\| Reason \|` and `\| Updated \|` rows in place with awk, leaving Target, Started, Stories and Notes untouched. The existing option loop already parses `--reason` (lines 649–657), so no parser change is needed. | Read lines 25–35 (header), 53–73 (`usage`), 491–523 (`goal_field`, `goal_notes`, `write_goal`, `load_goal`, `refresh_goal`) and 641–752 (dispatch). `refresh_goal` already preserves Notes through `goal_notes`, and Started through `G_STARTED`. `start` with the same target resumes a BLOCKED goal (lines 700–706), which satisfies design "BLOCKED \| STOPPED → ACTIVE". |
| `scripts/guard-delivery-loop.sh` | New file, likely 180–260 lines of bash. **Header:** purpose, the scenarios it implements, exit codes (0 allow, 2 block, 3 usage error, the `guard-archive.sh` convention), and "Dependencies: bash, awk, grep, sed, cksum — no Node/Python (NFR-001)". **Mode:** chosen from the payload's `"hook_event_name"`: `Stop` selects Stop mode, `PreToolUse` selects the write guard, anything else is exit 0. **Root:** `cd` to the repository root taken from `$0`, because `delivery.sh` and the gate reporters use relative paths. **Stop mode:** follows design §1, §2, §4 and §5. The block message goes to stderr and is printed **even with `--quiet`**, which suppresses only allow messages. **PreToolUse mode:** follows design §3, taking `file_path` through `json_str`. | Does not exist yet (`ls` fails). The hook-JSON decoder idiom was read in `scripts/guard-story-done.sh` lines 86–106 and `scripts/guard-archive.sh` lines 85–101. The greedy-sed pitfall is documented at `guard-archive.sh` lines 79–84. Exit codes and `--quiet` semantics come from `guard-archive.sh` lines 26 and 41–56. The subagent test comes from design §3. |
| `scripts/test-delivery.sh` | Append sections for the six US-12.2 scenarios, before `# Summary`. Add `guard-delivery-loop.sh` and `guard-archive.sh` to the staging `for f in …` list (line 86). Extend the header "properties this suite protects" list. The existing US-12.1 cases stay as they are. | Read the whole file (412 lines): the helpers `check`, `expect_contains`, `expect_absent`, `expect_eq`, `action_of`; the staging at lines 84–97; the stub `SPECS.md` with EPIC-1 (READY), EPIC-2 (NEEDS CLARIFICATION), EPIC-3 (dependencies) and EPIC-4 (in flight / DONE); and `PATH=/usr/bin:/bin:/usr/sbin:/sbin` (line 99). The header already names US-12.2 (line 3). |
| `.claude/settings.json` | **(a)** Add a new `"Stop"` key under `hooks`: `[ { "hooks": [ { "type": "command", "command": "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/guard-delivery-loop.sh\" && exec \"$d/scripts/guard-delivery-loop.sh\" --hook --quiet; exit 0'", "statusMessage": "Checking the delivery goal" } ] } ]`. Stop takes no `matcher`. **(b)** Append one entry to the existing `PreToolUse` `"matcher": "Write\|Edit\|MultiEdit"` group, using the same wrapper and a `statusMessage` such as "Checking delivery verdict authorship". **(c)** Add `"Bash(bash scripts/guard-delivery-loop.sh:*)"` and `"Bash(scripts/guard-delivery-loop.sh:*)"` to `permissions.allow`. | Read the file (137 lines). Every harness hook uses the `sh -c 'd=…; test -x … && exec … --hook --quiet; exit 0'` wrapper (lines 80–120). `exec` passes on exit 2, and a missing script falls through to `exit 0`. `permissions.allow` pairs `bash scripts/X.sh` and `scripts/X.sh` for every harness script. There is no `Stop` key today (grep for `"Stop"` returns nothing). |
| `.claude/rules/delivery-loop.md` | New Markdown rule with no frontmatter, like the other rules. Sections cover: the loop; who owns each action (the owner vocabulary from `delivery.sh`: `product-manager`, `planner`, `implementer`, `reviewer`, `tester`, `human-product-manager`); when the loop stops (complete, escalate, no progress); what it must never do (author verdicts, bypass `guard-archive.sh`, resolve ambiguity, run two changes); `loop.state` semantics; and the mechanical enforcement for each rule. | Read `.claude/rules/*.md`. They have no frontmatter, cite their source (`PRD.md`, `SPECS.md` ids), and use blockquoted MUST rules. The owner strings come from `derive_next` in `scripts/delivery.sh` lines 254–396. |
| `.claude/skills/deliver/SKILL.md` | New skill. **Frontmatter:** `name: deliver`, `description` (with trigger phrases), `allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent`, `license: MIT`, `compatibility`, `metadata.author: claude-harness`, `metadata.version: "1.0"`, `metadata.implements: "US-12.2"`, `argument-hint: [target]`, and **no `hooks:`** (design §3). **Body:** start or resume with `scripts/delivery.sh start $ARGUMENTS`; loop over `scripts/delivery.sh next`; an owner→delegation table (planner → `/opsx:explore`, `/opsx:propose`, `/plan-feature` via the `planner` agent; implementer → `implementer` agent / `/opsx:apply`; reviewer → `reviewer` agent / `/review-feature`; tester → `tester` agent / `/test-feature`; product-manager → `select`, `reopen`, `archive`, `mark-done` in the main session through the guarded commands; human-product-manager → stop and report); `scripts/delivery.sh refresh` after each action; and Boundaries. | Frontmatter convention read from `.claude/skills/product-iteration/SKILL.md` lines 1–12. `scripts/check-frontmatter.js` requires `name` for each `.claude/skills/*/SKILL.md` (lines 42–54). The action set and commands come from `derive_next` output. |
| `.claude/agents/product-manager.md` | Add one `## Goal-driven delivery` section, likely between `## Resuming an iteration` (line 158) and `## Recording state` (line 191). It covers: `/deliver` as the entry point; the goal record; the PM-owned actions (`select`, `reopen`, `archive`, `mark-done`); the Stop gate and when it releases; that archival still goes through `guard-archive.sh` and `completion-gate.sh`; and that escalation hands the decision to the human Product Manager. The frontmatter and the other sections stay as they are. | Read the section headings (`grep -n '^#'`), lines 54–125 and 276–294. The agent has `tools: … Write, Edit, Agent` and **no** write-scope hook in its frontmatter (see Risks). |
| `openspec/changes/us-12-2-run-delivery-goal-loop/tasks.md` | Checkbox ticks only, made by the Implementer. | `check-write-scope.sh` lines 176–178 allow the implementer to tick `tasks.md`. Gate 4 counts ticks (`0/13 tasks complete` in the current `workflow-status.sh` output). |
| `openspec/delivery/goal.md` | Not an Implementer deliverable. It may be rewritten as a side effect if `delivery.sh refresh` / `next` / the wired Stop hook run in this repository. | The file is tracked (`.gitignore` lines 17–20) and is currently `Target EPIC-12`, `Status ACTIVE`. |

`.gitignore` is expected to stay unchanged. The `openspec/delivery/loop.state` entry already exists (line 20), and `git check-ignore -v openspec/delivery/loop.state` matches it. The following are also expected to stay unchanged, because proposal §Out of Scope assigns their documentation to US-12.3 and forbids changes to gates:

- `scripts/guard-archive.sh`, `scripts/check-write-scope.sh`, `scripts/workflow-status.sh`, `scripts/completion-gate.sh`;
- all fixtures;
- `scripts/README.md`, `.claude/rules/README.md` (index), `CLAUDE.md`, `README.md`.

## Test Strategy

Automated cases go in `scripts/test-delivery.sh`, which is run by `scripts/test-delivery.sh`. They reuse the existing staged copy, the stub `SPECS.md` and the `PATH` without `openspec`. The Tester's acceptance evidence is separate, in `test-report.md`.

**Shared helpers to add:**

- `stop_payload`, which prints `{"session_id":"t","hook_event_name":"Stop","stop_hook_active":false}`, plus a variant with `"stop_hook_active":true` and a variant with `"agent_id":"a1"`.
- `write_payload <path> [agent]`, which prints a PreToolUse `Write` payload: `{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"<path>","content":"…"}}`, with `"agent_id":"a1"` added when a second argument is given.
- `run_stop`, which pipes a payload into `scripts/guard-delivery-loop.sh --hook --quiet` and captures stderr and the exit code separately (`err=$( … 2>&1 >/dev/null )`).
- `goal_status`, which is `sed -n 's/^| Status | \(.*\) |$/\1/p' openspec/delivery/goal.md`.

**§A — Scenario: Start a delivery goal (2.1)**

- `rm -rf openspec/delivery; scripts/delivery.sh start EPIC-1` exits 0. `goal.md` then contains `| Target | EPIC-1 |`, `| Status | ACTIVE |` and a Stories row for each of `US-1.1`, `US-1.2` and `US-1.3`. This is the recording half.
- Write guard with an ACTIVE goal:
  - a main-session `Write` to `openspec/changes/us-4-2-x/review.md` exits 2, and stderr names `review.md`;
  - the same for `test-report.md` exits 2;
  - an `Edit` payload (`file_path`, `old_string`, `new_string`) to `review.md` exits 2;
  - a `MultiEdit` payload to `review.md` exits 2;
  - the `review.md` write with a top-level `"agent_id":"a1"` exits 0, because it is delegated to the subagent's own hook;
  - a main-session write whose `content` contains the escaped text `\"agent_id\":\"x\"` and has no top-level `agent_id` still exits 2 (design §3 escaping rule);
  - a main-session write to `tasks.md` or `scripts/x.sh` exits 0;
  - with the goal `STOPPED`, the `review.md` write exits 0;
  - with no `goal.md`, it exits 0;
  - an empty stdin exits 0.
- Delegation by owner, checked structurally with grep: `.claude/skills/deliver/SKILL.md` names each owner (`planner`, `implementer`, `reviewer`, `tester`, `product-manager`, `human-product-manager`) and the `delivery.sh start`, `next` and `refresh` commands. It contains no `hooks:` frontmatter key (`awk` over the frontmatter block). Whether the skill actually delegates at run time cannot be run in bash. **That part is verified by inspection** of the skill text, and the Tester should score it `UNVERIFIED` unless it is exercised in a live Claude Code session.

**§B — Scenario: Continue while work remains (2.2)**

- `start EPIC-4` with `openspec/changes/us-4-2-x` staged at "unticked task" (next action `implement`). The Stop payload exits 2.
- stderr contains `implement` and `implementer`, which covers "MUST name the next action and its owner". It also contains the command `/opsx:apply us-4-2-x`.
- `goal_status` is still `ACTIVE`.
- `openspec/delivery/loop.state` exists with count 1.
- `stop_hook_active: true` still blocks (exit 2), because design §2 does not use that flag to release the stop.
- A second stage (tick the tasks, so the action becomes `review` / reviewer) blocks and names `reviewer`. This shows the message follows the derived state.
- `--quiet` does not suppress the block message: stderr is non-empty with `--quiet`.

**§C — Scenario: Halt for a human decision (2.3)**

- `stop; start EPIC-2` (NEEDS CLARIFICATION) and confirm `action_of` is `escalate`. The Stop payload exits 0.
- `goal_status` is `BLOCKED`, and the `| Reason |` row contains `NEEDS CLARIFICATION`.
- `loop.state` is absent.
- A second case uses `US-3.1` (unfinished dependency): exit 0, `BLOCKED`, and the reason contains `US-3.2`.
- `delivery.sh block` directly:
  - add a line between the AUTHORED notes markers first, then run `block --reason "test reason"`;
  - Status is `BLOCKED` and Reason is `test reason`;
  - Target and Started are unchanged (compare before and after with `goal_field`-style `sed`);
  - the note line is preserved.
- `block` with no `--reason` exits 2. `block` with no `goal.md` exits 1.
- Resume: `start <same target>` after `block` gives `ACTIVE` with the same Started.
- Fail open with record: remove the goal's epic heading from a copy of `SPECS.md`, so `next` cannot resolve the target. The Stop payload exits 0, and `goal_status` is `BLOCKED` with a Reason containing `no longer resolves`. This exercises the `block` fallback. Restore `SPECS.md` afterwards.

**§D — Scenario: Halt when the loop stops making progress (2.4)**

- Stage the `implement` state and set `DELIVERY_MAX_STALLS=2`. Three unchanged Stop attempts give exits `2`, `2`, `0`. After the third, `goal_status` is `BLOCKED` and the Reason contains `no progress` and `implement`.
- A second run with `--max-stalls 2` on the command line gives the same result, which covers the flag path.
- Reset on progress:
  - `start` again, run two unchanged attempts (exit 2 each), then tick one task so the reason detail changes;
  - the next attempt exits 2 (count reset to 1, not released);
  - two further unchanged attempts give exits 2 then 0.
- Default `max`: without the variable, three unchanged attempts give exit 2 and the fourth gives exit 0. This covers the design table row "block while count ≤ max".
- Target change: a stored `loop.state` for a different target does not count toward the current target (first attempt exits 2 with count 1).
- `loop.state` is removed once the goal leaves ACTIVE.

**§E — Scenario: Complete the goal (2.5)**

- Archive the staged `us-4-2-x` and set every EPIC-4 story to `DONE`, as the existing US-12.1 section does. With an ACTIVE `EPIC-4` goal, the Stop payload exits 0.
- `goal_status` is `COMPLETE`.
- `loop.state` is absent.
- A following Stop attempt exits 0, because the goal is no longer ACTIVE (fail open).

**§F — Scenario: The loop cannot bypass a gate (2.6)**

- Set up an ACTIVE goal on `US-4.2` whose change has unticked tasks, so it is not archive-eligible.
- `printf '{"tool_name":"Bash","tool_input":{"command":"openspec archive us-4-2-x --yes","description":"archive"}}' | scripts/guard-archive.sh --hook --quiet` exits 2.
- `scripts/guard-archive.sh --change us-4-2-x --quiet` exits 2.
- The Stop hook's stderr for this state does not name `archive` as the action.
- `.claude/settings.json` in `$ROOT` still wires `guard-archive.sh` under `PreToolUse` `Bash`, checked with `grep -F`.
- `scripts/guard-delivery-loop.sh` contains no bypass: `grep -c 'openspec archive' scripts/guard-delivery-loop.sh` is 0, so the guard never archives by itself.

**§G — Wiring and contracts (1.2, 1.6, 1.7; by inspection plus static checks)**

- `check "guard is executable" 0 test -x "$ROOT/scripts/guard-delivery-loop.sh"`. The settings wrapper's `test -x` would otherwise fail open without any message.
- `node -e 'const s=JSON.parse(require("fs").readFileSync(".claude/settings.json","utf8")); if(!s.hooks.Stop) process.exit(1)'`.
- `grep -F 'guard-delivery-loop.sh' .claude/settings.json | grep -c .` returns 4 (Stop, PreToolUse and two allow entries).
- `.claude/rules/delivery-loop.md` exists and names `guard-delivery-loop.sh`, `guard-archive.sh` and `loop.state`.
- `.claude/agents/product-manager.md` has a `## Goal-driven delivery` heading.
- Whether the hook fires in a live Claude Code session is **verified by inspection or a manual session only**. The suite calls the script directly.

**Harness-wide checks:**

```bash
bash -n scripts/guard-delivery-loop.sh && bash -n scripts/delivery.sh && bash -n scripts/test-delivery.sh
scripts/test-delivery.sh
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh && scripts/test-completion.sh
node scripts/check-frontmatter.js          # must list "OK  skill  deliver"
scripts/validate-product-artifacts.sh
openspec validate us-12-2-run-delivery-goal-loop --strict   # read the printed result, not only the exit code
```

## Dependencies

- **US-12.1 (DONE).** It provides:
  - `delivery.sh next --json`, one line with keys `target`, `action`, `story`, `change`, `owner`, `command` and `reason`, escaped by `jstr` (backslash and quote only);
  - `refresh`, which records `COMPLETE` when the action is `complete`;
  - `start`, which resumes the same target;
  - the `goal.md` field table, read by the `| Field | Value |` awk in `goal_field`.
- **`scripts/guard-archive.sh` (US-8.2, DONE).** It must stay unchanged. §F depends on its hook-mode parse and exit 2.
- **`scripts/workflow-status.sh` and `scripts/completion-gate.sh`.** They are called indirectly through `delivery.sh next`.
- **Claude Code hook semantics** (external, and not checkable from the repository):
  - `Stop` exit 2 blocks the stop and feeds stderr back to Claude;
  - exit 0 allows;
  - Claude Code overrides after 8 consecutive Stop blocks;
  - the Stop payload carries `stop_hook_active`;
  - `agent_id` is present only in subagent payloads;
  - hook configuration is read from `.claude/settings.json`.
- **Tooling.** bash 3.2.57 (checked with `bash --version`), BSD awk, sed, grep and `cksum` (POSIX). `node` is used only for the JSON and frontmatter checks, which the harness already needs.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Dogfooding trap.** `openspec/delivery/goal.md` is `ACTIVE` for `EPIC-12` in this repository. Once task 1.6 wires the Stop hook, the main session here is blocked from stopping, and it cannot write `review.md` / `test-report.md` for this change unless the Reviewer and Tester run as subagents. | high | high | Wire `.claude/settings.json` last. Before wiring, the Product Manager decides between `scripts/delivery.sh stop --reason "implementing US-12.2"` and keeping the goal ACTIVE with review and test run as `reviewer` / `tester` subagents. Record the choice in `status.md` Blockers or the goal Notes. |
| **`scripts/` and `.claude/` are harness control surface.** `check-write-scope.sh` lines 146–155 set `IS_PRODUCT_CODE=0`, so the `implementer` subagent is BLOCKED from writing every deliverable of this change. | high | medium | As in US-12.1 (its review.md O-1), the main session implements and the review records this. Do not weaken `check-write-scope.sh`. |
| **`block` cannot record a resolver failure as written.** It reuses `load_goal`, which calls `die` when the target no longer resolves (lines 507–513). The design §5 requirement to record BLOCKED with the resolver's error would then fail silently and the goal would stay ACTIVE. | high | medium | In `block`, fall back to an in-place awk rewrite of the Status, Reason and Updated rows when resolution fails, preserving everything else. §C covers it. |
| **Claude Code's 8-block cap on a progressing loop.** The stall counter resets whenever the fingerprint changes. A multi-story epic can therefore collect more than 8 consecutive Stop blocks while making real progress, and Claude Code would then override the hook, leaving the goal `ACTIVE` with no recorded reason. | medium | medium | The skill and the rule should tell the orchestrator to delegate stage after stage within one turn and not end the turn between stages, since Stop fires only when the turn ends. A resumed `/deliver <same target>` continues from derived state. Whether the harness should also record the cap is raised in Open Questions. |
| **Relative paths under the hook's working directory.** `delivery.sh` uses `openspec/delivery` and `scripts/workflow-status.sh` relative to cwd. If the session has `cd`'d elsewhere, the hook would find no `goal.md` and fail open without any message. | medium | high | `cd` to the repository root taken from `$0` (`ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)`, as `test-delivery.sh` line 30 does) before anything else. |
| **Greedy JSON parsing.** `check-write-scope.sh` and `guard-planning-handoff.sh` still use the greedy `sed 's/.*"file_path"…"\([^"]*\)".*/'` form. A payload whose content contains `"file_path"` could then be misparsed. | medium | high | Use the `json_str` awk decoder from `guard-story-done.sh` lines 86–106 for `file_path`, `hook_event_name` and every `next --json` field. Test with an `Edit` payload that includes `old_string`/`new_string` after `file_path`. |
| **Subagent detection by substring.** The escaped content `\"agent_id\":` must not count as a subagent marker. | medium | high | Match with `grep -qE '(^\|[^\\])"agent_id"[[:space:]]*:'`: a bracket expression, no `\|` inside the BRE, and ERE through `grep -E`. §A covers both the escaped and the top-level forms. |
| **BSD sed / bash 3.2 portability.** There is no `\|` or `\?` in BSD sed BRE, no `mapfile`, no associative arrays, and an empty `"${arr[@]}"` fails under `set -u`. `grep -c` exits 1 on zero matches. | high | medium | Use awk or `grep -E` for alternation. Use `V=$(grep -c … \|\| true); V=${V:-0}`. Use newline strings with `while IFS= read -r`. `guard-archive.sh` lines 134–137 show the two-`s///` workaround for `true\|false`. |
| **Fingerprint storage and quoting.** The `next --json` line contains quotes, `\|` and `=`, which break a naive `key=value` store. | medium | medium | Store `target` and `count` as plain lines, and store the fingerprint as a `cksum` of the JSON line. `cksum` is POSIX and present under the suite's `PATH`. Write through a temp file and `mv`. |
| **A stale `loop.state` after `STOPPED`.** `delivery.sh stop` is US-12.1 code and does not remove `loop.state`, yet design §2 says the file is removed "whenever the goal leaves ACTIVE". | medium | low | Remove it in `block`, in the hook's COMPLETE and BLOCKED outcomes, and whenever the Stop hook sees a non-ACTIVE goal. Also reset the count when the stored target differs. Leave `stop` alone (the proposal limits `delivery.sh` changes to `block`). §D covers the reset. |
| **The write guard covers the `Write\|Edit\|MultiEdit` tools only.** A main-session Bash redirection (`cat > review.md`) is not intercepted, the same limit `check-write-scope.sh` has. | medium | medium | State the rule in `delivery-loop.md` and the skill Boundaries. The Tester should score "orchestrator MUST NOT author" against the tool-write mechanism the design defines and note the Bash limitation, rather than inferring full coverage. |
| **The `product-manager` agent has `Write, Edit` and no write-scope hook.** If `/deliver` delegated a PM action to a `product-manager` subagent, that subagent's write to `review.md` would carry `agent_id` and pass the new guard with no other hook to stop it. | low | high | Have the skill perform PM-owned actions in the main session, where the new guard applies, and delegate only to `planner`, `implementer`, `reviewer` and `tester` agents. Raised in Open Questions. |
| **The block message is hidden by `--quiet`.** The settings wrapper passes `--quiet`. If `--quiet` suppressed stderr, Claude would receive an empty reason and could not name the next action. | medium | high | `--quiet` suppresses allow messages only, the same way validator warnings and failures ignore it. §B asserts non-empty stderr under `--quiet`. |
| **A missing execute bit.** The wrapper's `test -x` fails open without any message if the new script is not executable. | medium | high | `chmod +x scripts/guard-delivery-loop.sh`. §G asserts `test -x`. |
| **Hook latency.** `next --json` runs `workflow-status.sh` and `completion-gate.sh`, and the latter may call the `openspec` CLI. | low | low | No `timeout` is set, following the current convention. If it turns out slow, record it as a finding rather than adding caching, since the next action must stay derived (US-12.1 design §2). |
| **Scope creep into documentation.** Adding a `.claude/rules/README.md` index row, `scripts/README.md`, `CLAUDE.md` or `README.md` text would fall outside the plan. | medium | low | US-12.3 owns documentation. `scripts/check-scope.sh --plan openspec/changes/us-12-2-run-delivery-goal-loop/implementation-plan.md --diff <new-entries>` flags such edits. Capture a baseline first (`{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } \| sort -u`), because the working tree is already largely untracked (`git status`). |
| **`openspec validate` exit codes are unreliable.** | high | low | Read the printed result, as US-12.1 did. |

## Open Questions

- **Consecutive-block cap on a progressing loop.** Should the Stop hook also count *total* consecutive blocks, whether or not progress is made, and record the goal as `BLOCKED` with a distinct reason before Claude Code's cap of 8? Otherwise the goal stays `ACTIVE` without a record when the cap is reached. Neither the design nor the scenarios require this, so the plan does not add it. It needs a Product Manager decision, and none of the six scenarios depends on it.
- **Write scope for a `product-manager` subagent.** Should a `check-write-scope.sh --role product-manager` hook be added to `.claude/agents/product-manager.md` frontmatter, so a delegated PM subagent cannot author `review.md` / `test-report.md`? Task 1.7 covers only a new section, so the plan does not add the hook. The mitigation in Risks (PM actions stay in the main session) satisfies the scenario as written.
