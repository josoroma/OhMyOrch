# README-EPIC-9 — Durable Workflow State

Implementation record for **EPIC-9** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-9 — Durable Workflow State |
| Stories | US-9.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-9-1-change-status/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| OpenSpec | 1.13.2 |
| Spec source | `SPECS.md` lines 1013–1058; `PRD.md` FR-011, NFR-003, BR-004 |

---

## 1. Objective

Let an interrupted iteration resume deterministically in a fresh Claude session,
using only repository artifacts.

## 2. The gap this epic closed: `status.md` was a name, not a mechanism

By the end of EPIC-8, `status.md` was referenced in five places — the Product
Manager agent, the `product-iteration` skill, `check-write-scope.sh`, the write-scope
matrix, and `.claude/rules/team-responsibilities.md` — and defined in none of them.

```bash
$ grep -rn 'status\.md' .claude/ scripts/ | wc -l
19
$ ls scripts/templates/
implementation-plan.md
$ ls scripts/ | grep -i status
workflow-status.sh
```

The consequences were concrete:

- **No format.** `workflow-status.sh` *reported* gate state but wrote nothing; the
  skill told the agent to `cat status.md` and interpret it however it liked.
- **No writer.** The skill instructed "read `status.md`", but nothing created one.
  An instruction to read a file that is never written is a dead branch.
- **No validator.** A malformed resume line would be read and believed, and a
  *stale* one would send a fresh session to the wrong gate with no warning.

That last point is the one US-9.1 is really about. `validate-product-artifacts.sh`
and its siblings validate artifacts *before* work happens; `status.md` is the only
artifact a session reads *to decide what to do next*. A wrong value there is not a
cosmetic defect — it causes work to be redone and correct work to be skipped.

## 3. The design problem: derived versus authored

`status.md` must hold two kinds of content that pull in opposite directions.

| Content | Wanted behavior | Why |
|---|---|---|
| Gates, `State`, owner, Resume line | **Always overwritten** on refresh | They restate what `workflow-status.sh` computes. A hand-editable copy is a second source of truth that can silently disagree with the reporter. |
| `## Blockers` | **Never overwritten** | It records a human decision — "waiting on the CI runner" — that no script can reconstruct. Losing it means losing the reason the work stopped. |

A single file satisfying both needs an explicit boundary, so the blockers live
between markers:

```markdown
<!-- BEGIN AUTHORED: blockers -->
## Blockers

- Waiting on the CI runner to be restored before review can be exercised.
<!-- END AUTHORED: blockers -->
```

Everything outside those markers is derived; everything inside is preserved verbatim.

### The verdict is delegated, never recomputed

`status.sh` does not compute gates. It reads `workflow-status.sh --json` and
reformats it. This is the same decision made for `guard-archive.sh` in EPIC-8, for
the same reason: a second implementation of the gate rules would eventually disagree
with the first, and there would be no way to tell which was right.

## 4. Scope

### In scope

- A `status.md` format, template, writer, and validator.
- Resume reporting that a fresh session can read in one command.
- Freshness detection: is the recorded state still true?
- Wiring the state lifecycle into the Product Manager agent and the iteration skill.

### Out of scope

- The completion gate consuming `archiveEligible` (EPIC-10). `workflow-status.sh`
  already exposes it and `guard-archive.sh` already enforces it.
- Server-side or cross-machine state. `status.md` is a repository artifact (BR-004).

## 5. Step-by-step execution

### 5.1 Recon

```bash
grep -rn 'status\.md' .claude/ scripts/
ls scripts/templates/
```

Confirmed `status.md` had five references and zero definitions, and that
`workflow-status.sh --json` already emitted everything a status file needs:

```json
{
  "change": "guard-arch",
  "tasks": { "total": 2, "complete": 2 },
  "firstIncompleteGate": "acceptance",
  "archiveEligible": false,
  "gates": [
    { "gate": "selection", "status": "pass", "detail": "change 'guard-arch' exists", "owner": "product-manager" },
    ...
  ]
}
```

### 5.2 Define the format

`scripts/templates/status.md` fixes the shape: an identity table, a seven-row gates
table, a Resume block, and the authored Blockers section. It follows the EPIC-4 plan
template convention — comments explain the rules, and sections are never deleted.

### 5.3 Build the writer

`scripts/status.sh` derives everything, preserves blockers, and filters the story id.

```bash
$ scripts/status.sh --change add-planner
Wrote openspec/changes/add-planner/status.md

  State:          IMPLEMENTING
  Current owner:  implementer
  Resume:         implementation

  Gates are derived from workflow-status.sh. Blockers are preserved.
```

### 5.4 Bug 1 — the gate table came back empty

The first `status.sh` run wrote a table of `fail | unknown` for all seven gates:

```text
| 1 | selection | fail | unknown | product-manager |
| 2 | planning  | fail | unknown | planner |
...
```

The parser split the JSON on commas before matching:

```bash
printf '%s' "$LIVE" | tr ',' '\n' | awk '/"gate":/ && /"status":/ { ... }'
```

`workflow-status.sh --json` emits **one gate object per line**, and each object
contains commas. Splitting on commas therefore put `"gate": "selection"` and
`"status": "pass"` on *different lines*, so no line ever matched both. Every lookup
returned empty, and the `:-fail` fallback disguised the failure as a gate that had
not passed. Fixed by matching within each line:

```bash
gate_field() { # gate_field <gate-name> <field>
  printf '%s' "$LIVE" | awk -v want="$1" -v fld="$2" '
    index($0, "\"gate\":") && index($0, "\"" fld "\":") && index($0, "{") {
      g=$0; sub(/.*"gate":[[:space:]]*"/, "", g); sub(/".*/, "", g)
      if (g != want) next
      v=$0; sub(".*\"" fld "\":[[:space:]]*\"", "", v); sub(/".*/, "", v)
      print v; exit
    }'
}
```

```text
| 1 | selection      | pass | change 'status-test' exists | product-manager |
| 4 | implementation | fail | 1/2 tasks complete | implementer |
| 7 | acceptance     | fail | SPECS.md fails the readiness/context contract | product-manager |
```

### 5.5 Bug 2 — BSD `sed` deleted the resume value

`validate-status.sh` reported that the Resume line it had just read could not be
parsed:

```text
  FAIL  Resume says '' but the first failing gate is 'implementation'
```

The cause was the second BSD-tool portability defect in this project:

```bash
RESUME_GATE=$(printf '%s' "$RESUME" | sed 's/[[:space:]]*(\{0,1\}.*$//' | tr -d '`')
```

Isolating it:

```bash
$ printf 'implementation\n' | sed 's/[[:space:]]*(\{0,1\}.*$//' | od -c
0000000   \n
```

BSD `sed` does not treat `\{0,1\}` as a portable interval here, and the pattern
consumed the entire value. Replaced with `awk`, matching the EPIC-6 precedent:

```bash
RESUME_GATE=$(printf '%s' "$RESUME" | awk '{
  v = $0
  sub(/[[:space:]]*\(.*$/, "", v)
  gsub(/`/, "", v)
  sub(/[[:space:]]+$/, "", v)
  print v
}')
```

### 5.6 Bug 3 — a multi-byte character class ate the story id

After fixing the resume matcher, the validator rejected its own output:

```text
  FAIL  Story 'US-<n>.<m>' is not a story identifier (expected US-<n>.<m>)
```

The story id was extracted with an `awk` character class meant to stop at a dash:

```bash
sub(/[[:space:]]*[—-].*$/, "", v)
```

Bisecting showed the substitution truncating `US-2.1` to `US`:

```bash
$ awk '... sub(/[[:space:]]*[—-].*$/, "", v); print "v2=[" v "]" }' plan.md | od -c
0000000    v   2   =   [   U   S   ]  \n
```

The cause is subtle and worth recording: **an em-dash is three bytes in UTF-8**
(`\xe2\x80\x94`), and BSD `awk` evaluates bracket expressions byte-by-byte. A class
like `[—-]` is therefore read as a byte *range* — from the first byte of `—` to the
first byte of `-` — which swallowed `2.1` along with it. The identifier is now
extracted directly, never with a multi-byte class:

```bash
grep -oE 'US-[0-9]+\.[0-9]+'
```

### 5.7 Bug 4 — resolved from derived state

With extraction fixed, the story came out as **`US-9.1`** — correct for *this
repository* and wrong for the change. `status.md`'s own header comment explains the
US-9.1 contract, so scanning the whole file found that mention instead of the
change's story.

Reading derived state back in as if it were authored is a self-reference: the file
records what the change is, so it must not also be the source of what the change is.
Fixed by requiring a **designating context** and ordering sources by authority:

```bash
story_designated() { # story_designated <file>
  [ -f "$1" ] || return 1
  { grep -oE '^[[:space:]]*Story:[[:space:]]*US-[0-9]+\.[0-9]+' "$1" 2>/dev/null \
      | grep -oE 'US-[0-9]+\.[0-9]+'
    grep -oE '^[[:space:]]*\|[[:space:]]*Story[[:space:]]*\|[[:space:]]*US-[0-9]+\.[0-9]+' "$1" 2>/dev/null \
      | grep -oE 'US-[0-9]+\.[0-9]+'
  } | head -1
}

# Authoritative order: the plan, then the proposal, then status.md's own table.
STORY=$(story_designated "$CDIR/implementation-plan.md")
[ -n "$STORY" ] || STORY=$(story_designated "$CDIR/proposal.md")
[ -n "$STORY" ] || STORY=$(story_designated "$STATUS")
```

```text
| Story | US-2.1 |
```

### 5.8 Build the validator

Six checks, each enforcing something the resume path depends on:

| Check | Enforces |
|---|---|
| Required sections | `## Gates`, `## Resume`, `## Blockers` |
| Identity and state | story id shape; `State` in the defined vocabulary; owner recorded |
| Gates | exactly seven rows, in fixed order, each `pass` or `fail` |
| Resume coherence | the Resume line agrees with the table |
| Blockers | AUTHORED markers present; section not empty prose |
| Freshness | with `--change`, recorded gates still match the live report |

A passing run:

```text
$ scripts/validate-status.sh --change status-test

Required sections
  PASS  ## Gates
  PASS  ## Resume
  PASS  ## Blockers

Identity and state
  PASS  Story: US-2.1
  PASS  Change: status-test
  PASS  State: IMPLEMENTING
  PASS  Current owner: implementer
  PASS  Updated: 2026-09-24

Gates
  PASS  seven gate rows present
  PASS  all gate statuses are pass or fail

Resume coherence
  PASS  Resume: implementation (matches first failing gate)

Blockers
  PASS  authored blocker section delimited
  PASS  Blockers: none recorded

Freshness
  PASS  recorded gate state matches the live report

  RESULT: PASS — status.md satisfies the US-9.1 contract.
exit=0
```

### 5.9 Prove the two checks that nothing else provides

**Resume coherence.** The `incoherent` fixture has a table showing gate 4 passing
and gate 5 failing, with a Resume line pointing back at gate 4. A resuming session
would redo finished work and skip the real blocker:

```text
$ scripts/validate-status.sh --status scripts/fixtures/status/incoherent/status.md --quiet
  FAIL  Resume says 'implementation' but the first failing gate is 'review'
  RESULT: FAIL — 1 failure(s), 1 warning(s).
```

**Freshness.** Completing the outstanding task makes the recorded state stale:

```text
$ printf -- '- [x] a\n- [x] b\n' > "$C/tasks.md"
$ scripts/validate-status.sh --change status-test
Freshness
  FAIL  gate 'implementation' recorded as 'fail' but is now 'pass'

  fix: this file is STALE, not malformed. Refresh it with:
    scripts/status.sh --change status-test
```

One refresh clears it, and the derived fields advance together:

```bash
$ scripts/status.sh --change status-test --quiet
$ scripts/validate-status.sh --change status-test --quiet
  RESULT: PASS — status.md satisfies the US-9.1 contract.

$ grep -E '^\| (State|Current owner) \|' openspec/changes/status-test/status.md
| State | REVIEWING |
| Current owner | reviewer |
```

### 5.10 Prove blockers survive

The authored section is the only content a refresh must not touch:

```text
=== add blocker ===
<!-- BEGIN AUTHORED: blockers -->
## Blockers

- waiting on CI runner
<!-- END AUTHORED: blockers -->

=== refresh ===
<!-- BEGIN AUTHORED: blockers -->
## Blockers

- waiting on CI runner
<!-- END AUTHORED: blockers -->
```

### 5.11 Prove the resume path end-to-end

Session 1 records state and ends. Session 2 has no chat history:

```bash
# session 1
$ scripts/status.sh --change us-9-1 --blocker "needs a human decision on naming"
  State:          IMPLEMENTING
  Current owner:  implementer
  Resume:         implementation

# session 2 — artifacts only, no transcript
$ scripts/validate-status.sh --change us-9-1
Freshness
  PASS  recorded gate state matches the live report
  RESULT: PASS — status.md satisfies the US-9.1 contract.

$ scripts/status.sh --resume --change us-9-1
  First incomplete gate: implementation
  Next owner:            implementer

  Recorded blocker(s):
    - needs a human decision on naming

  Read-only. status.md was not written.
```

The session recovers the gate, the owner, and the blocker from files alone.

### 5.12 Wire the lifecycle

`product-iteration` now records state at the `IN PROGRESS` transition, refreshes after
every gate, and reads `status.sh --resume` first on a resume:

```bash
scripts/status.sh --change <change-id>
scripts/validate-status.sh --change <change-id>
scripts/status.sh --change <change-id> --blocker "waiting on the CI runner"
scripts/status.sh --resume --change <change-id>
```

A new boundary was added to the skill, and the same rule to the Product Manager agent:

> Never hand-edit the gates table in `status.md`; refresh it with `scripts/status.sh`.

`.claude/rules/openspec.md` gained a "Durable state versus derived state" section, and
the three scripts were pre-approved in `.claude/settings.json` (47 allow rules).

### 5.13 Full regression

```text
=== test-write-scope.sh ===
  passed: 36
  failed: 0
  RESULT: PASS — separation of duties holds across all roles.

=== test-guards.sh ===
  passed: 31
  failed: 0
  RESULT: PASS — all guard behaviours hold.

=== test-status.sh ===
  passed: 42
  failed: 0
  RESULT: PASS — durable workflow state holds.

=== check-frontmatter.js ===
RESULT: PASS — all definitions valid.
```

Validators unchanged on both fixture sets:

```text
=== valid fixtures (expect 0) ===
product-artifacts  exit=0
implementation-plan exit=0
review              exit=0
test-report         exit=0

=== invalid fixtures (expect 1) ===
product-artifacts  exit=1
implementation-plan exit=1
review              exit=1
test-report         exit=1
```

---

## 6. Deliverables

### Created

| File | Purpose |
|---|---|
| `scripts/status.sh` | Write `status.md` (derived gates + preserved blockers) and report resume |
| `scripts/validate-status.sh` | Six-check US-9.1 contract, including coherence and freshness |
| `scripts/test-status.sh` | 42-case regression suite |
| `scripts/templates/status.md` | The `status.md` format |
| `scripts/fixtures/status/valid/status.md` | Coherent file with an authored blocker |
| `scripts/fixtures/status/incoherent/status.md` | Resume line contradicts the gates table |
| `scripts/fixtures/status/malformed/status.md` | Invented state, six rows, no markers, no Resume |

### Modified

| File | Change |
|---|---|
| `.claude/skills/product-iteration/SKILL.md` | Record state at Step 3, refresh after each gate, `--resume` at Step 5, new boundary |
| `.claude/agents/product-manager.md` | New "Recording state" section; resume reads `status.sh --resume` and validates freshness |
| `.claude/rules/openspec.md` | New "Durable state versus derived state" section |
| `.claude/settings.json` | +6 allow rules (47 total) |
| `scripts/README.md` | Index entries and a full US-9.1 section |

---

## 7. Acceptance verification

### US-9.1 — Persist Change Status

| Criterion | Evidence | Result |
|---|---|---|
| Active state recorded in `status.md` | `\| State \| IMPLEMENTING \|` written by `status.sh` | PASS |
| Current owner recorded | `\| Current owner \| implementer \|` | PASS |
| Unresolved blockers recorded | Authored section preserved across refreshes | PASS |
| Fresh session inspects artifacts | Session 2 read gate, owner, and blocker from files alone | PASS |
| First incomplete gate identified | `First incomplete gate: implementation` | PASS |
| Continues instead of restarting | Resume reports completed gates separately, and `test-status.sh` proves coherence is enforced | PASS |

```text
Scenario 1: state recorded
| State | IMPLEMENTING |
| Current owner | implementer |
- CI runner unavailable

Scenario 2: fresh session identifies the gate
record current: exit=0
  First incomplete gate: implementation
  Next owner:            implementer
```

The "continues instead of restarting" clause is not left to prompt compliance: the
`incoherent` fixture proves that a Resume line disagreeing with the gates table is
rejected with `exit 1`, so a session cannot be told to redo completed work without
the inconsistency surfacing.

Task checklist from `SPECS.md` — all three complete:

- [x] Define `status.md` format — `scripts/templates/status.md`
- [x] Add status updates to orchestration skill — `product-iteration` Steps 3, 4, 6
- [x] Add resume logic — `status.sh --resume`, Step 5, "Resuming an iteration"

---

## 8. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Gates derived, blockers authored, separated by markers | The two contents need opposite refresh behavior, and one file must hold both |
| 2 | Verdict delegated to `workflow-status.sh --json` | Same reasoning as `guard-archive.sh`: a second gate implementation would eventually disagree with the first |
| 3 | Freshness is a validator failure, not a warning | A stale status file is read *before* work is chosen; a warning there is easy to scroll past |
| 4 | The staleness message says "STALE, not malformed" | The two need different remedies, and calling a stale file malformed sends the reader looking for a syntax error |
| 5 | `status.md` is read last for the story id | It is generated *from* the plan, so reading it first is self-reference |
| 6 | Story id extracted with `grep -oE`, never a character class | A multi-byte `—` in an `awk` bracket expression becomes a byte range |
| 7 | `--resume` writes nothing | It is the read a resuming session performs first; a read that mutates state is a trap |
| 8 | An unmappable gate maps to `BLOCKED` | The rules say unclear state is never an invented intermediate value |
| 9 | Three fixtures, not one | Coherent, incoherent, and malformed are three distinct failure classes |
| 10 | Resume surfaces blockers | A blocker is often why a gate is stuck, so hiding it in the file wastes the session |

---

## 9. Notes for reuse

- **A read that precedes a decision must be validated hardest.** `status.md` is the
  only artifact a session consults *to choose what to do*; an error there causes real
  rework, and a stale file is worse than a missing one.
- **Separate derived from authored with explicit markers.** One file can hold both if
  the boundary is mechanical. Hand-editable derived content is a second source of
  truth.
- **Never put a multi-byte character in an `awk` or `sed` bracket expression.** BSD
  tools evaluate byte-by-byte, so `[—-]` becomes a byte range. This is the third
  BSD-tool portability defect found by running code rather than reading it.
- **A silent no-match must not read as a value.** The comma-splitting bug produced
  `fail | unknown` for every gate, and the `:-fail` default made it look like a gate
  that had failed rather than a parser that had not run.
- **Do not read generated state back as input.** `status.md` describing `US-9.1`
  nearly became the story of every change. Prefer the authoring artifact, and require
  a designating context rather than a bare mention.
- **The fastest resume is one command.** `status.sh --resume` prints the gate, the
  owner, and the blockers together, so a session does not assemble the picture from
  four files.
- **A blocked verdict is still a successful report.** `validate-status.sh` exiting `1`
  on a stale file is the check working, not the change failing.

---

## 10. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). It remains the
   only reason gate 7 fails on this repository, and it is now the only thing blocking
   a fully green gate chain in the harness's own repository.
2. **EPIC-10** implements the completion gate. `workflow-status.sh` exposes
   `archiveEligible`, and `guard-archive.sh` already enforces it — EPIC-10 should
   consume both rather than re-deriving either.
3. **`status.sh` could refresh on transition automatically.** Today the skill calls it
   after each gate. A `PostToolUse` hook on the reviewing agents' writes could make the
   refresh mechanical in the same way EPIC-8 made the gates mechanical.
4. **EPIC-11** updates `README.md`: it now needs to document seventeen scripts, and the
   US-11.1 scenarios must be given a `When` before that story can truthfully be called
   `READY`.
5. **Rotate the OpenRouter token** in commit `ea0d29b` (carried from EPIC-1). Still
   unpushed, no remote configured.
6. **Commit this work.** Suggested message:
   `feat(EPIC-9): durable workflow state with derived gates and authored blockers`.
