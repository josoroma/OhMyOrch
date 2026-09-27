# Review — us-12-2-run-delivery-goal-loop

Change: us-12-2-run-delivery-goal-loop
Story: US-12.2
Verdict: pass
Blocking: None
Coverage: 6/6 acceptance criteria evaluated
OpenSpec verify: PASS — `openspec validate us-12-2-run-delivery-goal-loop --strict` reports "Change 'us-12-2-run-delivery-goal-loop' is valid". Every ADDED requirement in `specs/delivery-loop/spec.md` is implemented. `design.md` decisions 1–4 match the code, and decision 5 matches in every case but one. All 13 ticked tasks in `tasks.md` are done. No blocking mismatch. Two non-blocking design deviations are recorded as O-1 and O-2.

## Summary

The implementation satisfies all six US-12.2 scenarios.

- `scripts/guard-delivery-loop.sh` blocks the main session's Stop (exit 2) while an ACTIVE goal has a non-escalating next action, and names the action, owner, and command.
- It allows the stop on `escalate`, on N unchanged stop attempts, and on `complete`, and records `BLOCKED` or `COMPLETE` through `delivery.sh`.
- In `PreToolUse` mode it blocks main-session writes to `review.md` and `test-report.md`.
- `guard-archive.sh` is unchanged and still rejects a premature archive during a goal.

Evidence comes from code reading, the suite (156/0), and probes in a throwaway `mktemp -d` copy. The probes include running the exact `settings.json` commands with `CLAUDE_PROJECT_DIR` unset. I found no MUST violation. The observations below are design-level edge cases, documentation gaps, and live-session aspects that the suite cannot exercise.

## Blocking Issues

None. No MUST in `specs/delivery-loop/spec.md` is violated.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| Start a delivery goal | PASS | **Recording:** `delivery.sh start` writes `\| Target \|`, a Stories row per story, and `\| Status \| ACTIVE \|`. Suite "Start a delivery goal": 13/13 ok. **Delegation by owner:** `.claude/skills/deliver/SKILL.md` Step 2 table maps every `delivery.sh` action to its owner (planner, implementer, reviewer, tester, product-manager, human PM). Verified by inspection only; see O-6. **Verdict authorship:** `guard-delivery-loop.sh` lines 178–193. In the throwaway copy, the wired `PreToolUse` command blocked (exit 2) main-session Write to `review.md`, Edit to `review.md` (with an escaped `\"file_path\"` in `old_string`), MultiEdit to `test-report.md`, a `./`-relative path, a pretty-printed multi-line payload, and content containing escaped `\"agent_id\":`. It allowed (exit 0) reviewer/tester subagent payloads, `tasks.md`, and `history/review-r1.md`. Coverage limits: O-3. |
| Continue while work remains | PASS | Lines 240–273: exit 2 with stderr `Next action: <action>  (owner: <owner>, story: …)` plus `Command:` and `Reason:`. In the throwaway copy, the wired Stop command (`sh -c '…${CLAUDE_PROJECT_DIR:-$PWD}…'`, `CLAUDE_PROJECT_DIR` unset) was fed a realistic payload (`session_id`, `transcript_path`, `cwd`, `permission_mode`, `stop_hook_active`, `last_assistant_message` with escaped quotes and backslashes). It exited 2 and printed `Next action: review  (owner: reviewer, story: US-12.2)` and `Command: /review-feature us-12-2-run-delivery-goal-loop …`. `--quiet` still prints the 6-line block reason. `stop_hook_active:true` does not bypass. Invoking by absolute path from `cwd=/tmp` still blocks, because the script `cd`s to its own root at line 91. `docs/SPECS.md` layout: still blocks with `review`. Suite: 8/8 ok. |
| Halt for a human decision | PASS | Lines 229–233: `escalate` → `delivery.sh block --reason "escalate: <reason>"`, `rm loop.state`, `systemMessage`, exit 0. `block` (`delivery.sh` lines 753–775) calls `refresh_goal BLOCKED`, which preserves Target, Started, and Notes. Suite: the NEEDS CLARIFICATION epic records `\| Status \| BLOCKED \|` with reason `US-2.1 is NEEDS CLARIFICATION`. An unfinished dependency records `US-3.2 (READY)`. No change directory is created. Throwaway probe: when the goal target no longer resolves (`EPIC-99`), Stop exits 0 and records `BLOCKED` with `the goal could not be derived: unknown target: EPIC-99 …`, through the in-place awk fallback. Suite: 12/12 ok. |
| Halt when the loop stops making progress | PASS | Lines 236–256: the fingerprint is `cksum` of the full `next --json` line, stored per target. The count increments only when target and fingerprint both match. When `count > max`, it records `BLOCKED` "no progress: …" and exits 0. Throwaway probes: default max 3 gave exits 2,2,2,0 and reason `no progress: next action 'review' for US-12.2 unchanged across 4 stop attempts`. A stored state for a different target (`US-12.2`, count 3) reset to `count=1` for `EPIC-12`. A BLOCKED goal resumed with `start EPIC-12` starts at `count=1`. Suite: 14/14 ok, including a progress reset when the derived state changes. Stop→start edge case: O-1. |
| Complete the goal | PASS | Lines 223–228: `complete` → `delivery.sh refresh` (whose `refresh_goal` forces `COMPLETE`), `rm loop.state`, exit 0. Suite "Complete the goal": 5/5 ok. It blocks while US-4.2 is undelivered, records `\| Status \| COMPLETE \|` once it is DONE, clears `loop.state`, and allows every later stop. |
| The loop cannot bypass a gate | PASS | `guard-delivery-loop.sh` contains no archive path. It ignores Bash payloads (suite: `the loop guard has no archive bypass`, exit 0). Throwaway probe: the **wired** `PreToolUse` Bash command for `guard-archive.sh`, given `scripts/completion-gate.sh --change us-12-2-run-delivery-goal-loop --record && openspec archive us-12-2-run-delivery-goal-loop -y` for this not-yet-eligible change, printed `BLOCKED  archive us-12-2-run-delivery-goal-loop … First failing condition: review` and exited 2. Suite: the archive guard rejects mid-goal (unticked task) and blocking-review states, and allows the eligible control case. Suite: 7/7 ok. |

## Regression Checks

- `bash -n` is clean on `scripts/guard-delivery-loop.sh`, `scripts/delivery.sh`, and `scripts/test-delivery.sh`. The guard is executable (`-rwxr-xr-x`). Shell is GNU bash 3.2.57.
- Portability: there is no `mapfile`, `readarray`, `declare -A`, `[[`, or case-modification expansion in the guard. There is no `\|` inside a sed BRE. Alternation uses awk or `grep -E` (line 128). `cksum` is `/usr/bin/cksum`.
- Suites:
  - `scripts/test-delivery.sh`: 156/0
  - `scripts/test-write-scope.sh`: 36/0
  - `scripts/test-guards.sh`: 38/0
  - `scripts/test-status.sh`: 46/0
  - `scripts/test-completion.sh`: 63/0

  All exit 0.
- `node scripts/check-frontmatter.js`: `RESULT: PASS — all definitions valid`, including the new `deliver` skill.
- `scripts/validate-product-artifacts.sh --quiet`: exit 0 (warnings only: non-READY stories, `CODEBASE.md` absent).
- Existing gates are unmodified:
  - The mtimes of `guard-archive.sh` (13:42), `check-write-scope.sh` (10:13), `workflow-status.sh` (13:12), `completion-gate.sh` (11:28), `guard-story-done.sh` (13:42), and `guard-planning-handoff.sh` (11:28) all predate this change's `.openspec.yaml` (16:20).
  - `find -newer .openspec.yaml` lists only the planned files, change artifacts, `goal.md`, and `SPECS.md` (the PM `select` step).
  - Their suites pass unchanged.
- Scope: `scripts/check-scope.sh --plan … --diff <8 implementation files>` reports `RESULT: IN SCOPE`.
- `.claude/settings.json`:
  - It parses with `node`.
  - It has a new `Stop` group, one new entry in the `Write|Edit|MultiEdit` PreToolUse group, and the two paired allow-list entries.
  - The `guard-archive.sh` Bash wiring is unchanged.
- Task honesty: all 13 tasks are ticked, and each deliverable and regression section exists. The `SPECS.md` story tasks remain unticked, as they should until `mark-done`.
- I ran no `start`, `stop`, `block`, `refresh`, or hook invocation against the real repository. All probes ran in a `mktemp -d /tmp/rv122.XXXXXX` copy (rsync, no `.git`), which I removed afterwards. The real `openspec/delivery/` holds only `goal.md`.

## Observations

- **O-1** (design §2 deviation, non-blocking). Design §2 says "`loop.state` is removed whenever the goal leaves `ACTIVE`". `delivery.sh stop` (US-12.1 code, deliberately untouched) does not remove it. The guard only clears it when a hook fires and sees a non-ACTIVE goal (line 170). If `stop` and `start <same target>` run in the same turn, no hook fires in between, and the stall count carries over. Probe: the count went 2 → `stop` → `start` → 3. The loop still halts after N unchanged attempts, so the scenario holds, but the resumed goal does not "start counting fresh". Possible remediation: clear `loop.state` in the guard when the stored target matches but the goal's `Started`/`Updated` changed, or have `start` remove it.
- **O-2** (design §5 deviation, non-blocking). When `SPECS.md` is missing entirely, `next` fails, and the hook calls `block`. `block` then exits 1, because `load_specs` calls `exit 1` from inside `resolve_target` (`delivery.sh` line 165) and bypasses the in-place fallback. The hook ignores that exit code (line 211) and still prints `systemMessage: "… recorded BLOCKED — … SPECS.md not found …"`, while `goal.md` stays `ACTIVE`. The stop is allowed, so fail-open holds, but the message to the user is inaccurate. Possible remediation: check `block`'s exit status before announcing, and run `resolve_target` in a subshell inside `block` so that a `SPECS.md`-level failure reaches the fallback.
- **O-3** (guard coverage, planned risk). The verdict-authorship guard covers only the `Write|Edit|MultiEdit` tools. It does not intercept a main-session Bash redirection (`cat > review.md`), and a case variant (`REVIEW.md`, which aliases `review.md` on default case-insensitive APFS) passes (exit 0). A `product-manager` **subagent** writing `review.md` also passes (exit 0), because it carries `agent_id` and has no write-scope hook. The plan's Risks table accepts this, and the skill keeps PM actions in the main session. However, the plan's stated mitigation ("State the rule in `delivery-loop.md` and the skill Boundaries", for the Bash limitation) was not carried out: neither file mentions the limitation.
- **O-4** (documentation gap, planned open question). Neither the skill nor the rule tells the orchestrator to keep delegating stages within one turn. The plan's Risks table proposed that as the mitigation for Claude Code's cap of 8 consecutive Stop blocks. On a long, progressing epic, the cap can override the hook and leave the goal `ACTIVE` with no recorded reason. Resuming from derived state recovers from this. It remains a Product Manager decision (plan §Open Questions).
- **O-5** (cosmetic). `--quiet` is parsed into `QUIET` (line 76) but never read, because the guard has no stderr allow messages. `DELIVERY_MAX_STALLS=0` allows the first stop, and its reason reads "unchanged across 1 stop attempts" even though nothing was compared. Both are harmless.
- **O-6** (live-session evidence). Three things were verified only by running the wired commands directly, not in a live Claude Code session: that Claude Code fires the hook, feeds stderr back as the continuation reason, shows `systemMessage`, and applies the 8-block cap; that `agent_id` is present only in subagent payloads; and that the skill actually delegates at run time. Per the plan's Test Strategy, the Tester should score these aspects `UNVERIFIED` unless exercised live.
- **O-7** (process, planned risk; carried forward from US-12.1 O-1). `scripts/` and `.claude/` are harness control surface that the `implementer` subagent cannot write, so the main session implemented the change. This review is the independent check.

## Handoff

Gate 5 passes with this review. Control proceeds to the Tester:
`/test-feature us-12-2-run-delivery-goal-loop`, for independent acceptance evidence in
`test-report.md`. The Reviewer modified no product code.
