# Test Report — us-13-1-navigable-specs-structure

Change: us-13-1-navigable-specs-structure
Story: US-13.1
Verdict: pass
Coverage: 4/4 acceptance criteria evaluated

Independent acceptance record (2026-09-26, working tree). The Tester did not write this
change. The acceptance criteria were taken from `SPECS.md` `### US-13.1:` and the
change's `specs/spec-ingestor/spec.md`, not from the implementer's claims. Every result
below comes from a check I wrote and ran, or from lines I inspected, and the output
shown is what I observed.

- **Method: mixed.** Criteria 1–3 are structural properties of `SPECS.md`, judged by
  Tester-written Python checks that derive the expected values from the document itself
  and compare them to the generated sections. Criterion 4 is a definition requirement,
  judged by inspection of the quoted wording.
- **The checks are mine, not the implementer's.** I did not run `scripts/test-guards.sh`
  as the basis for any row; I wrote independent parsers for the table of contents, the
  status table, and the Mermaid blocks. The implementer's suite was run only as
  supplementary regression (E-6).
- **Real repository:** I ran only read-only commands. `openspec/delivery/goal.md` was
  not modified; `scripts/delivery.sh resolve` and `next` are read-only reporters.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | SPECS.md opens with a table of contents | PASS | Tester-written Python check (E-1). Derived 13 epic headings (`^# EPIC-N:`) and 25 story headings (`^### US-N.M:`) from the body; parsed the `## Table of Contents` block into 38 entries (13 epic + 25 story). Every heading appears in the TOC and every TOC entry has a heading — 0 missing, 0 extra. For each entry I derived the anchor from its own heading text (lowercase, drop punctuation, spaces→hyphens) and compared to the link target: **0 anchor mismatches over 38 entries**. Punctuation heading confirmed: `US-13.1: Generate a Navigable SPECS.md Structure` → `#us-131-generate-a-navigable-specsmd-structure`, matching the TOC line; `US-2.4: Create Generate PRD Skill` → `#us-24-create-generate-prd-skill`, matching. |
| 2 | SPECS.md carries a work-item status table | PASS | Tester-written Python check (E-2). Derived 13 epics, 25 stories (with their `Status:` lines), and 103 tasks (from `- [ ]`/`- [x]` checkboxes) from the body = 141 work items. Parsed the `## Work Item Status` table: header `\| ID \| Title \| Status \| Parent \|`, **141 data rows**, 0 missing, 0 extra. Compared every row: each story row's Status equals its `Status:` line, each task row's Parent names its story and its Status matches its checkbox, each epic row uses `—` for Status and Parent. **0 mismatches over 141 rows.** |
| 3 | SPECS.md carries a dependency diagram | PASS | Tester-written Python check (E-3). Parsed all 14 `mermaid` blocks: every block header is `flowchart TD`; 13 `subgraph` ids, one per epic; **no node id contains a dot**; 25 story nodes nested one-per-epic in the cross-epic diagram (0 duplicates); 103 task edges (`story --> task`) across the 13 per-epic diagrams, matching the 103 tasks in the body. The 11 distinct dotted edges (`-.->`) equal the 11 declared `Dependencies:` entries exactly — **0 missing, 0 invented**. |
| 4 | The Spec Ingestor defines the SPECS.md structure | PASS | Inspection (E-4). `.claude/agents/spec-ingestor.md` line 125 `## Required SPECS.md structure` states "A generated or materially updated `SPECS.md` MUST open with three navigation sections, in this order" and shows the order `## Table of Contents` → `## Work Item Status` → `## Dependency Diagram` → `## Product Context` (lines 135–139), with a subsection defining each (lines 151, 158, 172). `.claude/skills/ingest-spec/SKILL.md` line 88 requires the same three sections "in this order, before `## Product Context`" (lines 93–95), checks them in Step 5 (line 114), and reports them in Step 6. |

## Evidence Commands

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-13-1-navigable-specs-structure --quiet
```

```text
  PASS  selection        change 'us-13-1-navigable-specs-structure' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   9/9 tasks complete
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
        next owner: tester (/test-feature)
  PASS  acceptance       artifact contracts satisfied
  First incomplete gate: testing
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Table of contents (Tester-written check)

```bash
python3 - <<'PY'
import re
lines=open('SPECS.md').read().splitlines()
headings={}
for ln in lines:
    m=re.match(r'^(#{1,3}) (EPIC-\d+|US-\d+\.\d+): (.*)$', ln)
    if m: headings[m.group(2)]=m.group(3)
def anchor(ident,title):
    s=f"{ident}: {title}".lower()
    s=re.sub(r'[^\w\s-]','',s)
    return '#'+re.sub(r'\s+','-',s.strip())
toc=[]; in_toc=False
for ln in lines:
    if ln.strip()=='## Table of Contents': in_toc=True; continue
    if ln.strip()=='## Work Item Status': break
    if in_toc:
        m=re.match(r'^\s*- \[([^\]]+)\]\(([^)]+)\)', ln)
        if m: toc.append((m.group(1),m.group(2)))
mismatch=0
for label,target in toc:
    m=re.match(r'^(EPIC-\d+|US-\d+\.\d+): (.*)$', label)
    if anchor(m.group(1),m.group(2))!=target: mismatch+=1
print("headings:",len(headings),"toc entries:",len(toc),"anchor mismatches:",mismatch)
PY
```

```text
headings: 38 toc entries: 38 anchor mismatches: 0
headings missing from TOC: []
TOC entries with no heading: []
US-13.1 -> #us-131-generate-a-navigable-specsmd-structure
US-2.4  -> #us-24-create-generate-prd-skill
TOC line: - [US-13.1: Generate a Navigable SPECS.md Structure](#us-131-generate-a-navigable-specsmd-structure)
```

### E-2 — Work-item status table (Tester-written check)

```bash
python3 /tmp/tst-us131-check.py   # derives work items, parses the table, compares
```

```text
derived epics: 13 stories: 25 tasks: 103
table data rows: 141
expected total: 141
missing from table: []
extra in table: []
mismatches: 0
```

### E-3 — Dependency diagram (Tester-written check)

```bash
python3 /tmp/tst-us131-mermaid.py   # parses mermaid blocks, compares edges to Dependencies:
python3 /tmp/tst-us131-nest.py      # verifies nesting: stories in subgraphs, tasks per epic
```

```text
declared dependency edges: 11
mermaid blocks: 14
headers: {'flowchart TD'}
subgraphs: 13
distinct node ids: 25
node ids containing a dot: []
dotted edges: 11
missing edges (declared not drawn): []
invented edges (drawn not declared): []

subgraphs: 13
stories nested in subgraphs: 25
duplicate story nodes: 0
per-epic blocks: 13
task edges (story->task): 103
distinct stories with tasks: 25
expected tasks in doc: 103
expected stories: 25
```

**Note on the scenario wording.** The scenario says "a Mermaid diagram of the epics,
user stories, and tasks as nested parents and children". The `## Dependency Diagram`
section holds one cross-epic `flowchart TD` (epics as subgraphs, stories as nodes,
dependency edges) followed by one diagram per epic (stories and their tasks). No single
block shows all three levels together. I judge this **satisfies** the scenario: the
section as a whole is "a Mermaid diagram" of all three levels, the nesting is real
(stories inside epic subgraphs, tasks hanging off their story), and the declared
dependencies are shown. The Reviewer recorded the same reading as an open question, not
a defect. If the Product Manager intends a strict single-block contract, that is a
specification clarification, not a failure of this change.

### E-4 — Spec Ingestor definition (inspection)

```bash
grep -n "Required SPECS.md structure\|## Table of Contents\|## Work Item Status\|## Dependency Diagram\|## Product Context" .claude/agents/spec-ingestor.md
grep -n "Table of Contents\|Work Item Status\|Dependency Diagram\|in this order\|before \`## Product Context\`" .claude/skills/ingest-spec/SKILL.md
```

```text
.claude/agents/spec-ingestor.md
 125:## Required SPECS.md structure
 127:A generated or materially updated `SPECS.md` MUST open with three navigation sections,
 135:## Table of Contents
 136:## Work Item Status
 137:## Dependency Diagram
 139:## Product Context
 151:### Table of Contents
 158:### Work Item Status
 172:### Dependency Diagram

.claude/skills/ingest-spec/SKILL.md
  88:Either way, the file MUST open with the three navigation sections, in this order,
  89:before `## Product Context`:
  93:| `## Table of Contents` | a nested list of every epic and user story, each a link to its heading |
  94:| `## Work Item Status` | one table of every epic, user story, and task: `ID`, `Title`, `Status`, `Parent` |
  95:| `## Dependency Diagram` | a Mermaid `flowchart TD` of the work items as nested parents and children, with one dotted edge per declared dependency, then one diagram per epic |
 114:grep -n '^## Table of Contents$\|^## Work Item Status$\|^## Dependency Diagram$' SPECS.md
 117:All three MUST be present, before `## Product Context`. The status table MUST list
```

The definition requires all three sections and states the section order; the skill
requires and checks the same.

### E-5 — Regression: the new sections do not disturb the parsers

```bash
scripts/validate-product-artifacts.sh
scripts/delivery.sh resolve EPIC-13
scripts/delivery.sh next
scripts/workflow-status.sh --change us-13-1-navigable-specs-structure --quiet
scripts/completion-gate.sh --change us-13-1-navigable-specs-structure
```

```text
validate-product-artifacts.sh
  PASS  Epic identifiers unique (13 found)
  PASS  User Story identifiers unique (25 found)
  PASS  every story declares a valid status
  PASS  every READY story has complete Given/When/Then acceptance criteria
  PASS  every READY story is source-traceable
  failures: 0   warnings: 0
  (closing line: "RESULT: PASS — all required checks passed, 0 warning(s).")   exit=0

delivery.sh resolve EPIC-13
  Target: EPIC-13   Kind: epic
   1  US-13.1  IN PROGRESS  us-13-1-navigable-specs-structure  Generate a Navigable SPECS.md Structure   exit=0

delivery.sh next
  Action:  test
  Story:   US-13.1
  Change:  us-13-1-navigable-specs-structure
  Owner:   tester
  Command: /test-feature us-13-1-navigable-specs-structure
  Reason:  gate testing: test-report.md missing   exit=0

workflow-status.sh --change us-13-1-navigable-specs-structure --quiet
  PASS  selection / planning / plan-handoff / implementation (9/9) / review / acceptance
  ----  testing          test-report.md missing
  First incomplete gate: testing   exit=0

completion-gate.sh --change us-13-1-navigable-specs-structure
  PASS  tasks                    9/9 tasks complete
  PASS  review                   verdict 'pass', blocking: none
  FAIL  acceptance               test-report.md missing
  PASS  openspec-verification    openspec validate clean; recorded: VERIFIED
  NOT ELIGIBLE FOR ARCHIVE   exit=1
```

The new sections did not disturb the artifact validator, the delivery resolver, or the
gate reporters. The completion gate's only failing condition is `acceptance`, which is
the report this run produces.

### E-6 — Supplementary regression (implementer's suite, not a basis for any row)

```bash
scripts/test-guards.sh | tail -6
```

```text
  passed: 64
  failed: 0
  (closing line: "RESULT: PASS — all guard behaviours hold.")
```

Run as supplementary regression only. No row in this report rests on it.

## Failures

None.

## Result

All four criteria were evaluated, and all four passed. Criteria 1–3 rest on
Tester-written checks that derive the expected values from `SPECS.md` itself and compare
them to the generated sections: 38/38 TOC entries with matching anchors, 141/141 status
rows with 0 mismatches, and 11/11 dependency edges with none missing or invented.
Criterion 4 rests on inspection of the agent and skill definitions, which require all
three sections and state the section order. No criterion was scored without observed
evidence.

## Handoff

All criteria pass. Gate 6 now passes. The change is eligible for the completion gate;
the Product Manager evaluates the archive gate (`/opsx:archive`). Acceptance alone does
not archive the change.
