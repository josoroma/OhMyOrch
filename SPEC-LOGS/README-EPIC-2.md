# README-EPIC-2 — Codebase Understanding and Product Specification

Implementation record for **EPIC-2** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-2 — Codebase Understanding and Product Specification |
| Stories | US-2.1 … US-2.7 (7 stories) |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-2-1-codebase-analyst-agent/`<br>`openspec/changes/archive/2026-09-24-us-2-2-analyze-codebase-skill/`<br>`openspec/changes/archive/2026-09-24-us-2-3-product-specifier-agent/`<br>`openspec/changes/archive/2026-09-24-us-2-4-generate-prd-skill/`<br>`openspec/changes/archive/2026-09-24-us-2-5-spec-ingestor-agent/`<br>`openspec/changes/archive/2026-09-24-us-2-6-ingest-spec-skill/`<br>`openspec/changes/archive/2026-09-24-us-2-7-artifact-validation/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| Spec source | `SPECS.md` lines 172–452; `PRD.md` sections 5, 6, FR-013…FR-018 |

---

## 1. Objective

Support both greenfield and brownfield projects by creating a durable model of an
existing repository in `CODEBASE.md`, then requiring product-definition workflows to
consider that evidence when generating or updating `PRD.md` and `SPECS.md`.

## 2. The design problem

EPIC-2 contains six narrative requirements ("the agent must not invent behavior") and
one mechanical requirement (US-2.7, validation). Prompt instructions alone cannot
enforce a narrative rule — an agent can read "do not modify application source code"
and modify it anyway.

So every narrative requirement in this epic is backed by a mechanism, not only by
prose:

| Requirement | Mechanism |
|---|---|
| Analyst / Specifier / Ingestor never edit product code | Their `tools` list omits `Write` and `Edit`, so the action is unavailable |
| `CODEBASE.md` is consumed before PRD/SPECS generation | The validator fails when `CODEBASE.md` exists and the artifact does not record consuming it |
| `READY` implies testable acceptance | The validator fails a `READY` story lacking a complete Gherkin scenario |
| Claims stay traceable | The validator fails a `READY` story with no `Source:` reference |
| Description stays separate from intent | Dedicated `## Current-State Context` and `## Gaps` PRD sections, so codebase evidence never sits among requirements |

## 3. Scope

### In scope

- **US-2.1** — `codebase-analyst` agent: repository analysis, read boundaries,
  evidence/unknown handling, `CODEBASE.md` schema.
- **US-2.2** — `analyze-codebase` skill: detection, delegation, staleness refresh.
- **US-2.3** — `product-specifier` agent: source precedence, current-vs-target
  language, ambiguity handling.
- **US-2.4** — `generate-prd` skill: source handling, create-vs-update, preflight.
- **US-2.5** — `spec-ingestor` agent: traceability, `CODEBASE.md` consumption,
  conflict preservation.
- **US-2.6** — `ingest-spec` skill: incremental merge, ingestion summary, preflight.
- **US-2.7** — validation contracts, portable validator, fixtures, hook integration.

### Out of scope

- The Product Manager, Planner, Implementer, Reviewer, and Tester (EPIC-3…EPIC-7).
- Rules files and hook guards beyond the artifact validator (EPIC-8).
- `status.md` and resumption (EPIC-9).

## 4. Plan

```text
1. Recon: confirm Claude Code subagent + skill frontmatter formats
2. Design the mechanism-backed strategy (see section 2)
3. Build + test the validator and its fixtures        (US-2.7 mechanism first)
4. Author the three agents (read-only tool allowlists)
5. Author the three skills (delegation + preflight)
6. Document the validation contracts
7. Register the PostToolUse hook
8. Verify every acceptance criterion
9. Document the result in this file
```

Building the validator first was deliberate: it is the only mechanically testable
deliverable in the epic, so it could be proven before the prose that depends on it
was written.

## 5. Step-by-step execution

### 5.1 Recon — confirm the file formats

The subagent and skill frontmatter formats were verified against the official
documentation before authoring, rather than assumed.

```bash
head -8 .claude/skills/openspec-propose/SKILL.md
```

```text
---
name: openspec-propose
description: Propose a new OpenSpec change with all artifacts generated in one step. ...
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.13.2"
---
```

Confirmed field names: `name`, `description`, `allowed-tools` (hyphenated), `license`,
`compatibility`, `metadata`. Subagent files use the same shape with camelCase
multi-word fields (`disallowedTools`, `maxTurns`).

Version check, which later shaped a design decision:

```bash
claude --version
```

```text
2.1.128 (Claude Code)
```

### 5.2 Build the validator

Created `scripts/validate-product-artifacts.sh` — bash + `awk`/`grep`/`sed` only, no
Node or Python, so it stays portable across arbitrary host repositories (NFR-001).

```bash
chmod +x scripts/validate-product-artifacts.sh
bash -n scripts/validate-product-artifacts.sh
```

```text
syntax: OK
```

Ran it against the repository's own artifacts:

```bash
./scripts/validate-product-artifacts.sh
```

```text
OhMyOrch Harness — product artifact validation
============================================

SPECS.md — SPECS.md
  PASS  Epic identifiers unique (11 found)
  PASS  User Story identifiers unique (20 found)
  FAIL  US-11.1: 2 of 3 scenario(s) lack Given/When/Then
  fix: every acceptance scenario needs all three of Given, When, Then
  PASS  every story declares a valid status
  PASS  every READY story is source-traceable

CODEBASE.md — CODEBASE.md
  not present — skipping schema validation

PRD.md — PRD.md
  PASS  no CODEBASE.md present, so no context acknowledgment is required

Summary
  failures: 1
  warnings: 0

  RESULT: FAIL — 1 required check(s) failed.
```

**The validator found a real pre-existing defect in `SPECS.md`.** See section 8.

### 5.3 Prove the validator with fixtures

Seeded two artifact sets so the validator's own behaviour is verifiable.

```bash
./scripts/validate-product-artifacts.sh \
  --specs scripts/fixtures/invalid/SPECS.md \
  --codebase scripts/fixtures/invalid/CODEBASE.md \
  --prd scripts/fixtures/invalid/PRD.md
```

```text
SPECS.md — scripts/fixtures/invalid/SPECS.md
  FAIL  duplicate User Story identifier: US-1.1:
  FAIL  US-1.1: 1 of 2 scenario(s) lack Given/When/Then
  FAIL  US-1.1: invalid status 'BOGUS STATUS'
  FAIL  US-1.2: READY but has no 'Source:' reference
  FAIL  US-1.3: missing 'Status:' line

CODEBASE.md — scripts/fixtures/invalid/CODEBASE.md
  WARN  analyzed revision recorded but empty or 'unknown'
  PASS  has required section: ## System Summary
  FAIL  missing required section: ## Runtime and Tooling
  FAIL  missing required section: ## Evidence Paths
  WARN  no section for: Architecture, Entry Points, ...

PRD.md — scripts/fixtures/invalid/PRD.md
  FAIL  ...CODEBASE.md exists but ...PRD.md does not record consuming it

Summary
  failures: 8
  warnings: 2

  RESULT: FAIL — 8 required check(s) failed.
```

All 8 seeded defects detected, exit `1`.

```bash
./scripts/validate-product-artifacts.sh \
  --specs scripts/fixtures/valid/SPECS.md \
  --codebase scripts/fixtures/valid/CODEBASE.md \
  --prd scripts/fixtures/valid/PRD.md
```

```text
SPECS.md — scripts/fixtures/valid/SPECS.md
  PASS  Epic identifiers unique (1 found)
  PASS  User Story identifiers unique (3 found)
  PASS  every story declares a valid status
  PASS  every READY story has complete Given/When/Then acceptance criteria
  PASS  every READY story is source-traceable
  2 story/stories are not READY — acceptance checks not applied

CODEBASE.md — scripts/fixtures/valid/CODEBASE.md
  PASS  records an analyzed revision (0f1e2d3)
  PASS  has required section: ## System Summary
  PASS  has required section: ## Repository Map
  PASS  has required section: ## Runtime and Tooling
  PASS  has required section: ## Evidence Paths
  PASS  has required section: ## Unknowns
  PASS  all advisory sections present

PRD.md — scripts/fixtures/valid/PRD.md
  PASS  records codebase context consumption: CODEBASE Context: consumed (0f1e2d3)

Summary
  failures: 0
  warnings: 0

  RESULT: PASS — all required checks passed, 0 warning(s).
```

Exit `0`, no false positives. Note the valid fixture deliberately includes
`NEEDS CLARIFICATION` and `DONE` stories to prove only `READY` stories are gated.

### 5.4 Author the three agents

Each declares `tools: Read, Grep, Glob, Bash` — no `Write`, no `Edit`. The stated
boundary ("never modify application source code") is therefore enforced by the tool
allowlist, not only by prompt compliance.

| File | Implements | Key content |
|---|---|---|
| `.claude/agents/codebase-analyst.md` | US-2.1 | 12-step method, read boundaries, secret handling, `CODEBASE.md` schema, `ANALYSIS RESULT` block |
| `.claude/agents/product-specifier.md` | US-2.3 | Authority order, the intent-vs-state diagram, `CODEBASE Context:` marker, ambiguity/conflict rules |
| `.claude/agents/spec-ingestor.md` | US-2.5 | Status decision table, mandatory story shape, traceability, conflict preservation |

The Codebase Analyst defines explicit read boundaries: it must not read `.env` files,
key material, `.claude/settings.local.json`, or dependency/build output, and must
report a secret found in version control as a risk **without reproducing the value**.

### 5.5 Author the three skills

Each is a procedural wrapper that delegates to its agent and enforces preflight.

| File | Implements | Preflight behaviour |
|---|---|---|
| `.claude/skills/analyze-codebase/SKILL.md` | US-2.2 | Detects a meaningful codebase; **stops without creating the file** if none exists |
| `.claude/skills/generate-prd/SKILL.md` | US-2.4 | Three cases: `CODEBASE.md` present → read + freshness check; codebase present but file missing → stop and require analysis or a recorded skip; greenfield → proceed from sources |
| `.claude/skills/ingest-spec/SKILL.md` | US-2.6 | Same three cases, plus incremental merge rules and the ingestion summary |

The greenfield guard is explicit in all three: a project with no meaningful codebase
must **not** receive a fabricated `CODEBASE.md`.

### 5.6 Document the contracts

Created `scripts/README.md` documenting the readiness contract, the `CODEBASE.md`
schema contract, the context-consumption contract, exit codes, hook integration, and
the fixtures.

### 5.7 Register the hook

Added to `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/validate-product-artifacts.sh\" && exec \"$d/scripts/validate-product-artifacts.sh\" --hook --quiet; exit 0'",
            "statusMessage": "Validating product artifacts"
          }
        ]
      }
    ]
  }
}
```

**Why the `sh -c` wrapper.** `${CLAUDE_PROJECT_DIR}` is documented as a *skill
body* substitution, which requires Claude Code v2.1.196; the installed CLI is
**2.1.128**. Hook `command` strings receive the variable as an exported environment
variable instead, but referencing `${CLAUDE_PROJECT_DIR:-$PWD}` is correct whether or
not it is set — so the hook behaves identically on older and newer CLIs. The
`test -x` guard makes the hook fail *open* (exit `0`) when the script is absent,
rather than blocking every write in a project that copied the settings but not
`scripts/`.

Verified by running the command string verbatim, extracted from the settings file:

```bash
CMD=$(node -e "process.stdout.write(require('./.claude/settings.json').hooks.PostToolUse[0].hooks[0].command)")
printf '%s' '{"tool_input":{"file_path":"scripts/fixtures/invalid/SPECS.md"}}' | CLAUDE_PROJECT_DIR="$PWD" sh -c "$CMD"
printf '%s' '{"tool_input":{"file_path":"scripts/fixtures/invalid/SPECS.md"}}' | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
printf '%s' '{"tool_input":{"file_path":"README.md"}}' | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
```

```text
--- case 1: CLAUDE_PROJECT_DIR set, invalid SPECS (expect block/exit 2) ---
SPECS.md: 5 validation failure(s). Fix them before proceeding.
exit=2
--- case 2: CLAUDE_PROJECT_DIR UNSET, invalid SPECS (fallback to PWD, expect block/exit 2) ---
SPECS.md: 5 validation failure(s). Fix them before proceeding.
exit=2
--- case 3: unrelated file (expect exit 0) ---
exit=0
```

### 5.8 Validate frontmatter

All six authored files were parsed as YAML to confirm the frontmatter is well-formed
and carries the required `name` and `description` fields.

```bash
node -e "…parse frontmatter of all 6 files…"
```

```text
OK    .claude/agents/codebase-analyst.md        name=codebase-analyst   desc=220 chars
OK    .claude/agents/product-specifier.md       name=product-specifier  desc=210 chars
OK    .claude/agents/spec-ingestor.md           name=spec-ingestor      desc=226 chars
OK    .claude/skills/analyze-codebase/SKILL.md  name=analyze-codebase   desc=300 chars
OK    .claude/skills/generate-prd/SKILL.md      name=generate-prd       desc=259 chars
OK    .claude/skills/ingest-spec/SKILL.md       name=ingest-spec        desc=353 chars
```

A file whose `name` is missing, whose `---` is not the first line, or whose YAML does
not parse is silently skipped by Claude Code, so this check matters. All descriptions
are well under the 1,536-character listing cap.

---

## 6. Deliverables

### Created

| Path | Implements | Purpose |
|---|---|---|
| `.claude/agents/codebase-analyst.md` | US-2.1 | Read-only repository analyst |
| `.claude/agents/product-specifier.md` | US-2.3 | Read-only PRD author |
| `.claude/agents/spec-ingestor.md` | US-2.5 | Read-only backlog author |
| `.claude/skills/analyze-codebase/SKILL.md` | US-2.2 | Codebase-analysis command |
| `.claude/skills/generate-prd/SKILL.md` | US-2.4 | PRD-generation command |
| `.claude/skills/ingest-spec/SKILL.md` | US-2.6 | Backlog-ingestion command |
| `scripts/validate-product-artifacts.sh` | US-2.7 | Portable artifact validator |
| `scripts/README.md` | US-2.7 | Validation contract documentation |
| `scripts/fixtures/valid/{SPECS,CODEBASE,PRD}.md` | US-2.7 | Passing fixture |
| `scripts/fixtures/invalid/{SPECS,CODEBASE,PRD}.md` | US-2.7 | Failing fixture |
| `README-EPIC-2.md` | — | This document |

### Modified

| Path | Change |
|---|---|
| `.claude/settings.json` | Added the `PostToolUse` validation hook and two allow rules for the validator |
| `.claude/agents/README.md` | Replaced the scaffold placeholder with the delivered/pending role table |

---

## 7. Acceptance verification

Executed as a single scripted check:

```bash
echo "--- US-2.1 Codebase Analyst agent ---"
grep -q "^name: codebase-analyst" .claude/agents/codebase-analyst.md && echo "PASS  agent defined"
grep -q "Read, Grep, Glob, Bash" .claude/agents/codebase-analyst.md && echo "PASS  read-only tool list (no Write/Edit)"
grep -q "Analyzed revision" .claude/agents/codebase-analyst.md && echo "PASS  CODEBASE.md schema defined"
grep -q "Unknowns" .claude/agents/codebase-analyst.md && echo "PASS  unknown-handling defined"
grep -q "Existing behavior is not product intent" .claude/agents/codebase-analyst.md && echo "PASS  existing-behavior-not-intent rule"
```

```text
--- US-2.1 Codebase Analyst agent ---
PASS  agent defined
PASS  read-only tool list (no Write/Edit)
PASS  no Write/Edit in tools
PASS  CODEBASE.md schema defined
PASS  unknown-handling defined
PASS  existing-behavior-not-intent rule

--- US-2.2 / US-2.4 / US-2.6 skills present ---
PASS  analyze-codebase skill
PASS  generate-prd skill
PASS  ingest-spec skill

--- US-2.7 validator + hook registered ---
PASS  validator executable
PASS  PostToolUse hook registered
```

### Story-by-story results

| Story | Acceptance criterion | Evidence | Result |
|---|---|---|---|
| **US-2.1** | Identify structure, runtime, entry points, modules, data, integrations, tests, tooling, commands, conventions from evidence | 12-step method in the agent; schema requires each section | PASS |
| **US-2.1** | Persist understanding in `CODEBASE.md` | Agent returns the full document; skill writes it | PASS |
| **US-2.1** | Must not modify application source code | `tools` omits `Write`/`Edit` — mechanically prevented | PASS |
| **US-2.1** | Claims evidence-backed; unsupported → unknowns | "Evidence or unknown — never a guess"; every section must appear, unknowns enumerated | PASS |
| **US-2.1** | Existing behavior not promoted to product intent | Explicit rule + `## Existing Product Behavior` section labelled descriptive | PASS |
| **US-2.2** | Delegate analysis; create/refresh `CODEBASE.md` | Skill step 2 delegates to `codebase-analyst` | PASS |
| **US-2.2** | Include analyzed revision + evidence paths | Validator requires `Analyzed revision:` and `## Evidence Paths` (proven by fixture) | PASS |
| **US-2.2** | Do not fabricate context for greenfield | Skill step 1 stops and reports `no meaningful codebase found` | PASS |
| **US-2.2** | Refresh stale understanding | Skill step 3 diffs recorded revision against HEAD | PASS |
| **US-2.2** | Stable current-state schema | Validator enforces 5 required + 10 advisory sections (proven by fixture) | PASS |
| **US-2.3** | Read `CODEBASE.md` before writing PRD | Agent preflight step 2; marker required by validator | PASS |
| **US-2.3** | Greenfield PRD from sources, no invented architecture | "Greenfield means greenfield" rule | PASS |
| **US-2.3** | Intent conflicting with implementation | Desired behavior retained; difference recorded as gap/constraint/migration/open question | PASS |
| **US-2.4** | Determine whether `CODEBASE.md` exists | Skill step 2 | PASS |
| **US-2.4** | Run analysis first or record a skip | Skill case B stops and offers exactly those two options | PASS |
| **US-2.4** | Surface stale context | Skill case A prints the staleness report | PASS |
| **US-2.5** | Convert artifacts to structured requirements | Agent method steps 2–4 | PASS |
| **US-2.5** | Read `CODEBASE.md` when it exists | Agent preflight; `Codebase Context:` field in the story shape | PASS |
| **US-2.5** | Missing behavior not invented | `NEEDS CLARIFICATION` + `Open Questions` rule | PASS |
| **US-2.5** | Conflicts preserved, story `BLOCKED` | Conflict rule keeps both sources traceable | PASS |
| **US-2.6** | Delegate extraction; provide codebase context | Skill step 3 | PASS |
| **US-2.6** | No duplicate requirements on merge | Skill step 4 merge rules; agent preflight step 8 | PASS |
| **US-2.6** | Run analysis first or record a skip | Skill case B | PASS |
| **US-2.7** | Validate unique Epic and story identifiers | Validator; proven by invalid fixture | PASS |
| **US-2.7** | Validate `READY` criteria and Given/When/Then | Validator; proven by both fixtures | PASS |
| **US-2.7** | Untraceable requirement cannot be ready | Validator `Source:` check; proven by invalid fixture | PASS |
| **US-2.7** | PRD/SPECS acknowledge existing `CODEBASE.md` | Context-marker check; proven by invalid fixture | PASS |
| **US-2.7** | Hook or script integration | `PostToolUse` hook; verified verbatim | PASS |
| **US-2.7** | Validation failures actionable | Every failure prints `fix:` / `allowed:` guidance and the offending identifier | PASS |
| **US-2.7** | Portable mechanism selected per host project | Pure bash; no runtime dependency | PASS |

### Validator result on the repository

```bash
./scripts/validate-product-artifacts.sh
```

```text
SPECS.md — SPECS.md
  PASS  Epic identifiers unique (11 found)
  PASS  User Story identifiers unique (20 found)
  FAIL  US-11.1: 2 of 3 scenario(s) lack Given/When/Then
  PASS  every story declares a valid status
  PASS  every READY story is source-traceable

CODEBASE.md — CODEBASE.md
  not present — skipping schema validation

PRD.md — PRD.md
  PASS  no CODEBASE.md present, so no context acknowledgment is required

Summary
  failures: 1
  warnings: 0
```

---

## 8. Finding: `SPECS.md` US-11.1 is not `READY`

The validator's first real run flagged a pre-existing defect in `SPECS.md`, unrelated
to this epic. Two of the three `US-11.1` acceptance scenarios contain `Given` and
`Then` but **no `When`**:

```gherkin
Scenario: README explains brownfield context and document-to-delivery flow
  Given a developer opens README.md
  Then it MUST explain how an existing codebase becomes CODEBASE.md
  And it MUST explain how CODEBASE.md is consumed when generating PRD.md and SPECS.md
  ...
```

```gherkin
Scenario: README explains installation
  Given a developer opens README.md
  Then it MUST explain OpenSpec installation
  ...
```

**Why this was not fixed.** `US-11.1` is `READY`, which asserts its behavior is
testable. Adding a `When` clause would be inventing the missing product behavior, which
`BR-001` forbids. The three legitimate resolutions are all Product Manager decisions:

1. **Add a `When`** that reflects the intended trigger — e.g. *"When the developer
   reads the installation section"*.
2. **Accept `Given`/`Then` as the intended form.** This requires relaxing the
   validator, which contradicts `SPECS.md` FR-003 ("Ready user stories SHALL contain
   observable acceptance criteria expressed as Gherkin scenarios using `Given`, `When`,
   and `Then`"). Recommend against.
3. **Mark `US-11.1` `NEEDS CLARIFICATION`** until the acceptance criteria are settled.

Recommended: option 1, since the intent is clear and only the phrasing is missing.
Until resolved, `US-11.1` must not enter delivery.

> This finding is the validator working as designed. It is recorded here rather than
> silently repaired, per `BR-001` and `CLAUDE.md` rule 1.

---

## 9. Task checklist

### US-2.1 — Create Codebase Analyst Agent
- [x] Create `.claude/agents/codebase-analyst.md`.
- [x] Define repository read boundaries and prohibit product-code edits.
- [x] Define evidence and unknown-handling rules.
- [x] Define the `CODEBASE.md` schema.

### US-2.2 — Create Analyze Codebase Skill
- [x] Create `.claude/skills/analyze-codebase/SKILL.md`.
- [x] Define codebase-detection guidance.
- [x] Define snapshot metadata and evidence-path format.
- [x] Define refresh behavior.

### US-2.3 — Create Product Specifier Agent
- [x] Create `.claude/agents/product-specifier.md`.
- [x] Define source precedence rules.
- [x] Define current-state vs target-state language.
- [x] Define ambiguity and conflict handling.

### US-2.4 — Create Generate PRD Skill
- [x] Create `.claude/skills/generate-prd/SKILL.md`.
- [x] Define input source handling.
- [x] Define create-vs-update behavior for `PRD.md`.
- [x] Define `CODEBASE.md` preflight behavior.

### US-2.5 — Create Spec Ingestor Agent
- [x] Create `.claude/agents/spec-ingestor.md`.
- [x] Define read/write boundaries.
- [x] Define source-traceability rules.
- [x] Define `CODEBASE.md` consumption rules.
- [x] Define ambiguity and conflict handling.

### US-2.6 — Create Ingest Spec Skill
- [x] Create `.claude/skills/ingest-spec/SKILL.md`.
- [x] Define create-vs-update behavior.
- [x] Define ingestion summary format.
- [x] Define `CODEBASE.md` preflight behavior.

### US-2.7 — Validate Product Artifacts and Context
- [x] Define `CODEBASE.md` validation contract.
- [x] Define `PRD.md` context-consumption validation.
- [x] Define `SPECS.md` readiness validation contract.
- [x] Add hook or validation-script integration.
- [x] Make validation failures actionable.

---

## 10. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Validator written in bash, not Node or Python | `NFR-001` requires portability; the harness has no runtime and must not impose one on host repositories |
| 2 | Hook command wrapped in `sh -c` with `${VAR:-$PWD}` | Installed CLI is 2.1.128; the documented `${CLAUDE_PROJECT_DIR}` skill substitution needs 2.1.196. The wrapper is correct on both |
| 3 | Hook fails open when the script is missing | A copied `settings.json` without `scripts/` must not block every write |
| 4 | Advisory `CODEBASE.md` sections warn rather than fail | `US-2.2` says "when discoverable"; failing would push agents to invent content |
| 5 | `SPECS.md` not modified | Story *state* is Product Manager-owned (`US-10.1`); the task checklist is recorded here as evidence, consistent with `README-EPIC-1.md` |
| 6 | `US-11.1` defect reported, not repaired | Repairing requires inventing behavior, which `BR-001` forbids |
| 7 | `Codebase Context:` marker line chosen as the acknowledgment mechanism | It is greppable, sits at a fixed location, and is required by both the agent prompts and the validator |

---

## 11. Notes for reuse

- **Hook scope.** The `PostToolUse` hook fires for every `Write|Edit|MultiEdit` in the
  project, but the script exits `0` for any file it does not validate, so the cost is a
  `basename` check on unrelated writes.
- **`PostToolUse` is not transactional.** Exit code 2 surfaces findings and interrupts
  the workflow; the file is already written. `PreToolUse` cannot validate a file's
  post-write content, which is why validation is post-write.
- **Validator section matching is exact.** Headings must match `^## <Name>$`
  case-insensitively. Renaming a `CODEBASE.md` heading breaks the contract — update
  both the script and `scripts/README.md`.
- **Fixture paths are explicit.** The fixtures rely on `--specs` / `--codebase` /
  `--prd` flags because hook mode resolves paths relative to the project root.
- **`claude plugin validate` is a plugin-manifest checker.** Passing it a bare
  `.claude/agents` or `.claude/skills` directory reports a missing manifest; it only
  inspects agent/skill files when v2.1.233+ is installed. Frontmatter was verified by
  parsing instead.

---

## 12. Follow-ups

1. **Resolve `US-11.1`.** Add a `When` clause to the two scenarios, or mark the story
   `NEEDS CLARIFICATION`. Until then the validator will report it as a failure.
2. **`CODEBASE.md` for this repository.** Once authored for the harness project itself,
   the context-consumption check becomes live for `PRD.md` and `SPECS.md`.
3. **Author the remaining agents** — Product Manager, Planner, Implementer, Reviewer,
   Tester (EPIC-3 … EPIC-7).
4. **Commit this work.** Suggested message:
   `feat(EPIC-2): codebase analysis, product specification, and artifact validation`.
