# README-EPIC-10 — Completion and Archival

Implementation record for **EPIC-10** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-10 — Completion and Archival |
| Stories | US-10.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-10-1-definition-of-done/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| OpenSpec | 1.13.2 |
| Spec source | `SPECS.md` lines 1060–1105; `PRD.md` section 14, FR-010 |

---

## 1. Objective

Prevent incomplete work from being treated as shipped, and close the lifecycle cleanly.

## 2. The defect this epic closed: the gate chain is not the definition of done

By EPIC-9 the harness had two overlapping-but-different notions of "done", and only one
of them was implemented.

| | Workflow gates | US-10.1 conditions |
|---|---|---|
| Count | 7 | 4 |
| Question | *where is this change?* | *may it be shipped?* |
| Script | `workflow-status.sh` | — |
| Edge | resumes a session | authorises archival |

The second list existed only in prose. `SPECS.md` US-10.1 names four conditions, and
`guard-archive.sh` (EPIC-8) delegated to the **seven gates** — which are not those four
conditions, and are not a superset of them.

Two consequences were real defects, not theoretical ones.

**Defect 1 — condition 4 was nowhere.** "OpenSpec verification has no blocking
mismatch" has no gate. Gate 7 is an *artifact-contract* gate (SPECS readiness +
CODEBASE context), which answers a different question entirely. So the harness could
report every gate green while OpenSpec validation was failing.

**Defect 2 — the `OpenSpec verify:` line was recorded, never evaluated.** Probed
directly with a review whose only change was that line:

```bash
$ sed 's/^OpenSpec verify: .*/OpenSpec verify: MISMATCH — 4 blocking mismatches found/' \
    scripts/fixtures/reviews/valid/review.md > bad-verify.md
$ scripts/validate-review.sh --review bad-verify.md
  PASS  records the /opsx:verify outcome
  RESULT: PASS — all required checks passed, 0 warning(s).
```

A review declaring **four blocking mismatches** passed its contract. The field was
checked for *presence*, never for *meaning*. And because gate 5 only asks "does
review.md pass its contract", that declaration also passed the gate chain.

Together these meant the harness would have archived a change with failing OpenSpec
verification. That is precisely the failure US-10.1 exists to prevent.

## 3. Why a new script rather than a new gate

Adding an eighth gate would have been the wrong fix.

A gate is a *position* in a sequence: "you are here, the next owner is X". The
completion conditions are not positions — they can fail in any combination, and a
change can be at the *acceptance* gate with three of the four already satisfied. More
importantly, the two lists genuinely overlap without either containing the other:

```text
workflow gates                US-10.1 conditions
  1 selection                  1 all tasks complete        ~ gate 4
  2 planning                   2 review not blocking       ~ gate 5
  3 plan-handoff               3 acceptance criteria pass  ~ gate 6
  4 implementation             4 OpenSpec verification     <- no gate
  5 review
  6 testing
  7 acceptance  <- not a completion condition
```

Gate 7 has no completion counterpart, and condition 4 has no gate. Collapsing them
would lose a signal either way. So the harness now has `completion-gate.sh` for the
conditions and `workflow-status.sh` for the progression, and `guard-archive.sh`
consults the former while reporting the latter.

## 4. Scope

### In scope

- `completion-gate.sh` — the four conditions, with recorded evidence.
- Condition 4 with teeth: the machine check *and* the recorded outcome.
- `validate-verification.sh` — a completion record contract.
- Making the `DONE` transition mechanical (US-10.1 task 3).
- Delegating `guard-archive.sh` to the completion gate.

### Out of scope

- Changing the seven-gate model. EPIC-9 owns it and `status.md` is derived from it.
- `/opsx:archive` itself, which is OpenSpec's operation; this epic documents it and
  guards the invocation.

## 5. Step-by-step execution

### 5.1 Recon

```bash
openspec validate --help
openspec archive --help
grep -rn 'OpenSpec verify' scripts/
```

Confirmed `openspec validate` supports `--json`, and found the verify-line contract:

```text
scripts/validate-review.sh:14:#   OpenSpec verify: the recorded /opsx:verify outcome
scripts/validate-review.sh:328:if grep -qiE '^[[:space:]]*([-*][[:space:]]*)?OpenSpec verify[[:space:]]*:' ...
```

The check is a presence test. Then the probe in §2 confirmed it has no teeth.

### 5.2 Build the evaluator

`scripts/completion-gate.sh` evaluates four conditions and names the first that fails.

```text
$ scripts/completion-gate.sh --change completion-test

  FAIL  tasks                    1/2 tasks complete
  FAIL  review                   review.md missing
  FAIL  acceptance               test-report.md missing
  FAIL  openspec-verification    no verification evidence (openspec CLI unavailable, nothing recorded)

  NOT ELIGIBLE FOR ARCHIVE
  First failing condition: tasks
  US-10.1: only a change that satisfies every condition may be archived.
exit=1
```

### 5.3 Bug 1 — the OpenSpec JSON was parsed with the wrong key

The first implementation counted errors with:

```bash
OPENSPEC_ERRORS=$(printf '%s' "$VALIDATE_JSON" | grep -c '"severity": *"error"')
```

It always returned `0`. Probing the two failure shapes showed why:

```bash
$ openspec validate nope-not-real --json          # unknown item
{ "status": [ { "severity": "error", "code": "unknown_item", ... } ] }

$ openspec validate completion-test --json        # invalid change
{ "items": [ { "id": "completion-test", "valid": false,
               "issues": [ { "level": "ERROR", ... } ] } ] }
```

The two share **no key names**. `"severity"` appears only for an unknown item, so for a
real change the pattern matched nothing and the count was `0` — condition 4 would have
passed with blocking mismatches present. This is the same class of defect as EPIC-9's
comma-split bug: a silent non-match reading as success. Now both shapes are checked, and
`"valid": false` is the primary signal.

### 5.4 Bug 2 — `|| VAR=""` discarded the output it was checking

After fixing the keys, condition 4 *still* reported the CLI unavailable:

```text
  FAIL  openspec-verification    no verification evidence (openspec CLI unavailable, nothing recorded)
```

The CLI was present and returned 776 bytes. The defect was the assignment idiom:

```bash
VALIDATE_JSON=$(openspec validate "$CHANGE" --json 2>/dev/null) || VALIDATE_JSON=""
```

`openspec validate` exits **non-zero when the change is invalid** — which is exactly
the case being tested. So the `||` fired and wiped the JSON, converting every invalid
change into "cannot tell". A guarded assignment must never discard the failure case's
output; it is the only case that matters here.

```bash
VALIDATE_JSON=$(openspec validate "$CHANGE" --json 2>/dev/null)
VALIDATE_RC=$?
```

### 5.5 Condition 4 with both signals

The recorded outcome and the machine check now combine, because either alone is
insufficient: the recorded line carries the Reviewer's judgement, and `openspec
validate` carries the machine's. A declared mismatch is blocking regardless of what the
CLI says:

```text
$ sed 's/^OpenSpec verify: .*/OpenSpec verify: MISMATCH — 4 blocking mismatches found/' \
    scripts/fixtures/reviews/valid/review.md > "$C/review.md"
$ scripts/completion-gate.sh --change completion-test --quiet
  PASS  tasks                    2/2 tasks complete
  PASS  review                   verdict 'pass', blocking: none
  PASS  acceptance               3 acceptance criterion/criteria PASS
  FAIL  openspec-verification    recorded /opsx:verify outcome reports a blocking mismatch

  NOT ELIGIBLE FOR ARCHIVE
exit=1
```

### 5.6 Fail-open probes

The two conditions that could pass by absence were probed deliberately, since that is
the EPIC-7 gate-6 defect:

```text
=== D. empty tasks.md (fail-open probe) ===
  FAIL  tasks                    tasks.md has no task checkboxes
  First failing condition: tasks
```

An empty checklist is not completion, and a criterion scored `UNVERIFIED` does not
block but is reported in the evidence line rather than silently counted as a pass.

### 5.7 The decisive test

Staged a scratch harness where **all seven gates genuinely pass**, then changed one
line in `review.md`:

```bash
$ sed -i '' 's/^OpenSpec verify: .*/OpenSpec verify: MISMATCH — 4 blocking mismatches found/' \
    openspec/changes/ok/review.md
```

```text
--- 7-gate chain (blind to condition 4) ---
  "archiveEligible": true,

--- completion gate ---
  "eligible": false,
  "firstFailingCondition": "openspec-verification",

--- guard-archive verdict ---
{ "change": "ok", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "openspec-verification" }
exit=2
```

The gate chain says *eligible*; the completion gate blocks. That divergence is the
defect this epic closed, demonstrated end-to-end rather than argued.

And the eligible path still archives:

```text
$ scripts/completion-gate.sh --change ok --json | grep -E '"eligible"|"openspecValidateState"'
  "eligible": true,
  "openspecValidateState": "pass",

$ scripts/guard-archive.sh --change ok --json
{ "change": "ok", "archiveEligible": true, "blocked": false }
exit=0
```

### 5.8 Delegate archival to the completion gate

`guard-archive.sh` keeps its gate-chain read but, when `completion-gate.sh` is present,
takes its verdict from it. The fallback matters: a copied settings file in a repository
without the completion gate still works off the gate chain, and still fails open.

```bash
$ scripts/guard-archive.sh --change completion-test
BLOCKED  archive completion-test
  Change is not archive-eligible.
  First failing condition: openspec-verification

  US-10.1: every completion condition must pass before a change is archived.
  Run scripts/completion-gate.sh --change completion-test for the four conditions.
exit=2
```

### 5.9 Build the record and its validator

`--record` writes `completion.md`, with the same derived-versus-authored split used for
`status.md` in EPIC-9: the four rows are derived, the `## Notes` section is preserved.

```text
| Field | Value |
|---|---|
| Story | US-2.1 |
| Change | completion-test |
| Verdict | eligible |
| Evaluated | 2026-09-24 |

| # | Condition | Status | Evidence | Source |
|---|---|---|---|---|
| 1 | tasks | pass | 2/2 tasks complete | tasks.md |
| 2 | review | pass | verdict 'pass', blocking: none | review.md |
| 3 | acceptance | pass | 3 acceptance criterion/criteria PASS | test-report.md |
| 4 | openspec-verification | pass | openspec validate clean; recorded: VERIFIED — no blocking mismatch | openspec validate |
```

The validator's coherence check targets the false certificate:

```text
$ scripts/validate-verification.sh --verification scripts/fixtures/completion/incoherent/completion.md --quiet
  FAIL  Verdict 'eligible' while condition 'acceptance' fails
  RESULT: FAIL — 1 failure(s), 1 warning(s).
```

### 5.10 The last unenforced rule: the DONE transition

US-10.1 task 3 — *"Update SPECS.md story state to DONE only after successful
completion"* — was documented in the Product Manager agent and enforced nowhere.
Archival was guarded from EPIC-8, but the story-state transition that follows it was
only prose.

The hook payload makes it enforceable: `PreToolUse` on `Edit` carries `new_string`, so
the guard can judge the write *about to happen*.

```bash
$ node -e "const d=require('/tmp/pt/in.json');console.log('new_string present:', 'new_string' in d.tool_input)"
new_string present: true
```

Checking the file on disk instead would read the old state and always allow. The guard
fires only when the write newly introduces `Status: DONE` for the active change's
story:

```text
$ printf '{"tool_input":{"file_path":"'"$PWD"'/SPECS.md","new_string":"### US-2.1: Demo\n\nStatus: DONE"}}' \
    | scripts/guard-story-done.sh --hook
BLOCKED  SPECS.md — US-2.1 to DONE
  Change verify is not archive-eligible.
  First failing condition: tasks

  US-10.1: a story is marked DONE only after a successful archive.
  Archive the change first, then set the story to DONE.
exit=2
```

Once eligible, the same payload is allowed, and both the empty-stdin and
missing-`scripts/` cases fail open.

### 5.11 Wire the guard and verify hooks verbatim

The `PreToolUse` Write matcher now carries three guards:

```text
PreToolUse  Write|Edit|MultiEdit  guard-planning-handoff.sh
                                  guard-context-preflight.sh
                                  guard-story-done.sh
PreToolUse  Bash                  guard-archive.sh
PostToolUse Write|Edit|MultiEdit  validate-product-artifacts.sh
                                  run-project-validation.sh
```

Each was extracted from `settings.json` and run with `CLAUDE_PROJECT_DIR` unset:

```text
$ for i in 0 1 2; do node -e "const c=require('./.claude/settings.json');process.stdout.write(c.hooks.PreToolUse[0].hooks[$i].command)" > /tmp/hk.sh
    printf '{"tool_input":{"file_path":"%s/src/app.ts","new_string":"x"}}' "$PWD" | sh /tmp/hk.sh; echo "exit=$?"; done
PreToolUse[0].hooks[0] exit=0
PreToolUse[0].hooks[1] exit=0
PreToolUse[0].hooks[2] exit=0
```

And fail-open was re-confirmed for the whole guard set after the delegation change:

```text
=== fail-open: settings copied, no scripts/ ===
archive-guard exit=0
planning-guard exit=0
```

### 5.12 Full regression

```text
test-write-scope         passed: 36
   exit=0
test-guards              passed: 31
   exit=0
test-status              passed: 42
   exit=0
test-completion          passed: 56
   exit=0
--- frontmatter ---
RESULT: PASS — all definitions valid.
--- validators ---
valid fixtures exit=0
```

---

## 6. Deliverables

### Created

| File | Purpose |
|---|---|
| `scripts/completion-gate.sh` | The four US-10.1 conditions, with recorded evidence |
| `scripts/validate-verification.sh` | The completion-record contract, including the false-certificate check |
| `scripts/guard-story-done.sh` | `PreToolUse`: `DONE` only after archival |
| `scripts/test-completion.sh` | 56-case regression suite |
| `scripts/templates/completion.md` | The completion record format |
| `scripts/fixtures/completion/valid/completion.md` | All four conditions passing |
| `scripts/fixtures/completion/incoherent/completion.md` | Verdict eligible over two failures |
| `scripts/fixtures/completion/malformed/completion.md` | Invented verdict, three rows, no Verdict section |

### Modified

| File | Change |
|---|---|
| `scripts/guard-archive.sh` | Defers to `completion-gate.sh`; falls back to the gate chain |
| `.claude/settings.json` | +1 `PreToolUse` hook, +2 allow rules (55 total) |
| `.claude/agents/product-manager.md` | Archive decision now runs both checks; documents the `/opsx:archive` flow |
| `.claude/skills/product-iteration/SKILL.md` | Step 6 evaluates and records both checks |
| `.claude/rules/openspec.md` | Archival requires all conditions; DONE transition is enforced |
| `.claude/rules/README.md` | Rule-to-gate mapping gains the `DONE` guard |
| `scripts/README.md` | Index entries and a full US-10.1 section |

---

## 7. Acceptance verification

### US-10.1 — Enforce Definition of Done

**Scenario 1 — change is eligible for archive.** Verified with all four conditions
passing:

```text
$ scripts/completion-gate.sh --change verify --json | grep -E '"eligible"|"firstFailingCondition"'
  "eligible": true,
  "firstFailingCondition": null,

$ scripts/guard-archive.sh --change verify --json
{ "change": "verify", "archiveEligible": true, "blocked": false }
guard exit=0
```

**Scenario 2 — change is not eligible for archive.** The scenario lists four
disqualifying conditions ("Or" clauses). Each was verified to reject independently:

| Disqualifier | Verdict | Result |
|---|---|---|
| A required task remains incomplete | `"firstIncompleteGate": "tasks"` | PASS |
| Review has a blocking finding | `"firstIncompleteGate": "review"` | PASS |
| An acceptance criterion is failing | `"firstIncompleteGate": "acceptance"` | PASS |
| OpenSpec verification reports a blocking mismatch | `"firstIncompleteGate": "openspec-verification"` | PASS |

```text
SCENARIO 2: change is NOT eligible — each of the four conditions

--- a) a task remains incomplete ---
{ "change": "verify", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "tasks" }

--- b) review has a blocking finding ---
{ "change": "verify", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "review" }

--- c) an acceptance criterion is failing ---
{ "change": "verify", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "acceptance" }

--- d) OpenSpec verification reports a blocking mismatch ---
{ "change": "verify", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "openspec-verification" }
```

**Task checklist** from `SPECS.md` — all three complete:

- [x] Implement completion-gate check — `scripts/completion-gate.sh`
- [x] Document `/opsx:archive` usage — Product Manager agent, `product-iteration` Step 6, `scripts/README.md`
- [x] Update SPECS.md story state to DONE only after successful completion — enforced by `scripts/guard-story-done.sh`

The two MUST-level scenarios are both blocked by `guard-archive.sh` mechanically, and
the `DONE` task is blocked by `guard-story-done.sh` — verified by `56/56` suite cases.

---

## 8. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | A separate script, not an eighth gate | The conditions are not positions in a sequence; gate 7 and condition 4 are in neither the other's list |
| 2 | Condition 4 checks both the recorded line and the CLI | The recorded line carries the Reviewer's judgement, the CLI the machine's; either alone leaves a hole |
| 3 | `"valid": false` and `"level": "ERROR"`, not `"severity"` | The two JSON shapes share no keys; keying on one silently matched nothing |
| 4 | Capture output and exit code separately | `openspec validate` exits non-zero exactly when invalid, so `|| VAR=""` discarded the failing case |
| 5 | An empty checklist fails condition 1 | Absence of evidence is not evidence — the EPIC-7 gate-6 defect |
| 6 | `UNVERIFIED` does not block but is reported | It is a finding to record, not a false pass; hiding it in the count would be |
| 7 | The guard reads `new_string`, not the file on disk | The file holds the old state, so a disk check would always allow the transition |
| 8 | `guard-story-done.sh` fires only on a *new* DONE | Re-writing an already-DONE story is not the transition being policed |
| 9 | `guard-archive.sh` prefers the completion gate, falls back to the chain | One source of truth, while a repository without the new script keeps working |
| 10 | Re-recording a not-eligible change exits 1 | The exit code reports eligibility, not whether the write succeeded; both are visible |
| 11 | Record verdict is derived, notes authored | Same reasoning as `status.md` in EPIC-9: opposite refresh behaviour, one file |

---

## 9. Notes for reuse

- **A list of conditions in a spec is not automatically a gate.** US-10.1's four
  conditions sat in the backlog while the harness guarded a *different* four-plus-three.
  When a story says "reject when X, Y, or Z", check that each of X, Y, Z is actually
  evaluated somewhere.
- **A field that is checked for presence is not checked.** `OpenSpec verify:` passed
  its contract while declaring four blocking mismatches. If a line carries a verdict,
  something must read the verdict.
- **`VAR=$(cmd) || VAR=""` discards the failure output.** Guarded assignments must keep
  the output when a command exits non-zero, because that is when the output matters.
- **Confirm a JSON parse against a real failing case, not a success case.** The
  `"severity"` key was present in the one shape that never occurs for a valid change
  name, which is why the bug survived the first test round.
- **Two lists that overlap are not the same list.** Enumerate the members before
  deciding one supersedes the other; here each had a member the other lacked.
- **`PreToolUse` can judge prospective content.** `new_string` / `content` in the
  payload make a transition guard possible; reading the file would see the old state.
- **Test the divergence, not just the outcome.** The decisive evidence was the gate
  chain saying `true` while the completion gate said `false`. A test that only asserted
  "ineligible changes are blocked" would have passed before this epic too.

---

## 10. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried since EPIC-2). It remains the only
   reason the harness's own repository fails a contract — `validate-product-artifacts.sh`
   still reports `US-11.1: 2 of 3 scenario(s) lack Given/When/Then`. EPIC-11 needs a
   `When` in those two scenarios before the story can truthfully be `READY`.
2. **The harness now passes seven of seven gates** on a staged change, and all four
   completion conditions. Its own repository is blocked only by the US-11.1 defect.
3. **EPIC-11** updates `README.md` with seventeen-plus scripts: twenty-one now exist.
   The `US-11.1` scenarios must gain a `When` as part of that work.
4. **Consider a `--strict` mode** where `UNVERIFIED` criteria block archival. The
   current behaviour reports them; a strict flag would let a project opt into blocking.
5. **Rotate the OpenRouter token** in commit `ea0d29b` (carried from EPIC-1). Still
   unpushed, no remote configured.
6. **Commit this work.** Suggested message:
   `feat(EPIC-10): four-condition completion gate and mechanical DONE transition`.
