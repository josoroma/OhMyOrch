# Design — us-12-2-run-delivery-goal-loop

Story: US-12.2

This change adds new hook wiring to `.claude/settings.json`: a `Stop` event, plus a
`PreToolUse` entry. It also adds a goal-status transition (`BLOCKED`) that other
sessions will read. Both are external contracts, so `openspec/config.yaml` requires a
design artifact.

## Decisions

### 1. The loop is enforced by a `Stop` hook, not by the prompt

A skill can *ask* the model to keep going, but the model may still end its turn early.
Claude Code runs `Stop` hooks when the main agent finishes a response. Exit code 2
prevents the stop and feeds stderr back to Claude as the reason to continue. The loop
is therefore:

```text
/deliver <target>
  -> scripts/delivery.sh start <target>        (goal.md, Status ACTIVE)
  -> repeat:
       scripts/delivery.sh next                (derived action + owner)
       delegate the action to its owner
       scripts/delivery.sh refresh
  -> session tries to stop
       guard-delivery-loop.sh (Stop):
         complete           -> record COMPLETE, allow
         escalate           -> record BLOCKED (reason), allow
         no progress x N    -> record BLOCKED (no progress), allow
         anything else      -> exit 2: "next action X, owner Y, command Z"
```

Rejected: a prompt-only loop ("keep going until done"). It cannot satisfy
"a Stop hook MUST block the stop", and it fails silently when the model decides it is
finished.

Rejected: a `type: "prompt"` or `type: "agent"` Stop hook. That would put an LLM
judgement where a deterministic derivation already exists (`delivery.sh next`), and
agent hooks are marked experimental. The harness convention is portable bash (NFR-001).

### 2. Progress is the derived state, fingerprinted per target

The Stop hook stores `target`, `fingerprint`, and `count` in
`openspec/delivery/loop.state`, which is per-machine and git-ignored. The fingerprint
is the full `delivery.sh next --json` output: action, story, change, owner, command,
and reason. The reason carries gate detail such as `3/10 tasks complete`, so ticking a
task, writing a review, or archiving a change all change it.

| Stop attempt | Fingerprint vs stored | Result |
|---|---|---|
| first for this target | — | count = 1, block |
| changed | differs | count = 1, block |
| unchanged | same | count + 1; block while count ≤ max, else BLOCKED + allow |

`max` defaults to 3 and can be set with `DELIVERY_MAX_STALLS` or `--max-stalls`. The
default sits below Claude Code's own cap of 8 consecutive Stop blocks, so the harness
records *why* it stopped before Claude Code overrides the hook. `loop.state` is removed
whenever the goal leaves `ACTIVE`, so a resumed goal starts counting fresh.

Rejected: counting on `stop_hook_active`. That flag says whether this turn continues a
Stop-hook block. It does not say whether the repository moved, which is what "progress"
means.

### 3. The orchestrator cannot author verdicts

While a goal is ACTIVE, the same script runs as a `PreToolUse` hook on
`Write|Edit|MultiEdit` and blocks a **main-session** write whose target is `review.md`
or `test-report.md` (exit 2). Writes made inside a subagent carry `agent_id` in the
hook payload and are left to that subagent's own write-scope hook
(`check-write-scope.sh --role reviewer|tester`). The Reviewer and the Tester therefore
remain the only authors of their artifacts.

The check matches `"agent_id":` only where it is not preceded by a backslash. File
content inside the payload is JSON-escaped, so a written document that *mentions*
`"agent_id"` is not mistaken for a subagent marker.

Rejected: a `PreToolUse` hook in the `deliver` skill's frontmatter. Skill hooks persist
for the rest of the session, including in subagents, and would block the Implementer.

### 4. Escalation and COMPLETE are recorded by the hook, not the model

The Stop hook writes goal state through `delivery.sh` so that `goal.md` has a single
writer:

| Outcome | Command |
|---|---|
| escalate | `delivery.sh block --reason "<escalation reason>"` |
| no progress | `delivery.sh block --reason "no progress: <action> unchanged across <n> stop attempts"` |
| complete | `delivery.sh refresh` (already records `COMPLETE`) |
| continue | `delivery.sh refresh` (keeps `## Next Action` current) |

`block` preserves Target, Started, and Notes. A later `delivery.sh start <same target>`
resumes the goal as `ACTIVE`.

### 5. Fail open when the harness is absent

The Stop hook allows the stop (exit 0) in each of these cases:

- `delivery.sh` is missing;
- no `goal.md` exists;
- the goal is not `ACTIVE`;
- the payload says the hook is running inside a subagent;
- `next` cannot resolve the goal. In this case it records `BLOCKED` with the resolver's
  error first.

This keeps to the harness hook convention: a copied `settings.json` never traps an
unrelated session.

## Goal status transitions

```text
ACTIVE --(Stop: complete)--> COMPLETE
ACTIVE --(Stop: escalate | no progress)--> BLOCKED
ACTIVE --(delivery.sh stop)--> STOPPED
BLOCKED | STOPPED --(delivery.sh start <same target>)--> ACTIVE
```
