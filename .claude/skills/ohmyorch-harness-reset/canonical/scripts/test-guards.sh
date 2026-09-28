#!/usr/bin/env bash
#
# test-guards.sh — regression suite for the US-8.2 guards
#
# Exercises guard-planning-handoff.sh, guard-context-preflight.sh, and
# guard-archive.sh against staged repository states and hook payloads.
#
# Runs in throwaway directories under ${TMPDIR:-/tmp} and removes them on exit.
# It never modifies the harness repository.
#
# Usage: scripts/test-guards.sh
#
# Exit codes: 0 all cases matched, 1 a case mismatched, 2 setup failure.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPTS="$ROOT/scripts"

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/harness-guards.XXXXXX") || { echo "error: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    printf '  %sok%s    %-52s exit=%s\n' "$c_green" "$c_reset" "$label" "$got"
    PASS=$((PASS + 1))
  else
    printf '  %sFAIL%s  %-52s want=%s got=%s\n' "$c_red" "$c_reset" "$label" "$want" "$got"
    FAIL=$((FAIL + 1))
  fi
}

section() { printf '\n%s\n' "$1"; }

# expect_contains <label> <needle> <command...>
# The match is a case statement, not `grep -q`: under `set -o pipefail`, grep's early
# exit on a match makes the pipeline report failure, so a present needle read as absent.
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  case "$out" in
    *"$needle"*)
    printf '  %sok%s    %-52s found\n' "$c_green" "$c_reset" "$label"
    PASS=$((PASS + 1)) ;;
    *)
    printf '  %sFAIL%s  %-52s missing: %s\n' "$c_red" "$c_reset" "$label" "$needle"
    FAIL=$((FAIL + 1)) ;;
  esac
}

# ---------------------------------------------------------------------------
# Scenario 1 — no implementation before the planning handoff
# ---------------------------------------------------------------------------

section "US-8.2 scenario 1 — implementation requires a plan"

S1="$WORK/s1"
mkdir -p "$S1/openspec/changes/active" "$S1/src"
cd "$S1" || exit 2

check "product code, no plan"            2 "$SCRIPTS/guard-planning-handoff.sh" --file src/app.ts --quiet
check "harness control surface allowed"  0 "$SCRIPTS/guard-planning-handoff.sh" --file .claude/rules/x.md --quiet
check "change artifact allowed"          0 "$SCRIPTS/guard-planning-handoff.sh" --file openspec/changes/active/tasks.md --quiet
check "CLAUDE.md allowed"                0 "$SCRIPTS/guard-planning-handoff.sh" --file CLAUDE.md --quiet
check "hook mode, absolute path"         2 sh -c "printf '{\"tool_input\":{\"file_path\":\"$S1/src/app.ts\"}}' | '$SCRIPTS/guard-planning-handoff.sh' --hook --quiet"
check "hook mode, empty stdin"           0 sh -c "printf '' | '$SCRIPTS/guard-planning-handoff.sh' --hook"

touch openspec/changes/active/implementation-plan.md
check "product code, plan present"       0 "$SCRIPTS/guard-planning-handoff.sh" --file src/app.ts --quiet

mkdir -p openspec/changes/second
check "ambiguous: two active changes"    0 "$SCRIPTS/guard-planning-handoff.sh" --file src/app.ts --quiet

rm -rf openspec/changes/second openspec/changes/active
check "no active change"                 0 "$SCRIPTS/guard-planning-handoff.sh" --file src/app.ts --quiet

# ---------------------------------------------------------------------------
# Scenarios 3, 4, 5 — CODEBASE context preflight
# ---------------------------------------------------------------------------

section "US-8.2 scenarios 3-5 — CODEBASE context preflight"

S2="$WORK/s2"
mkdir -p "$S2/src"
cd "$S2" || exit 2
git init -q .
printf '{"name":"demo"}' > package.json
printf 'export const a=1\n' > src/app.ts
git add -A && git -c user.email=t@t -c user.name=t commit -qm init
REV1=$(git rev-parse HEAD)

check "brownfield, no CODEBASE.md (scenario 5)" 2 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --quiet

printf '# PRD\n\nCODEBASE Context: skipped (legacy port)\n' > PRD.md
check "recorded skip decision"           0 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --quiet
rm -f PRD.md

printf 'Analyzed revision: %s\n' "$REV1" > CODEBASE.md
check "CODEBASE.md current (scenario 3/4)" 0 "$SCRIPTS/guard-context-preflight.sh" --file SPECS.md --quiet

printf 'export const b=2\n' > src/other.ts
git add -A && git -c user.email=t@t -c user.name=t commit -qm advance
check "CODEBASE.md stale"                2 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --quiet

check "non-target artifact ignored"      0 "$SCRIPTS/guard-context-preflight.sh" --file README.md --quiet

# Product documents may live under docs/. The guards use basename matching, so a
# relocated SPECS.md/PRD.md must still be recognised rather than silently skipped.
check "docs/PRD.md is still a target"    2 "$SCRIPTS/guard-context-preflight.sh" --file docs/PRD.md --quiet
check "docs/SPECS.md is still a target"  2 "$SCRIPTS/guard-context-preflight.sh" --file docs/SPECS.md --quiet

# PostToolUse half of the same contract (US-2.7 scenarios 4-5): once CODEBASE.md
# exists, the validator must reject a PRD.md *or* SPECS.md that does not record
# consuming it. SPECS.md was previously unchecked, so it passed silently.
FX="$SCRIPTS/fixtures/valid"
S2V="$WORK/s2v"
mkdir -p "$S2V"
cp "$FX/CODEBASE.md" "$FX/PRD.md" "$S2V/"
grep -v 'CODEBASE Context' "$FX/SPECS.md" > "$S2V/SPECS.md"
check "SPECS.md without context marker fails" 1 "$SCRIPTS/validate-product-artifacts.sh" \
  --specs "$S2V/SPECS.md" --prd "$S2V/PRD.md" --codebase "$S2V/CODEBASE.md" --quiet
check "SPECS.md hook blocks missing marker" 2 sh -c "cd '$S2V' && printf '{\"tool_input\":{\"file_path\":\"$S2V/SPECS.md\"}}' | '$SCRIPTS/validate-product-artifacts.sh' --hook --quiet"
cp "$FX/SPECS.md" "$S2V/SPECS.md"
check "SPECS.md with context marker passes" 0 "$SCRIPTS/validate-product-artifacts.sh" \
  --specs "$S2V/SPECS.md" --prd "$S2V/PRD.md" --codebase "$S2V/CODEBASE.md" --quiet

S3="$WORK/s3"
mkdir -p "$S3"
cd "$S3" || exit 2
check "greenfield: no codebase"          0 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --quiet

# ---------------------------------------------------------------------------
# Scenario 2 — no premature archival
# ---------------------------------------------------------------------------

section "US-8.2 scenario 2 — archive requires every gate"

# The archive guard delegates to workflow-status.sh, so the fixture change lives
# in a copy of the harness where the validators and fixtures are present.
S4="$WORK/s4"
mkdir -p "$S4/scripts" "$S4/openspec/changes/incomplete"
cp "$SCRIPTS"/workflow-status.sh "$SCRIPTS"/validate-*.sh "$S4/scripts/" 2>/dev/null
cp -R "$SCRIPTS/fixtures" "$S4/scripts/fixtures"
cd "$S4" || exit 2

C=openspec/changes/incomplete
cp scripts/fixtures/plans/valid/implementation-plan.md "$C/"
mkdir -p "$C/specs"
printf '# P\n' > "$C/proposal.md"
printf '# S\n' > "$C/specs/spec.md"
printf -- '- [x] done\n' > "$C/tasks.md"

check "missing review and test evidence" 2 "$SCRIPTS/guard-archive.sh" --change incomplete --quiet

cp scripts/fixtures/reviews/blocking/review.md "$C/review.md"
cp scripts/fixtures/test-reports/valid/test-report.md "$C/test-report.md"
check "blocking review findings"         2 "$SCRIPTS/guard-archive.sh" --change incomplete --quiet

cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
cp scripts/fixtures/test-reports/failing/test-report.md "$C/test-report.md"
check "failing acceptance tests"         2 "$SCRIPTS/guard-archive.sh" --change incomplete --quiet

check "hook mode rejects archive"        2 sh -c "printf '{\"tool_input\":{\"command\":\"openspec archive incomplete --yes\"}}' | '$SCRIPTS/guard-archive.sh' --hook --quiet"
check "hook mode ignores archive --help" 0 sh -c "printf '{\"tool_input\":{\"command\":\"openspec archive --help\"}}' | '$SCRIPTS/guard-archive.sh' --hook --quiet"
check "hook mode ignores other commands" 0 sh -c "printf '{\"tool_input\":{\"command\":\"git status --short\"}}' | '$SCRIPTS/guard-archive.sh' --hook --quiet"

# Claude Code's Bash payload always carries a `description` after `command`. A
# greedy parse folded it into the change name and ALLOWED the archive.
check "real payload with description blocks" 2 sh -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"openspec archive incomplete --yes\",\"description\":\"Archive the change\"}}' | '$SCRIPTS/guard-archive.sh' --hook --quiet"
check "archive only in description ignored"  0 sh -c "printf '{\"tool_input\":{\"command\":\"ls\",\"description\":\"then openspec archive\"}}' | '$SCRIPTS/guard-archive.sh' --hook --quiet"

# All gates passing: the guard must allow.
cp "$SCRIPTS/fixtures/valid/PRD.md" "$SCRIPTS/fixtures/valid/CODEBASE.md" .
cp "$SCRIPTS/fixtures/valid/SPECS.md" .
printf '\nCODEBASE Context: consumed\n' >> SPECS.md
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
cp scripts/fixtures/test-reports/valid/test-report.md "$C/test-report.md"
check "all gates pass -> eligible"       0 "$SCRIPTS/guard-archive.sh" --change incomplete --quiet

# ---------------------------------------------------------------------------
# Scenario 6 — project validation adaptation point
# ---------------------------------------------------------------------------

section "US-8.2 scenario 6 — configured fast validation"

S5="$WORK/s5"
mkdir -p "$S5/src" "$S5/scripts"
cd "$S5" || exit 2

check "not configured -> skip, allow"    0 "$SCRIPTS/run-project-validation.sh" --file src/app.ts --quiet
check "non-source file ignored"          0 "$SCRIPTS/run-project-validation.sh" --file README.md --quiet

printf '#!/usr/bin/env bash\nexit 0\n' > scripts/fast-validate.sh
chmod +x scripts/fast-validate.sh
check "configured and passing"           0 "$SCRIPTS/run-project-validation.sh" --file src/app.ts --quiet

printf '#!/usr/bin/env bash\nexit 1\n' > scripts/fast-validate.sh
check "configured and failing"           1 "$SCRIPTS/run-project-validation.sh" --file src/app.ts --quiet

# ---------------------------------------------------------------------------
# Usage errors
# ---------------------------------------------------------------------------

section "Usage errors"

cd "$ROOT" || exit 2
check "planning: unknown option"         3 "$SCRIPTS/guard-planning-handoff.sh" --bogus
check "planning: missing path"           3 "$SCRIPTS/guard-planning-handoff.sh"
check "context: unknown option"          3 "$SCRIPTS/guard-context-preflight.sh" --bogus
check "archive: unknown option"          3 "$SCRIPTS/guard-archive.sh" --bogus
check "validation: unknown option"       3 "$SCRIPTS/run-project-validation.sh" --bogus

# ---------------------------------------------------------------------------
# US-13.1 — the SPECS.md navigation structure
#
# The Spec Ingestor defines the structure, so the definition and the harness's own
# SPECS.md are both checked. The sections are generated from the work items, so a
# section that disagrees with the stories is a defect.
# ---------------------------------------------------------------------------

section "US-13.1 — SPECS.md navigation structure"

SPECS="$ROOT/SPECS.md"
INGESTOR="$ROOT/.claude/agents/ohmyorch-spec-ingestor.md"
INGEST_SKILL="$ROOT/.claude/skills/ohmyorch-ingest-spec/SKILL.md"

# Scenario: SPECS.md opens with a table of contents
expect_contains "SPECS.md has a table of contents" "## Table of Contents" cat "$SPECS"
toc_epics=$(sed -n '/^## Table of Contents$/,/^## Work Item Status$/p' "$SPECS" | grep -cE '^- \[EPIC-[0-9]+:' || true)
specs_epics=$(grep -cE '^# EPIC-[0-9]+:' "$SPECS" || true)
check "the TOC lists every epic"                  0 test "$toc_epics" = "$specs_epics"
toc_stories=$(sed -n '/^## Table of Contents$/,/^## Work Item Status$/p' "$SPECS" | grep -cE '^  - \[US-[0-9]+\.[0-9]+:' || true)
specs_stories=$(grep -cE '^### US-[0-9]+\.[0-9]+:' "$SPECS" || true)
check "the TOC lists every story"                 0 test "$toc_stories" = "$specs_stories"
if [ "$specs_stories" -gt 0 ]; then
  expect_contains "the TOC links an epic"          "](#epic-1-harness-bootstrap)" cat "$SPECS"
  expect_contains "the TOC links a story"          "](#us-131-generate-a-navigable-specsmd-structure)" cat "$SPECS"
else
  expect_contains "the TOC exposes the empty Epics section" "](#epics)" cat "$SPECS"
fi

# Scenario: SPECS.md carries a work-item status table
expect_contains "SPECS.md has a work item status table" "## Work Item Status" cat "$SPECS"
expect_contains "the status table has the required columns" "| ID | Title | Status | Parent |" cat "$SPECS"
rows=$(sed -n '/^## Work Item Status$/,/^## Dependency Diagram$/p' "$SPECS" | grep -cE '^\| (EPIC|US)-' || true)
specs_tasks=$(grep -cE '^- \[[ xX]\]' "$SPECS" || true)
check "the status table lists every work item"    0 test "$rows" = "$((specs_epics + specs_stories + specs_tasks))"
# The row's status must track the story's own Status: line, not a fixed value.
if [ "$specs_stories" -gt 0 ]; then
  expect_contains "a story row carries its title" "| US-13.1 | Generate a Navigable SPECS.md Structure |" cat "$SPECS"
  row_status=$(grep -E '^\| US-13\.1 \|' "$SPECS" | awk -F'|' '{ gsub(/^[ ]+|[ ]+$/, "", $4); print $4 }')
  story_status=$(awk '/^### US-13\.1:/{f=1;next} f&&/^Status:/{sub(/^Status:[ ]*/,"");print;exit}' "$SPECS")
  check "a story row tracks its Status: line"     0 test "$row_status" = "$story_status"
  expect_contains "a task row names its parent"   "| US-13.1#1 |" cat "$SPECS"
else
  expect_contains "the empty status table is explicit" "| — | No work items yet | — | — |" cat "$SPECS"
fi

# Scenario: SPECS.md carries a dependency diagram
expect_contains "SPECS.md has a dependency diagram" "## Dependency Diagram" cat "$SPECS"
expect_contains "the diagram is mermaid"           '```mermaid' cat "$SPECS"
if [ "$specs_stories" -gt 0 ]; then
  expect_contains "the diagram nests epics"        'subgraph EPIC_13["EPIC-13: Backlog Navigation and Structure"]' cat "$SPECS"
  expect_contains "the diagram nests stories"      'US-13_1["US-13.1:' cat "$SPECS"
  expect_contains "the diagram nests tasks"        'US-13_1 --> US-13_1_t1' cat "$SPECS"
  expect_contains "the diagram draws a dependency" 'US-2_5 -.-> US-13_1' cat "$SPECS"
else
  expect_contains "the empty diagram is explicit"  'empty["No epics yet"]' cat "$SPECS"
fi
# Each edge is drawn in the cross-epic diagram and again in its epic's diagram, so
# compare the distinct edges with the declared dependencies.
edges=$(grep -oE 'US-[0-9]+_[0-9]+ -\.-> US-[0-9]+_[0-9]+' "$SPECS" | sort -u | grep -c . || true)
declared=$(awk '/^Dependencies:/{d=1;next} d&&/^- /{n++} d&&!/^- /{d=0} END{print n+0}' "$SPECS")
check "the diagram draws every declared dependency" 0 test "$edges" = "$declared"

# Scenario: The Spec Ingestor defines the SPECS.md structure
expect_contains "the agent requires the TOC"       "## Table of Contents" cat "$INGESTOR"
expect_contains "the agent requires the status table" "## Work Item Status" cat "$INGESTOR"
expect_contains "the agent requires the diagram"   "## Dependency Diagram" cat "$INGESTOR"
expect_contains "the agent defines the section order" "## Required SPECS.md structure" cat "$INGESTOR"
expect_contains "the agent defines the table columns" "| ID | Title | Status | Parent |" cat "$INGESTOR"
expect_contains "the skill requires the sections"  "## Table of Contents" cat "$INGEST_SKILL"
expect_contains "the skill requires the diagram"   "## Dependency Diagram" cat "$INGEST_SKILL"

# The new sections must not disturb the parsers that read SPECS.md.
cd "$ROOT" || exit 2
if [ "$specs_stories" -gt 0 ]; then
  stories_seen=$(scripts/delivery.sh resolve EPIC-13 2>/dev/null | grep -cE 'US-13\.1' || true)
  check "delivery.sh still resolves stories"      0 test "$stories_seen" = "1"
else
  check "delivery.sh rejects absent stories cleanly" 1 scripts/delivery.sh resolve EPIC-13
fi
check "the artifact validator still passes"       0 "$SCRIPTS/validate-product-artifacts.sh" --specs "$SPECS" --quiet

# ---------------------------------------------------------------------------
# US-13.2 — README navigation and the orchestrator loop
#
# The README is the operational handbook, so its table of contents and the section
# that explains the loop and the plan handoff are checked against the file itself.
# ---------------------------------------------------------------------------

section "US-13.2 — README navigation and the orchestrator loop"

README="$ROOT/README.md"

# Scenario: README opens with a table of contents
expect_contains "README has a table of contents"   "## Table of Contents" cat "$README"
toc_entries=$(sed -n '/^## Table of Contents$/,/^## Why this exists$/p' "$README" | grep -cE '^- \[[0-9]' || true)
numbered=$(grep -cE '^## [0-9]+\. ' "$README" || true)
check "the TOC lists every numbered section"       0 test "$toc_entries" = "$numbered"
expect_contains "the TOC links a numbered section" "](#19-the-orchestrator-loop-and-the-plan-handoff)" cat "$README"
expect_contains "the TOC links the last section"   "](#28-references)" cat "$README"
# Every numbered heading must have a matching TOC entry.
toc_text=$(sed -n '/^## Table of Contents$/,/^## Why this exists$/p' "$README")
missing_toc=0
while IFS= read -r h; do
  n=$(printf '%s' "$h" | sed -n 's/^## \([0-9]*\)\..*/\1/p')
  case "$toc_text" in *"- [$n. "*) ;; *) missing_toc=$((missing_toc + 1)) ;; esac
done < <(grep -E '^## [0-9]+\. ' "$README")
check "every numbered section is in the TOC"       0 test "$missing_toc" = "0"

# Scenario: README explains the orchestrator loop
expect_contains "README has the orchestrator section" "## 19. The Orchestrator Loop and the Plan Handoff" cat "$README"
expect_contains "the loop names the ohmyorch-planner"       "| \`plan\` | ohmyorch-planner |" cat "$README"
expect_contains "the loop names the ohmyorch-implementer"   "| \`implement\` | ohmyorch-implementer |" cat "$README"
expect_contains "the loop names the ohmyorch-reviewer"      "| \`review\` | ohmyorch-reviewer |" cat "$README"
expect_contains "the loop names the ohmyorch-tester"        "| \`test\` | ohmyorch-tester |" cat "$README"
expect_contains "the loop names the skills"        "/ohmyorch:opsx:apply" cat "$README"
expect_contains "the loop is shown as a diagram"   "flowchart TD" cat "$README"
expect_contains "the loop shows the Stop hook"     "guard-delivery-loop.sh" cat "$README"

# Scenario: README explains the plan-to-implement handoff
expect_contains "the handoff names the plan file"  "implementation-plan.md" cat "$README"
expect_contains "the handoff says the Planner writes it" "The Planner writes a file into the change directory" cat "$README"
expect_contains "the handoff says the Implementer reads it" "the Implementer reads that file" cat "$README"
expect_contains "the handoff names the gate"       "guard-planning-handoff.sh" cat "$README"
expect_contains "the handoff names gate 3"         "plan-handoff" cat "$README"
expect_contains "the handoff is shown as a diagram" "flowchart LR" cat "$README"
expect_contains "the handoff names the scope check" "check-scope.sh --plan" cat "$README"

# ---------------------------------------------------------------------------
# US-13.3 — every artifact handoff between roles
# ---------------------------------------------------------------------------

section "US-13.3 — artifact handoffs between roles"

expect_contains "README has the artifact handoffs subsection" "### How every artifact reaches the next role" cat "$README"
# Scenario: README explains every artifact handoff
expect_contains "the handoff table names the proposal" "| proposal → plan |" cat "$README"
expect_contains "the handoff table names the plan"     "| plan → implement |" cat "$README"
expect_contains "the handoff table names the implementation" "| implement → review |" cat "$README"
expect_contains "the handoff table names the review"   "| review → test |" cat "$README"
expect_contains "the handoff table names the acceptance evidence" "| test → archive |" cat "$README"
expect_contains "the handoff table names the writer"   "| Written by |" cat "$README"
expect_contains "the handoff table names the reader"   "| Read by |" cat "$README"
# Scenario: README shows the handoffs as a diagram
expect_contains "the handoffs are shown as a diagram"  "flowchart LR" cat "$README"
expect_contains "the diagram shows the change directory as the medium" "the medium" cat "$README"
expect_contains "the diagram nests the artifacts in the change directory" 'subgraph change["openspec/changes/' cat "$README"
# Scenario: README explains the mechanical gate on each handoff
expect_contains "the handoff names gate 2"             "gate 2 \`planning\`" cat "$README"
expect_contains "the handoff names gate 4"             "gate 4 \`implementation\`" cat "$README"
expect_contains "the handoff names gate 5"             "gate 5 \`review\`" cat "$README"
expect_contains "the handoff names gate 6"             "gate 6 \`testing\`" cat "$README"
expect_contains "the handoff explains the return path" "the work goes back" cat "$README"
expect_contains "the return path names reopen"         "delivery.sh reopen" cat "$README"
expect_contains "the return path preserves the verdict" "history/<artifact>-r<round>.md" cat "$README"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n=======================================================\n'
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS — all guard behaviours hold.%s\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL — guard behaviour regressed.%s\n' "$c_red" "$c_reset"
exit 1
