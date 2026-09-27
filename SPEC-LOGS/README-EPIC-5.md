# README-EPIC-5 — Implementation

Implementation record for **EPIC-5** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-5 — Implementation |
| Stories | US-5.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-5-1-implementer-agent/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| Spec source | `SPECS.md` lines 714–760; `PRD.md` BR-002, §5, §7 |

---

## 1. Objective

Constrain source-code changes to an Implementer working from approved specification
artifacts, and ensure the Implementer cannot approve its own work.

## 2. The problem this epic exists to solve

`BR-002` says:

> The agent that implements a change MUST NOT be the authority that approves its
> implementation or acceptance result.

Through EPIC-4, that rule was enforced purely by prompt text. Every agent had `Write`.
Nothing stopped an Implementer from creating `review.md` marked `Blocking: None` and
walking its own work through gates 5 and 6. The harness would then archive work
nobody had independently reviewed — the exact failure mode the whole project is built
to prevent.

EPIC-5's acceptance criterion is explicit that a real mechanism is wanted:

> Then the Implementer MUST hand control to the Reviewer
> And MUST NOT author the approval decision in review.md

So the separation of duties became **structural**, at two levels:

| Level | Mechanism | Effect |
|---|---|---|
| Tool allowlist | Role `tools` lists | Analyst/Specifier/Ingestor/Planner cannot write at all |
| Pre-write hook | `check-write-scope.sh` on the Implementer | Self-approval blocked *before* the write |

Prompt rules still exist, but they are now a second line rather than the only one.

## 3. Scope

### In scope

- **US-5.1** — `implementer` agent, the write-scope guard, the scope-expansion checker.

### Out of scope

- The Reviewer and Tester (EPIC-6, EPIC-7) author `review.md` and `test-report.md`.
  This epic only guarantees the Implementer cannot.
- Rules files and the remaining hook guards (EPIC-8). This epic ships one hook; US-8.2
  generalizes the guard set.
- `status.md` (EPIC-9).

## 4. Plan

```text
1. Recon: inspect the settings hook surface and the BR-002 exposure
2. Build + test the write-scope guard, all 5 roles     (the mechanism)
3. Build + test the scope-expansion checker
4. Author the implementer agent with a frontmatter PreToolUse hook
5. Register scripts; label gate 4's owner
6. Regression across the whole harness
7. Verify every acceptance criterion
8. Document the result in this file
```

## 5. Step-by-step execution

### 5.1 Recon — how much of BR-002 was actually enforced

```bash
node -e "const c=require('./.claude/settings.json');console.log('hooks:',JSON.stringify(c.hooks.PostToolUse[0].matcher));console.log('allow rules:',c.permissions.allow.length)"
```

```text
hooks: Write|Edit|MultiEdit
allow rules: 21
```

The only hook was EPIC-2's artifact validator. Nothing inspected *who* was writing.
Checking the agent definitions confirmed every role had `Write` in its tool list
where it needed it, and the implementer did not exist yet.

The exposure: with no Implementer defined, whoever played that role inherited the
default tool set — which includes `Write` with no role check at all.

### 5.2 Build the write-scope guard

Created `scripts/check-write-scope.sh`. It classifies the target path into an artifact
kind (or product code), then applies a per-role decision table.

```bash
chmod +x scripts/check-write-scope.sh
bash -n scripts/check-write-scope.sh
```

```text
syntax OK
```

**A note on the first test attempt.** I tried to drive the guard from a shell loop:

```bash
for c in "implementer openspec/changes/x/review.md"; do
  set -- $c; ./scripts/check-write-scope.sh --role "$1" --file "$2"
done
```

```text
error: unknown role 'implementer openspec/changes/x/review.md'
```

That is **zsh**, not the script: zsh does not word-split unquoted parameter
expansions, so `set -- $c` produced a single word. Rather than work around it, I
replaced the ad-hoc loop with a proper regression suite — more useful and repeatable.

### 5.3 Build the regression matrix

Created `scripts/test-write-scope.sh`: 36 cases covering every role's allow and block
paths, absolute-path normalisation, hook mode, and the fail-open path.

```bash
./scripts/test-write-scope.sh
```

```text
BR-002: an Implementer must not author its own approval
  ok    block   implementer     openspec/changes/some-change/review.md
  ok    block   implementer     openspec/changes/some-change/test-report.md

Implementer may write product code and tick tasks
  ok    allow   implementer     src/app.ts
  ok    allow   implementer     lib/util.py
  ok    allow   implementer     tests/app.test.ts
  ok    allow   implementer     openspec/changes/some-change/tasks.md

Implementer may not write other roles' artifacts
  ok    block   implementer     openspec/changes/some-change/implementation-plan.md
  ok    block   implementer     SPECS.md
  ok    block   implementer     openspec/changes/some-change/status.md
  ok    block   implementer     openspec/changes/some-change/proposal.md

US-6.1: a Reviewer must not repair the code it evaluates
  ok    block   reviewer        src/app.ts
  ok    block   reviewer        lib/util.py
  ok    allow   reviewer        openspec/changes/some-change/review.md
  ok    block   reviewer        openspec/changes/some-change/test-report.md
  ok    block   reviewer        openspec/changes/some-change/implementation-plan.md

US-7.1: a Tester must not repair failing behavior
  ok    block   tester          src/app.ts
  ok    allow   tester          openspec/changes/some-change/test-report.md
  ok    block   tester          openspec/changes/some-change/review.md
  ok    block   tester          openspec/changes/some-change/tasks.md

US-4.1: a Planner must not modify source code
  ok    block   planner         src/app.ts
  ok    allow   planner         openspec/changes/some-change/implementation-plan.md
  ok    block   planner         openspec/changes/some-change/review.md
  ok    block   planner         openspec/changes/some-change/tasks.md

US-3.1: a Product Manager orchestrates, and owns SPECS/status only
  ok    block   product-manager src/app.ts
  ok    allow   product-manager SPECS.md
  ok    allow   product-manager openspec/changes/some-change/status.md
  ok    block   product-manager openspec/changes/some-change/review.md
  ok    block   product-manager openspec/changes/some-change/test-report.md

Harness control surface is not product code
  ok    block   implementer     CLAUDE.md
  ok    block   implementer     .claude/settings.json
  ok    block   implementer     scripts/workflow-status.sh

Absolute paths under the project root normalise correctly
  ok    block   implementer     /Users/josoroma/projects/claude-dev/openspec/changes/some-change/review.md
  ok    allow   implementer     /Users/josoroma/projects/claude-dev/src/app.ts

Hook mode blocks on stdin and fails open on empty input
  ok    block   hook mode blocked review.md
  ok    allow   hook mode fails open on empty stdin
  ok    allow   hook mode allowed product code

=======================================================
  passed: 36
  failed: 0

  RESULT: PASS — separation of duties holds across all roles.
```

The suite deliberately covers the other roles too. EPIC-6 and EPIC-7 will need the
same protection — a Reviewer that repairs the code it reviews, or a Tester that fixes
failing behavior, are the same class of violation.

### 5.4 Build the scope-expansion checker

US-5.1's second scenario is about scope, not approval:

> Then the Implementer MUST NOT silently add it to the implementation
> And it MAY record it as follow-up work

Created `scripts/check-scope.sh`. It compares a diff against the paths the change's
plan predicted and reports the difference.

```bash
chmod +x scripts/check-scope.sh
bash -n scripts/check-scope.sh
```

```text
syntax OK
```

In-scope case:

```bash
printf '.claude/agents/codebase-analyst.md\n.claude/agents/README.md\n' > /tmp/in.txt
./scripts/check-scope.sh --plan scripts/fixtures/plans/valid/implementation-plan.md --diff /tmp/in.txt
```

```text
Plan:      scripts/fixtures/plans/valid/implementation-plan.md
Changed:   2 file(s)
Predicted: 5 path(s) named in the plan

  Every changed file was predicted by the plan.

  RESULT: IN SCOPE
```

Exit `0`.

Out-of-scope case:

```bash
printf '.claude/agents/codebase-analyst.md\nsrc/unrelated-refactor.ts\ndocs/typo-fix.md\n' > /tmp/out.txt
./scripts/check-scope.sh --plan scripts/fixtures/plans/valid/implementation-plan.md --diff /tmp/out.txt
```

```text
  Unpredicted change(s) — not necessarily wrong, but must be accounted for:

    docs/typo-fix.md
    src/unrelated-refactor.ts

  For each, either:
    - it is required by the change, and the plan should have named it; or
    - it is unrelated, and belongs in follow-up work, not this change (US-5.1).

  RESULT: OUT OF PLAN SCOPE — 2 file(s) unaccounted for.
```

Exit `1`. Note the reporting language: unpredicted is *not* the same as wrong. The
Implementer may have discovered a file the Planner could not have known about. The
point is that it must be visible and decided, not silent.

Edge cases verified:

```bash
./scripts/check-scope.sh --plan <plan> --diff /tmp/all.txt   # all unpredicted
./scripts/check-scope.sh --plan <plan> --diff /tmp/none.txt  # no changes
./scripts/check-scope.sh --plan /nope.md --diff /tmp/in.txt  # missing plan
```

```text
all-unpredicted:  exit=1  (reports 1 file, lists the two options)
no changes:       exit=0
missing plan:     exit=2
```

### 5.5 Author the Implementer agent

Created `.claude/agents/implementer.md` with `tools: Read, Grep, Glob, Bash, Write,
Edit` — deliberately **including** `Write`/`Edit`, because this is the one role whose
job is to change product code. The restriction is not the absence of the tool; it is a
hook that checks *what* is being written.

The definition carries a `PreToolUse` hook:

```yaml
hooks:
  PreToolUse:
    - matcher: "Write|Edit|MultiEdit"
      hooks:
        - type: command
          command: "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/check-write-scope.sh\" && exec \"$d/scripts/check-write-scope.sh\" --role implementer --hook --quiet; exit 0'"
          statusMessage: "Checking Implementer write scope"
```

The agent's prompt states the two directions of the boundary (no self-approval, no
scope expansion), a required precondition on gate 3, a specification-conflict
escalation format, and an `IMPLEMENTATION RESULT` report block.

### 5.6 Verify the hook works, verbatim

The command string was extracted from the file's own frontmatter and executed as
Claude Code would run it — including with `CLAUDE_PROJECT_DIR` unset, which is the
case that broke a naive implementation in EPIC-2.

```bash
CMD=$(node -e "…parse frontmatter, print d.hooks.PreToolUse[0].hooks[0].command…")
printf '%s' '{"tool_input":{"file_path":"openspec/changes/x/review.md"}}' | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
printf '%s' '{"tool_input":{"file_path":"src/app.ts"}}'                  | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
```

```text
--- self-approval: review.md (expect exit 2 = BLOCK) ---
BLOCKED  [implementer] openspec/changes/x/review.md
  an Implementer must not author review.md — that is self-approval (BR-002, US-5.1)
  Hand the artifact to the role that owns it; do not write it yourself.
exit=2

--- product code (expect exit 0 = ALLOW) ---
exit=0
```

Frontmatter was also parsed as YAML to confirm the hook block loads:

```text
name:        implementer
tools:       Read, Grep, Glob, Bash, Write, Edit
has hooks:   yes
matcher:     Write|Edit|MultiEdit
has Agent in tools:      no (Implementer delegates directly)
```

`Agent` is absent deliberately: the Implementer executes the plan rather than
delegating it. If it delegated, it could route around its own write-scope hook.

### 5.7 Integration test through the gates

A change was staged to confirm the EPIC-5 stages compose with the earlier gates.

```bash
D=openspec/changes/epic5-demo
mkdir -p "$D/specs"
printf 'schema: spec-driven\n' > "$D/.openspec.yaml"
printf '# Proposal\n\nStory: US-5.1\n' > "$D/proposal.md"
printf '# Spec\n' > "$D/specs/x.md"
printf '# Tasks\n- [ ] write the parser\n- [ ] add tests\n' > "$D/tasks.md"
cp scripts/fixtures/plans/valid/implementation-plan.md "$D/implementation-plan.md"
./scripts/workflow-status.sh --quiet
```

```text
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
```

After the Implementer completes one task:

```bash
printf '# Tasks\n- [x] write the parser\n- [ ] add tests\n' > "$D/tasks.md"
./scripts/workflow-status.sh --quiet
```

```text
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  ----  implementation   1/2 tasks complete
  First incomplete gate: implementation
```

Gate 4 tracks real task state and correctly becomes the resume point. The demo change
was removed afterward.

### 5.8 Register scripts and label the owner

Added to `permissions.allow` — all read-only or reporting, so pre-approval is safe:

```json
"Bash(bash scripts/check-write-scope.sh:*)",
"Bash(scripts/check-write-scope.sh:*)",
"Bash(bash scripts/check-scope.sh:*)",
"Bash(scripts/check-scope.sh:*)",
"Bash(bash scripts/test-write-scope.sh:*)",
"Bash(scripts/test-write-scope.sh:*)"
```

Gate 4's owner label became `implementer (/opsx:apply)` so the report names the
command as well as the role — consistent with gate 3's `planner (/plan-feature)`.

### 5.9 Full regression

```bash
for s in scripts/*.sh; do bash -n "$s" || echo "SYNTAX FAIL $s"; done
./scripts/test-write-scope.sh
./scripts/validate-implementation-plan.sh --plan <valid>   --quiet
./scripts/validate-implementation-plan.sh --plan <invalid> --quiet
./scripts/validate-product-artifacts.sh --specs <valid…>   --quiet
./scripts/validate-product-artifacts.sh --specs <invalid…> --quiet
./scripts/check-scope.sh --plan <plan> --diff <in-scope>
./scripts/check-scope.sh --plan <plan> --diff <out-of-scope>
./scripts/workflow-status.sh
```

```text
-- script syntax --      all OK
-- write-scope matrix -- passed: 36  failed: 0
-- plan validator --     valid plan exit=0 (0)
                         invalid plan exit=1 (1)
-- artifact validator -- valid artifacts exit=0 (0)
                         invalid artifacts exit=1 (1)
-- scope checker --      in scope exit=0 (0)
                         out of scope exit=1 (1)
-- gate reporter --      no active change exit=1 (1)
```

Every script's pass path, fail path, and error path behaves as documented.

---

## 6. The two write-scope questions

These are easy to confuse, and the harness keeps them deliberately separate:

| Question | Script | Answers |
|---|---|---|
| **Is this role allowed to write this file at all?** | `check-write-scope.sh` | role boundaries, `BR-002` |
| **Is this file part of *this* change?** | `check-scope.sh` | change scope, `US-5.1` |

An Implementer editing `src/app.ts` passes the first (product code is its job) and can
still fail the second (the plan never mentioned it). Both checks are needed; neither
substitutes for the other.

## 7. Deliverables

### Created

| Path | Implements | Purpose |
|---|---|---|
| `.claude/agents/implementer.md` | US-5.1 | Implementer, with `PreToolUse` write-scope hook |
| `scripts/check-write-scope.sh` | US-5.1, BR-002 | Role write-scope guard |
| `scripts/check-scope.sh` | US-5.1 | Scope-expansion reporter |
| `scripts/test-write-scope.sh` | US-5.1 | 36-case regression matrix |
| `README-EPIC-5.md` | — | This document |

No new skill: US-5.1 specifies an agent only. Implementation is driven by
`/opsx:apply` plus the agent, so inventing a skill would have added a wrapper with no
distinct behaviour.

### Modified

| Path | Change |
|---|---|
| `.claude/settings.json` | Pre-approved the three new read-only scripts |
| `scripts/workflow-status.sh` | Gate 4 owner label → `implementer (/opsx:apply)` |
| `scripts/README.md` | Documented both new scripts, the write-scope matrix, and the distinction between them |
| `.claude/agents/README.md` | Recorded `implementer` as delivered; added the hook-enforcement section |

---

## 8. Acceptance verification

### US-5.1 — Create Implementer Agent

> **Scenario: Implement from OpenSpec tasks**
> Given proposal, specs, tasks, and implementation-plan artifacts exist
> When the Implementer applies the change
> Then it MUST implement work required by the active specification
> And it MUST update task completion only for completed work
> And it MUST run relevant project validation before declaring implementation complete

| Criterion | Evidence | Result |
|---|---|---|
| Implements from the active spec | Agent reads `implementation-plan.md`, `tasks.md`, specs, and acceptance criteria in order | PASS |
| Updates task completion only for completed work | Rule 2: "Tick a task only when it is actually complete"; gate 4 counts real checkboxes | PASS |
| Runs relevant project validation | Rule 3; report field `validation run: <command, and its outcome; or "none defined in this project">` | PASS |

> **Scenario: Scope expansion is prohibited**
> Then the Implementer MUST NOT silently add it to the implementation
> And it MAY record it as follow-up work

| Criterion | Evidence | Result |
|---|---|---|
| No silent scope addition | Rule 1 + Step 4 ("Do not fix it"); `check-scope.sh` reports unpredicted files; verified exit 1 on the out-of-scope fixture | PASS |
| May record as follow-up | Report field `follow-up discovered:` | PASS |

> **Scenario: Implementer cannot approve itself**
> Then the Implementer MUST hand control to the Reviewer
> And MUST NOT author the approval decision in review.md

| Criterion | Evidence | Result |
|---|---|---|
| Hands control to the Reviewer | Rule 5 and Step 8: "Stop. Do not review your own work." | PASS |
| Must not author review.md | **Mechanically blocked**: `review.md` → `BLOCKED`, exit 2, verified verbatim through the frontmatter hook | PASS |

Also enforced, beyond the letter of the scenario:

| Rule | Mechanism | Verified |
|---|---|---|
| Must not author `test-report.md` | Blocked, exit 2 | PASS |
| Must not write `SPECS.md`, `status.md`, plan, specs | Blocked, exit 2 | PASS |
| Must not write harness control surface | Blocked, exit 2 | PASS |
| Other roles' prohibitions hold | 36/36 matrix cases | PASS |

### Scripted check

```text
PASS  agent defined
PASS  may write product code
PASS  sole-writer role stated
PASS  no-self-approval rule
PASS  blocked artifacts named
PASS  honest task rule
PASS  validation required
PASS  scope-expansion rule
PASS  frontmatter hook present
PASS  hook wired to guard
PASS  scope checker referenced
PASS  gate-3 precondition

--- scripts ---
PASS  scripts/check-write-scope.sh
PASS  scripts/check-scope.sh
PASS  scripts/test-write-scope.sh

--- separation-of-duties matrix ---
  passed: 36   failed: 0

--- settings ---
PASS  check-write-scope pre-approved
PASS  check-scope pre-approved
```

---

## 9. Task checklist

### US-5.1 — Create Implementer Agent
- [x] Create `.claude/agents/implementer.md`.
- [x] Define allowed write scope.
- [x] Define required handoff to Reviewer.

---

## 10. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Enforced BR-002 with a `PreToolUse` hook, not only prompt text | Prompt text cannot stop an agent that decides to write `review.md`; the hook runs before the write |
| 2 | Implementer keeps `Write`/`Edit` | It is the one role that must change product code. Restricting the tool would make it useless; restricting the *target* is the correct control |
| 3 | Hook fails open when the script is missing | A copied agent file without `scripts/` must not block all implementation |
| 4 | Guard covers all five roles, not just the Implementer | EPIC-6 and EPIC-7 need the same protection against reviewer-repairs and tester-repairs |
| 5 | `check-scope.sh` reports rather than blocks | An unpredicted file may be legitimate new information; the requirement is visibility, not prohibition |
| 6 | No skill created for US-5.1 | The spec asks for an agent; `/opsx:apply` is the driver. A skill would add a wrapper with no distinct behaviour |
| 7 | Replaced the ad-hoc zsh test loop with a regression suite | The loop mis-parsed under zsh; a real suite is repeatable and covers 36 cases |
| 8 | `Agent` omitted from Implementer tools | Prevents delegating around its own write-scope hook |

---

## 11. Notes for reuse

- **Two different questions.** `check-write-scope.sh` = "may this role write this?".
  `check-scope.sh` = "is this file part of this change?". A change can pass either and
  fail the other.
- **Hook mode fails open on empty input.** A malformed hook payload never blocks work;
  the guard reports nothing rather than silently failing closed.
- **zsh does not word-split.** `set -- $var` yields one word. Use an array or a
  dedicated test script — this bit the first test attempt.
- **Run the matrix after any matrix change.** `scripts/test-write-scope.sh` is the
  contract; if a case fails, the guard or its documentation is wrong.
- **`--quiet` never hides a block.** Consistent with the other scripts: passing output
  is suppressed, blocked/failed output always prints.
- **Frontmatter hooks need a trusted folder.** Claude Code runs project-level subagent
  frontmatter hooks only after the workspace trust dialog is accepted.

---

## 12. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). Still the sole
   reason gate 7 fails on this repository.
2. **EPIC-6 (Reviewer)** should carry the mirror hook with `--role reviewer`, so
   "the Reviewer must not repair reviewed code" becomes structural too.
3. **EPIC-7 (Tester)** likewise with `--role tester`.
4. **EPIC-8** generalizes these into the documented hook configuration and adds the
   archive gate. `workflow-status.sh --json` is the natural archive-gate input.
5. **EPIC-9** adds `status.md`; the guard already reserves it for the Product Manager.
6. **Commit this work.** Suggested message:
   `feat(EPIC-5): implementer agent with hook-enforced separation of duties`.
