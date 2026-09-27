# Test Report — us-12-3-document-delivery-orchestrator

Change: us-12-3-document-delivery-orchestrator
Story: US-12.3
Verdict: pass
Coverage: 2/2 acceptance criteria evaluated

Independent acceptance record (2026-09-26, revision `ae11530` + working tree). The
Tester did not write this change. The acceptance criteria were taken from `SPECS.md`
`### US-12.3:` and `specs/harness-documentation/spec.md`, not from the implementer's
claims. Every result below comes from a command I ran or lines I inspected, and the
output shown is what I observed.

- **Method: mixed.** This is a documentation change, so whether the README *explains*
  something is judged by inspection of the quoted sections. Whether the documented
  commands and stop paths *behave as the README says* is judged by executable checks.
- **Stop paths were enumerated from the implementation first**, independently of the
  README: `scripts/guard-delivery-loop.sh` (Stop mode, lines 216–289) and
  `scripts/delivery.sh` (`stop`, `block`, `start`, and every `set_action escalate` in
  `derive_next`, lines 295–427). Only then did I compare them with README §18.
- **Primary behavioural evidence** comes from a Tester-built sandbox
  (`dir=$(mktemp -d /tmp/tst-us123.XXXXXX)`, here `/tmp/tst-us123.lEa9Qk`). It holds a copy
  of `scripts/`, `.claude/settings.json`, and `openspec/config.yaml`, plus a stub `SPECS.md`
  that I wrote. I removed it at the end with `rm -rf "$dir"`.
- **The Stop hook** was extracted verbatim from `.claude/settings.json` with `node -e` and
  run through `sh -c`. `CLAUDE_PROJECT_DIR` was unset and the working directory was the
  sandbox. Payloads were multi-key Claude Code Stop payloads: `session_id`,
  `transcript_path`, `cwd`, `permission_mode`, `hook_event_name: "Stop"`,
  `stop_hook_active`, and `last_assistant_message`. The subagent control payload also
  carried `agent_id` and `agent_type`.
- **Real repository:** I ran only `delivery.sh --help`, `resolve`, and `next`, the
  read-only `scripts/test-delivery.sh`, and the three validators and reporters. A
  `shasum` of `openspec/delivery/goal.md` taken before the probes still matched (`OK`)
  after the sandbox was removed. `openspec/delivery/` still holds only `goal.md`.

Stub design (sandbox `SPECS.md`, containing the line `CODEBASE Context: absent (greenfield)`):

- EPIC-1: US-1.1 READY, with task 1 `Implement the walrus-lexer module.` and task 2
  `Write the otter docs.`; US-1.2 READY, which depends on US-1.1.
- EPIC-2: US-2.1 NEEDS CLARIFICATION.
- EPIC-3: US-3.1 and US-3.2, both DONE.
- EPIC-4: US-4.1 DONE and US-4.2 READY. Later in the run I moved US-4.2 to IN PROGRESS
  with a sandbox change, `us-4-2-ship-puffin-extras`, that has 1 of 2 tasks ticked.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | README explains goal-driven delivery | PASS | Method: mixed. **Command per target kind.** README.md §18 (line 742), "The command, per target kind", has one row each: `/deliver EPIC-3`, `/deliver US-3.2`, `/deliver US-3.2#2`, and `/deliver "widget parser"`. Each row says what is delivered. The §20 cookbook repeats all four. `/deliver` maps to `scripts/delivery.sh start "$ARGUMENTS"` (deliver `SKILL.md` line 47). E-1: on the real repo, `resolve` gives `Kind: epic` for EPIC-12 (byte-identical to the §18 example, checked with `diff`), `Kind: story` for US-12.3, and `Kind: task` with Focus for `US-12.3#1`, `README-EPIC-12`, and `goal-driven delivery section`. `EPIC-99` and `US-12.3#9` exit 1 and name the target. Ambiguous `README` exits 1 with `ambiguous target … use US-N.M#k`, as §18 documents. E-2: in the sandbox, `start`/`next`/`stop` for EPIC-1, US-1.1, `US-1.1#1`, and `walrus-lexer` each recorded the documented Kind, stories, and Focus, and then STOPPED. Ambiguous `otter` and unknown `EPIC-9` exit 1 and print `no delivery goal recorded`. **Every way the loop stops.** I enumerated the implementation's stop paths from the code (E-3), and the §18 "Every way the loop stops" table has a row for each: COMPLETE, escalate→BLOCKED, no progress→BLOCKED, could not be derived→BLOCKED, and `stop`→STOPPED. It also states the Claude Code 8-block override. E-4 ran each path through the wired Stop hook, and each gave the status and reason the README states. Work remaining gave exit 2 "do not stop yet". **Resume.** §18 "Resume an interrupted goal" and §19 say to run `/deliver <same target>`, resolve a BLOCKED reason first, expect no redone stories, and expect a different target to be refused. E-5 covers resume after BLOCKED (no progress; another change active; could not be derived) and after STOPPED (`lunch break`). Each returned `ACTIVE` with the stall counter cleared, resumed at the first undelivered story's first incomplete gate (`implement … 1/2 tasks complete`), and left DONE stories `DONE` and skipped. Findings F-1 to F-4 are precision issues inside documented paths, not omitted paths. See the reasoning below. |
| 2 | Contracts and indexes list the orchestrator | PASS | Method: inspection with `grep -nE` (E-6). **CLAUDE.md** (6 matching lines): line 33 document-map row (`/deliver`, `scripts/delivery.sh`); line 72 `/deliver <EPIC-N \| US-N.M \| US-N.M#k \| "task text">` (skill `.claude/skills/deliver/`); lines 75–76 `scripts/delivery.sh next`, `scripts/guard-delivery-loop.sh`; line 80 `.claude/rules/delivery-loop.md`; line 130 `&& scripts/test-delivery.sh`. **.claude/rules/README.md** (4 lines): line 16 the `delivery-loop.md` index row, which names `/deliver`; lines 37–39 rule-to-guard rows that name `scripts/guard-delivery-loop.sh` and `scripts/delivery.sh next`. **scripts/README.md** (23 lines): lines 28–30 inventory rows for `delivery.sh`, `guard-delivery-loop.sh`, and `test-delivery.sh`; line 1202 `/deliver <target>` (`.claude/skills/deliver/SKILL.md`); line 1204 `.claude/rules/delivery-loop.md`; line 1207 `## delivery.sh`. Each of the three files references the skill, the rule, and the scripts, and every referenced path exists (`ls`). |

### Stop-path coverage (implementation vs README §18)

| Stop path in the implementation | Code location | README §18 row | Exercised (E-4) | Observed |
|---|---|---|---|---|
| next action `complete` | guard L243–247; `derive_next` L307 | every story is `DONE` → `COMPLETE` | yes | exit 0, `Status=COMPLETE`, systemMessage "… is COMPLETE — every story is DONE." |
| next action `escalate` | guard L248–251; 7 `set_action escalate` sites | next action is `escalate` → `BLOCKED` + reason | yes, all 7 causes | exit 0, `Status=BLOCKED`, `Reason=escalate: <cause>` |
| stall count `> MAX_STALLS` | guard L269–273 | no progress → `BLOCKED` "no progress" | yes, default 3 and `DELIVERY_MAX_STALLS=1` | exit 0 on attempt N+1, reason "… unchanged across 4 stop attempts" |
| `delivery.sh next` fails | guard L228–233 | the goal cannot be derived → `BLOCKED` | yes, SPECS.md missing and target gone | exit 0, `Reason=the goal could not be derived: …` |
| `delivery.sh stop` | delivery.sh L751–756 | a human stops it → `STOPPED` | yes | `Status=STOPPED`, `Reason=lunch break`; hook then fails open |
| `delivery.sh block` | delivery.sh L758–786 | recorder of the three BLOCKED rows (not a row of its own) | yes, manual | `Status=BLOCKED`, `Reason=awaiting PM call` (see F-3) |

Escalate causes, in `derive_next` order, with the README row text that covers each:

| Cause | README §18 escalate row | Exercised |
|---|---|---|
| story not READY / IN PROGRESS | "a story is not `READY`/`IN PROGRESS`" | yes, US-2.1 NEEDS CLARIFICATION |
| dependency not DONE | "a dependency is not `DONE`" | yes, US-1.2 → US-1.1 (READY) |
| another change active | "another change is already active" | yes, EPIC-4 with a second change directory |
| gate reporter could not report | not named (O-2) | yes, via a sandbox stub reporter that exits 1 |
| acceptance gate fails | "the acceptance gate fails" | yes, via a sandbox stub |
| gates pass, completion condition fails | "gates pass but a completion condition fails" | yes, via a sandbox stub completion gate |
| unmapped gate | not named (O-2) | yes, via a sandbox stub (`frobnicate`) |

Not counted as loop stops: the fail-open exits (no harness, no `goal.md`, goal not
`ACTIVE`, a non-Stop event) and a subagent Stop payload. In none of these is a loop
running in the main session. Both behaviours are still documented: the fail-open idiom
in §25, and the fact that the guard is aimed at the main session in §18.

### Judgement on the reviewer's observations

The criterion's MUST is "explain every way the loop stops". I read "way" as a stop
*path*: a distinct condition under which the Stop hook allows the stop, or under which
a human halts the goal, together with the status it records. On that reading:

- **O-1 (N versus N+1 attempts):** confirmed. With the default limit, attempts 1–3
  exit 2 and attempt 4 exits 0, with the reason "unchanged across 4 stop attempts".
  The no-progress path itself, its trigger (unchanged derived state including gate
  detail), its setting (`DELIVERY_MAX_STALLS`, default 3), and its recorded status
  are all documented. This is an off-by-one in the threshold wording inside a
  documented path, so it is a finding (F-1), not a FAIL. The wording matches
  `.claude/rules/delivery-loop.md` line 53 and the canonical spec's "across the
  configured number of stop attempts". The README follows its sources.
- **O-2 (two escalate causes not named):** confirmed. Both causes were driven through
  the wired Stop hook, and both took the escalate path: exit 0, `Status=BLOCKED`,
  `Reason=escalate: …`, and the same "human Product Manager decision" systemMessage.
  The README row that governs them, "next action is `escalate`" → `BLOCKED` + reason,
  is present and describes their exact outcome. The cause list is incomplete, but no
  stop path is omitted, so this is a finding (F-2), not a FAIL.
- **Had a whole path been missing** from §18, for example the "could not be derived"
  branch or `stop`→STOPPED, I would have scored criterion 1 FAIL. None is missing.

## Evidence Commands

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-12-3-document-delivery-orchestrator --quiet
shasum openspec/delivery/goal.md > /tmp/tst-us123-goal.sha
```

```text
  PASS  implementation   10/10 tasks complete
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
  First incomplete gate: testing
b42ae41dcf24e6b645dc4d6136d567b6002ce94f  openspec/delivery/goal.md
| Target | EPIC-12 |
| Status | ACTIVE |
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Documented commands on the real repository (read-only)

```bash
for t in EPIC-12 US-12.3 'US-12.3#1' 'README-EPIC-12' 'goal-driven delivery section' \
         EPIC-99 'US-12.3#9' 'README'; do scripts/delivery.sh resolve "$t"; done
scripts/delivery.sh next; scripts/delivery.sh --help
diff <(scripts/delivery.sh resolve EPIC-12) <(README §18 example block)
```

```text
resolve 'EPIC-12'   Kind: epic   3 stories (US-12.1 DONE, US-12.2 DONE, US-12.3 IN PROGRESS)  exit=0
resolve 'US-12.3'   Kind: story                                                          exit=0
resolve 'US-12.3#1' Kind: task   Focus: Add a goal-driven delivery section to `README.md`.  exit=0
resolve 'README-EPIC-12'               Kind: task  Focus: Write `SPEC-LOGS/README-EPIC-12.md`.  exit=0
resolve 'goal-driven delivery section' Kind: task  Focus: Add a goal-driven delivery section …   exit=0
unknown target: EPIC-99 (no '# EPIC-99:' heading in SPECS.md)                            exit=1
unknown target: US-12.3#9 (story US-12.3 has no task #9)                                 exit=1
ambiguous target: 'README' matches 3 tasks — use US-N.M#k:                               exit=1
  US-12.3#1 …  US-12.3#2 …  US-12.3#3 …
Action: test  Owner: tester  Command: /test-feature us-12-3-document-delivery-orchestrator
help exit=0
resolve EPIC-12 == README §18 example (byte-identical)
openspec/delivery/goal.md: OK
```

### E-2 — start / next / stop per target kind (sandbox)

```bash
for t in EPIC-1 US-1.1 'US-1.1#1' 'walrus-lexer'; do
  scripts/delivery.sh start "$t"; grep -E '^\| (Target|Kind|Focus|Status) \|' openspec/delivery/goal.md
  scripts/delivery.sh next; scripts/delivery.sh stop
done
scripts/delivery.sh start 'otter'; scripts/delivery.sh start EPIC-9
```

```text
GOAL  EPIC-1 (epic) — ACTIVE      | Focus | - |   stories US-1.1, US-1.2   next: select US-1.1   Goal EPIC-1 recorded as STOPPED
GOAL  US-1.1 (story) — ACTIVE     | Focus | - |   stories US-1.1           next: select US-1.1   Goal US-1.1 recorded as STOPPED
GOAL  US-1.1#1 (task) — ACTIVE    | Focus | Implement the walrus-lexer module. |   stories US-1.1   Goal US-1.1#1 recorded as STOPPED
GOAL  walrus-lexer (task) — ACTIVE| Focus | Implement the walrus-lexer module. |   stories US-1.1   Goal walrus-lexer recorded as STOPPED
ambiguous target: 'otter' matches 2 tasks — use US-N.M#k:  (US-1.1#2, US-1.2#1)   no delivery goal recorded  exit=1
unknown target: EPIC-9 (no '# EPIC-9:' heading in SPECS.md)                       no delivery goal recorded  exit=1
```

### E-3 — Stop paths enumerated from the implementation

```bash
grep -n "exit\|record_block\|MAX_STALLS\|NRC" scripts/guard-delivery-loop.sh
grep -n "set_action escalate\|STOPPED\|BLOCKED\|COMPLETE" scripts/delivery.sh
```

```text
guard-delivery-loop.sh  (Stop mode, main session, goal ACTIVE)
  228  if [ "$NRC" -ne 0 ] || [ -z "$NEXT" ]  -> record_block "the goal could not be derived: …"; exit 0
  243  complete)  -> delivery.sh refresh (COMPLETE); exit 0
  248  escalate)  -> record_block "escalate: $NREASON"; exit 0
  269  if [ "$COUNT" -gt "$MAX_STALLS" ] -> record_block "no progress: …"; exit 0
  289  otherwise  -> exit 2 (block, name action/owner/command)
  fail-open exits 0: no delivery.sh, no goal.md, Status != ACTIVE, event != Stop, subagent
delivery.sh
  322 escalate "$sid is $status, not READY"                     342 "$sid depends on unfinished …"
  360 "another change is active: …"                             374 "the gate reporter could not report (exit $wrc)"
  407 "gate acceptance: $detail"                                419 "gates pass but completion condition '…' fails"
  424 "unmapped gate '$first'"
  754 stop  -> refresh_goal STOPPED "${REASON_ARG:-stopped by the Product Manager}"
  770 block -> refresh_goal BLOCKED "$REASON_ARG"  (in-place rewrite when the target no longer resolves)
```

### E-4 — Every stop path through the wired Stop hook (sandbox)

```bash
unset CLAUDE_PROJECT_DIR
STOP_CMD=$(node -e 'const s=require("./.claude/settings.json");console.log(s.hooks.Stop[0].hooks[0].command)')
stop_payload false | sh -c "$STOP_CMD"      # helper `fire` prints exit, stderr, stdout, goal Status/Reason
```

```text
STOP_CMD=sh -c 'd="${CLAUDE_PROJECT_DIR:-$PWD}"; test -x "$d/scripts/guard-delivery-loop.sh" && exec "$d/scripts/guard-delivery-loop.sh" --hook --quiet; exit 0'
CLAUDE_PROJECT_DIR=<unset>
payload: {"session_id":"tst-us123-25082","transcript_path":"/tmp/tst-us123.jsonl","cwd":"/tmp/tst-us123.lEa9Qk","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"Done with this step; stopping here."}

[work remains, EPIC-1 next=select]  exit=2  Status=ACTIVE
    stderr: Delivery goal EPIC-1 is ACTIVE — do not stop yet.
    stderr: Next action: select  (owner: product-manager, story: US-1.1)
    stderr: … Unchanged stop attempts: 1 of 3 allowed.
[stop_hook_active=true]             exit=2  Status=ACTIVE  (2 of 3 allowed)
[subagent payload, agent_id]        exit=0  Status=ACTIVE  (control: not the main session)

[no progress, default 3]  attempt 3: exit=2 "3 of 3 allowed"
                          attempt 4: exit=0  Status=BLOCKED  Reason=no progress: next action 'select' for US-1.1 unchanged across 4 stop attempts
    stdout: { "systemMessage": "Delivery goal EPIC-1 recorded BLOCKED — no progress: … run /deliver EPIC-1 to resume." }
    loop.state: absent;  further stop on BLOCKED goal: exit=0
[no progress, DELIVERY_MAX_STALLS=1]  #1 exit=2 "1 of 1 allowed";  #2 exit=0  Reason=no progress: … unchanged across 2 stop attempts
[progress resets count]  archive→… : 1 of 3, 2 of 3, (tick 1.2) review 1 of 3, (untick) implement 1 of 3

[escalate: NEEDS CLARIFICATION]  exit=0  Status=BLOCKED  Reason=escalate: US-2.1 is NEEDS CLARIFICATION, not READY
    stdout: { "systemMessage": "Delivery goal EPIC-2 recorded BLOCKED — a human Product Manager decision is required: … Resolve it, then run /deliver EPIC-2 to resume." }
[escalate: dependency]           exit=0  Reason=escalate: US-1.2 depends on unfinished US-1.1 (READY)   (no change dir created)
[escalate: another change]       exit=0  Reason=escalate: another change is active: us-1-1-build-otter-parser (one active change at a time)
[escalate: reporter failed]      exit=0  Reason=escalate: the gate reporter could not report (exit 1)          (O-2)
[escalate: unmapped gate]        exit=0  Reason=escalate: unmapped gate 'frobnicate'                             (O-2)
[escalate: acceptance gate]      exit=0  Reason=escalate: gate acceptance: SPECS.md fails the readiness/context contract
[escalate: completion condition] exit=0  Reason=escalate: gates pass but completion condition 'openspec-verification' fails
sandbox reporters restored   (cmp against the real scripts: identical)

[could not be derived: SPECS.md missing]  exit=0  Status=BLOCKED  Reason=the goal could not be derived: SPECS.md not found (looked for docs/SPECS.md and SPECS.md)
[could not be derived: target gone]       exit=0  Status=BLOCKED  Reason=the goal could not be derived: unknown target: US-1.1#2 (story US-1.1 has no task #2)

[COMPLETE: EPIC-3 all DONE]        start → "GOAL EPIC-3 (epic) — COMPLETE"; Stop exit=0  Status=COMPLETE
[COMPLETE: US-1.1 set DONE]        before: exit=2;  after: exit=0  Status=COMPLETE
    stdout: { "systemMessage": "Delivery goal US-1.1 is COMPLETE — every story is DONE." }
    Action: complete   Reason: all 1 story/stories are DONE   loop.state: absent

[human stop]  scripts/delivery.sh stop --reason "lunch break" → "Goal EPIC-4 recorded as STOPPED" exit=0
              Status=STOPPED  Reason=lunch break  loop.state: absent;  Stop hook then exit=0 (fails open)
[manual block] scripts/delivery.sh block --reason "awaiting PM call" → "Goal US-1.1 recorded as BLOCKED — awaiting PM call"; Stop hook exit=0
```

The four escalate branches that are hard to reach naturally were driven by sandbox-only
stubs: two replacement `scripts/workflow-status.sh` bodies, `scripts/completion-gate.sh`
returning `eligible: false`, and a gate reporter that exits 1. The sandbox copies were
restored and compared with `cmp` against the real scripts before the next step.

### E-5 — Resume, following README §18 "Resume an interrupted goal" (sandbox)

```bash
scripts/delivery.sh start <same target>          # what /deliver <same target> runs (deliver SKILL.md line 47)
```

```text
[after BLOCKED no-progress]  GOAL EPIC-1 (epic) — ACTIVE   loop.state absent; next Stop "1 of 3 allowed"
[after BLOCKED another-change, cause resolved]  GOAL EPIC-4 (epic) — ACTIVE  Action: select  Story: US-4.2
    | 1 | US-4.1 | us-4-1-ship-puffin-core | DONE | …   (DONE story skipped, not redone)
[after STOPPED "lunch break"]  GOAL EPIC-4 (epic) — ACTIVE
    Action: implement  Story: US-4.2  Command: /opsx:apply us-4-2-ship-puffin-extras
    Reason: gate implementation: 1/2 tasks complete   (first incomplete gate; planning gates not redone)
    | 1 | US-4.1 | … | DONE |   | 2 | US-4.2 | … | IN PROGRESS |   Started unchanged
[after BLOCKED could-not-be-derived, SPECS.md restored]  GOAL EPIC-4 (epic) — ACTIVE  Action: implement
[after manual block]  GOAL US-1.1 (story) — ACTIVE
[EPIC-1 after US-1.1 DONE]  Action: select  Story: US-1.2   | 1 | US-1.1 | … | DONE |
[different target while ACTIVE]   error: a different goal is ACTIVE (EPIC-1) — run scripts/delivery.sh stop first   exit=1
[different target while BLOCKED]  error: a different goal is BLOCKED (EPIC-2) — run scripts/delivery.sh stop first  exit=1
[stop on an unresolvable target]  error: recorded target 'US-1.1#2' no longer resolves   exit=1   (F-4)
```

### E-6 — Contracts and indexes (real repository)

```bash
for f in CLAUDE.md .claude/rules/README.md scripts/README.md; do
  grep -nE '/deliver|deliver/SKILL\.md|delivery-loop|delivery\.sh|guard-delivery-loop\.sh|test-delivery\.sh' "$f"
done
ls .claude/skills/deliver/SKILL.md .claude/rules/delivery-loop.md scripts/delivery.sh scripts/guard-delivery-loop.sh scripts/test-delivery.sh
```

```text
=== CLAUDE.md  count=6
33:| `openspec/delivery/goal.md` | The recorded delivery goal (`/deliver`); derived by `scripts/delivery.sh` | No — derived record |
72:`/deliver <EPIC-N | US-N.M | US-N.M#k | "task text">` (skill `.claude/skills/deliver/`)
75:`scripts/delivery.sh next`, never remembered. Each action is delegated to its owning
76:role. `scripts/guard-delivery-loop.sh`, wired as a `Stop` hook, keeps the session
80:`.claude/rules/delivery-loop.md`.
130:    && scripts/test-delivery.sh
=== .claude/rules/README.md  count=4
16:| `delivery-loop.md` | Goal-driven delivery (`/deliver`): derived next action, role delegation, stop conditions, no gate exceptions | US-12.1, US-12.2, FR-019 |
37:| Keep working while a goal is ACTIVE (`delivery-loop.md`) | `scripts/guard-delivery-loop.sh` via `Stop` |
38:| Orchestrator never authors verdicts (`delivery-loop.md`) | `scripts/guard-delivery-loop.sh` via `PreToolUse` |
39:| Next action is derived, not remembered (`delivery-loop.md`) | `scripts/delivery.sh next` |
=== scripts/README.md  count=23
28:| `delivery.sh` | Resolve a delivery target; derive the next action; record, refresh, reopen, stop, and block a goal | US-12.1, US-12.2 |
29:| `guard-delivery-loop.sh` | `Stop` hook keeping a delivery goal running; blocks the orchestrator from authoring verdicts | US-12.2 |
30:| `test-delivery.sh` | Regression suite for goal-driven delivery (166 cases) | US-12.1, US-12.2 |
1202:`/deliver <target>` (`.claude/skills/deliver/SKILL.md`) runs the workflow as a loop over
1204:delivered as its own change. Rules: `.claude/rules/delivery-loop.md`. Handbook:
1207:## `delivery.sh`
CLAUDE.md: skill=4 rule=2 scripts=4
.claude/rules/README.md: skill=2 rule=4 scripts=3
scripts/README.md: skill=13 rule=6 scripts=19
(all five referenced paths exist)
```

### E-7 — Supplementary: regression suite and live-goal integrity

```bash
scripts/test-delivery.sh | tail -4
shasum -c /tmp/tst-us123-goal.sha; ls openspec/delivery
rm -rf "$dir"
```

```text
  passed: 166
  failed: 0
openspec/delivery/goal.md: OK
goal.md
removing /tmp/tst-us123.lEa9Qk
sandbox removed
```

The suite's closing line reads "RESULT: PASS — goal-driven delivery holds.". It is
quoted inline here so that the validator does not count it as a criterion. The suite
is the implementer's own evidence, and no row in this report rests on it.

## Findings

These are non-blocking. None of them omits a stop path or breaks a MUST.

- **F-1 — Stall threshold is off by one (confirms O-1).** README §18 says the goal is
  BLOCKED when the action "did not change across `DELIVERY_MAX_STALLS` (default 3) stop
  attempts". The observed behaviour is that N unchanged attempts are *blocked* and
  attempt N+1 is *allowed* and recorded: "unchanged across 4 stop attempts" with the
  default, and "2 stop attempts" with `DELIVERY_MAX_STALLS=1`. A reader who expects
  the third stop to be allowed would be surprised. Suggested wording: "after
  `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts, the next unchanged attempt
  is allowed". The same wording appears in `.claude/rules/delivery-loop.md` line 53.
- **F-2 — Escalate cause list is not exhaustive (confirms O-2).** The §18 escalate row
  omits "the gate reporter could not report" (`delivery.sh` line 374) and "unmapped
  gate" (line 424). Both were exercised and both take the documented escalate→BLOCKED
  path with the documented systemMessage. Adding "or the gate reporter fails or
  reports an unknown gate" would make the row complete.
- **F-3 — Manual `delivery.sh block` is not mentioned in §18.** It is listed in the §25
  inventory ("stop, and block a goal") and in `scripts/README.md` line 1216 ("used by
  the Stop hook"). It is the recorder behind the three BLOCKED rows, not an independent
  trigger of the Stop hook, so I did not count it as a separate stop path. A human can
  still run it by hand. It records BLOCKED with the given reason, and `start <same
  target>` resumes it, which I observed. §18 could say so in one line.
- **F-4 — Troubleshooting advice fails for a goal that cannot be derived (confirms
  O-3).** README line 1374 advises "`scripts/delivery.sh stop`, then `/deliver <new
  target>`". When the recorded target no longer resolves, `stop` exits 1 with
  `recorded target 'US-1.1#2' no longer resolves`. A different target is then refused
  because the goal is BLOCKED. Resume with the same target, after the target is
  restored, works as §18 describes (observed). The gap is in switching targets, not in
  resuming, so the resume MUST holds.

## Result

Both criteria were evaluated, and both passed. Criterion 1 rests on inspection of README
§18–§20 for the explanations. It also rests on executable checks showing that every
documented command, stop path, and resume step behaves as written. I enumerated the stop
paths from the implementation before reading the README's list, and all five
implementation stop paths have a §18 row. Criterion 2 rests on `grep -n` inspection
of the three named files, with the matching lines quoted. No criterion was scored
without observed evidence.

## Failures

None.

## Handoff

All criteria pass, so gate 6 (testing) should now pass. Next: the Product Manager
evaluates the completion gate and archival (`/opsx:archive`). Findings F-1 to F-4 may
be taken up as follow-ups at the Product Manager's discretion. The Tester modified no
product code, scripts, `.claude/**`, `README.md`, `SPECS.md`, `tasks.md`, `review.md`,
or `openspec/delivery/goal.md`. The only file written is this report.
