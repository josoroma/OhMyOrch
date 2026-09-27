# README-EPIC-11 — Harness Documentation and Adoption

Implementation record for **EPIC-11** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-11 — Harness Documentation and Adoption |
| Stories | US-11.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-11-1-team-readme/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| OpenSpec | 1.13.2 |
| Spec source | `SPECS.md` lines 1110–1170; `PRD.md` initial delivery scope, FR-003 |

---

## 1. Objective

Make the workflow understandable and executable by a new team without relying on oral
knowledge.

## 2. What this epic found: the README described a harness that no longer existed

`docs/README.md` was already substantial — 951 lines covering installation, brownfield
analysis, PRD/SPECS generation, the full iteration, review, testing, archival, and
resumption. It was not a stub to be written.

But it documented the workflow **conceptually** and the machinery **not at all**:

```bash
$ for s in status.sh completion-gate.sh guard-archive.sh guard-story-done.sh \
           workflow-status.sh test-completion.sh; do
    printf '%-24s %s\n' "$s" "$(grep -c "$s" docs/README.md)"
  done
status.sh                0
completion-gate.sh       0
guard-archive.sh         0
guard-story-done.sh      0
workflow-status.sh       0
test-completion.sh       0
```

Six scripts — the entire enforcement layer built across EPIC-8, EPIC-9, and EPIC-10 —
had **zero** mentions. A new team member following the README would have learned the
process and never discovered that it was mechanically enforced, that `status.md` had a
generated format, or that a completion gate existed at all.

Three further gaps:

1. **No greenfield section.** Four scattered mentions of "greenfield" and no workflow.
   The brownfield path was documented in detail; the greenfield path was implied.
2. **A stale layout.** The repository layout section showed `PRD.md`, `SPECS.md`, and
   `README.md` at the root — but the workspace had since been restructured to `docs/`.
3. **`status.md` documented as prose.** Section 19 showed a hand-written `status.md`
   with a `## Completed Gates` checklist. The real file is generated, has a derived
   gates table, and separates derived from authored content with markers.

## 3. The regression the restructure introduced

Moving the documents into `docs/` broke the harness, and the breakage was silent in the
worst way — it looked like a content failure.

```bash
$ scripts/validate-product-artifacts.sh --quiet
  FAIL  SPECS.md not found at 'SPECS.md'
  RESULT: FAIL — 1 required check(s) failed.
```

The validator's defaults were root-only:

```bash
SPECS_FILE="SPECS.md"
PRD_FILE="PRD.md"
CODEBASE_FILE="CODEBASE.md"
```

So a repository with a perfectly good `docs/SPECS.md` was reported as missing it. The
same assumption appeared in `workflow-status.sh` (gate 7's context check) and
`status.sh` (reading the story's state).

This matters beyond this repository. The harness is meant to be reusable across
arbitrary host repositories (NFR-001), and "where do the product documents live" is
exactly the kind of thing a host repository decides for itself. A harness that only
works when the documents sit at the root is not portable.

**The fix** is a resolver that prefers `docs/` when the file is actually there and
falls back to the root, so both layouts work with no flags:

```bash
doc_path() { # doc_path <filename>
  if [ -f "docs/$1" ]; then printf 'docs/%s\n' "$1"
  else printf '%s\n' "$1"; fi
}
```

Verified in both directions:

```text
=== (1) docs/ layout (default) ===
docs/ layout (default): exit=0

=== (2) root layout still works ===
root layout: exit=0
```

## 4. The US-11.1 defect, resolved

Since EPIC-2 I had flagged that `US-11.1` scenarios 1 and 2 used `Given`/`Then` with no
`When`, making them untestable while the story was marked `READY` — which per BR-005
asserts testability, and per FR-003 requires all three Gherkin keywords.

```bash
$ scripts/validate-product-artifacts.sh --specs docs/SPECS.md --prd docs/PRD.md
  FAIL  US-11.1: 2 of 3 scenario(s) lack Given/When/Then
```

I had deliberately not fixed it, because adding a `When` looked like authoring product
behavior (BR-001). That reasoning was too cautious here, and this epic is where it
resolves: **US-11.1 is "Publish Team README"**, so its acceptance criteria are this
epic's own deliverable. The `Then` clauses already state exactly what the README must
contain; a `When` names the action that exercises them without adding a requirement.

```gherkin
Scenario: README explains installation
  Given a developer opens README.md
  When the developer follows it to install the harness
  Then it MUST explain OpenSpec installation
  ...
```

The two scenarios gained a `When`; nothing else in `SPECS.md` was touched. The result:

```text
$ scripts/validate-product-artifacts.sh --quiet
exit=0

$ scripts/validate-product-artifacts.sh
Summary
  failures: 0
  warnings: 0

  RESULT: PASS — all required checks passed, 0 warning(s).
```

**For the first time, the harness's own `SPECS.md` passes its own contract.** Gate 7 is
no longer red on this repository.

## 5. Scope

### In scope

- Fix the `docs/` path regression across the affected scripts.
- Document the executable harness: script inventory, exit codes, hooks, suites.
- Add the missing greenfield workflow.
- Correct the stale layout and the `status.md` description.
- Resolve US-11.1's testability defect.

### Out of scope

- New harness capability. This epic documents and repairs; it adds no new gate.
- Rewriting the existing README prose, which was accurate and well-structured.

## 6. Step-by-step execution

### 6.1 Recon

```bash
ls -1                       # CLAUDE.md  docs  openspec  scripts
ls -1 docs/                 # PRD.md  README.md  SPEC-LOGS  SPECS.md
grep -n '^## ' docs/README.md | wc -l
```

Found the restructure, the 951-line README, and the zero tooling references.

### 6.2 Fix the path regression

Applied the `doc_path` resolver to `validate-product-artifacts.sh`, and a matching
`docs/`-aware resolution to `workflow-status.sh` and `status.sh`:

```bash
DOCS=""
[ -f docs/SPECS.md ] && DOCS="docs/"
SPECS_PATH="${DOCS}SPECS.md"
CODEBASE_PATH="${DOCS}CODEBASE.md"
```

The guards needed no change: `guard-context-preflight.sh` matches on `basename`, and
`guard-story-done.sh` already accepted `*/SPECS.md`. Verified rather than assumed:

```text
=== does docs/SPECS.md match each guard's case? ===
--- docs/SPECS.md ---
guard-planning-handoff     SPECS-match
guard-context-preflight    SPECS-match
guard-story-done           SPECS-match
```

Then a regression case was added so this cannot silently return:

```text
  ok    docs/PRD.md is still a target                        exit=2
  ok    docs/SPECS.md is still a target                      exit=2
```

### 6.3 Resolve US-11.1

Added a `When` to scenarios 1 and 2, then confirmed all three scenarios carry the three
keywords:

```text
=== all 3 US-11.1 scenarios now have Given/When/Then ===
9

Scenario: README explains installation
  Given a developer opens README.md
  When the developer follows it to install the harness
  Then it MUST explain OpenSpec installation
Scenario: README explains brownfield context and document-to-delivery flow
  Given a developer opens README.md
  When the developer follows it from product sources to a delivered change
  Then it MUST explain how an existing codebase becomes CODEBASE.md
Scenario: README explains resumption
  Given work is interrupted
  When a developer returns in a new Claude session
  Then README.md MUST explain how the harness resumes from repository artifacts
```

### 6.4 Add the greenfield workflow

A new §6, placed directly after the brownfield section so the two paths read as a pair.
Its central point is a prohibition, not a step:

> **Do not run `/analyze-codebase`.** With no code to inspect there is nothing to
> describe, and the skill's own contract requires it to report that no meaningful
> codebase was found and to fabricate no architecture, integrations, commands, or
> existing behavior. A fabricated `CODEBASE.md` is worse than none: later agents would
> treat invented "current behavior" as evidence.

It also documents the two guards that behave differently on greenfield, with the
observed output:

```text
$ scripts/guard-context-preflight.sh --file docs/PRD.md
ALLOW  no meaningful codebase detected (greenfield)
```

### 6.5 Rewrite the workflow-state section

Section 19 previously showed a hand-written `status.md`. It now leads with the two
questions and their two commands, because conflating them is the mistake the tooling
exists to prevent:

| Question | Command |
|---|---|
| Where is this change in the workflow? | `scripts/workflow-status.sh --change <id>` |
| May this change be shipped? | `scripts/completion-gate.sh --change <id>` |

It documents the seven gates, the four conditions, the derived-versus-authored split in
`status.md`, the `State` mapping, and the STALE-versus-malformed distinction — each with
real command output.

### 6.6 Add the executable-harness chapter

A new §24 covering what the README had never mentioned:

- **Script inventory** — all 21 scripts with purpose and implementing story.
- **Exit-code convention** — including that a well-formed report describing a failure
  still exits `0`, and that hooks use `2` for *blocked*.
- **Mechanical guards** — the six hooks, their matchers, and what each prevents.
- **Running the suites** — with real output.
- **Troubleshooting** — seven symptoms mapped to causes and fixes.

The troubleshooting table is the part a new team member actually needs, and every row
is grounded in a failure this project hit:

| Symptom | Cause | Fix |
|---|---|---|
| `SPECS.md not found` | documents live under `docs/` | scripts resolve both; pass `--specs docs/SPECS.md` if your layout differs |
| `US-x.y: N of M scenario(s) lack Given/When/Then` | a `READY` story has an untestable scenario | add the keyword, or mark `NEEDS CLARIFICATION` (BR-005) |
| `status.md` validates but reports STALE | the change advanced without a refresh | `scripts/status.sh --change <id>` |
| `openspec archive` blocked | a completion condition fails | `scripts/completion-gate.sh --change <id>` names it |
| Write blocked with "no implementation plan" | no `implementation-plan.md` | `/plan-feature <change-id>` |
| Write blocked with "stale CODEBASE context" | `CODEBASE.md` describes an older revision | `/analyze-codebase`, or record the staleness decision |
| A guard never fires | the script is not executable | `chmod +x scripts/*.sh` — `test -x` fails open, so a missing bit means silence |

### 6.7 Correct the layout and the contract

The repository-layout section now shows `docs/` and states the resolution rule. The
change-directory listing gained `completion.md`. `CLAUDE.md`'s document map was updated
to match, and gained a `scripts/` row — the executable harness is normative for
enforcement and was absent from the contract entirely.

### 6.8 Verify the README's own claims

Documentation that states counts must be checked against reality, or it becomes the next
stale artifact:

```bash
$ node -e "const c=require('./.claude/settings.json');const n=Object.values(c.hooks).reduce((a,v)=>a+v.reduce((b,g)=>b+g.hooks.length,0),0);console.log('actual hooks:',n)"
actual hooks: 6

$ for s in test-write-scope test-guards test-status test-completion; do
    printf '%-20s ' "$s"; scripts/$s.sh 2>&1 | grep -E '^  passed:'; done
test-write-scope       passed: 36
test-guards            passed: 33
test-status            passed: 42
test-completion        passed: 56

$ node scripts/check-frontmatter.js 2>&1 | grep -c '^OK'
22
```

Every number in the README matches: 6 hooks, 36/33/42/56 cases, 22 definitions.

### 6.9 Full regression

```text
=== full regression ===
test-write-scope         passed: 36   failed: 0
test-guards              passed: 33   failed: 0
test-status              passed: 42   failed: 0
test-completion          passed: 56   failed: 0
RESULT: PASS — all definitions valid.
--- validators: valid fixtures (expect 0) ---
product-artifacts exit=0
implementation-plan exit=0
review exit=0
test-report exit=0
```

And the harness's own repository, end-to-end:

```text
$ scripts/validate-product-artifacts.sh --quiet
exit=0
```

---

## 7. Deliverables

### Created

| File | Purpose |
|---|---|
| `docs/SPEC-LOGS/README-EPIC-11.md` | This record |

### Modified

| File | Change |
|---|---|
| `docs/README.md` | +§6 greenfield; §19 rewritten for the real `status.md`; +§24 executable harness; layout corrected; sections renumbered 6–25 |
| `docs/SPECS.md` | US-11.1 scenarios 1 and 2 gained a `When` (testability fix) |
| `CLAUDE.md` | Document map updated for `docs/`; `scripts/` added as a normative surface |
| `scripts/validate-product-artifacts.sh` | `doc_path` resolver for `docs/` or root |
| `scripts/workflow-status.sh` | Gate 7 resolves `docs/SPECS.md` and `docs/CODEBASE.md` |
| `scripts/status.sh` | Reads story state from `docs/SPECS.md` when present |
| `scripts/guard-context-preflight.sh` | Skip-decision scan includes `docs/` paths |
| `scripts/test-guards.sh` | +2 cases for the `docs/` layout (31 → 33) |

---

## 8. Acceptance verification

### US-11.1 — Publish Team README

**Scenario 1 — README explains installation.**

| Clause | Evidence | Result |
|---|---|---|
| explains OpenSpec installation | `npm install -g @fission-ai/openspec@latest` in §1 | PASS |
| explains initialization for Claude Code | `openspec init --tools claude` in §2 | PASS |
| explains how to confirm installed workflows | §3: `openspec config profile`, the required workflow list, `openspec update`, "Confirm that `/opsx:verify` is available" | PASS |

**Scenario 2 — README explains brownfield context and document-to-delivery flow.**

| Clause | Evidence | Result |
|---|---|---|
| how an existing codebase becomes `CODEBASE.md` | §5 "Bootstrap an Existing Codebase" | PASS |
| how `CODEBASE.md` is consumed for PRD and SPECS | §7 "must read it before materially updating `PRD.md`"; §8 for SPECS | PASS |
| how product sources become PRD and SPECS | §7 and §8 | PASS |
| how one READY story is selected | §10 "Start a Feature Iteration" | PASS |
| explore, propose, apply, verify, archive commands | §11, §12, §14, §15, §17 — all five `/opsx:` commands present | PASS |
| review and test loops | §15 "Review", §16 "Acceptance Test" | PASS |

**Scenario 3 — README explains resumption.**

| Clause | Evidence | Result |
|---|---|---|
| explains how the harness resumes from repository artifacts | §18 "Resume Work in a New Claude Session" — inspects repository state, lists the artifacts, resumes from the first incomplete gate; §20 documents `scripts/status.sh --resume` | PASS |

**Task checklist** from `SPECS.md` — all seven complete:

- [x] Write installation section — §1–§4
- [x] Write role model — "Team" table and §21
- [x] Write command cookbook — §19
- [x] Write greenfield-project workflow — §6 (new)
- [x] Write brownfield codebase-analysis and product-generation workflow — §5, §7, §8
- [x] Document `/analyze-codebase`, `/generate-prd`, and CODEBASE-aware `/ingest-spec` — §5, §7, §8
- [x] Write recovery/resume workflow — §18, §20

**Contract verdict:**

```text
$ scripts/validate-product-artifacts.sh
Summary
  failures: 0
  warnings: 0

  RESULT: PASS — all required checks passed, 0 warning(s).
```

---

## 9. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Fixed the `docs/` path regression rather than documenting a workaround | A harness that only works at the repository root is not portable (NFR-001); the fix is one helper |
| 2 | Resolver prefers `docs/` only when the file exists | A root layout must keep working unchanged |
| 3 | Added a `When` to US-11.1 scenarios 1 and 2 | The story's criteria are this epic's deliverable; the `Then` clauses already fixed the content, so no behavior was invented (BR-001) |
| 4 | Documented the tooling as a new chapter rather than inline | The workflow sections stay readable; the machinery is reference material |
| 5 | Rewrote §19 instead of appending | It described a hand-written `status.md` that no longer exists; leaving it would teach the wrong format |
| 6 | Renumbered sections 6–25 | Inserting greenfield as §6 keeps the two project types adjacent; only one internal reference existed and it was updated |
| 7 | Verified every count the README states | Documentation with numbers becomes the next stale artifact otherwise |
| 8 | Added `scripts/` to `CLAUDE.md`'s document map | The enforcement layer was absent from the top-level contract |
| 9 | Troubleshooting rows drawn from real failures | Each row is a defect this project actually hit, so the fixes are known to work |
| 10 | No new gate or script | This epic documents and repairs; adding capability would exceed its scope |

---

## 10. Notes for reuse

- **A README can be long and still omit the machinery.** 951 lines described the process
  and never named the six scripts that enforce it. Length is not coverage; check that
  every executable artifact is mentioned.
- **A restructure is a breaking change for path assumptions.** Moving documents into
  `docs/` broke three scripts, and the failure surfaced as "SPECS.md not found" — which
  reads like a missing file, not a wrong default.
- **Prefer resolution over configuration.** A helper that checks both locations beats
  requiring every caller to pass a flag, and it keeps a root layout working.
- **A `Given`/`Then` pair with no `When` is not testable.** This is the defect the
  project carried for nine epics. When the story *is* the documentation, fixing its own
  criteria is in scope — the `Then` clauses already bound the content.
- **Verify the numbers you publish.** Hook counts, suite counts, and definition counts
  are cheap to check and embarrassing to get wrong.
- **Document the failure modes, not just the happy path.** The troubleshooting table is
  the most useful part of the chapter, and every row came from a real defect.
- **A guard that is not executable fails open.** `test -x` means a missing `chmod +x`
  produces silence, not an error — worth a troubleshooting row.

---

## 11. Follow-ups

1. **The harness's own repository now passes its own contract.** Gate 7 is green; the
   US-11.1 defect that blocked it since EPIC-2 is resolved. All seven gates pass on a
   staged change, and all four completion conditions.
2. **`docs/SPEC-LOGS/` holds the per-epic records.** EPIC-1 through EPIC-11 are
   complete. The `CLAUDE.md` document map now lists this directory.
3. **Consider a `docs/`-layout case in `test-status.sh` and `test-completion.sh`.** The
   guard suite covers it; the other two suites still stage root-level documents.
4. **Rotate the OpenRouter token** in commit `ea0d29b` (carried from EPIC-1). Still
   unpushed, no remote configured.
5. **Commit this work.** Suggested message:
   `docs(EPIC-11): executable-harness chapter, greenfield workflow, and docs/ path fix`.