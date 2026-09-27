# Review — us-12-2-run-delivery-goal-loop

Change: us-12-2-run-delivery-goal-loop
Story: US-12.2
Verdict: pass
Blocking: None
Coverage: 6/6 acceptance criteria evaluated
OpenSpec verify: VERIFIED. `openspec validate us-12-2-run-delivery-goal-loop --strict` reports "Change 'us-12-2-run-delivery-goal-loop' is valid". Every ADDED requirement in `specs/delivery-loop/spec.md` is implemented. The implementation now matches `design.md` decisions 1–5, including the §2 rule that "`loop.state` is removed whenever the goal leaves `ACTIVE`", which was the round-1 deviation. All 17 tasks in `tasks.md` (1.1–1.7, 2.1–2.6, R1.1–R1.4) are ticked, and each is backed by code and a regression case. No blocking mismatch.

Review round: 2. This review **supersedes `history/review-r1.md`**, which is preserved verbatim.

## Summary

The implementation satisfies all six US-12.2 acceptance scenarios. Each R1 follow-up is actually implemented, not just ticked:

- R1.1: `stop`, `block`, and `start` clear `loop.state`.
- R1.2: the Stop hook reports honestly when `block` cannot record the halt, and a missing `SPECS.md` now falls through to the in-place fallback.
- R1.3: the verdict-guard limits are documented, and the verdict paths now match case-insensitively.
- R1.4: "stop attempt(s)" is pluralised correctly.

Mutation checks show that the suite catches a regression in R1.1, R1.2, and the R1.3 case match. The R1.4 assertion does not catch a regression (observation O-1). That item is cosmetic, not a MUST, so it does not block. There are no blocking findings.

## Blocking Issues

None.

## R1 Follow-up Verification

| Item | Round-1 obs. | Verified | Evidence |
|---|---|---|---|
| R1.1 `stop`/`block`/`start` clear `loop.state` | O-1 | YES | `scripts/delivery.sh`: `rm -f "$LOOP_STATE"` in `start` (after `G_STATUS="ACTIVE"`), in `stop` (after `load_goal`), and in `block` (after the goal check). `LOOP_STATE` is declared near the top with the invariant comment. Probe (throwaway copy, wired Stop command): count reached 3 → `stop` → file absent. Resume + one stop gave `count=1`. A blocked stop followed by `start` with no hook in between left the file absent, which is exactly the round-1 O-1 reproduction and is now fixed. A blocked stop followed by `block --reason "manual probe"` left the file absent. Suite: `stop clears the stall counter`, `start (resume) clears the stall counter`, and `block clears the stall counter` all pass. |
| R1.2 honest reporting and the `block` fallback | O-2 | YES | `scripts/guard-delivery-loop.sh` `record_block()` re-reads `Status` after `delivery.sh block`. It sets `RECORDED="recorded BLOCKED"` only when `goal.md` says `BLOCKED`, and otherwise "could NOT be recorded as BLOCKED (goal.md still says …)". All three block paths (underivable, escalate, no-progress) use it. `delivery.sh block` probes `( resolve_target "$TARGET" )` in a subshell, so the `exit 1` from `load_specs` no longer bypasses the awk in-place fallback. Probe with `SPECS.md` removed: exit 0, `goal.md` shows `Status=BLOCKED  Reason=the goal could not be derived: SPECS.md not found …`, and the message says "recorded BLOCKED", which is true. Probe with `goal.md` 0444 and its dir 0555: exit 0 (fail-open), message "could NOT be recorded as BLOCKED (goal.md still says ACTIVE)", and `goal.md` still says `ACTIVE`, which is honest. |
| R1.3 verdict-guard limits documented, case-insensitive match | O-3 | YES | `.claude/rules/delivery-loop.md` §"Known limits of the verdict guard" names shell redirects and the `product-manager` subagent, notes the case-insensitive match, and names the Reviewer as backstop. `.claude/skills/deliver/SKILL.md` Boundaries: "Never write a verdict through Bash (`cat > review.md`) or through a delegated `product-manager` subagent." Code: `tr '[:upper:]' '[:lower:]'` before the path `case`. Wired PreToolUse probe during an ACTIVE goal: main-session `review.md`, `REVIEW.md`, `Review.MD`, `test-report.md`, `TEST-REPORT.md`, and a relative-path `Edit` of `Review.md` all exit 2. `history/review-r1.md`, `tasks.md`, and a reviewer-subagent `review.md` exit 0. |
| R1.4 pluralisation and `--quiet` help | O-5 | YES (behaviour) / weak test | `plural()` is used in the no-progress reason. Probe `DELIVERY_MAX_STALLS=0` gave "unchanged across 1 stop attempt." and the default max gave "unchanged across 4 stop attempts". The `--quiet` help now says the guard prints nothing on a plain allow and that block messages and `systemMessage` always print. The regression assertion is too weak to catch a regression; see O-1. |

### Mutation checks

Each mutation was applied with `perl` to a `mktemp -d /tmp/rv122m.XXXXXX` rsync copy (no `.git`), and `scripts/test-delivery.sh` was then run inside that copy. Every copy was removed afterwards (`ls -d /tmp/rv122m.*` found nothing).

| Mutation | Suite result | Caught by |
|---|---|---|
| M1 remove `rm -f "$LOOP_STATE"` from `stop` | rc=1, 164/1 | `stop clears the stall counter` |
| M2 remove it from `start` | rc=1, 164/1 | `start (resume) clears the stall counter` |
| M3 remove it from `block` | rc=1, 164/1 | `block clears the stall counter` |
| M4 `record_block` always claims BLOCKED (`if true`) | rc=1, 164/1 | `an unrecordable halt is reported honestly` |
| M5 drop the subshell probe in `block` | rc=1, 164/1 | `no SPECS.md: the halt is recorded` |
| M6 remove the lower-casing of the verdict path | rc=1, 164/1 | `a case-variant REVIEW.md is still blocked` |
| M7 `plural()` always appends "s" | **rc=0, 165/0 — survived** | none (O-1) |

## Acceptance Criteria Evaluated

All probes ran in a `mktemp -d` rsync copy of the repository with `CLAUDE_PROJECT_DIR` unset, using the hook commands extracted from `.claude/settings.json` with `node -e`. Each copy was removed afterwards.

| Scenario | Result | Evidence |
|---|---|---|
| Start a delivery goal | PASS | `delivery.sh start EPIC-12` / `US-12.3` records Target, the Stories table, and `Status ACTIVE`, and prints the derived action with its owner. The skill's owner table delegates `plan`/`implement`/`review`/`test` to the planner/implementer/reviewer/tester subagents. The orchestrator cannot author verdicts: the wired `Write\|Edit\|MultiEdit` command gives exit 2 for main-session `review.md` / `test-report.md` (any case) and exit 0 for a reviewer subagent. Suite section "Start a delivery goal": all ok. |
| Continue while work remains | PASS | Wired Stop command on the ACTIVE EPIC-12 goal: exit 2, stderr "Next action: review (owner: reviewer, story: US-12.2)", plus the Command and Reason lines. `loop.state` records `count=1`. The suite also covers `stop_hook_active: true`, which still blocks, and a subagent Stop, which is allowed. |
| Halt for a human decision | PASS | Wired Stop command, goal `US-12.3`, which depends on unfinished `US-12.2`: exit 0, `systemMessage` "recorded BLOCKED — a human Product Manager decision is required …", `goal.md` `Status=BLOCKED  Reason=escalate: US-12.3 depends on unfinished US-12.2 (IN PROGRESS)`, and Target/Started preserved. With US-12.3 set to NEEDS CLARIFICATION (copy only), the reason is `escalate: US-12.3 is NEEDS CLARIFICATION, not READY`. `start US-12.3` resumes it as ACTIVE. |
| Halt when the loop stops making progress | PASS | Wired Stop command, default max 3, unchanged state: exits 2, 2, 2, 0. Reason `no progress: next action 'review' for US-12.2 unchanged across 4 stop attempts`, `Status=BLOCKED`. Suite: a progress reset when the derived state changes (`count=1`), and R1.1 clearing on every transition. |
| Complete the goal | PASS | Wired Stop command on EPIC-12: exit 2 while US-12.2 is undelivered. After the three US-12.x stories were set to `DONE` (copy only): exit 0, `systemMessage` "Delivery goal EPIC-12 is COMPLETE — every story is DONE.", `Status=COMPLETE`, and `loop.state` removed. A further stop gives exit 0 with no output. |
| The loop cannot bypass a gate | PASS | The wired `guard-archive.sh` Bash command, given `openspec archive us-12-2-run-delivery-goal-loop -y`, prints `BLOCKED archive … First failing condition: review` and exits 2. The loop guard on the same Bash payload exits 0, so it has no archive path. `guard-archive.sh` is not among the files modified since round 1. Suite section "The loop cannot bypass a gate": all ok, including the eligible control. |

## Regression Checks

- `bash -n` is clean on `scripts/delivery.sh`, `scripts/guard-delivery-loop.sh`, and `scripts/test-delivery.sh`.
- Suites, all exiting 0:

  | Suite | Passed / failed |
  |---|---|
  | `scripts/test-delivery.sh` | 165/0 (156 in round 1, plus 9 R1 cases) |
  | `scripts/test-write-scope.sh` | 36/0 |
  | `scripts/test-guards.sh` | 38/0 |
  | `scripts/test-status.sh` | 46/0 |
  | `scripts/test-completion.sh` | 63/0 |

- `node scripts/check-frontmatter.js` reports `RESULT: PASS — all definitions valid.`
- `scripts/validate-product-artifacts.sh --quiet` exits 0.
- `openspec validate us-12-2-run-delivery-goal-loop --strict` reports "Change 'us-12-2-run-delivery-goal-loop' is valid".
- Scope:
  - Since `history/review-r1.md`, the files modified are `scripts/delivery.sh`, `scripts/guard-delivery-loop.sh`, `scripts/test-delivery.sh`, `.claude/rules/delivery-loop.md`, `.claude/skills/deliver/SKILL.md`, and the change's `tasks.md`/`status.md`. `openspec/delivery/goal.md` was also modified, by the PM `refresh`.
  - `scripts/check-scope.sh --plan … --diff <the 5 implementation files>` reports `RESULT: IN SCOPE`.
  - No other gate script was touched.
- `.claude/settings.json` wiring is unchanged since round 1:
  - `Stop` → `guard-delivery-loop.sh --hook --quiet`.
  - `PreToolUse Write|Edit|MultiEdit` → the same guard.
  - `PreToolUse Bash` → `guard-archive.sh`.
  - Allow-list: `Bash(scripts/guard-delivery-loop.sh:*)` and `Bash(bash scripts/guard-delivery-loop.sh:*)`.
  - Every command falls back to `$PWD` when `CLAUDE_PROJECT_DIR` is unset, and all were exercised that way.
- No probe ran against the real repository. The real `openspec/delivery/` still holds only `goal.md`, with no `loop.state`.

## Observations

- **O-1 (test strength, R1.4; non-blocking).** The assertion `one attempt is singular` checks the substring `unchanged across 1 stop attempt`, and `…1 stop attempts` also contains it. Mutation M7 (`plural()` always appends "s") survived the suite at 165/0. The behaviour itself is correct (probe above), and pluralisation is cosmetic with no MUST behind it. Suggested hardening: add `expect_absent "…" "1 stop attempts"`, or include the trailing `.`/`|` delimiter in the needle.
- **O-2 (message wording, non-blocking).** In the unrecordable case, the `systemMessage` joins two dash clauses: "could NOT be recorded as BLOCKED (goal.md still says ACTIVE) — run scripts/delivery.sh block — no progress: …". It is accurate but reads awkwardly. Cosmetic.
- **O-3 (round-1 O-4 resolved).** Both the rule and the skill now say to keep delegating within the turn because of Claude Code's cap of 8 consecutive Stop blocks. The round-1 documentation gap is closed.
- **O-4 (carried from round-1 O-6: live-session evidence).** Three things are still verified only by running the wired commands directly: that Claude Code fires the hooks, feeds stderr back, shows `systemMessage`, and applies the 8-block cap; that `agent_id` appears only in subagent payloads; and that the skill delegates at run time. The Tester should score these aspects `UNVERIFIED` unless it exercises them live.
- **O-5 (carried from round-1 O-7: process).** The `scripts/` and `.claude/` control surface was implemented by the main session, because the `implementer` subagent cannot write there. This review is the independent check. The round-2 edits likewise stay within the plan's predicted files.

## Handoff

Gate 5 passes with this review, and control proceeds to the Tester:
`/test-feature us-12-2-run-delivery-goal-loop`. The Reviewer modified no product code, scripts, `.claude/**`, `SPECS.md`, `tasks.md`, or `goal.md`. Every probe and mutation ran in a throwaway copy.
