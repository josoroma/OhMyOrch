# Test Report — us-12-2-run-delivery-goal-loop

Change: us-12-2-run-delivery-goal-loop
Story: US-12.2
Verdict: pass
Coverage: 6/6 acceptance criteria evaluated

Independent acceptance record (2026-09-26, revision `ae11530` + working tree). The
Tester did not write this code. Every result below was produced by running the command
shown under Evidence Commands, and the output shown is what I observed.

- **Primary evidence** comes from a Tester-built sandbox (`mktemp -d /tmp/tst-us122.XXXXXX`,
  here `/tmp/tst-us122.oog2da`). It holds a copy of `scripts/` and `.claude/settings.json`,
  a stub `SPECS.md` that I wrote, and change fixtures that I built.
- **Hook commands** were extracted verbatim from `.claude/settings.json` with `node -e` and
  run through `sh -c`. `CLAUDE_PROJECT_DIR` was unset and the working directory was the
  sandbox, so every command resolved `$PWD`.
- **Payloads** were realistic multi-key Claude Code payloads:
  - Stop: `session_id`, `transcript_path`, `cwd`, `permission_mode`,
    `hook_event_name: "Stop"`, `stop_hook_active`, `last_assistant_message`.
  - PreToolUse `Write`/`Edit`/`MultiEdit`: `tool_name`, `tool_input.file_path` (absolute)
    with `content` or `old_string`/`new_string`, `tool_use_id`.
  - PreToolUse `Bash`: `tool_input.command` plus `description`.
  - Subagent payloads also carry `agent_id` and `agent_type`.
- **Supplementary only:** read-only `resolve`/`next` probes on the real repository and the
  implementer's `scripts/test-delivery.sh`.
- **Real repository untouched:** I ran no `start`, `stop`, `block`, or `refresh` against
  it. Its `openspec/delivery/goal.md` passed a `shasum -c` check taken before the
  probes, and it still holds only `goal.md`. I removed the sandbox afterwards.

Stub design (sandbox `SPECS.md`, first line `CODEBASE Context: absent (greenfield)`;
`validate-product-artifacts.sh --quiet` exited 0 on it):

- EPIC-1 has two READY stories. US-1.2 depends on US-1.1, and US-1.1 task 2 is
  `Implement the quokka-scanner module.`
- EPIC-2 has US-2.1, which is NEEDS CLARIFICATION.
- EPIC-3 has US-3.1 (DONE) and US-3.2 (READY).
- EPIC-4 has US-4.1, which is READY but depends on US-4.2 (READY, not DONE).

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Start a delivery goal | PASS | Method: mixed (executable checks, plus inspection for the delegation instruction). **Goal recorded.** E-1a: `delivery.sh start EPIC-1` exits 0. `goal.md` holds `\| Target \| EPIC-1 \|`, `\| Kind \| epic \|`, `\| Status \| ACTIVE \|`, and a Stories table with US-1.1 and US-1.2. `start US-3.2` (story) and `start 'US-1.1#2'` / `start quokka-scanner` (task) each record Target, the story or parent story, `Status ACTIVE`, and for a task the Focus `Implement the quokka-scanner module.` A different target is refused while one is ACTIVE (exit 1), and `goal.md` stays byte-identical (`cmp`). **Each action is delegated to its owner.** E-1b: I built a change one artifact at a time through 9 stages. Every `next --json` action named a non-empty owner, and each owner equals the Owner column of the deliver skill's delegation table: select→product-manager, propose→planner, plan→planner, implement→implementer, review→reviewer, reopen→product-manager, test→tester, archive→product-manager. The escalate/complete rows are covered in rows 3 and 5. By inspection, the skill's Step 2 and `product-manager.md` §Goal-driven delivery tell the orchestrator to delegate every action it does not own, and the Stop hook's block message repeats "Delegate this action to the `<owner>` role". **Orchestrator cannot author verdicts.** E-1c: with the wired `Write\|Edit\|MultiEdit` command, main-session writes to `review.md`, `test-report.md`, `REVIEW.md`, and `Test-Report.MD`, and `Edit`/`MultiEdit` on `review.md`, all exit 2 with `BLOCKED … the orchestrator must not author … (BR-002)`. Controls: main `tasks.md` and `history/review-r1.md`, and reviewer/tester subagent payloads, exit 0. With the goal STOPPED, the guard fails open (exit 0). Limitation: a live model delegating in a real Claude Code session was not observed. The delegation clause rests on the executable owner derivation plus inspection of the skill and agent text. That is the correct method for a prompt contract, and I did not treat it as a live observation. |
| 2 | Continue while work remains | PASS | E-2: wired Stop command, main-session payload, ACTIVE goal EPIC-1. Next action `archive`: exit 2, stderr `Next action: archive  (owner: product-manager, story: US-1.1)`, plus the `Command:` and `Reason:` lines. Next action `implement` (after I unticked task 1.2): exit 2, stderr `Next action: implement  (owner: implementer, story: US-1.1)`, `Command: /opsx:apply us-1-1-build-kiwi-tokenizer`. EPIC-3 next action `select`: exit 2, `owner: product-manager`. Payload with `stop_hook_active: true`: still exit 2. Control: a subagent Stop payload (`agent_id`, `agent_type: reviewer`) exits 0, so only the main session is held. The goal stays `ACTIVE` throughout. |
| 3 | Halt for a human decision | PASS | E-3: wired Stop command. Goal EPIC-2, next action `escalate` (`US-2.1 is NEEDS CLARIFICATION, not READY`): exit 0. stdout `systemMessage` says "recorded BLOCKED — a human Product Manager decision is required …". `goal.md` shows `Status=BLOCKED  Reason=escalate: US-2.1 is NEEDS CLARIFICATION, not READY`, with Target and Started preserved. Goal US-4.1 (unfinished dependency): exit 0, `Reason=escalate: US-4.1 depends on unfinished US-4.2 (READY)`, and no change directory was created. Goal EPIC-3 while another change was active: exit 0, `Reason=escalate: another change is active: us-1-1-build-kiwi-tokenizer (one active change at a time)`. A further stop on the BLOCKED goal exits 0 and leaves the record as is. `start EPIC-2` resumes it as `ACTIVE`. |
| 4 | Halt when the loop stops making progress | PASS | E-4: wired Stop command, goal EPIC-1, derived state unchanged. With the default limit of 3, stops #1–#3 exit 2 (`Unchanged stop attempts: 1/2/3 of 3 allowed`). Stop #4 exits 0 with `goal.md` `Status=BLOCKED  Reason=no progress: next action 'archive' for US-1.1 unchanged across 4 stop attempts`, a matching `systemMessage`, and `loop.state` removed. With `DELIVERY_MAX_STALLS=1` in the wired command's environment: stop #1 exits 2 and stop #2 exits 0, recorded BLOCKED "no progress … 2 stop attempts". Control: when the derived state changes between stops (archive→implement→archive), the count resets to 1 each time and nothing is recorded. After a stall, `start EPIC-1` resumes with `loop.state` absent. |
| 5 | Complete the goal | PASS | E-5: wired Stop command, goal EPIC-3 with US-3.1 DONE and US-3.2 READY: exit 2, next action `select`. After US-3.2 was set to `Status: DONE` in the sandbox `SPECS.md`: exit 0, stdout `{ "systemMessage": "Delivery goal EPIC-3 is COMPLETE — every story is DONE." }`, `goal.md` `Status=COMPLETE`, both story rows `DONE`, `Action: complete`, and `loop.state` removed. A further stop exits 0 with no output. Control: `start US-3.1` (already DONE) records `COMPLETE`, and its Stop exits 0. |
| 6 | The loop cannot bypass a gate | PASS | E-6: the goal EPIC-1 is ACTIVE. The payload is the wired `Bash` PreToolUse command (`guard-archive.sh --hook --quiet`) with `command: "openspec archive us-1-1-build-kiwi-tokenizer -y"`. Four ineligible states each exit 2, print `BLOCKED  archive … Change is not archive-eligible.`, and leave the change directory in place. The first failing condition matched `completion-gate.sh` each time: a blocking review → `review`; a failing test report → `acceptance`; an unticked task → `tasks`; all seven gates passing but a recorded `OpenSpec verify: MISMATCH` → `openspec-verification`. The last case is a completion-only condition that no gate checks. The exact command string that `delivery.sh next` emits for archival (`completion-gate.sh … --record && openspec archive … -y`) is also blocked (exit 2). The delivery-loop guard exits 0 on the same Bash payload: it has no archive path or override. Control: with the change eligible (`eligible=true`, `next=archive`), the same wired command exits 0. |

## Evidence Commands

Sandbox commands ran with the sandbox as the working directory. The sandbox helper
(`.t-helpers.sh`, a sandbox-only file) extracts the three hook commands and builds
the payloads. `$C` is `openspec/changes/us-1-1-build-kiwi-tokenizer`.

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-12-2-run-delivery-goal-loop --quiet
```

```text
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
        next owner: tester (/test-feature)
  First incomplete gate: testing
```

Gate 5 (review) passes, so testing may proceed.

### Hook extraction

```bash
unset CLAUDE_PROJECT_DIR
STOP_CMD=$(node -e 'const s=require("./.claude/settings.json");console.log(s.hooks.Stop[0].hooks[0].command)')
PTU_CMD=$(node -e '…PreToolUse.find(x=>x.matcher==="Write|Edit|MultiEdit")…guard-delivery-loop…')
ARCH_CMD=$(node -e '…PreToolUse.find(x=>x.matcher==="Bash")…guard-archive…')
stop_payload | sh -c "$STOP_CMD"      # and likewise for write_payload / bash_payload
```

```text
STOP: sh -c 'd="${CLAUDE_PROJECT_DIR:-$PWD}"; test -x "$d/scripts/guard-delivery-loop.sh" && exec "$d/scripts/guard-delivery-loop.sh" --hook --quiet; exit 0'
PTU:  sh -c 'd="${CLAUDE_PROJECT_DIR:-$PWD}"; test -x "$d/scripts/guard-delivery-loop.sh" && exec "$d/scripts/guard-delivery-loop.sh" --hook --quiet; exit 0'
ARCH: sh -c 'd="${CLAUDE_PROJECT_DIR:-$PWD}"; test -x "$d/scripts/guard-archive.sh" && exec "$d/scripts/guard-archive.sh" --hook --quiet; exit 0'
CLAUDE_PROJECT_DIR=<unset>
```

Example Stop payload used:
`{"session_id":"tst-7f3a","transcript_path":"/tmp/tst-7f3a.jsonl","cwd":"<sandbox>","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"I have finished this step and will stop here."}`.
The subagent variant adds `"agent_id":"agt-91","agent_type":"reviewer"`.

### E-1 — Start a delivery goal

```bash
scripts/delivery.sh start EPIC-1; grep -E '^\| (Target|Kind|Focus|Status|Reason|Started) \|' openspec/delivery/goal.md
scripts/delivery.sh start US-3.2          # while EPIC-1 is ACTIVE -> refused; cmp goal.md
scripts/delivery.sh start US-3.2 / 'US-1.1#2' / quokka-scanner   # each after `stop`
bash .t-e1-stages.sh      # 9-stage owner derivation vs. the deliver skill's table
bash .t-e1-verdict.sh     # wired PreToolUse verdict guard
scripts/check-write-scope.sh --role <r> --file $C/review.md|test-report.md   # supplementary
```

```text
GOAL  EPIC-1 (epic) — ACTIVE
Action:  select
Owner:   product-manager
start exit=0
| Target | EPIC-1 |
| Kind | epic |
| Status | ACTIVE |
| 1 | US-1.1 | us-1-1-build-kiwi-tokenizer | READY | Build the kiwi tokenizer |
| 2 | US-1.2 | us-1-2-render-kiwi-tokens | READY | Render kiwi tokens |
error: a different goal is ACTIVE (EPIC-1) — run scripts/delivery.sh stop first
different-goal start exit=1
goal.md unchanged by refused start
GOAL  US-3.2 (story) — ACTIVE        | Kind | story |  | 1 | US-3.2 | …
GOAL  US-1.1#2 (task) — ACTIVE       | Focus | Implement the quokka-scanner module. |  | 1 | US-1.1 | …
GOAL  quokka-scanner (task) — ACTIVE | Focus | Implement the quokka-scanner module. |

-- stages (goal EPIC-1 ACTIVE): derived owner vs. deliver-skill owner
0 no change        action=select     owner=product-manager  skill=product-manager (you)
1 tasks.md only    action=propose    owner=planner          skill=planner
2 +proposal+specs  action=plan       owner=planner          skill=planner
3 +plan            action=implement  owner=implementer      skill=implementer
4 tasks ticked     action=review     owner=reviewer         skill=reviewer
5a blocking review action=reopen     owner=product-manager  skill=product-manager (you)
5b approved review action=test       owner=tester           skill=tester
6a failing test    action=reopen     owner=product-manager  skill=product-manager (you)
6b passing test    action=archive    owner=product-manager  skill=product-manager (you)
(skill table also maps: mark-done -> product-manager (you); escalate -> human Product Manager; complete -> —)

-- wired verdict guard, goal ACTIVE
main   review.md                  exit=2  BLOCKED  delivery goal EPIC-1 is ACTIVE: the orchestrator must not author review.md (BR-002).
main   test-report.md             exit=2  BLOCKED  … must not author test-report.md (BR-002).
main   REVIEW.md (case)           exit=2
main   Test-Report.MD (case)      exit=2
main   Edit review.md             exit=2
main   MultiEdit review.md        exit=2
main   tasks.md (control)         exit=0
main   history/review-r1.md       exit=0
reviewer subagent review.md       exit=0
tester subagent test-report.md    exit=0
  Delegate to the reviewer subagent (/review-feature <change-id>); it writes review.md under its own write-scope hook.
main   review.md, goal STOPPED    exit=0
-- supplementary role write scope (check-write-scope.sh)
product-manager  review.md exit=2   test-report.md exit=2
reviewer         review.md exit=0   test-report.md exit=2
tester           review.md exit=2   test-report.md exit=0
```

### E-2 — Continue while work remains

```bash
stop_payload | sh -c "$STOP_CMD"                 # next=archive
perl -0pi -e 's/- \[x\] 1\.2/- [ ] 1.2/' $C/tasks.md; stop_payload | sh -c "$STOP_CMD"   # next=implement
SHA=true stop_payload | sh -c "$STOP_CMD"        # stop_hook_active: true
stop_payload agent | sh -c "$STOP_CMD"           # subagent control
```

```text
[2a main Stop, next=archive] exit=2  goal Status=ACTIVE
    stderr: Delivery goal EPIC-1 is ACTIVE — do not stop yet.
    stderr: Next action: archive  (owner: product-manager, story: US-1.1)
    stderr: Command: scripts/completion-gate.sh --change us-1-1-build-kiwi-tokenizer --record && openspec archive us-1-1-build-kiwi-tokenizer -y
    stderr: Reason: all seven gates and all four completion conditions pass
[2b main Stop, next=implement] exit=2  goal Status=ACTIVE
    stderr: Next action: implement  (owner: implementer, story: US-1.1)
    stderr: Command: /opsx:apply us-1-1-build-kiwi-tokenizer
    stderr: Reason: gate implementation: 1/2 tasks complete
[2c main Stop, stop_hook_active=true] exit=2  goal Status=ACTIVE
[2d subagent Stop (agent_id)] exit=0  goal Status=ACTIVE
[5a EPIC-3, next=select] exit=2
    stderr: Next action: select  (owner: product-manager, story: US-3.2)
```

In my first E-2 run, the 2b untick used GNU-only `sed '0,/re/'`, which BSD sed ignores.
That run exercised the archive stage twice. I discarded it and reran 2b with `perl`, and
the rerun is shown above.

### E-3 — Halt for a human decision

```bash
scripts/delivery.sh start EPIC-2; stop_payload | sh -c "$STOP_CMD"
scripts/delivery.sh start US-4.1; stop_payload | sh -c "$STOP_CMD"; find openspec/changes -maxdepth 1 -mindepth 1 -type d
```

```text
Action:  escalate
Owner:   human-product-manager
Reason:  US-2.1 is NEEDS CLARIFICATION, not READY
[3a main Stop, next=escalate] exit=0  goal Status=BLOCKED  Reason=escalate: US-2.1 is NEEDS CLARIFICATION, not READY
    stdout: { "systemMessage": "Delivery goal EPIC-2 recorded BLOCKED — a human Product Manager decision is required: US-2.1 is NEEDS CLARIFICATION, not READY. Resolve it, then run /deliver EPIC-2 to resume." }
    Target=EPIC-2 Started=2026-09-26 (before: 2026-09-26)
[3a' main Stop again] exit=0  goal Status=BLOCKED
GOAL  EPIC-2 (epic) — ACTIVE          (resume)
[3b main Stop, next=escalate] exit=0  goal Status=BLOCKED  Reason=escalate: US-4.1 depends on unfinished US-4.2 (READY)
    changes: openspec/changes/archive openspec/changes/us-1-1-build-kiwi-tokenizer
[EPIC-3 with another change active] exit=0  goal Status=BLOCKED  Reason=escalate: another change is active: us-1-1-build-kiwi-tokenizer (one active change at a time)
```

### E-4 — Halt when the loop stops making progress

```bash
for i in 1 2 3 4; do stop_payload | sh -c "$STOP_CMD"; done      # default limit 3
DELIVERY_MAX_STALLS=1; stop x2                                   # configured limit
# progress control: stop, stop, untick 1.2, stop, re-tick, stop
```

```text
[4a stop #1] exit=2  … Unchanged stop attempts: 1 of 3 allowed.   loop.state: count=1
[4a stop #2] exit=2  … Unchanged stop attempts: 2 of 3 allowed.   loop.state: count=2
[4a stop #3] exit=2  … Unchanged stop attempts: 3 of 3 allowed.   loop.state: count=3
[4a stop #4] exit=0  goal Status=BLOCKED  Reason=no progress: next action 'archive' for US-1.1 unchanged across 4 stop attempts
    stdout: { "systemMessage": "Delivery goal EPIC-1 recorded BLOCKED — no progress: … Inspect scripts/delivery.sh next, then run /deliver EPIC-1 to resume." }
    loop.state: absent
GOAL  EPIC-1 (epic) — ACTIVE   loop.state absent      (resume)
[4b stop #1] exit=2  … 1 of 1 allowed.
[4b stop #2] exit=0  goal Status=BLOCKED  Reason=no progress: next action 'archive' for US-1.1 unchanged across 2 stop attempts
[4c stop #1 (archive)]   exit=2  count=1
[4c stop #2 (archive)]   exit=2  count=2
[4c stop #3 (implement)] exit=2  count=1
[4c stop #4 (archive)]   exit=2  count=1
```

### E-5 — Complete the goal

```bash
mv $C .parked-us-1-1           # sandbox: so EPIC-3 is not held by one-active-change
scripts/delivery.sh start EPIC-3; stop_payload | sh -c "$STOP_CMD"
perl -0pi -e 's/(### US-3\.2: Ship the papaya extras\n\nStatus: )READY/${1}DONE/' SPECS.md
stop_payload | sh -c "$STOP_CMD"; stop_payload | sh -c "$STOP_CMD"
scripts/delivery.sh start US-3.1; stop_payload | sh -c "$STOP_CMD"
```

```text
[5a US-3.2 READY, US-3.1 DONE -> work remains] exit=2  goal Status=ACTIVE
[5b every story DONE] exit=0  goal Status=COMPLETE
    stdout: { "systemMessage": "Delivery goal EPIC-3 is COMPLETE — every story is DONE." }
    loop.state: absent
    | 1 | US-3.1 | us-3-1-ship-papaya-core | DONE | Ship the papaya core |
    | 2 | US-3.2 | us-3-2-ship-papaya-extras | DONE | Ship the papaya extras |
    Action: complete
    Reason: all 2 story/stories are DONE
[5c further stop on COMPLETE goal] exit=0  (no output)
GOAL  US-3.1 (story) — COMPLETE
[5d US-3.1 goal] exit=0  goal Status=COMPLETE
```

### E-6 — The loop cannot bypass a gate

```bash
bash_payload "openspec archive us-1-1-build-kiwi-tokenizer -y" | sh -c "$ARCH_CMD"
# states: blocking review | failing test report | unticked task | OpenSpec verify MISMATCH | eligible
bash_payload "scripts/completion-gate.sh --change … --record && openspec archive … -y" | sh -c "$ARCH_CMD"
bash_payload "openspec archive us-1-1-build-kiwi-tokenizer -y" | sh -c "$PTU_CMD"   # loop guard
```

```text
== 6a blocking review         eligible=false first=review                | next=reopen
[6a openspec archive … -y] exit=2
    BLOCKED  archive us-1-1-build-kiwi-tokenizer
      Change is not archive-eligible.
      First failing condition: review
    change dir still active: yes
== 6b failing test report     eligible=false first=acceptance            | next=reopen
[6b] exit=2  First failing condition: acceptance
== 6c unticked task           eligible=false first=tasks                 | next=implement
[6c] exit=2  First failing condition: tasks
== 6d gates pass, verify MISMATCH   "firstIncompleteGate": null
                              eligible=false first=openspec-verification | next=escalate
[6d openspec archive … -y] exit=2  First failing condition: openspec-verification
[6d completion-gate --record && openspec archive] exit=2
    guard-delivery-loop exit=0
== 6e CONTROL: eligible       eligible=true first=null                   | next=archive
[6e openspec archive … -y] exit=0
    matcher=Write|Edit|MultiEdit -> guard-planning-handoff.sh, guard-context-preflight.sh, guard-story-done.sh, guard-delivery-loop.sh
    matcher=Bash -> guard-archive.sh
```

### E-7 — Supplementary: real-repository read-only probes and regression suite

```bash
shasum openspec/delivery/goal.md > <sandbox>/.real-goal.sha
scripts/delivery.sh resolve EPIC-12; scripts/delivery.sh next; scripts/delivery.sh next US-12.3
scripts/test-delivery.sh
shasum -c <sandbox>/.real-goal.sha; find openspec/changes -maxdepth 1 | sort | cmp - <before>
```

```text
   1  US-12.1  DONE                 us-12-1-resolve-delivery-target-report   …
   2  US-12.2  IN PROGRESS          us-12-2-run-delivery-goal-loop           …
   3  US-12.3  READY                us-12-3-document-delivery-orchestrator   …
Action:  test
Owner:   tester
Command: /test-feature us-12-2-run-delivery-goal-loop
Action:  escalate
Reason:  US-12.3 depends on unfinished US-12.2 (IN PROGRESS)
  passed: 165
  failed: 0
suite exit=0
openspec/delivery/goal.md: OK
real openspec/changes unchanged
```

The suite's final summary line (`RESULT: PASS — goal-driven delivery holds.`) is quoted
here inline, not in the output block, so the validator does not count it as a criterion.

## Limits of this evidence

I did not run the hooks inside a live Claude Code session, which the review's
observation O-4 also notes. Four things are therefore not observed:

- that Claude Code fires the `Stop` and `PreToolUse` hooks from `settings.json` and
  treats exit 2 as a block;
- that it feeds the stderr block message back to the model and displays `systemMessage`;
- that it applies its cap of 8 consecutive Stop blocks;
- that `agent_id` appears only in subagent payloads.

These are properties of the Claude Code platform, not of this change. The evidence above
shows what the wired commands do when given the documented payloads. For criterion 1, a
model delegating at run time was also not observed. That clause was judged on the
executable owner derivation plus inspection of the skill and agent contract, as stated in
its row.

## Result

All 6 criteria were exercised against Tester-built fixtures, using the hook commands
wired in `.claude/settings.json`. All 6 passed. Criteria 2–6 rest on executable checks.
Criterion 1 rests on executable checks, plus inspection for the delegation instruction.
No criterion was scored without observed evidence. The implementer's suite (165/0)
agrees with these results but is not the primary evidence for any row.

## Failures

None.

## Handoff

All criteria pass, and gate 6 (testing) should now pass. Next: the Product Manager
evaluates the completion gate and archival (`/opsx:archive`). The Tester modified no
product code, scripts, `.claude/**`, `SPECS.md`, `tasks.md`, `review.md`, or
`openspec/delivery/goal.md`.
