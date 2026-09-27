# Review — us-13-2-document-orchestrator-loop

Change: us-13-2-document-orchestrator-loop
Story: US-13.2
Verdict: pass
Blocking: None
Coverage: 3/3 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-13-2-document-orchestrator-loop --strict` reports "Change 'us-13-2-document-orchestrator-loop' is valid"; no spec/task/design mismatch found.

## Summary

The implementation satisfies the delta spec. `README.md` opens with a table of
contents that lists all 27 numbered sections with anchors that resolve to their
headings; §19 names the agent and skill at each loop step and shows the loop as a
Mermaid diagram; and the handoff subsection explains the file handoff and the
mechanical gate with a second diagram. Every factual claim I checked against the
implementation holds. No blocking findings; one non-blocking observation on an
over-broad rationale clause.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| README opens with a table of contents | PASS | `README.md:7` `## Table of Contents`; 27 numbered headings (`grep -cE '^## [0-9]+\. ' README.md` = 27) and 27 numbered TOC entries; all 31 TOC anchors resolve to a heading (derived anchors, 0 mismatches); no stale `§N` reference remains (`grep -n '§[0-9]' README.md` → §18, §26, §18, §18, §18, all valid) |
| README explains the orchestrator loop | PASS | `README.md:896` §19; loop table (`README.md:929`–`941`) maps every action→owner→skill; `flowchart TD` block at `README.md:906`; owners match `derive_next` in `scripts/delivery.sh:296`–`425` and the delegation table in `.claude/skills/deliver/SKILL.md` Step 2 |
| README explains the plan-to-implement handoff | PASS | `README.md:958`–`1007`; `flowchart LR` block at `README.md:966`; names `implementation-plan.md`, the Planner write, the Implementer read, `guard-planning-handoff.sh`, gate 3 `plan-handoff`, and `check-scope.sh --plan` |

## Blocking Issues

None.

## Observations

- **O-1 (non-blocking): the guard allow-list rationale overstates one case.**
  `README.md:1000`–`1002` reads: "The guard allows harness control surfaces
  (`.claude/`, `scripts/`), change artifacts (`openspec/`), and `CLAUDE.md`, so the
  Planner can still write the plan and the Product Manager can still update
  `SPECS.md`." The enumerated allow-list is accurate (`scripts/guard-planning-handoff.sh:95`–`99`),
  but `SPECS.md` is **not** on it: with the plan missing, `guard-planning-handoff.sh --file SPECS.md`
  exits `2` (verified in a copy with `implementation-plan.md` removed). The clause is
  true only once the plan exists, which is the normal case, so the gate's core
  behaviour — "blocks implementation until the plan exists" — is documented correctly
  and the scenario is met. Suggested (optional) tightening: drop the `SPECS.md` clause
  or qualify it with "once the plan exists". Not required by the scenario.

## Notes on verification performed

- **Loop table accuracy.** Every action in the README table (`select`, `propose`,
  `plan`, `implement`, `review`, `test`, `reopen`, `archive`, `mark-done`, `escalate`,
  `complete`) matches a `set_action` call in `derive_next` (`scripts/delivery.sh:296`–`425`),
  and every owner matches the delegation table in `.claude/skills/deliver/SKILL.md`
  Step 2. The `reopen` row ("failing verdict moved to `history/`, remediation tasks
  appended") matches `do_reopen` (`scripts/delivery.sh:578`–`618`).
- **Handoff claims.** Planner writes the file (`.claude/skills/plan-feature/SKILL.md:92`,
  `.claude/agents/planner.md:17`); Implementer reads it (`.claude/agents/implementer.md:63`)
  and confirms gate 3 first (`:51`); `guard-planning-handoff.sh` is a `PreToolUse` hook
  on `Write|Edit|MultiEdit` (`.claude/settings.json:97`–`103`) that blocks product-code
  writes with exit `2` while the plan is missing (`scripts/guard-planning-handoff.sh:150`–`165`),
  allows `.claude/`, `scripts/`, `openspec/`, and `CLAUDE.md` (`:95`–`99`), and fails
  open (`:104`–`120`). Gate 3 is `plan-handoff` (`scripts/workflow-status.sh:17`, `:265`),
  owner `planner (/plan-feature)` (`:297`). `check-scope.sh --plan` compares changed
  files against the plan's predicted files and exits `1` on an unpredicted file
  (`scripts/check-scope.sh:1`–`20`).
- **Mermaid syntax.** Both blocks are balanced (`subgraph`/`end` paired in the LR
  diagram), node ids contain no dots, and labels are quoted. The loop diagram's
  back-edges (`pm/pl/pl2/im/rv/ts/pm2/pm3/pm4 --> next`) and the Stop-hook edge
  (`stop -.->|"blocks the stop"| next`) are consistent with `guard-delivery-loop.sh`
  as a `Stop` hook.
- **Mutation check.** In a `mktemp -d` copy, removing the §19 TOC entry made
  `scripts/test-guards.sh` fail with 3 failures (`the TOC lists every numbered section`,
  `the TOC links a numbered section`, `every numbered section is in the TOC`); the
  unmodified suite passes 85/85. The regression cases have teeth.
- **Scope.** `scripts/check-scope.sh --plan` reports 314 unaccounted files, but this is
  an artifact of the repository's untracked working tree (`git ls-files --others`
  lists the whole harness, which is not yet committed), not of this change. The change
  itself touched only the two files the plan predicted: `README.md` and
  `scripts/test-guards.sh`.

## Handoff

No remediation requested. Control proceeds to acceptance testing.
