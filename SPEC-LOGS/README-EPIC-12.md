# README-EPIC-12 — Goal-Driven Delivery Orchestration

Implementation record for **EPIC-12** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-12 — Goal-Driven Delivery Orchestration |
| Stories | US-12.1, US-12.2, US-12.3, US-12.4 |
| Status | Complete — all acceptance criteria verified; delivery goal `EPIC-12` COMPLETE |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-12-1-resolve-delivery-target-report/`, `openspec/changes/archive/2026-09-26-us-12-2-run-delivery-goal-loop/`, `openspec/changes/archive/2026-09-26-us-12-3-document-delivery-orchestrator/`, `openspec/changes/archive/2026-09-26-us-12-4-delivery-loop-followups/` |
| SPECS.md status | US-12.1, US-12.2, US-12.3, US-12.4 DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Dates | 2026-09-24 – 2026-09-26 |
| Claude Code | 2.1.128 |
| OpenSpec | 1.13.2 |
| Spec source | `SPECS.md` EPIC-12; `PRD.md` FR-019; human Product Manager decision, 2026-09-24 |

---

## 1. Objective

Let the Product Manager hand the harness one delivery target — an epic, a user story,
or a task from `SPECS.md` — and have it driven to completion as a goal loop:

- each story is planned, implemented, reviewed, tested, and archived as its own
  OpenSpec change;
- every step is derived from repository artifacts;
- the loop stops only when the target is delivered or a human decision is required.

## 2. What existed before

`/product-iteration` already moved **one** story through the seven gates. A human still
had to prompt every stage, split an epic into stories by hand, and decide each time
what to do next. The gate reporters could answer "where is this change?"
(`workflow-status.sh`) and "may it ship?" (`completion-gate.sh`). Nothing answered
"what is the next action, who owns it, and what command performs it?" Nothing stopped a
session from ending its turn with work left.

## 3. What was built

| Story | Deliverable | Change |
|---|---|---|
| US-12.1 | `scripts/delivery.sh` (`resolve`, `start`, `next`, `refresh`, `reopen`, `stop`); the `openspec/delivery/goal.md` format; `scripts/test-delivery.sh` | `2026-09-24-us-12-1-resolve-delivery-target-report` |
| US-12.2 | `.claude/skills/deliver/SKILL.md`; `.claude/rules/delivery-loop.md`; `scripts/guard-delivery-loop.sh` wired as a `Stop` hook and a `PreToolUse` verdict guard; `delivery.sh block`; the goal-driven section of `.claude/agents/product-manager.md` | `2026-09-26-us-12-2-run-delivery-goal-loop` |
| US-12.3 | `README.md` §18 Goal-Driven Delivery and handbook updates; `CLAUDE.md`, `.claude/rules/README.md`, `.claude/agents/README.md`, and `scripts/README.md` references; this record | `2026-09-26-us-12-3-document-delivery-orchestrator` |
| US-12.4 | Accurate stall-limit wording; the two missing escalation causes; `delivery.sh stop` fallback; the `guard-archive.sh` index row; four regression cases | `2026-09-26-us-12-4-delivery-loop-followups` |

Canonical capabilities added: `openspec/specs/delivery-target/` (US-12.1) and
`openspec/specs/delivery-loop/` (US-12.2). US-12.3 modifies `harness-documentation`.

## 4. Key design decisions

1. **The story is the unit of delivery.** An epic is a view onto its stories, and each
   story is its own change (BR-003). A task delivers its parent story, and the task is
   recorded as the goal's Focus, because a task has no acceptance criteria (BR-005).
2. **The next action is derived, never stored as truth.** `delivery.sh next` recomputes
   it from `SPECS.md` and both gate reporters on every call. `goal.md` is a record for a
   human reader, and a hand-edited action is ignored (BR-004, NFR-003).
3. **The loop is a `Stop` hook, not a prompt.** A skill can only ask the model to keep
   going. The hook prevents the stop (exit 2) and names the next action. An LLM-judged
   prompt or agent hook was rejected: a deterministic derivation already existed, and
   the harness is portable bash (NFR-001).
4. **Progress is the derived state.** The fingerprint is the full `next --json` line,
   which includes gate detail such as `3/10 tasks complete`. The default stall limit
   (3) sits below Claude Code's cap of 8 consecutive Stop blocks, so the harness records
   *why* it stopped before Claude Code overrides the hook.
5. **The orchestrator never authors a verdict.** While a goal is `ACTIVE`, main-session
   writes to `review.md` / `test-report.md` are blocked. Only the Reviewer and Tester
   subagents, each under its own write-scope hook, may write them (BR-002).
6. **No gate has a loop exception.** `guard-archive.sh` and `guard-story-done.sh` are
   unchanged. They reject a premature archive or DONE edit inside the loop exactly as
   they do outside it.

## 5. The epic delivered itself

EPIC-12 was delivered **by the orchestrator it was building**. Once US-12.1 was
archived, the EPIC-12 goal was recorded with `scripts/delivery.sh start EPIC-12`. Every
later step followed `scripts/delivery.sh next`:

```text
select US-12.2 -> propose -> plan -> implement -> review -> (follow-ups) -> review
-> test -> archive -> mark-done -> select US-12.3 -> propose -> plan -> implement -> ...
```

The Planner, Reviewer, and Tester were independent subagents at each gate. The review
and test verdicts were never written by the session that implemented the change.

## 6. Review and reopen history

| Change | Rounds | What the rounds found |
|---|---|---|
| US-12.1 | 3 reviews (`history/review-r1.md`, `review-r2.md`, final `review.md`) | **F-1:** an archived change bypassed readiness escalation. **F-2:** an archived change bypassed dependency escalation, the same defect class, which the round-1 remediation text did not cover. Both were fixed by ordering `derive_next` as readiness → dependencies → archived → select → gates. Mutation checks confirmed that each regression case catches its defect. Each round used `delivery.sh reopen`, which preserved the verdict and appended one remediation task per finding. |
| US-12.2 | 2 reviews (`history/review-r1.md`, final `review.md`) | Round 1 approved with observations. The follow-ups R1.1–R1.4 then changed code, so the change was re-reviewed rather than archived on the first verdict: `loop.state` is cleared on every goal transition; a halt that could not be recorded is reported honestly; verdict-guard limits are documented and the path match is case-insensitive; pluralisation is fixed. |

| US-12.3 | 1 review (`review.md`) | Passed with non-blocking wording observations. The "N unchanged stop attempts" wording is off by one: the stop is allowed on attempt N+1. Two rare escalate causes are not named. `stop` exits 1 when the recorded target no longer resolves. These became US-12.4. |
| US-12.4 | 1 review (`review.md`) | Passed with no blocking findings. It closed the US-12.2 and US-12.3 observations: accurate stall-limit wording, the two missing escalation causes, the `stop` fallback, and the archive-guard index row. |

Acceptance, per the archived test reports:

- US-12.1: 6/6 scenarios PASS.
- US-12.2: 6/6 scenarios PASS. The "delegated to the role that owns it" clause was
  shown by the scripted owner mapping plus inspection of the skill.
- US-12.3: 2/2 scenarios PASS. The Tester enumerated five stop paths from the code,
  exercised each through the wired Stop hook, and confirmed README §18 documents each.
- US-12.4: 4/4 scenarios PASS. The Tester derived the stall behavior from the guard's
  `COUNT > MAX_STALLS` branch, enumerated all seven `escalate` sites in `derive_next`,
  and exercised the `stop` fallback in a throwaway copy.

### Follow-ups

All follow-ups from US-12.2 and US-12.3 were closed by US-12.4. None remain open.

## 7. Known limits

- **Live Claude Code behavior was not exercised in a live session.** That covers the
  hook firing, the 8-block override, and `agent_id` appearing only in subagent payloads.
  The wired commands were run directly with realistic payloads; the reports say so.
- **The verdict guard sees only `Write`/`Edit`/`MultiEdit`.** It does not see a shell
  redirect or a `product-manager` subagent write. The rule still applies, and review is
  the backstop (`.claude/rules/delivery-loop.md`).
- **The implementer subagent cannot write `scripts/` or `.claude/`** under
  `check-write-scope.sh`. For this harness-on-harness epic, the main session implemented
  the changes, and independence was kept by delegating planning, review, and testing to
  separate subagents. The reviews record this.

## 8. How to use it

See `README.md` §18. In short:

```text
/deliver EPIC-N | US-N.M | US-N.M#k | "task text"
scripts/delivery.sh resolve <target>    # preview
scripts/delivery.sh next                # what happens next, and who does it
scripts/delivery.sh stop                # halt deliberately
/deliver <same target>                  # resume a BLOCKED or STOPPED goal
```

## 9. Verification

```bash
scripts/test-delivery.sh          # 179 passed, 0 failed
scripts/test-write-scope.sh && scripts/test-guards.sh \
  && scripts/test-status.sh && scripts/test-completion.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate --all --strict
```
