# Test Report — us-12-4-delivery-loop-followups

Change: us-12-4-delivery-loop-followups
Story: US-12.4
Verdict: pass
Coverage: 4/4 acceptance criteria evaluated

Independent acceptance record (2026-09-26, working tree). The Tester did not write this
change. The acceptance criteria were taken from `SPECS.md` `### US-12.4:` and the
change's `specs/delivery-target/spec.md` and `specs/harness-documentation/spec.md`, not
from the implementer's claims. Every result below comes from a command I ran or lines I
inspected, and the output shown is what I observed.

- **Method: mixed.** Three criteria are documentation accuracy, judged by inspection of
  the quoted wording. Whether the documented behavior matches the code is judged by
  reading the code independently. Criterion 3 is a behavior, judged by executable checks
  in a throwaway copy.
- **The code was read first, independently of the documents.** For criterion 1 I read the
  no-progress branch in `scripts/guard-delivery-loop.sh` and derived, from the code, on
  which attempt the stop is allowed. For criterion 2 I enumerated every `set_action
  escalate` site in `derive_next` in `scripts/delivery.sh` myself. For criterion 4 I read
  what `scripts/guard-archive.sh` actually does. Only then did I compare each with the
  documentation.
- **Primary behavioural evidence** comes from a Tester-built sandbox
  (`dir=$(mktemp -d /tmp/tst-us124.XXXXXX)`, here `/tmp/tst-us124.uwhMYk`). It held a copy
  of `scripts/delivery.sh`, `scripts/guard-delivery-loop.sh`, `scripts/workflow-status.sh`,
  `scripts/completion-gate.sh`, `openspec/config.yaml`, and `.claude/settings.json`, plus a
  stub `SPECS.md` that I wrote. I removed it at the end with `rm -rf "$dir"`.
- **Real repository:** I ran only read-only commands — the preflight reporter, the
  read-only `scripts/test-delivery.sh`, and the validators. `openspec/delivery/goal.md`
  was not modified.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | The stall limit is described accurately | PASS | Method: inspection of the wording, checked against the code. **Code first.** `scripts/guard-delivery-loop.sh` line 269 is `if [ "$COUNT" -gt "$MAX_STALLS" ]`; `COUNT` is incremented per unchanged attempt (lines 258–266) and `MAX_STALLS` defaults to `3` (line 48, `DELIVERY_MAX_STALLS:-3`). So attempts 1..N are blocked and attempt N+1 is allowed — the stop is allowed *after* N blocked attempts. **README.md** line 831: "did not change across `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts — the stop is allowed after that many blocked attempts, so the default allows it on the 4th. Override with `--max-stalls <n>` or `DELIVERY_MAX_STALLS`". **.claude/rules/delivery-loop.md** line 53: "derived state unchanged across `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts — the stop is allowed after that many, so the default allows it on the 4th (`--max-stalls <n>` overrides)". Both state "blocked stop attempts", both name the default (`3`) and the override (`--max-stalls <n>` / `DELIVERY_MAX_STALLS`), and both agree with the code. |
| 2 | Every escalation cause is documented | PASS | Method: inspection, code first. I enumerated the `set_action escalate` sites in `derive_next` (`scripts/delivery.sh`): line 322 (story not READY/IN PROGRESS), 342 (dependency not DONE), 360 (another change active), 374 (gate reporter could not report), 407 (acceptance gate fails), 419 (gates pass but a completion condition fails), 424 (unmapped gate) — seven causes. **README.md** line 830, the `escalate` row, lists: "a story is not `READY`/`IN PROGRESS`, a dependency is not `DONE`, another change is already active, the gate reporter could not report, an unmapped gate, the acceptance gate fails, or gates pass but a completion condition fails". All seven are named, including the two the story requires: "the gate reporter could not report" and "an unmapped gate". |
| 3 | Stop records a halt when the target no longer resolves | PASS | Method: executable checks in the sandbox. **A — target row edited to a nonexistent story.** After `start US-1.1`, I set `\| Target \| US-9.9 \|` and ran `scripts/delivery.sh stop --reason "target gone"`: exit `0`, output `Goal US-9.9 recorded as STOPPED`, and the goal then read `\| Status \| STOPPED \|`, `\| Reason \| target gone \|`, with `Target` (`US-9.9`), `Started` (`2026-09-26`), and the authored Notes block preserved. **B — SPECS.md removed.** With the goal ACTIVE, `mv SPECS.md SPECS.md.bak` then `stop --reason "specs gone"`: exit `0`, `Goal US-1.1 recorded as STOPPED`, `\| Status \| STOPPED \|`, `Target`/`Started` preserved. **Normal path.** With a resolvable target, `stop --reason "lunch break"` exits `0` and records `\| Status \| STOPPED \|`. **No goal.** `stop` with no `goal.md` exits `1` with `error: no delivery goal recorded …`. |
| 4 | The script index describes the archive guard accurately | PASS | Method: inspection, code first. **scripts/README.md** line 25: "`guard-archive.sh` \| Reject archive while any completion condition is unmet \| US-8.2, US-10.1". **scripts/guard-archive.sh** delegates the verdict: it reads `archiveEligible` from `workflow-status.sh` (lines 144–153) and then, when `completion-gate.sh` is executable, runs it and lets its `eligible` field override the gate-chain verdict (lines 176–186), with the comment "when the completion gate is available its verdict is authoritative for archival". The row's "checks the completion conditions" matches that delegation, and it cites both US-8.2 and US-10.1. |

## Evidence Commands

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-12-4-delivery-loop-followups --quiet
```

```text
  PASS  selection        change 'us-12-4-delivery-loop-followups' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   8/8 tasks complete
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
        next owner: tester (/test-feature)
  PASS  acceptance       artifact contracts satisfied
  First incomplete gate: testing
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Stall limit: code, then documents

```bash
grep -n "MAX_STALLS\|max-stalls" scripts/guard-delivery-loop.sh
sed -n '255,290p' scripts/guard-delivery-loop.sh
grep -n "blocked stop attempts" README.md .claude/rules/delivery-loop.md
```

```text
guard-delivery-loop.sh
  48:MAX_STALLS="${DELIVERY_MAX_STALLS:-3}"
  64:  --max-stalls <n>   Unchanged stop attempts allowed before the goal is recorded
  79:    --max-stalls) ... MAX_STALLS="$2" ...
 269:if [ "$COUNT" -gt "$MAX_STALLS" ]; then
 287:  ... Unchanged stop attempts: %s of %s allowed.

README.md
 831:| no progress | `BLOCKED` "no progress" | the derived next action, including gate detail such as `3/10 tasks complete`, did not change across `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts — the stop is allowed after that many blocked attempts, so the default allows it on the 4th. Override with `--max-stalls <n>` or `DELIVERY_MAX_STALLS` |

.claude/rules/delivery-loop.md
  53:| derived state unchanged across `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts — the stop is allowed after that many, so the default allows it on the 4th (`--max-stalls <n>` overrides) | allowed | `BLOCKED` "no progress" |
```

`COUNT > MAX_STALLS` with `MAX_STALLS=3` means attempts 1–3 are blocked and attempt 4 is
allowed. Both documents say "blocked stop attempts", name the default `3`, and name the
override. They agree with the code.

### E-2 — Escalation causes: code, then README

```bash
grep -n "set_action escalate" scripts/delivery.sh
sed -n '830p' README.md
```

```text
delivery.sh escalate sites (derive_next order)
  322  "$sid is $status, not READY"
  342  "$sid depends on unfinished $blocked"
  360  "another change is active: $others (one change at a time)"
  374  "the gate reporter could not report (exit $wrc)"
  407  "gate acceptance: $detail"
  419  "gates pass but completion condition '${ffc:-unknown}' fails"
  424  "unmapped gate '$first'"

README.md:830
| next action is `escalate` | `BLOCKED` + reason | a story is not `READY`/`IN PROGRESS`, a dependency is not `DONE`, another change is already active, the gate reporter could not report, an unmapped gate, the acceptance gate fails, or gates pass but a completion condition fails |
```

Seven code causes, seven named in the README row, including the two the story requires.

### E-3 — Stop fallback (sandbox)

```bash
dir=$(mktemp -d /tmp/tst-us124.XXXXXX)   # /tmp/tst-us124.uwhMYk
# copy scripts/, openspec/config.yaml, .claude/settings.json; write a stub SPECS.md
scripts/delivery.sh start US-1.1
scripts/delivery.sh stop --reason "lunch break"          # normal path
sed -i '' 's/^| Target | US-1.1 |/| Target | US-9.9 |/' openspec/delivery/goal.md
scripts/delivery.sh stop --reason "target gone"          # A: target row unresolvable
mv SPECS.md SPECS.md.bak; scripts/delivery.sh stop --reason "specs gone"   # B: SPECS.md gone
rm -f openspec/delivery/goal.md; scripts/delivery.sh stop                  # C: no goal
```

```text
[normal]  Goal US-1.1 recorded as STOPPED   exit=0
          | Target | US-1.1 |  | Status | STOPPED |  | Reason | lunch break |  | Started | 2026-09-26 |

[A: target row US-9.9]  Goal US-9.9 recorded as STOPPED   exit=0
          | Target | US-9.9 |  | Status | STOPPED |  | Reason | target gone |
          | Started | 2026-09-26 |  | Updated | 2026-09-26 |
          Notes block preserved: <!-- BEGIN AUTHORED: notes --> None. <!-- END AUTHORED: notes -->

[B: SPECS.md removed]  Goal US-1.1 recorded as STOPPED   exit=0
          | Target | US-1.1 |  | Status | STOPPED |  | Reason | specs gone |  | Started | 2026-09-26 |

[C: no goal]  error: no delivery goal recorded at openspec/delivery/goal.md — run: scripts/delivery.sh start <target>   exit=1
```

### E-4 — Archive-guard row: code, then index

```bash
sed -n '25p' scripts/README.md
sed -n '176,186p' scripts/guard-archive.sh
```

```text
scripts/README.md:25
| `guard-archive.sh` | Reject archive while any completion condition is unmet | US-8.2, US-10.1 |

scripts/guard-archive.sh:176-186
if [ -x scripts/completion-gate.sh ]; then
  COMPLETION=$(scripts/completion-gate.sh --change "$CHANGE" --json 2>/dev/null)
  C_ELIGIBLE=$(... "eligible" ...)
  if [ -n "$C_ELIGIBLE" ]; then
    ELIGIBLE="$C_ELIGIBLE"
    ...
# "when the completion gate is available its verdict is authoritative for archival"
```

The row's "checks the completion conditions" matches the delegation to
`completion-gate.sh`, and it cites US-8.2 and US-10.1.

### E-5 — Suite counts cited vs real

```bash
scripts/test-delivery.sh | tail -4
grep -n "179 cases\|179 passed" README.md scripts/README.md SPEC-LOGS/README-EPIC-12.md
```

```text
  passed: 179
  failed: 0

README.md:1301                 | `test-delivery.sh` | Regression suite for goal-driven delivery (179 cases) | US-12.1, US-12.2 |
README.md:1347                 scripts/test-delivery.sh       # 179 cases — goal-driven delivery + Stop hook
scripts/README.md:30           | `test-delivery.sh` | Regression suite for goal-driven delivery (179 cases) | US-12.1, US-12.2 |
scripts/README.md:1292         `179` cases, run in a throwaway copy with a stub `SPECS.md` ...
SPEC-LOGS/README-EPIC-12.md:144   scripts/test-delivery.sh          # 179 passed, 0 failed
```

All three files cite `179`, which matches the real count. The suite's closing line reads
"RESULT: PASS — goal-driven delivery holds."; it is quoted inline here so the validator
does not count it as a criterion. The suite is the implementer's own evidence, and no row
in this report rests on it.

## Failures

None.

## Result

All four criteria were evaluated, and all four passed. Criteria 1, 2, and 4 rest on
inspection of the quoted wording, checked against the code read independently first.
Criterion 3 rests on executable checks in a throwaway copy: the target-row and
missing-`SPECS.md` cases both record `STOPPED` and exit `0`, the normal path still
records `STOPPED`, and `stop` with no goal exits `1`. No criterion was scored without
observed evidence.

## Handoff

All criteria pass, so gate 6 (testing) should now pass. Next: the Product Manager
evaluates the completion gate and archival (`/opsx:archive`). The Tester modified no
product code, scripts, `.claude/**`, `README.md`, `SPECS.md`, `tasks.md`, `review.md`, or
`openspec/delivery/goal.md`. The only file written is this report.
