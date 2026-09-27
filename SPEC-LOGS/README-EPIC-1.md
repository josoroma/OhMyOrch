# README-EPIC-1 — Harness Bootstrap

Implementation record for **EPIC-1: Harness Bootstrap** from `SPECS.md`.

This document captures the plan, the exact commands executed, their observed
outputs, the resulting deliverables, and the acceptance verification.

| Field | Value |
|---|---|
| Epic | EPIC-1 — Harness Bootstrap |
| Stories | US-1.1, US-1.2 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-1-1-initialize-openspec/`<br>`openspec/changes/archive/2026-09-24-us-1-2-harness-structure/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Spec source | `SPECS.md` lines 89–154; `PRD.md` sections 8 and 11 |

---

## 1. Objective

Establish the reusable repository structure, OpenSpec integration, Claude agent,
skill, and rule scaffolding, and workflow conventions required by the harness.

## 2. Scope

### In scope

- **US-1.1** — Initialize OpenSpec for Claude Code, enable the `verify`
  workflow, and add `openspec/config.yaml` project guidance.
- **US-1.2** — Create the harness repository structure: `CLAUDE.md`,
  `.claude/agents/`, `.claude/skills/`, `.claude/rules/`,
  `.claude/settings.json`, and confirm `SPECS.md`.

### Out of scope

- Authoring the individual agent, skill, and rule files. Their content belongs
  to EPIC-2 through EPIC-8. US-1.2 requires only that the directories and the
  top-level contract exist.
- Workflow hooks (US-8.2) and specification validation (US-2.7).

## 3. Plan

```text
1. Verify toolchain (node, npm, claude, openspec)
2. Install OpenSpec CLI
3. Configure a custom OpenSpec profile that includes `verify`
4. Initialize OpenSpec for Claude Code
5. Add project guidance to openspec/config.yaml
6. Create CLAUDE.md (top-level session contract)
7. Create .claude/agents/ and .claude/rules/ scaffolds
8. Create .claude/settings.json (tracked team settings, no secrets)
9. Verify both stories' acceptance criteria
10. Document the result in this file
```

### Design decisions

**Why a custom OpenSpec profile?** US-1.1 requires the `verify` workflow. The
OpenSpec `core` profile installs
`propose, explore, apply, update, sync, archive` — `verify` is not included.
`verify` is only available through a `custom` profile.

**Why `.claude/settings.json` instead of `.claude/settings.local.json`?**
`settings.local.json` is machine-local and holds an API token, so it must never
be committed. Team-shared, secret-free configuration belongs in the tracked
`settings.json`, which US-1.2 explicitly requires.

**Why placeholder READMEs in the scaffold directories?** Git does not track
empty directories. `.claude/agents/` and `.claude/rules/` are required to exist
by US-1.2 but their contents are delivered by later epics, so each holds a
README that documents the intended file set.

---

## 4. Step-by-step execution

### 4.1 Verify the toolchain

```bash
node --version
npm --version
command -v openspec
openspec --version
command -v claude
```

Output:

```text
--- node ---
v22.23.2
--- npm ---
10.9.8
--- openspec ---
zsh: command not found: openspec
--- claude ---
/opt/homebrew/bin/claude
```

Node and npm were present; OpenSpec was **not** installed at this point.

### 4.2 Install OpenSpec

```bash
npm install -g @fission-ai/openspec@latest
```

Output:

```text
added 70 packages in 6s

23 packages are looking for funding
  run `npm fund` for details
```

Confirm the installation:

```bash
command -v openspec
openspec --version
```

Output:

```text
--- which ---
/Users/josoroma/.nvm/versions/node/v22.23.2/bin/openspec
--- version ---
1.13.2
```

OpenSpec `1.13.2` installed.

### 4.3 Confirm the default profile lacks `verify`

```bash
openspec config list
```

Output:

```text
Profile settings:
  profile: core (default)
  delivery: both (default)
  workflows: propose, explore, apply, update, sync, archive (from core profile)
```

The `core` profile omits `verify`, confirming that a custom profile is required.

### 4.4 Configure a custom profile including `verify`

```bash
openspec config set profile custom
```

Output:

```text
Set profile = "custom"
```

The first attempt at the workflow list used a comma-separated string:

```bash
openspec config set workflows propose,explore,apply,update,sync,verify,archive
```

Output:

```text
Error: Invalid configuration - workflows: Invalid input: expected array, received string
```

> **Note** — the `workflows` key requires a JSON array, not a comma-separated
> string.

Retry with JSON array syntax:

```bash
openspec config set workflows '["propose","explore","apply","update","sync","verify","archive"]'
```

Output:

```text
Set workflows = propose,explore,apply,update,sync,verify,archive
```

Verify:

```bash
openspec config list
```

Output:

```text
profile: custom
delivery: both
workflows:
  - propose
  - explore
  - apply
  - update
  - sync
  - verify
  - archive

Profile settings:
  profile: custom (explicit)
  delivery: both (explicit)
  workflows: propose, explore, apply, update, sync, verify, archive (explicit)
```

`verify` is now in the active workflow set.

### 4.5 Initialize OpenSpec for Claude Code

```bash
openspec init --tools claude --no-animation
```

Output:

```text
- Creating OpenSpec structure...
▌ OpenSpec structure created
- Setting up Claude Code...
✔ Setup complete for Claude Code

OpenSpec Setup Complete

Created: Claude Code
7 skills and 7 commands in .claude/
Config: openspec/config.yaml (schema: spec-driven)

Getting started:
  Start your first change: /opsx:propose "your idea"
```

Inspect the generated structure:

```bash
find openspec .claude -maxdepth 3 | sort
```

Output (abridged):

```text
.claude/commands/opsx/apply.md
.claude/commands/opsx/archive.md
.claude/commands/opsx/explore.md
.claude/commands/opsx/propose.md
.claude/commands/opsx/sync.md
.claude/commands/opsx/update.md
.claude/commands/opsx/verify.md
.claude/skills/openspec-apply-change/SKILL.md
.claude/skills/openspec-archive-change/SKILL.md
.claude/skills/openspec-explore/SKILL.md
.claude/skills/openspec-propose/SKILL.md
.claude/skills/openspec-sync-specs/SKILL.md
.claude/skills/openspec-update-change/SKILL.md
.claude/skills/openspec-verify-change/SKILL.md
openspec/changes/archive/.gitkeep
openspec/config.yaml
openspec/specs/.gitkeep
```

Both the `verify` command and the `openspec-verify-change` skill were installed.

### 4.6 Add project guidance to `openspec/config.yaml`

The generated file contained only commented examples. It was replaced with
concrete project guidance covering: the repository's nature, the authoritative
documents, the one-bounded-change delivery model, the required per-change
handoff artifacts, role separation, and ambiguity handling.

Per-artifact rules were added for `proposal`, `tasks`, and `design`; per-operation
guidance was added for `apply` and `archive`.

**Defect found and fixed.** The first write produced invalid YAML: an `archive`
guidance entry wrapped onto a second line whose extra indentation was parsed as
an implicit nested mapping.

```text
Warning: could not parse /Users/josoroma/projects/claude-dev/openspec/config.yaml
(Implicit map keys need to be followed by map values at line 54, column 9:); ignoring it.

Note: .../openspec/config.yaml declares a store: pointer that cannot be used
(the config file could not be read as YAML).
```

The multi-line entry was converted to a single quoted YAML string. Re-checking:

```bash
openspec doctor
```

Output:

```text
Doctor

Root
  Location: /Users/josoroma/projects/claude-dev
  OpenSpec root: ok

References
  (none declared)
```

The warning is gone and the config parses cleanly. The keys used
(`schema`, `context`, `rules`, `operations.apply.guidance`,
`operations.archive.guidance`) match OpenSpec's `ProjectConfigSchema` exactly.

### 4.7 Create `CLAUDE.md`

Created as the top-level session contract, containing:

- the document map and authority order;
- the workflow from `SPECS.md` story to archived change;
- the seven hard rules (no silent product assumptions, separation of duties,
  one manageable change, durable artifacts, mandatory acceptance, context
  before generation, reviewers/testers do not repair);
- the agent role table with product-code edit permissions;
- repository working conventions;
- the story and change status vocabularies.

### 4.8 Create the scaffold directories

Created `.claude/agents/README.md` and `.claude/rules/README.md`. Each documents
the files it will hold and cross-references the owning epic, so Git tracks the
directory before the files are authored.

`.claude/skills/` already existed with OpenSpec's generated skills.

### 4.9 Create `.claude/settings.json`

Created a tracked, secret-free team settings file:

- `permissions.allow` — read-only and `openspec` inspection commands;
- `permissions.deny` — `.env`, secret files, private keys, and
  `.claude/settings.local.json`;
- `permissions.defaultMode: "default"`;
- `respectGitignore` and `includeGitInstructions` enabled;
- empty commit/PR attribution;
- `OPENSPEC_TELEMETRY=0`.

Validated as syntactically correct JSON and checked against the published
Claude Code settings schema (`https://json.schemastore.org/claude-code-settings.json`).

---

## 5. Deliverables

### Created

| Path | Purpose |
|---|---|
| `.gitignore` | Ignore local secrets and build artifacts (pre-existing task) |
| `CLAUDE.md` | Top-level session contract |
| `.claude/settings.json` | Tracked team settings, no secrets |
| `.claude/agents/README.md` | Scaffold placeholder + intended file list |
| `.claude/rules/README.md` | Scaffold placeholder + intended file list |
| `openspec/config.yaml` | Project context, artifact rules, operation guidance |
| `.claude/commands/opsx/*.md` | 7 OpenSpec commands (generated) |
| `.claude/skills/openspec-*/` | 7 OpenSpec skills (generated) |
| `openspec/specs/`, `openspec/changes/` | OpenSpec planning roots (generated) |
| `README-EPIC-1.md` | This document |

### Untracked intentionally

`.claude/settings.local.json` was already tracked and contains a live API token.
It was removed from the index with `git rm --cached` so `.gitignore` takes
effect; the file remains on disk.

---

## 6. Acceptance verification

### US-1.1 — Initialize OpenSpec for Claude Code

> **Scenario: Initialize OpenSpec in a project**
> Then an `openspec/` project structure MUST exist
> And Claude-compatible OpenSpec workflow files MUST be installed
> And the project MUST be able to create a new OpenSpec change

| Criterion | Evidence | Result |
|---|---|---|
| `openspec/` structure exists | `openspec/`, `openspec/specs/`, `openspec/changes/` | PASS |
| Claude workflow files installed | 7 commands in `.claude/commands/opsx/`, 7 skills in `.claude/skills/` | PASS |
| Can create a new change | `openspec new change probe-verify-workflow` succeeded and appeared in `openspec list` | PASS |

Change-creation proof:

```bash
openspec new change probe-verify-workflow
openspec list
```

Output:

```text
Created change 'probe-verify-workflow' at openspec/changes/probe-verify-workflow/
Schema: spec-driven
Next: openspec status --change probe-verify-workflow

Changes:
  probe-verify-workflow     No tasks      just now
```

The probe change was deleted afterward; `openspec list` returns
`No active changes found.`

> **Scenario: Enable verification workflow**
> Then the `verify` workflow MUST be available to Claude Code

| Criterion | Evidence | Result |
|---|---|---|
| `verify` workflow available | `.claude/commands/opsx/verify.md` present; `.claude/skills/openspec-verify-change/` present; `verify` in the active profile | PASS |

```bash
test -f .claude/commands/opsx/verify.md && echo "verify command: PRESENT"
test -d .claude/skills/openspec-verify-change && echo "verify skill:   PRESENT"
```

Output:

```text
verify command: PRESENT
verify skill:   PRESENT
```

### US-1.2 — Create Harness Repository Structure

> **Scenario: Required harness files exist**

```bash
for f in CLAUDE.md SPECS.md .claude/settings.json; do
  [ -e "$f" ] && printf 'PASS  %s\n' "$f" || printf 'FAIL  %s\n' "$f"
done
for d in .claude/agents .claude/skills .claude/rules; do
  [ -d "$d" ] && printf 'PASS  %s/\n' "$d" || printf 'FAIL  %s/\n' "$d"
done
```

Output:

```text
PASS  CLAUDE.md
PASS  SPECS.md
PASS  .claude/settings.json
PASS  .claude/agents/
PASS  .claude/skills/
PASS  .claude/rules/
```

| Required artifact | Result |
|---|---|
| `CLAUDE.md` | PASS |
| `.claude/agents/` | PASS |
| `.claude/skills/` | PASS |
| `.claude/rules/` | PASS |
| `.claude/settings.json` | PASS |
| `SPECS.md` | PASS |

### Cross-cutting checks

```bash
openspec doctor
```

```text
Doctor

Root
  Location: /Users/josoroma/projects/claude-dev
  OpenSpec root: ok

References
  (none declared)
```

```bash
git check-ignore -v .claude/settings.local.json
git status --short --ignored | grep '^!!'
```

```text
.gitignore:6:.claude/*.local.json       .claude/settings.local.json
!! .claude-dev/
!! .claude/settings.local.json
```

Only the secret-bearing local settings file and the local `.claude-dev/`
directory are ignored. All harness deliverables are visible to Git.

```bash
git status --short
```

```text
 M .gitignore
?? .claude/agents/
?? .claude/commands/
?? .claude/rules/
?? .claude/settings.json
?? .claude/skills/
?? CLAUDE.md
?? openspec/
```

---

## 7. Task checklist

### US-1.1

- [x] Document OpenSpec installation command.
- [x] Document `openspec init --tools claude`.
- [x] Configure a custom OpenSpec workflow profile that includes `verify`.
- [x] Add `openspec/config.yaml` project guidance.

### US-1.2

- [x] Create top-level `CLAUDE.md` contract.
- [x] Create `.claude/agents/`.
- [x] Create `.claude/skills/`.
- [x] Create `.claude/rules/`.
- [x] Create `.claude/settings.json`.

---

## 8. Deviations and decisions

| # | Deviation | Rationale |
|---|---|---|
| 1 | Used a `custom` OpenSpec profile instead of the default | `verify` is not in `core`; US-1.1 requires it |
| 2 | Configured the profile globally, not per-project | `openspec init --profile` is transient and does not persist. The profile lives in `~/.config/openspec/config.json` |
| 3 | Added README placeholders to empty scaffold dirs | Git does not track empty directories, so US-1.2's directory requirement would not survive a clone |
| 4 | Set commit/PR attribution to empty strings | The harness should not inject tool attribution into consumer repositories |

---

## 9. Notes for reuse

- **Profile persistence.** `openspec config set` writes to
  `~/.config/openspec/config.json`, which is machine-global. When adopting the
  harness on another machine, re-run the `profile` and `workflows` steps, or
  pass `--profile custom` to `init`.
- **`workflows` needs JSON.** Use `'["a","b"]'`; a comma-separated string is
  rejected.
- **`archive` requires `sync`.** OpenSpec auto-inserts `sync` when `archive` is
  selected.
- **Regenerate, do not hand-edit.** `.claude/commands/opsx/` and
  `.claude/skills/openspec-*` are OpenSpec-managed. Use `openspec update` after
  changing the profile.
- **YAML folding.** Multi-line list items in `openspec/config.yaml` must be
  quoted or consistently indented, or OpenSpec will reject the file.

---

## 10. Follow-ups

1. **Rotate the OpenRouter API token** in `.claude/settings.local.json`. It
   remains in commit `ea0d29b`. No Git remote is configured, so it has not been
   published; rotate before any push.
2. **Author the harness files** — the agent, skill, and rule content is
   delivered by EPIC-2 through EPIC-8.
3. **Commit this work.** Suggested message:
   `feat(EPIC-1): bootstrap harness structure and OpenSpec integration`.
