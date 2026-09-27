# Review — us-12-3-document-delivery-orchestrator

Change: us-12-3-document-delivery-orchestrator
Story: US-12.3
Verdict: pass
Blocking: None
Coverage: 2/2 acceptance criteria evaluated
OpenSpec verify: VERIFIED — no blocking mismatch. `openspec validate us-12-3-document-delivery-orchestrator --strict` reports "Change 'us-12-3-document-delivery-orchestrator' is valid". Both ADDED requirements in `specs/harness-documentation/spec.md` are met by the diff. All 10 ticked tasks in `tasks.md` are backed by edits or by evidence re-run in this review. The implementation matches the proposal's scope, and no delivery behavior changed (`scripts/delivery.sh`, `scripts/guard-delivery-loop.sh`, and `.claude/settings.json` were not edited).

## Summary

The implementation satisfies both US-12.3 scenarios. README.md §18 gives the command for all four target kinds, one row for every way the loop stops, and a resume procedure. I checked each against `scripts/delivery.sh` `derive_next`, `scripts/guard-delivery-loop.sh`, and runs in a throwaway copy. CLAUDE.md, `.claude/rules/README.md`, and `scripts/README.md` each reference the skill, the rule, and the delivery scripts. The documented counts match measured values, and the tightened `test-delivery.sh` assertion catches the `plural()` mutation. None of the observations below breaks a MUST.

## Blocking Issues

None.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| README explains goal-driven delivery — delivery command for each target kind | PASS | README.md §18 "The command, per target kind" has one row each for `/deliver EPIC-3`, `/deliver US-3.2`, `/deliver US-3.2#2`, and `/deliver "widget parser"`. The cookbook in §20 repeats them. On the real repo: `scripts/delivery.sh resolve EPIC-12` exit 0 and lists 3 stories, byte-identical to the §18 example; `resolve US-12.3` exit 0 `Kind: story`; `resolve 'US-12.3#1'` exit 0 `Kind: task` with Focus set; `resolve EPIC-99` exit 1 `unknown target: EPIC-99 …`, matching "exits 1 and names the target". The claim that ambiguous text is refused matches `delivery.sh` line 275 (`ambiguous target … use US-N.M#k`). `--help` exit 0 for both scripts. |
| README explains goal-driven delivery — every way the loop stops | PASS | The §18 "Every way the loop stops" table lists COMPLETE, escalate→BLOCKED, no-progress→BLOCKED, could-not-be-derived→BLOCKED, and `stop`→STOPPED. These are the four allow-with-record branches of `guard-delivery-loop.sh` (the complete and escalate cases, the stall branch at `COUNT > MAX_STALLS`, the `NRC != 0` branch) plus `delivery.sh stop`. Every row was exercised in a `mktemp -d` copy. Work remaining gave exit 2 with "do not stop yet". Four unchanged stops recorded `BLOCKED` "no progress". Another active change recorded `BLOCKED` "escalate: another change is active". Target `US-9.9` recorded `BLOCKED` "the goal could not be derived". `start US-12.1` (all DONE) gave `COMPLETE`. `stop --reason lunch` gave `STOPPED` with Reason `lunch`. The Claude Code 8-block override is also stated. |
| README explains goal-driven delivery — how an interrupted goal resumes | PASS | §18 "Resume an interrupted goal" and §19 describe the procedure (`cat goal.md`, `delivery.sh next`, `/deliver <same target>`). In the copy, `start US-12.3` after STOPPED and after BLOCKED both returned `ACTIVE`. `start US-12.1` while BLOCKED was refused with exit 1 `a different goal is BLOCKED … run scripts/delivery.sh stop first`, as documented. The claim that `start` clears the stall counter matches `delivery.sh` (`rm -f "$LOOP_STATE"` in `start`). |
| Contracts and indexes list the orchestrator | PASS | `grep -cE '/deliver\|delivery-loop\|delivery\.sh\|guard-delivery-loop\|test-delivery'` gives CLAUDE.md 6, `.claude/rules/README.md` 4, `scripts/README.md` 23 (and `.claude/agents/README.md` 5, which the scenario does not require). CLAUDE.md has the document-map row (line 33), the "Goal-driven delivery" subsection (lines 70–80), and `scripts/test-delivery.sh` in the validation chain (line 130). `.claude/rules/README.md` has the `delivery-loop.md` index row and three rule-to-gate rows. `scripts/README.md` has 3 top-table rows plus the `guard-story-done.sh` row, and sections for `delivery.sh`, `guard-delivery-loop.sh`, and `test-delivery.sh`. |

### Factual checks

- **Guard table vs `.claude/settings.json`:** `node` enumeration shows 8 hooks: PostToolUse ×2 (validate-product-artifacts, run-project-validation), PreToolUse `Write|Edit|MultiEdit` ×4 (planning-handoff, context-preflight, story-done, delivery-loop), PreToolUse `Bash` ×1 (guard-archive), `Stop` ×1 (delivery-loop). This matches README §25 "eight hooks" and every row of its table.
- **Verdict guard:** in the copy, a PreToolUse payload for `openspec/changes/x/REVIEW.md` with an ACTIVE goal got exit 2 and the documented message. The same payload with `agent_id` got exit 0. This matches §18, §25, and `scripts/README.md`.
- **Suite counts:** test-delivery 166/0, test-write-scope 36/0, test-guards 38/0, test-status 46/0, test-completion 63/0. These match README §25 and `scripts/README.md`. `check-frontmatter.js` reports 8 agents + 15 skills = 23, `RESULT: PASS`, matching "23 definitions (8 agents, 15 skills)".
- **Section numbering:** headings run 1–26 with no gaps. `§18` (lines 115, 727, 907) points to Goal-Driven Delivery, and `§25` (line 118) points to The Executable Harness. No "§24 Executable Harness" or other stale `§` reference remains in README.md, CLAUDE.md, `.claude/rules/README.md`, `.claude/agents/README.md`, or `scripts/README.md`.
- **Epic record vs archive:** US-12.1 has `history/review-r1.md` (changes-requested, F-1 readiness), `review-r2.md` (changes-requested, F-2 dependency), and a final `review.md` (approved). Its tasks.md has R1 and R2 reopen sections, its test report has 6 scenario rows with Verdict pass, and completion is 15/15, eligible. US-12.2 has `history/review-r1.md` (pass) and `review.md` (pass), a follow-ups R1 section, 6 scenario rows with Verdict pass, and completion 17/17, eligible. Canonical specs `delivery-target` and `delivery-loop` exist. `README-EPIC-12.md` §3, §6, and §9 match all of this.
- **Mutation check (task 2.1):** in a throwaway copy, `plural()` was changed to always append `s`. `test-delivery.sh` then reported `FAIL one attempt is not pluralised — unexpectedly found: 1 stop attempts`, passed 165, failed 1, exit 1. After the revert, the copy was deleted, and the real `scripts/guard-delivery-loop.sh` is unchanged (`git diff --stat` empty).
- **Live goal untouched:** after the review, `openspec/delivery/goal.md` still reads Target `EPIC-12`, Status `ACTIVE`. On the real repo I ran only `--help`, `resolve`, and `next`.

### Scope

`scripts/check-scope.sh --plan … --diff <declared 8 files>` reports `RESULT: IN SCOPE`. Against HEAD, the check also reports `.gitignore` and `openspec/config.yaml` as unpredicted. Both have mtimes of 2026-09-24, before this change's proposal (2026-09-26 06:23). The `.gitignore` hunk is the US-12.2 `loop.state` entry. Neither is attributable to this change. The repository has had no commit since `ae11530`, so HEAD-based scope includes prior stories' work.

## Observations

Non-blocking. None of these breaks a MUST.

- **O-1 — Stall threshold wording is off by one.** README §18 says BLOCKED "no progress" happens when the action "did not change across `DELIVERY_MAX_STALLS` (default 3) stop attempts". The guard actually blocks at `COUNT > MAX_STALLS`, which is the 4th unchanged attempt with the default. The copy recorded "unchanged across 4 stop attempts". `.claude/rules/delivery-loop.md` uses the same wording, so the handbook follows the rule. A future edit could say "more than N" or "N allowed, then BLOCKED". §18 also does not mention the `--max-stalls` flag; `scripts/README.md` does.
- **O-2 — Escalate causes are listed as examples, and the list is not exhaustive.** The §18 escalate row omits two `derive_next` branches: "the gate reporter could not report" and "unmapped gate". The row still describes the stop mechanism (next action `escalate`) completely.
- **O-3 — Recovery from a "could not be derived" block is not documented.** In the copy, `scripts/delivery.sh stop` on a goal whose target no longer resolves exits 1 (`recorded target 'US-9.9' no longer resolves`). `start <different target>` is then refused because the goal is BLOCKED. The troubleshooting advice "`scripts/delivery.sh stop`, then `/deliver <new target>`" does not work in that case; the user must restore the target in `SPECS.md` or remove `goal.md`. This is US-12.2 behavior, and the README's "resolve the recorded reason first" covers it only loosely.
- **O-4 — `scripts/README.md` has minor staleness.** The `guard-archive.sh` top-table row still reads "any workflow gate is incomplete | US-8.2". README.md §25 says "any completion condition is unmet | US-8.2, US-10.1". The row predates this change, but it sits in a table this change edited. The "writes durable records" list also omits that `delivery.sh reopen` refreshes `goal.md` when a goal exists.
- **O-5 — Point-in-time examples.** The §18 `next EPIC-12` example shows `implement … 0/10 tasks complete`, and the `resolve` example shows US-12.3 `IN PROGRESS`. Both will read as stale after archive. They are illustrative, not claims about current state.
- **O-6 — The epic record needs a post-archive update.** `README-EPIC-12.md` marks US-12.3 "this change / IN PROGRESS" and correctly claims no US-12.3 verdicts. The plan's open question stands: the Product Manager should update the Status row after `mark-done`.

## Regression runs

| Command | Result |
|---|---|
| `scripts/test-delivery.sh` | passed 166, failed 0 |
| `scripts/test-write-scope.sh` | passed 36, failed 0 |
| `scripts/test-guards.sh` | passed 38, failed 0 |
| `scripts/test-status.sh` | passed 46, failed 0 |
| `scripts/test-completion.sh` | passed 63, failed 0 |
| `node scripts/check-frontmatter.js` | RESULT: PASS (8 agents, 15 skills) |
| `scripts/validate-product-artifacts.sh` | exit 0, RESULT: PASS, 0 warnings |
| `openspec validate us-12-3-document-delivery-orchestrator --strict` | "Change 'us-12-3-document-delivery-orchestrator' is valid" |
| `openspec validate --all --strict` | Totals: 23 passed, 0 failed |
| `scripts/check-scope.sh --plan … --diff <declared files>` | RESULT: IN SCOPE (8 files) |

## Handoff

No remediation requested. Control proceeds to the Tester (`/test-feature us-12-3-document-delivery-orchestrator`). The observations may be taken up as follow-ups at the Product Manager's discretion.
