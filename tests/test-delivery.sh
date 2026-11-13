#!/usr/bin/env bash
#
# test-delivery.sh — regression suite for goal-driven delivery
#
# Exercises scripts/delivery.sh (target resolution, next-action derivation, goal
# record) and scripts/guard-delivery-loop.sh (the Stop hook) against a staged
# project with a stub SPECS.md.
#
# Each story is one OpenSpec change: propose -> apply -> verify -> archive, then
# the story is marked DONE. The properties this suite protects:
#
#   1. Resolution — an epic lists its stories in order, a task resolves to its
#      parent story, and an unknown target is refused without recording a goal.
#   2. Derivation — the decision table: every row maps the repository state to
#      one action, command and reason, exactly, in text and in JSON. It is
#      recomputed from SPECS.md and the change directory on every call, reads
#      nothing but OpenSpec's own artifacts, and writes nothing. Tasks are
#      counted as OpenSpec counts them, and the cost of a call does not grow
#      with the number of delivered stories.
#   3. Escalation — a story that is not READY, or whose dependency is unfinished,
#      escalates and creates no change.
#   4. Leftovers — files an earlier plugin version wrote into a change
#      (review.md, status.md, implementation-plan.md, history/ ...) are ignored
#      and survive untouched.
#   5. The loop (guard-delivery-loop.sh) — a Stop hook blocks the stop while work
#      remains, allows it and records BLOCKED on escalation or lack of progress,
#      records COMPLETE when every story is DONE, and cannot bypass the archive
#      or DONE guards. Hooks are driven with realistic multi-key payloads.
#
# The openspec CLI is kept off PATH: derivation is plain file checks and must not
# need it. An archive is staged by moving the change directory.
# Runs in a throwaway copy under ${TMPDIR:-/tmp} and removes it on exit.
#
# Usage: bash tests/run.sh delivery
#
# Exit codes: 0 all cases matched, 1 a case mismatched, 2 setup failure.

set -uo pipefail

ROOT="$TEST_HARNESS_ROOT"

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/harness-delivery.XXXXXX") || { echo "error: cannot create temp dir" >&2; exit 2; }
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
# Scratch files the scripts create (mktemp) stay inside the throwaway directory.
mkdir -p "$WORK/tmp"
TMPDIR="$WORK/tmp"
export TMPDIR

ok()  { printf '  %sok%s    %-58s %s\n' "$c_green" "$c_reset" "$1" "$2"; PASS=$((PASS + 1)); }
bad() { printf '  %sFAIL%s  %-58s %s\n' "$c_red" "$c_reset" "$1" "$2"; FAIL=$((FAIL + 1)); }

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then ok "$label" "exit=$got"; else bad "$label" "want=$want got=$got"; fi
}

# expect_contains <label> <needle> <command...>
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -F -- "$needle" >/dev/null; then ok "$label" "found"
  else bad "$label" "missing: $needle"; fi
}

# expect_absent <label> <needle> <command...>
expect_absent() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -F -- "$needle" >/dev/null; then bad "$label" "unexpectedly found: $needle"
  else ok "$label" "absent"; fi
}

# expect_eq <label> <want> <got> — exact string comparison.
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1" "exact"
  else bad "$1" "mismatch"; printf '    want: %s\n    got:  %s\n' "$2" "$3"; fi
}

section() { printf '\n%s\n' "$1"; }

SEEN="$WORK/derived-actions.jsonl"; : > "$SEEN"

# expect_action <label> <target> <action> <story> <change> <command> <reason>
# Two cases: the five text lines and the one JSON line, each compared exactly.
# No derived string carries a double quote or a backslash, so the JSON line can be
# written out literally.
expect_action() {
  ea_label="$1"; ea_target="$2"
  ea_text=$(printf 'Action:  %s\nStory:   %s\nChange:  %s\nCommand: %s\nReason:  %s' "$3" "$4" "$5" "$6" "$7")
  ea_json=$(printf '{ "target": "%s", "action": "%s", "story": "%s", "change": "%s", "command": "%s", "reason": "%s" }' \
    "$2" "$3" "$4" "$5" "$6" "$7")
  expect_eq "$ea_label" "$ea_text" "$(scripts/delivery.sh next "$ea_target" 2>&1)"
  ea_got=$(scripts/delivery.sh next "$ea_target" --json 2>&1)
  expect_eq "$ea_label (json)" "$ea_json" "$ea_got"
  printf '%s\n' "$ea_got" >> "$SEEN"
}

action_of() { scripts/delivery.sh next "$@" 2>/dev/null | sed -n 's/^Action:  //p'; }
reason_of() { scripts/delivery.sh next "$@" 2>/dev/null | sed -n 's/^Reason:  //p'; }
changes_snapshot() { find openspec/changes -maxdepth 1 -mindepth 1 -type d | sort; }
# tree_sum <path>... — one checksum over every file path and content.
tree_sum() { find "$@" -type f | sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done | cksum; }
# left_sum <change dir> — the same, over the files an earlier plugin version left
# in a change, with paths relative to the change so an archive move does not matter.
left_sum() { ( cd "$1" && tree_sum review.md test-report.md status.md completion.md implementation-plan.md history ); }

PROPOSE_CONTINUE="(continue the existing change: author only what is missing)"

# ---------------------------------------------------------------------------
# Stage a project
# ---------------------------------------------------------------------------

S="$WORK/repo"
mkdir -p "$S/scripts" "$S/openspec/changes/archive"
for f in delivery.sh guard-delivery-loop.sh guard-archive.sh guard-story-done.sh; do
  cp "$ROOT/scripts/$f" "$S/scripts/" || { echo "error: cannot stage $f" >&2; exit 2; }
done
chmod +x "$S"/scripts/*.sh
cd "$S" || exit 2

PATH="$OHMYORCH_TEST_UTILITIES:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
TODAY=$(date +%Y-%m-%d)

cat > SPECS.md <<'EOF'
# Stub Specification

CODEBASE Context: absent (greenfield)

# EPIC-1: Multi-story epic

### US-1.1: First story

Status: READY

Tasks:
- [ ] Build the widget parser.
- [ ] Wire the widget renderer.

### US-1.2: Second story

Status: READY

Tasks:
- [ ] Shared step.

### US-1.3: Third story

Status: READY

Tasks:
- [ ] Shared step.

# EPIC-2: Unclear epic

### US-2.1: Undecided story

Status: NEEDS CLARIFICATION

# EPIC-3: Dependent epic

### US-3.1: Depends on an unfinished story

Status: READY

Dependencies:
- US-3.2

### US-3.2: Not yet delivered

Status: READY

### US-3.3: Inline dependency

Status: READY

Dependencies: US-3.2

### US-3.4: On hold with an archived change

Status: NEEDS CLARIFICATION

Change: `openspec/changes/archive/2026-09-24-us-3-4-x/`

### US-3.5: Archived change with an unfinished dependency

Status: IN PROGRESS

Change: `openspec/changes/archive/2026-09-24-us-3-5-x/`

Dependencies:
- US-3.2

### US-3.6: Several dependencies

Status: READY

Dependencies:
- US-3.2
- US-9.9
- US-4.1

### US-3.7: Blocked by a human

Status: BLOCKED

### US-3.8: Satisfied dependency

Status: READY

Dependencies: US-4.1

# EPIC-4: In-flight epic

### US-4.1: Delivered story

Status: DONE

Change: `openspec/changes/archive/2026-09-24-us-4-1-x/`

### US-4.2: Story with an active change

Status: IN PROGRESS

Change: `openspec/changes/us-4-2-x/`
EOF
mkdir -p openspec/changes/archive/2026-09-24-us-4-1-x openspec/changes/archive/2026-09-24-us-3-4-x \
         openspec/changes/archive/2026-09-24-us-3-5-x

section "Staging"
# Give every story the shape of a real backlog entry: the parser must read status,
# change, dependencies and tasks around Source lines and Gherkin blocks.
awk '
  /^### US-/ {print; print "\nSource:\n- PRD.md fixture\n\nAcceptance Criteria:\n\n```gherkin\nScenario: Fixture acceptance\n  Given a fixture\n  When it runs\n  Then it succeeds\n```\n"; next}
  {print}
' SPECS.md > SPECS.enriched
mv SPECS.enriched SPECS.md
cp SPECS.md "$WORK/specs.orig"

check "openspec CLI is absent in the copy" 1 bash -c 'command -v openspec'

# ---------------------------------------------------------------------------
# Scenario: Resolve an epic into its stories
# ---------------------------------------------------------------------------

section "Resolve an epic into its stories"

check "resolve EPIC-1 exits 0"                  0 scripts/delivery.sh resolve EPIC-1
order=$(scripts/delivery.sh resolve EPIC-1 | grep -oE 'US-[0-9]+\.[0-9]+' | tr '\n' ' ')
expect_eq "stories listed in SPECS.md order"    "US-1.1 US-1.2 US-1.3 " "$order"
ids=$(scripts/delivery.sh resolve EPIC-1 --json | grep -oE '"change": "[^"]*"' | sort -u | grep -c . || true)
expect_eq "each story maps to its own change id" "3" "${ids:-0}"
expect_absent "no story from another epic leaks" "US-2.1" scripts/delivery.sh resolve EPIC-1
expect_contains "lowercase epic id resolves"    "US-1.3" scripts/delivery.sh resolve epic-1
expect_contains "Change: line is the change id" "us-4-2-x" scripts/delivery.sh resolve EPIC-4
expect_contains "archive date prefix is stripped" '"change": "us-4-1-x"' scripts/delivery.sh resolve EPIC-4 --json
expect_eq "resolve --json, exactly" \
  '{ "target": "EPIC-4", "kind": "epic", "focus": "-", "stories": [ { "story": "US-4.1", "status": "DONE", "change": "us-4-1-x" }, { "story": "US-4.2", "status": "IN PROGRESS", "change": "us-4-2-x" } ] }' \
  "$(scripts/delivery.sh resolve EPIC-4 --json)"
expect_eq "a derived change id is us-n-m-<title slug>" "us-3-2-not-yet-delivered" \
  "$(scripts/delivery.sh resolve US-3.2 --json | jq -r '.stories[0].change')"

# ---------------------------------------------------------------------------
# Scenario: Resolve a task to its parent story
# ---------------------------------------------------------------------------

section "Resolve a task to its parent story"

expect_contains "US-N.M#k resolves to the parent story" "US-1.1" scripts/delivery.sh resolve 'US-1.1#2'
expect_contains "US-N.M#k kind is task"         "Kind:   task" scripts/delivery.sh resolve 'US-1.1#2'
expect_contains "task text resolves to the parent" "US-1.1" scripts/delivery.sh resolve 'widget parser'
check "out-of-range task index is refused"      1 scripts/delivery.sh resolve 'US-1.1#9'
check "ambiguous task text is refused"          1 scripts/delivery.sh resolve 'Shared step'
expect_contains "ambiguity lists the candidates" "US-1.3#1" scripts/delivery.sh resolve 'Shared step'

GOALF=openspec/delivery/goal.md
START_OUT=$(scripts/delivery.sh start 'US-1.1#2' 2>&1)
PROPOSE_11="/ohmyorch:opsx-propose us-1-1-first-story for US-1.1; then set US-1.1 to IN PROGRESS with a Change: line in SPECS.md"
expect_eq "start reports the goal and its first action" \
"GOAL  US-1.1#2 (task) — ACTIVE
Action:  propose
Story:   US-1.1
Change:  us-1-1-first-story
Command: $PROPOSE_11
Reason:  US-1.1 is READY and has no OpenSpec change" "$START_OUT"
expect_contains "goal records the task as Focus" "| Focus | Wire the widget renderer. |" cat "$GOALF"
expect_contains "goal records kind task"        "| Kind | task |" cat "$GOALF"
expect_contains "goal delivers the parent story" "| 1 | US-1.1 |" cat "$GOALF"
expect_contains "goal is ACTIVE"                "| Status | ACTIVE |" cat "$GOALF"

# The whole record, byte for byte: the layout is a contract for human readers
# and for the lease code that reads the Target row.
cat > "$WORK/goal.want" <<EOF
# Delivery Goal

Written by \`ohmyorch delivery\`. The field table, Stories, and Next Action are
**derived** from SPECS.md and the OpenSpec change artifacts: refresh them with
\`ohmyorch delivery refresh\`, never hand-edit. Notes between the AUTHORED
markers are preserved across refreshes.

| Field | Value |
|---|---|
| Target | US-1.1#2 |
| Kind | task |
| Focus | Wire the widget renderer. |
| Status | ACTIVE |
| Reason | - |
| Started | $TODAY |
| Updated | $TODAY |

## Stories

| # | Story | Change | SPECS status | Title |
|---|---|---|---|---|
| 1 | US-1.1 | us-1-1-first-story | READY | First story |

## Next Action

Action: propose
Story: US-1.1
Change: us-1-1-first-story
Command: $PROPOSE_11
Reason: US-1.1 is READY and has no OpenSpec change

This is the last computed action, for reading only. \`ohmyorch delivery next\`
recomputes it from the repository on every call.

## Notes

<!-- BEGIN AUTHORED: notes -->
None.
<!-- END AUTHORED: notes -->
EOF
check "goal.md matches the documented layout exactly" 0 cmp -s "$WORK/goal.want" "$GOALF"
expect_absent "goal.md has no Owner line"       "Owner" cat "$GOALF"
expect_absent "goal.md names no owner anywhere" "owner" cat "$GOALF"

# Notes between the AUTHORED markers are the only hand-written part.
sed 's/^None\.$/Human note: waiting on the design review./' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
expect_eq "refresh reports what it wrote" \
  "Wrote openspec/delivery/goal.md (Status ACTIVE, next action propose)" "$(scripts/delivery.sh refresh 2>&1)"
expect_contains "refresh preserves authored notes" "Human note: waiting on the design review." cat "$GOALF"
scripts/delivery.sh stop >/dev/null 2>&1
expect_contains "stop records STOPPED"          "| Status | STOPPED |" cat "$GOALF"
expect_contains "stop keeps authored notes"     "Human note: waiting on the design review." cat "$GOALF"

# ---------------------------------------------------------------------------
# Scenario: Reject an unknown target
# ---------------------------------------------------------------------------

section "Reject an unknown target, command or option"

check "unknown epic is refused"                 1 scripts/delivery.sh resolve EPIC-99
expect_contains "refusal names the epic"        "EPIC-99" scripts/delivery.sh resolve EPIC-99
check "unknown story is refused"                1 scripts/delivery.sh resolve US-9.9
expect_contains "refusal names the story"       "US-9.9" scripts/delivery.sh resolve US-9.9
check "unknown task text is refused"            1 scripts/delivery.sh resolve 'no such task anywhere'
check "missing target is a usage error"         2 scripts/delivery.sh resolve
check "unknown command is a usage error"        2 scripts/delivery.sh frobnicate
check "no command is a usage error"             2 scripts/delivery.sh

# The remediation round is gone: a finding is a new unticked task, not a command.
check "reopen is an unknown command"            2 scripts/delivery.sh reopen
expect_contains "reopen is reported as unknown" "unknown command 'reopen'" scripts/delivery.sh reopen
check "--change is an unknown option"           2 scripts/delivery.sh next --change us-4-2-x
expect_contains "--change is reported as unknown" "unknown option '--change'" scripts/delivery.sh next --change us-4-2-x
check "reopen --change is refused too"          2 scripts/delivery.sh reopen --change us-4-2-x
for a in propose apply verify mark-done escalate complete; do
  expect_contains "usage lists the $a action"   "$a" sh -c "scripts/delivery.sh help | grep '^Actions:'"
done
expect_eq "usage lists exactly the six actions" "Actions:  propose apply verify mark-done escalate complete" \
  "$(scripts/delivery.sh help | grep '^Actions:')"
expect_absent "usage no longer offers reopen"   "reopen" scripts/delivery.sh help
expect_absent "usage names no owner"            "wner" scripts/delivery.sh help

rm -rf openspec/delivery
check "start with an unknown target fails"      1 scripts/delivery.sh start US-9.9
check "no goal recorded for an unknown target"  1 test -e "$GOALF"
check "next without a goal or target is refused" 1 scripts/delivery.sh next
check "refresh without a goal is refused"       1 scripts/delivery.sh refresh

scripts/delivery.sh start EPIC-1 >/dev/null 2>&1
cp "$GOALF" "$WORK/goal.before"
scripts/delivery.sh start EPIC-99 >/dev/null 2>&1
check "a rejected start leaves the goal untouched" 0 cmp -s "$WORK/goal.before" "$GOALF"
check "a different target needs stop first"     1 scripts/delivery.sh start EPIC-3
expect_contains "the refusal names the active goal" "a different goal is ACTIVE (EPIC-1)" scripts/delivery.sh start EPIC-3
expect_contains "an epic goal lists every story" "| 3 | US-1.3 |" cat "$GOALF"

# ---------------------------------------------------------------------------
# Decision table rows 1-3: nothing left, not ready, unfinished dependency
# ---------------------------------------------------------------------------

section "Decision table — complete and escalate (rows 1-3)"

before=$(changes_snapshot)

expect_action "row 1: a DONE story is complete" US-4.1 complete - - \
  "none — every story in the goal is DONE" "all 1 story/stories are DONE"

expect_action "row 2: NEEDS CLARIFICATION escalates" EPIC-2 escalate US-2.1 us-2-1-undecided-story \
  "resolve US-2.1 in SPECS.md (a product decision is required)" "US-2.1 is NEEDS CLARIFICATION, not READY"
expect_action "row 2: BLOCKED escalates" US-3.7 escalate US-3.7 us-3-7-blocked-human \
  "resolve US-3.7 in SPECS.md (a product decision is required)" "US-3.7 is BLOCKED, not READY"
# Readiness is checked before the archived branch: an on-hold story is never
# steered to its DONE edit.
expect_action "row 2 before row 4: on hold with an archived change" US-3.4 escalate US-3.4 us-3-4-x \
  "resolve US-3.4 in SPECS.md (a product decision is required)" "US-3.4 is NEEDS CLARIFICATION, not READY"

expect_action "row 3: unfinished dependency escalates" US-3.1 escalate US-3.1 us-3-1-depends-unfinished-story \
  "deliver or re-scope the dependency first" "US-3.1 depends on unfinished US-3.2 (READY)"
expect_action "row 3: inline Dependencies: line" US-3.3 escalate US-3.3 us-3-3-inline-dependency \
  "deliver or re-scope the dependency first" "US-3.3 depends on unfinished US-3.2 (READY)"
expect_action "row 3: unfinished and unknown dependencies" US-3.6 escalate US-3.6 us-3-6-several-dependencies \
  "deliver or re-scope the dependency first" "US-3.6 depends on unfinished US-3.2 (READY), US-9.9 (not in SPECS.md)"
expect_action "row 3 before row 4: archived change, unfinished dependency" US-3.5 escalate US-3.5 us-3-5-x \
  "deliver or re-scope the dependency first" "US-3.5 depends on unfinished US-3.2 (READY)"
expect_action "an epic stops at its first unfinished story" EPIC-3 escalate US-3.1 us-3-1-depends-unfinished-story \
  "deliver or re-scope the dependency first" "US-3.1 depends on unfinished US-3.2 (READY)"

expect_eq "no change created by escalation"     "$before" "$(changes_snapshot)"

# A SPECS.md saved with CRLF line endings reads exactly like the LF file: no
# status, change id, title or dependency carries the carriage return along.
LF_READY=$(scripts/delivery.sh next US-1.1 --json 2>&1)
LF_DONE=$(scripts/delivery.sh next US-4.1 --json 2>&1)
LF_DEPENDENT=$(scripts/delivery.sh next US-3.6 --json 2>&1)
LF_EPIC=$(scripts/delivery.sh resolve EPIC-4 --json 2>&1)
LF_TASK=$(scripts/delivery.sh resolve 'US-1.1#2' 2>&1)
awk '{ printf "%s\r\n", $0 }' "$WORK/specs.orig" > SPECS.md
check "the staged SPECS.md has CRLF line endings" 0 grep -q "$(printf '^Status: READY\r$')" SPECS.md
expect_eq "CRLF: a READY story is still proposed" "propose" "$(action_of US-1.1)"
expect_eq "CRLF: a READY story derives the LF action" "$LF_READY" "$(scripts/delivery.sh next US-1.1 --json 2>&1)"
expect_eq "CRLF: a DONE story is still complete" "$LF_DONE" "$(scripts/delivery.sh next US-4.1 --json 2>&1)"
expect_eq "CRLF: dependencies read the same"    "$LF_DEPENDENT" "$(scripts/delivery.sh next US-3.6 --json 2>&1)"
expect_eq "CRLF: an epic resolves the same"     "$LF_EPIC" "$(scripts/delivery.sh resolve EPIC-4 --json 2>&1)"
expect_eq "CRLF: a task resolves the same"      "$LF_TASK" "$(scripts/delivery.sh resolve 'US-1.1#2' 2>&1)"
expect_eq "CRLF: no carriage return reaches the output" "0" \
  "$({ scripts/delivery.sh resolve EPIC-1; scripts/delivery.sh next US-3.4; } 2>&1 | tr -cd '\r' | wc -c | tr -d ' ')"
cp "$WORK/specs.orig" SPECS.md

# ---------------------------------------------------------------------------
# Decision table rows 5-6: no change directory yet
# ---------------------------------------------------------------------------

section "Decision table — propose a new change (rows 5-6)"

expect_action "row 6: a READY story with no change" US-3.2 propose US-3.2 us-3-2-not-yet-delivered \
  "/ohmyorch:opsx-propose us-3-2-not-yet-delivered for US-3.2; then set US-3.2 to IN PROGRESS with a Change: line in SPECS.md" \
  "US-3.2 is READY and has no OpenSpec change"
expect_action "row 6: a satisfied dependency does not block" US-3.8 propose US-3.8 us-3-8-satisfied-dependency \
  "/ohmyorch:opsx-propose us-3-8-satisfied-dependency for US-3.8; then set US-3.8 to IN PROGRESS with a Change: line in SPECS.md" \
  "US-3.8 is READY and has no OpenSpec change"
expect_action "row 6: IN PROGRESS with a Change: line but no directory" US-4.2 propose US-4.2 us-4-2-x \
  "/ohmyorch:opsx-propose us-4-2-x for US-4.2; then set US-4.2 to IN PROGRESS with a Change: line in SPECS.md" \
  "US-4.2 is IN PROGRESS and has no OpenSpec change"
expect_action "row 6: an epic proposes its first undelivered story" EPIC-4 propose US-4.2 us-4-2-x \
  "/ohmyorch:opsx-propose us-4-2-x for US-4.2; then set US-4.2 to IN PROGRESS with a Change: line in SPECS.md" \
  "US-4.2 is IN PROGRESS and has no OpenSpec change"
expect_eq "propose does not create the change"  "$before" "$(changes_snapshot)"

# One active change at a time: another active change blocks a new proposal.
mkdir -p openspec/changes/other-change
expect_action "row 5: another change is active" US-3.2 escalate US-3.2 us-3-2-not-yet-delivered \
  "finish or archive the active change first" "another change is active: other-change (one active change at a time)"
mkdir -p openspec/changes/zz-second
expect_eq "row 5: with several, still escalate"  "escalate" "$(action_of US-3.2)"
expect_contains "row 5: the reason names the first" "other-change" scripts/delivery.sh next US-3.2
expect_contains "row 5: the reason names the second" "zz-second" scripts/delivery.sh next US-3.2
expect_contains "row 5: the reason states the rule" "(one active change at a time)" scripts/delivery.sh next US-3.2
rmdir openspec/changes/zz-second openspec/changes/other-change
expect_eq "archived changes are not active ones" "propose" "$(action_of US-3.2)"

# ---------------------------------------------------------------------------
# Decision table row 7: the change exists, planning artifacts are incomplete
# ---------------------------------------------------------------------------

section "Decision table — planning incomplete (row 7)"

C=openspec/changes/us-4-2-x
CONTINUE_42="/ohmyorch:opsx-propose us-4-2-x for US-4.2 $PROPOSE_CONTINUE"
# planning <label> <reason> — row 7 for the current contents of the change directory.
planning() { expect_action "row 7: $1" US-4.2 propose US-4.2 us-4-2-x "$CONTINUE_42" "planning incomplete: $2"; }
reset_change() { rm -rf "$C"; mkdir -p "$C"; }
put_proposal() { printf '# Proposal\n\nStory: US-4.2\n' > "$C/proposal.md"; }
put_specs()    { mkdir -p "$C/specs/cap"; printf '# Spec\n' > "$C/specs/cap/spec.md"; }
put_tasks()    { printf -- '- [ ] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"; }

reset_change
planning "an empty change directory"       "missing proposal.md, specs/, tasks.md"
reset_change; put_proposal
planning "proposal only"                   "missing specs/, tasks.md"
reset_change; put_specs
planning "delta specs only"                "missing proposal.md, tasks.md"
reset_change; put_tasks
planning "tasks only"                      "missing proposal.md, specs/"
reset_change; put_proposal; put_tasks
planning "no delta specs"                  "missing specs/"
reset_change; put_proposal; put_specs
planning "no tasks.md"                     "missing tasks.md"
reset_change; put_specs; put_tasks
planning "no proposal.md"                  "missing proposal.md"

# specs/ needs at least one `.md` file, at any depth, as upstream's artifact
# glob specs/**/*.md: a placeholder or a note is not a delta spec.
reset_change; put_proposal; put_tasks; mkdir -p "$C/specs/cap/nested"
planning "specs/ holds directories but no file" "missing specs/"
: > "$C/specs/.gitkeep"
planning "specs/ holds only a placeholder" "missing specs/"
printf 'Notes for the spec.\n' > "$C/specs/cap/notes.txt"
planning "specs/ holds no .md file"        "missing specs/"
printf '# Spec\n' > "$C/specs/cap/nested/spec.md"
expect_eq "a nested delta spec file satisfies specs/" "apply" "$(action_of US-4.2)"

# `skip_specs: true` in the change's .openspec.yaml waives specs/, read as
# OpenSpec reads the YAML: true, True or TRUE, with an optional trailing comment.
reset_change; put_proposal; put_tasks
printf 'schema: spec-driven\nskip_specs: true\n' > "$C/.openspec.yaml"
expect_eq "skip_specs: true waives specs/"       "apply" "$(action_of US-4.2)"
printf 'schema: spec-driven\nskip_specs:   true  \n' > "$C/.openspec.yaml"
expect_eq "skip_specs tolerates surrounding spaces" "apply" "$(action_of US-4.2)"
printf 'schema: spec-driven\nskip_specs: true # decided in review\n' > "$C/.openspec.yaml"
expect_action "row 7: skip_specs tolerates a trailing YAML comment" US-4.2 apply US-4.2 us-4-2-x \
  "/ohmyorch:opsx-apply us-4-2-x" "0/2 tasks complete"
printf 'schema: spec-driven\nskip_specs: True\n' > "$C/.openspec.yaml"
expect_eq "skip_specs: True is a YAML boolean"   "apply" "$(action_of US-4.2)"
printf 'schema: spec-driven\nskip_specs: TRUE\t# shouted\n' > "$C/.openspec.yaml"
expect_eq "skip_specs: TRUE is a YAML boolean"   "apply" "$(action_of US-4.2)"
printf 'schema: spec-driven\nskip_specs: true#not-a-comment\n' > "$C/.openspec.yaml"
planning "skip_specs with trailing text does not count" "missing specs/"
printf 'schema: spec-driven\nskip_specs: tRuE\n' > "$C/.openspec.yaml"
planning "skip_specs in another spelling does not count" "missing specs/"
printf 'schema: spec-driven\nskip_specs: false\n' > "$C/.openspec.yaml"
planning "skip_specs: false"               "missing specs/"
printf 'schema: spec-driven\nmetadata:\n  skip_specs: true\n' > "$C/.openspec.yaml"
planning "an indented skip_specs key"      "missing specs/"
printf 'schema: spec-driven\nskip_specs: true\n' > "$C/.openspec.yaml"; rm -f "$C/tasks.md"
planning "skip_specs still needs tasks.md" "missing tasks.md"

# tasks.md must hold at least one checkbox.
reset_change; put_proposal; put_specs
printf '# Tasks\n\nTo be written.\n' > "$C/tasks.md"
planning "tasks.md without a checkbox"     "tasks.md has no task checkboxes"
: > "$C/tasks.md"
planning "an empty tasks.md"               "tasks.md has no task checkboxes"
printf -- '# Tasks\n\n- [The plan](./plan.md)\n- [x](./done.md) a link bullet\n' > "$C/tasks.md"
planning "tasks.md with link bullets only" "tasks.md has no task checkboxes"
# A checklist is a checklist whatever its list marker: OpenSpec counts these, so
# the planning is complete and the change is applied, not proposed again.
printf -- '* [ ] 1.1 build\n* [ ] 1.2 test\n' > "$C/tasks.md"
expect_action "row 8, not row 7: a checklist without a dash" US-4.2 apply US-4.2 us-4-2-x \
  "/ohmyorch:opsx-apply us-4-2-x" "0/2 tasks complete"
printf -- '1. [x] build\n2. [ ] test\n3) [ ] document\n' > "$C/tasks.md"
expect_eq "a numbered checklist is counted"     "1/3 tasks complete" "$(reason_of US-4.2)"

# design.md is conditional upstream: never required, harmless when present.
put_tasks
check "the change has no design.md"             1 test -e "$C/design.md"
expect_eq "design.md is never required"         "apply" "$(action_of US-4.2)"
printf '# Design\n' > "$C/design.md"
expect_eq "design.md does not change the action" "apply" "$(action_of US-4.2)"

# ---------------------------------------------------------------------------
# Decision table rows 8-9: apply, then verify
# ---------------------------------------------------------------------------

section "Decision table — apply and verify (rows 8-9)"

VERIFY_42="/ohmyorch:opsx-verify us-4-2-x; with no CRITICAL issue, run a separate Bash call: openspec archive us-4-2-x -y"

expect_action "row 8: nothing ticked" US-4.2 apply US-4.2 us-4-2-x "/ohmyorch:opsx-apply us-4-2-x" "0/2 tasks complete"
printf -- '- [x] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"
expect_action "row 8: one task left" US-4.2 apply US-4.2 us-4-2-x "/ohmyorch:opsx-apply us-4-2-x" "1/2 tasks complete"
printf -- '## 1. Build\n\n- [x] 1.1 build\n  - [X] nested, upper-case\n-[x] tight\n- [ ] 1.2 test\n' > "$C/tasks.md"
expect_eq "nested, tight and upper-case boxes are counted" "3/4 tasks complete" "$(reason_of US-4.2)"
# Any box that does not hold x or X is an unfinished task, as OpenSpec reads it:
# the change stays in apply and never reaches the archive command.
for marker in '- [~]' '- [-]' '- []' '* [ ]' '1. [ ]'; do
  printf -- '- [x] 1.1 build\n%s 1.2 test\n' "$marker" > "$C/tasks.md"
  expect_action "row 8: '$marker' is an unfinished task" US-4.2 apply US-4.2 us-4-2-x "/ohmyorch:opsx-apply us-4-2-x" "1/2 tasks complete"
done
printf -- '* [x] 1.1 build\n+ [X] 1.2 test\n1. [ x ] 1.3 document\n' > "$C/tasks.md"
expect_eq "row 9: every marker ticked is verified" "3/3 tasks complete; verify, then archive" "$(reason_of US-4.2)"

printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"
expect_action "row 9: every task ticked" US-4.2 verify US-4.2 us-4-2-x "$VERIFY_42" "2/2 tasks complete; verify, then archive"
expect_action "row 9: through the epic" EPIC-4 verify US-4.2 us-4-2-x "$VERIFY_42" "2/2 tasks complete; verify, then archive"

# Verify writes no file. A CRITICAL finding is an appended unticked task, which
# makes row 8 true again; ticking it returns to verify.
printf -- '- [ ] 2.1 fix the CRITICAL finding from verify\n' >> "$C/tasks.md"
expect_action "a CRITICAL finding returns to apply" US-4.2 apply US-4.2 us-4-2-x "/ohmyorch:opsx-apply us-4-2-x" "2/3 tasks complete"
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n- [x] 2.1 fix the CRITICAL finding from verify\n' > "$C/tasks.md"
expect_action "the fixed finding returns to verify" US-4.2 verify US-4.2 us-4-2-x "$VERIFY_42" "3/3 tasks complete; verify, then archive"

# Row 5 is only about a change that does not exist yet: beside its own existing
# change a story keeps reporting that change's progress.
mkdir -p openspec/changes/other-change
expect_eq "another active change does not hide this one" "verify" "$(action_of US-4.2)"
rmdir openspec/changes/other-change

# ---------------------------------------------------------------------------
# Output shape
# ---------------------------------------------------------------------------

section "Output shape"

J=$(scripts/delivery.sh next US-4.2 --json 2>/dev/null)
expect_eq "next --json is one line"             "1" "$(printf '%s\n' "$J" | wc -l | tr -d ' ')"
expect_eq "the JSON keys, in order"             "target,action,story,change,command,reason" "$(printf '%s' "$J" | jq -r 'keys_unsorted | join(",")')"
expect_eq "the JSON has no owner key"           "false" "$(printf '%s' "$J" | jq -r 'has("owner")')"
expect_eq "every JSON value is a string"        "true" "$(printf '%s' "$J" | jq -r '[.[] | type == "string"] | all')"
expect_eq "next prints nothing on stderr"       "" "$(scripts/delivery.sh next US-4.2 --json 2>&1 >/dev/null)"
T=$(scripts/delivery.sh next US-4.2 2>/dev/null)
expect_eq "text output is exactly five lines"   "5" "$(printf '%s\n' "$T" | wc -l | tr -d ' ')"
expect_eq "the five labels, in order"           "Action: Story: Change: Command: Reason: " "$(printf '%s\n' "$T" | awk '{ printf "%s ", $1 }')"
expect_absent "text output has no Owner line"   "wner" scripts/delivery.sh next US-4.2
expect_eq "the derivation is deterministic"     "$J" "$(scripts/delivery.sh next US-4.2 --json 2>/dev/null)"

# The derivation is self-contained: with every other script removed it answers the same.
ALONE="$WORK/alone-plugin"
mkdir -p "$ALONE/scripts"
cp -R "$OHMYORCH_TEST_PLUGIN_ROOT/lib" "$ALONE/lib"
cp "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/delivery.sh" "$ALONE/scripts/"
alone_delivery() { OHMYORCH_PROJECT_ROOT="$(pwd -P)" OHMYORCH_SESSION_ID=regression /bin/bash "$ALONE/scripts/delivery.sh" "$@"; }
expect_eq "delivery.sh alone derives the same action" "$J" "$(alone_delivery next US-4.2 --json 2>&1)"
expect_eq "delivery.sh alone escalates the same way" "$(scripts/delivery.sh next US-3.6 --json 2>&1)" "$(alone_delivery next US-3.6 --json 2>&1)"

# The command the verify row hands the agent is for a human-visible, separate call.
expect_contains "verify asks for a separate Bash call" "separate Bash call" printf '%s' "$J"
expect_absent "verify does not chain commands"  "&&" printf '%s' "$J"

# ---------------------------------------------------------------------------
# Leftover files of an earlier plugin version
# ---------------------------------------------------------------------------

section "Leftover per-change files are ignored and survive"

# Consumer projects may still hold these in active or archived changes. They are
# project history: never read, never required, never rewritten or deleted.
mkdir -p "$C/history"
printf '# Review\n\nVerdict: fail\n\nBlocking:\n- F-1: evidence rule is unenforceable\n\nOpenSpec verify: MISMATCH — 4 blocking mismatches found\n' > "$C/review.md"
printf '# Test Report\n\nVerdict: fail\n\nCoverage: 1/3 acceptance criteria evaluated\n\n| 1 | criterion | FAIL |\n' > "$C/test-report.md"
printf '# Status\n\n| State | REVIEWING |\n\nFirst incomplete gate: review\n' > "$C/status.md"
printf '# Completion\n\n| Verdict | not-eligible |\n' > "$C/completion.md"
printf '# Implementation Plan\n\n## Predicted files\n\n- src/app.ts\n' > "$C/implementation-plan.md"
printf '# Review round 1\n\nVerdict: fail\n' > "$C/history/review-r1.md"
printf '# Test report round 1\n\nVerdict: fail\n' > "$C/history/test-report-r1.md"
LEFT_BEFORE=$(left_sum "$C")
expect_eq "the staged leftovers are seven files" "7" "$(find "$C/review.md" "$C/test-report.md" "$C/status.md" "$C/completion.md" "$C/implementation-plan.md" "$C/history" -type f | wc -l | tr -d ' ')"

expect_action "failing leftover verdicts do not change verify" US-4.2 verify US-4.2 us-4-2-x "$VERIFY_42" "3/3 tasks complete; verify, then archive"
printf -- '- [ ] 3.1 one more\n' >> "$C/tasks.md"
expect_eq "leftovers do not change apply either" "3/4 tasks complete" "$(reason_of US-4.2)"
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n- [x] 2.1 fix the CRITICAL finding from verify\n' > "$C/tasks.md"
rm -f "$C/proposal.md"
planning "leftovers never stand in for a planning artifact" "missing proposal.md"
put_proposal
expect_eq "leftover files are byte-identical after derivation" "$LEFT_BEFORE" "$(left_sum "$C")"

# ---------------------------------------------------------------------------
# Derivation is read-only and never reads goal.md back
# ---------------------------------------------------------------------------

section "Derivation reads the repository, writes nothing"

scripts/delivery.sh stop >/dev/null 2>&1
scripts/delivery.sh start EPIC-4 >/dev/null 2>&1
ALL_BEFORE=$(tree_sum SPECS.md openspec)
scripts/delivery.sh next >/dev/null 2>&1
scripts/delivery.sh next --json >/dev/null 2>&1
scripts/delivery.sh next US-3.2 >/dev/null 2>&1
scripts/delivery.sh resolve EPIC-1 --json >/dev/null 2>&1
expect_eq "next and resolve write nothing"      "$ALL_BEFORE" "$(tree_sum SPECS.md openspec)"

expect_eq "next without a target uses the goal" "verify" "$(action_of)"
expect_eq "the goal's target is in the JSON"    "EPIC-4" "$(scripts/delivery.sh next --json | jq -r .target)"

sed 's/^Action: .*/Action: complete/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
printf -- '- [x] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"
expect_eq "a hand-edited goal.md does not steer next" "apply" "$(action_of)"

# refresh: one derivation rewrites goal.md and, with --json, reports it.
expect_eq "refresh reports status and action" \
  "Wrote openspec/delivery/goal.md (Status ACTIVE, next action apply)" "$(scripts/delivery.sh refresh 2>&1)"
expect_contains "refresh rewrites the Next Action"  "Action: apply" cat "$GOALF"
expect_contains "refresh rewrites the reason"       "Reason: 1/2 tasks complete" cat "$GOALF"
expect_absent "the refreshed goal has no Owner line" "Owner" cat "$GOALF"
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"
RJ=$(scripts/delivery.sh refresh --json 2>&1)
expect_eq "refresh --json prints the next --json line" "$(scripts/delivery.sh next --json 2>/dev/null)" "$RJ"
expect_eq "refresh --json, exactly" \
  "{ \"target\": \"EPIC-4\", \"action\": \"verify\", \"story\": \"US-4.2\", \"change\": \"us-4-2-x\", \"command\": \"$VERIFY_42\", \"reason\": \"2/2 tasks complete; verify, then archive\" }" "$RJ"
expect_absent "refresh --json prints no prose"  "Wrote" printf '%s' "$RJ"
expect_contains "refresh --json still rewrites goal.md" "Action: verify" cat "$GOALF"
expect_contains "the stories table follows SPECS" "| 2 | US-4.2 | us-4-2-x | IN PROGRESS | Story with an active change |" cat "$GOALF"
expect_eq "refresh leaves the leftover files alone" "$LEFT_BEFORE" "$(left_sum "$C")"
expect_eq "refresh adds nothing to the change directory" \
  "completion.md design.md history implementation-plan.md proposal.md review.md specs status.md tasks.md test-report.md " \
  "$(ls -A "$C" | sort | tr '\n' ' ')"

# ---------------------------------------------------------------------------
# Decision table row 4, then row 1: archived, then DONE
# ---------------------------------------------------------------------------

section "Decision table — mark-done and complete (rows 4 and 1)"

check "delivery never rewrote SPECS.md"         0 cmp -s SPECS.md "$WORK/specs.orig"
# `openspec archive` moves the change under archive/ with a date prefix.
mv "$C" openspec/changes/archive/2026-09-24-us-4-2-x
expect_action "row 4: archived but not DONE" US-4.2 mark-done US-4.2 us-4-2-x \
  "set 'Status: DONE' for US-4.2 in SPECS.md and point its Change: line at the archived change" \
  "change us-4-2-x is archived but US-4.2 is IN PROGRESS"
expect_eq "leftovers in an archived change are left alone" "$LEFT_BEFORE" "$(left_sum openspec/changes/archive/2026-09-24-us-4-2-x)"
# An active directory with the same id wins over the archive: the change was
# proposed again, so its own artifacts decide, never the DONE edit.
mkdir -p "$C"
expect_action "row 7, not row 4: the id is active again" US-4.2 propose US-4.2 us-4-2-x "$CONTINUE_42" \
  "planning incomplete: missing proposal.md, specs/, tasks.md"
put_proposal; put_specs; printf -- '- [x] 1.1 rebuild\n- [ ] 1.2 retest\n' > "$C/tasks.md"
expect_action "row 8, not row 4: the active change is applied" US-4.2 apply US-4.2 us-4-2-x \
  "/ohmyorch:opsx-apply us-4-2-x" "1/2 tasks complete"
printf -- '- [x] 1.1 rebuild\n- [x] 1.2 retest\n' > "$C/tasks.md"
expect_eq "row 9, not row 4: then verified"     "verify" "$(action_of US-4.2)"
rm -rf "$C"
expect_eq "with only the archive left it is mark-done again" "mark-done" "$(action_of US-4.2)"
sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md > "$WORK/s" && cp "$WORK/s" SPECS.md
expect_action "row 1: every story of the epic is DONE" EPIC-4 complete - - \
  "none — every story in the goal is DONE" "all 2 story/stories are DONE"
scripts/delivery.sh refresh >/dev/null 2>&1
expect_contains "a complete goal records COMPLETE" "| Status | COMPLETE |" cat "$GOALF"
expect_contains "a complete goal records the action" "Action: complete" cat "$GOALF"
cp "$WORK/specs.orig" SPECS.md

# Nothing the loop is told to run goes through the plugin CLI.
expect_absent "no derived command calls the plugin CLI" "bin/ohmyorch" cat "$SEEN"
expect_absent "no derived command passes a project root" "--project-root" cat "$SEEN"
expect_absent "no derived command names a retired operation" "completion-gate" cat "$SEEN"
expect_eq "all six actions were derived" "apply complete escalate mark-done propose verify " \
  "$(jq -r .action "$SEEN" | sort -u | tr '\n' ' ')"
expect_eq "nothing but the six actions was derived" "0" \
  "$(jq -r .action "$SEEN" | grep -cvxE 'propose|apply|verify|mark-done|escalate|complete' || true)"

# ---------------------------------------------------------------------------
# The delivery goal loop (scripts/guard-delivery-loop.sh)
# ---------------------------------------------------------------------------

LOOPF=.claude/ohmyorch/runtime/regression/loop.state
MAXS=100

# Realistic payloads: several keys, and the value of interest is not the last one.
stop_hook() { # stop_hook [stop_hook_active]
  printf '{"session_id":"s1","transcript_path":"/tmp/t.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":%s,"last_assistant_message":"Done for now.","background_tasks":[],"session_crons":[]}' \
    "$PWD" "${1:-false}" | scripts/guard-delivery-loop.sh --hook --quiet --max-stalls "$MAXS"
}
stop_err() { stop_hook "$@" 2>&1 >/dev/null; }
stop_out() { stop_hook "$@" 2>/dev/null; }
stop_sub() {
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop","agent_id":"a1","agent_type":"general-purpose","stop_hook_active":false}' \
    "$PWD" | scripts/guard-delivery-loop.sh --hook --quiet
}
stop_mention() { # the last message mentions agent_id, JSON-escaped: still the main session
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"subagents carry \\"agent_id\\": 1"}' \
    "$PWD" | scripts/guard-delivery-loop.sh --hook --quiet --max-stalls "$MAXS"
}
stop_nested() { # the event name sits only inside tool_input: this is not a Stop payload
  printf '{"session_id":"s1","cwd":"%s","tool_name":"Write","tool_input":{"hook_event_name":"Stop","file_path":"notes.md"}}' \
    "$PWD" | scripts/guard-delivery-loop.sh --hook --quiet --max-stalls "$MAXS"
}
write_hook() { # write_hook <repo-relative path> [agent_type]
  ag=""; [ -n "${2:-}" ] && ag="\"agent_id\":\"a1\",\"agent_type\":\"$2\","
  printf '{"session_id":"s1","cwd":"%s",%s"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/%s","content":"# Review"},"tool_use_id":"t1"}' \
    "$PWD" "$ag" "$PWD" "$1" | scripts/guard-delivery-loop.sh --hook --quiet
}
bash_hook() { # bash_hook <command> <guard>
  printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"Archive the change","timeout":120000},"tool_use_id":"t2"}' \
    "$1" | "scripts/$2" --hook --quiet
}
# message_of <hook stdout> — the systemMessage of an allow that changed goal state.
message_of() { printf '%s' "$1" | jq -r 'if (keys == ["systemMessage"]) then .systemMessage else "unexpected keys" end'; }

# ---------------------------------------------------------------------------
# Scenario: Start a delivery goal
# ---------------------------------------------------------------------------

section "Start a delivery goal"

rm -rf openspec/delivery openspec/changes/archive/2026-09-24-us-4-2-x
PROPOSE_32="/ohmyorch:opsx-propose us-3-2-not-yet-delivered for US-3.2; then set US-3.2 to IN PROGRESS with a Change: line in SPECS.md"
check "start a READY story records a goal"      0 scripts/delivery.sh start US-3.2
expect_contains "goal records the target"       "| Target | US-3.2 |" cat "$GOALF"
expect_contains "goal records kind story"       "| Kind | story |" cat "$GOALF"
expect_contains "goal records its stories"      "| 1 | US-3.2 |" cat "$GOALF"
expect_contains "goal status is ACTIVE"         "| Status | ACTIVE |" cat "$GOALF"
expect_contains "goal records the next action"  "Action: propose" cat "$GOALF"
expect_contains "goal records the command"      "Command: $PROPOSE_32" cat "$GOALF"

# The verdict-write guard is gone with the verdict files: the loop guard acts on
# Stop only, and every other event passes through untouched.
check "a review.md write is no longer the loop guard's" 0 write_hook openspec/changes/us-3-2-x/review.md
check "nor is a test-report.md write"           0 write_hook openspec/changes/us-3-2-x/test-report.md
check "nor a subagent's write"                  0 write_hook openspec/changes/us-3-2-x/tasks.md general-purpose
check "a SPECS.md write passes the loop guard"  0 write_hook SPECS.md
expect_eq "a write event prints nothing"        "" "$(write_hook openspec/changes/us-3-2-x/review.md 2>&1)"
check "a write event leaves no stall counter"   1 test -e "$LOOPF"

# ---------------------------------------------------------------------------
# Scenario: Continue while work remains
# ---------------------------------------------------------------------------

section "Continue while work remains"

rm -f "$LOOPF"
check "Stop is blocked while work remains"      2 stop_hook
expect_eq "the block message, exactly" \
"Delivery goal US-3.2 is ACTIVE — do not stop yet.
Next action: propose  (story: US-3.2, change: us-3-2-not-yet-delivered)
Command: $PROPOSE_32
Reason: US-3.2 is READY and has no OpenSpec change
Do it in this session, then run ohmyorch delivery next again. Unchanged stop attempts: 2 of 100 allowed." "$(stop_err)"
expect_eq "a block prints nothing on stdout"    "" "$(stop_out)"
expect_absent "the block names no owner"        "wner" stop_hook
expect_absent "the block delegates to no role"  "Delegate" stop_hook
check "stop_hook_active does not bypass the loop" 2 stop_hook true
check "a subagent's Stop is never blocked"      0 stop_sub
# Identity and event are top-level protocol fields, never text found elsewhere.
check "an agent_id mention in the message is not a subagent" 2 stop_mention
check "an event name inside tool_input is not the event" 0 stop_nested
expect_eq "such a payload prints nothing"       "" "$(stop_nested 2>&1)"
expect_contains "goal stays ACTIVE"             "| Status | ACTIVE |" cat "$GOALF"

# The stop derives once (`refresh --json`), so goal.md follows without another call.
mkdir -p openspec/changes/us-3-2-not-yet-delivered
printf '# Proposal\n\nStory: US-3.2\n' > openspec/changes/us-3-2-not-yet-delivered/proposal.md
stop_hook >/dev/null 2>&1
expect_contains "the stop itself refreshes goal.md" "Reason: planning incomplete: missing specs/, tasks.md" cat "$GOALF"
expect_contains "the refreshed command continues the change" \
  "Command: /ohmyorch:opsx-propose us-3-2-not-yet-delivered for US-3.2 $PROPOSE_CONTINUE" cat "$GOALF"
rm -rf openspec/changes/us-3-2-not-yet-delivered

# ---------------------------------------------------------------------------
# Scenario: Halt when the loop stops making progress
# ---------------------------------------------------------------------------

section "Halt when the loop stops making progress"

rm -f "$LOOPF"; MAXS=2
check "unchanged stop attempt 1 blocks"         2 stop_hook
expect_eq "the counter after one attempt"       "count=1" "$(grep '^count=' "$LOOPF")"
expect_contains "unchanged stop attempt 2 blocks and counts" "Unchanged stop attempts: 2 of 2 allowed." stop_hook
HALT=$(stop_out); HALT_RC=$?
expect_eq "unchanged stop attempt 3 is allowed" "0" "$HALT_RC"
expect_eq "the halt is announced, exactly" \
  "Delivery goal US-3.2 recorded BLOCKED — no progress: next action 'propose' for US-3.2 unchanged across 3 stop attempts. Inspect ohmyorch delivery next, then run /ohmyorch:deliver US-3.2 to resume." \
  "$(message_of "$HALT")"
expect_contains "goal recorded BLOCKED"         "| Status | BLOCKED |" cat "$GOALF"
expect_contains "reason is lack of progress" \
  "| Reason | no progress: next action 'propose' for US-3.2 unchanged across 3 stop attempts |" cat "$GOALF"
check "loop.state is cleared"                   1 test -e "$LOOPF"
check "a BLOCKED goal no longer blocks Stop"    0 stop_hook
expect_eq "a BLOCKED goal's stop is silent"     "" "$(stop_hook 2>&1)"
check "start resumes the same goal"             0 scripts/delivery.sh start US-3.2
expect_contains "a resumed goal is ACTIVE"      "| Status | ACTIVE |" cat "$GOALF"
expect_contains "a resumed goal clears the reason" "| Reason | - |" cat "$GOALF"
check "after resume, Stop blocks again"         2 stop_hook
check "a second unchanged attempt still blocks" 2 stop_hook
MAXS=100

# Progress is any change of the derived JSON line, including its reason.
C32=openspec/changes/us-3-2-not-yet-delivered
mkdir -p "$C32"
check "progress: the change now exists"         2 stop_hook
expect_eq "progress resets the stall count"     "count=1" "$(grep '^count=' "$LOOPF")"
expect_contains "goal.md follows the new reason" "Reason: planning incomplete: missing proposal.md, specs/, tasks.md" cat "$GOALF"
printf '# Proposal\n' > "$C32/proposal.md"; mkdir -p "$C32/specs/cap"; printf '# Spec\n' > "$C32/specs/cap/spec.md"
printf -- '- [ ] 1.1 build\n- [ ] 1.2 test\n' > "$C32/tasks.md"
check "progress: planning is complete"          2 stop_hook
expect_eq "a new action counts from one"        "count=1" "$(grep '^count=' "$LOOPF")"
expect_contains "the block now names apply"     "Next action: apply  (story: US-3.2, change: us-3-2-not-yet-delivered)" stop_hook
expect_eq "the same apply state counts up"      "count=3" "$(stop_hook >/dev/null 2>&1; grep '^count=' "$LOOPF")"
printf -- '- [x] 1.1 build\n- [ ] 1.2 test\n' > "$C32/tasks.md"
check "progress: one more task ticked"          2 stop_hook
expect_eq "a ticked task resets the stall count" "count=1" "$(grep '^count=' "$LOOPF")"
expect_contains "the block reports task progress" "Reason: 1/2 tasks complete" stop_hook
rm -rf "$C32"; MAXS=100

# Every goal transition clears the stall counter.
stop_hook >/dev/null 2>&1
check "a blocked stop leaves a stall counter"   0 test -e "$LOOPF"
scripts/delivery.sh stop >/dev/null 2>&1
check "stop clears the stall counter"           1 test -e "$LOOPF"
expect_contains "stop records STOPPED"          "| Status | STOPPED |" cat "$GOALF"
check "a STOPPED goal does not block Stop"      0 stop_hook
scripts/delivery.sh start US-3.2 >/dev/null 2>&1; stop_hook >/dev/null 2>&1
scripts/delivery.sh start US-3.2 >/dev/null 2>&1
check "start (resume) clears the stall counter" 1 test -e "$LOOPF"
stop_hook >/dev/null 2>&1
scripts/delivery.sh block --reason "manual" >/dev/null 2>&1
check "block clears the stall counter"          1 test -e "$LOOPF"
expect_contains "block records its reason"      "| Reason | manual |" cat "$GOALF"
scripts/delivery.sh start US-3.2 >/dev/null 2>&1
MAXS=0
# Capture once: the first stop records BLOCKED, so a second call would print nothing.
one=$(stop_hook 2>&1)
expect_contains "one attempt is singular"       "unchanged across 1 stop attempt" printf '%s' "$one"
expect_absent "one attempt is not pluralised"   "1 stop attempts" printf '%s' "$one"
MAXS=100

# ---------------------------------------------------------------------------
# Scenario: Halt for a human decision
# ---------------------------------------------------------------------------

section "Halt for a human decision"

scripts/delivery.sh stop >/dev/null 2>&1; rm -f "$LOOPF"
scripts/delivery.sh start EPIC-2 >/dev/null 2>&1
expect_contains "an escalating goal starts ACTIVE" "| Status | ACTIVE |" cat "$GOALF"
ESC=$(stop_out); ESC_RC=$?
expect_eq "Stop is allowed on escalate"         "0" "$ESC_RC"
expect_eq "the escalation is announced, exactly" \
  "Delivery goal EPIC-2 recorded BLOCKED — a human decision is required: US-2.1 is NEEDS CLARIFICATION, not READY. Resolve it, then run /ohmyorch:deliver EPIC-2 to resume." \
  "$(message_of "$ESC")"
expect_absent "the announcement names no role"  "Product Manager" printf '%s' "$ESC"
expect_contains "goal recorded BLOCKED"         "| Status | BLOCKED |" cat "$GOALF"
expect_contains "reason carries the escalation" "| Reason | escalate: US-2.1 is NEEDS CLARIFICATION, not READY |" cat "$GOALF"
check "an escalation leaves no stall counter"   1 test -e "$LOOPF"
scripts/delivery.sh start EPIC-2 >/dev/null 2>&1
check "a resumed escalation halts again"        0 stop_hook
scripts/delivery.sh stop >/dev/null 2>&1
scripts/delivery.sh start US-3.1 >/dev/null 2>&1
check "an unfinished dependency allows the stop" 0 stop_hook
expect_contains "reason names the dependency"   "escalate: US-3.1 depends on unfinished US-3.2 (READY)" cat "$GOALF"
expect_eq "no change created by the halt"       "$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive | wc -l | tr -d ' ')" "0"

# The recorded target no longer resolves: the halt is still recorded, never a trap.
sed 's/^| Target | .*/| Target | US-9.9 |/; s/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
check "an underivable goal allows the stop"     0 stop_hook
expect_contains "an underivable goal is BLOCKED" "| Status | BLOCKED |" cat "$GOALF"
expect_contains "reason says it could not be derived" "the goal could not be derived: " cat "$GOALF"
expect_contains "block preserves the target"    "| Target | US-9.9 |" cat "$GOALF"

# `stop` records the halt even when the target no longer resolves.
sed 's/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
check "stop with an underivable target exits 0" 0 scripts/delivery.sh stop --reason "manual halt"
expect_contains "stop records STOPPED"          "| Status | STOPPED |" cat "$GOALF"
expect_contains "stop preserves the target"     "| Target | US-9.9 |" cat "$GOALF"
expect_contains "stop records the reason"       "| Reason | manual halt |" cat "$GOALF"

# SPECS.md missing entirely: the halt is still recorded, and never mis-reported.
sed 's/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
mv SPECS.md "$WORK/specs.away"
check "no SPECS.md: the stop is allowed"        0 stop_hook
expect_contains "no SPECS.md: the halt is recorded" "| Status | BLOCKED |" cat "$GOALF"
check "no SPECS.md: next is refused"            1 scripts/delivery.sh next US-1.1
expect_eq "no SPECS.md: the refusal names the mapped document" \
  "error: SPECS.md not found (the mapped SPECS document)" "$(scripts/delivery.sh next US-1.1 2>&1)"
mv "$WORK/specs.away" SPECS.md
sed 's/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
chmod 0444 "$GOALF"; chmod 0555 openspec/delivery
expect_contains "an unrecordable halt is reported honestly" "could NOT be recorded as BLOCKED" stop_hook
chmod 0755 openspec/delivery; chmod 0644 "$GOALF"
expect_eq "an unrecordable halt leaves no staged goal copy" "" "$(find "$TMPDIR" -maxdepth 1 -name 'goal.*')"

# ---------------------------------------------------------------------------
# Scenario: Complete the goal
# ---------------------------------------------------------------------------

section "Complete the goal"

rm -rf openspec/delivery
scripts/delivery.sh start EPIC-4 >/dev/null 2>&1
check "Stop blocks while US-4.2 is undelivered" 2 stop_hook
sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md > "$WORK/s" && cp "$WORK/s" SPECS.md
DONE_OUT=$(stop_out); DONE_RC=$?
expect_eq "Stop is allowed when every story is DONE" "0" "$DONE_RC"
expect_eq "completion is announced, exactly"    "Delivery goal EPIC-4 is COMPLETE — every story is DONE." "$(message_of "$DONE_OUT")"
expect_contains "goal recorded COMPLETE"        "| Status | COMPLETE |" cat "$GOALF"
check "loop.state is cleared on completion"     1 test -e "$LOOPF"
check "a COMPLETE goal allows every stop"       0 stop_hook
expect_eq "a COMPLETE goal's stop is silent"    "" "$(stop_hook 2>&1)"
cp "$WORK/specs.orig" SPECS.md

# ---------------------------------------------------------------------------
# Scenario: One story through the whole loop
# ---------------------------------------------------------------------------

section "One story through propose, apply, verify, archive and DONE"

# The Stop hook, the archive guard and the DONE guard agree at every step. The
# archive itself is staged by moving the directory: the CLI is off PATH here.
rm -rf openspec/delivery
C=openspec/changes/us-4-2-x
# done_42 — the full prospective SPECS with US-4.2 set to DONE.
done_42() { sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md; }
scripts/delivery.sh start US-4.2 >/dev/null 2>&1
expect_contains "1. Stop names propose"         "Next action: propose  (story: US-4.2, change: us-4-2-x)" stop_hook
check "1. a change that does not exist is not ours to block" 0 bash_hook "openspec archive us-4-2-x -y" guard-archive.sh

mkdir -p "$C/specs/cap"
printf '# Proposal\n\nStory: US-4.2\n' > "$C/proposal.md"
printf '# Spec\n' > "$C/specs/cap/spec.md"
printf -- '- [ ] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"
expect_contains "2. Stop names apply"           "Next action: apply  (story: US-4.2, change: us-4-2-x)" stop_hook
expect_contains "2. Stop names the apply command" "Command: /ohmyorch:opsx-apply us-4-2-x" stop_hook
check "2. archive guard rejects archival mid-apply" 2 bash_hook "openspec archive us-4-2-x -y" guard-archive.sh
check "2. the loop guard is no archive bypass"  0 bash_hook "openspec archive us-4-2-x -y" guard-delivery-loop.sh
check "2. DONE guard rejects DONE mid-apply"    2 scripts/guard-story-done.sh --file SPECS.md --content "$(done_42)" --quiet

printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"
expect_contains "3. Stop names verify"          "Next action: verify  (story: US-4.2, change: us-4-2-x)" stop_hook
expect_contains "3. Stop hands over the archive command" "Command: $VERIFY_42" stop_hook
check "3. archive guard allows a fully ticked change" 0 bash_hook "openspec archive us-4-2-x -y" guard-archive.sh
check "3. DONE guard still requires the archive" 2 scripts/guard-story-done.sh --file SPECS.md --content "$(done_42)" --quiet

printf -- '- [ ] 2.1 fix the CRITICAL finding from verify\n' >> "$C/tasks.md"
expect_contains "4. a CRITICAL finding returns the loop to apply" "Reason: 2/3 tasks complete" stop_hook
check "4. archive guard rejects it again"       2 bash_hook "openspec archive us-4-2-x -y" guard-archive.sh
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n- [x] 2.1 fix the CRITICAL finding from verify\n' > "$C/tasks.md"
expect_contains "4. the fixed finding returns to verify" "Reason: 3/3 tasks complete; verify, then archive" stop_hook
check "4. the delivery loop wrote nothing into the change" 1 sh -c "ls -A '$C' | grep -vxE 'proposal.md|specs|tasks.md'"

mv "$C" openspec/changes/archive/2026-11-12-us-4-2-x
expect_contains "5. Stop names mark-done"       "Next action: mark-done  (story: US-4.2, change: us-4-2-x)" stop_hook
check "5. DONE guard allows DONE after the archive" 0 scripts/guard-story-done.sh --file SPECS.md --content "$(done_42)" --quiet
check "5. Stop still blocks until the DONE edit" 2 stop_hook

done_42 > "$WORK/s" && cp "$WORK/s" SPECS.md
FIN=$(stop_out); FIN_RC=$?
expect_eq "6. Stop is allowed once the story is DONE" "0" "$FIN_RC"
expect_eq "6. the goal is announced COMPLETE"   "Delivery goal US-4.2 is COMPLETE — every story is DONE." "$(message_of "$FIN")"
expect_contains "6. goal recorded COMPLETE"     "| Status | COMPLETE |" cat "$GOALF"
expect_eq "6. the archived change holds only OpenSpec artifacts" "proposal.md specs tasks.md " \
  "$(ls -A openspec/changes/archive/2026-11-12-us-4-2-x | sort | tr '\n' ' ')"
rm -rf openspec/changes/archive/2026-11-12-us-4-2-x
cp "$WORK/specs.orig" SPECS.md

# ---------------------------------------------------------------------------
# Change ids: one answer in resolve, next and goal.md
# ---------------------------------------------------------------------------

section "Every source of a change id, in resolve, next and goal.md"

rm -rf openspec/delivery
cat > SPECS.md <<'EOF'
# Change id fixture

# EPIC-7: Change id sources

### US-7.1: Delivered with an archive path

Status: DONE

Change: `openspec/changes/archive/2026-09-24-us-7-1-first/`

### US-7.2: Delivered under a bare id

Status: DONE

Change: custom-id

### US-7.3: Found by its active directory

Status: READY

### US-7.4: Found by its archived directory

Status: READY

### US-7.5: Derived from the title slug

Status: READY

### US-7.6: The and of

Status: READY

### US-7.7: 日本語のタイトル

Status: READY

### US-7.8: A dash is no change

Status: READY

Change: -

### US-7.9: Pipes | in a | title

Status: READY

# EPIC-8: Odd values

### US-8.1: Odd status

Status: "quoted" back\slash
EOF
mkdir -p openspec/changes/us-7-3-hand-named openspec/changes/archive/2026-09-24-us-7-4-archived-name

# A Change: line, an active directory, an archived directory, the title slug,
# and `story` where the title leaves no slug (OpenSpec refuses a trailing hyphen).
WANT_IDS="us-7-1-first custom-id us-7-3-hand-named us-7-4-archived-name us-7-5-derived-title-slug us-7-6-story us-7-7-story us-7-8-dash-no-change us-7-9-pipes-title "
RESOLVED=$(scripts/delivery.sh resolve EPIC-7 --json | jq -r '.stories[].change' | tr '\n' ' ')
expect_eq "resolve names the change of every story" "$WANT_IDS" "$RESOLVED"
check "the epic goal starts"                    0 scripts/delivery.sh start EPIC-7
GOAL_IDS=$(awk -F' [|] ' '/^## Stories/ { t = 1; next } /^## / { t = 0 } t && /^[|] [0-9]+ [|]/ { print $3 }' "$GOALF" | tr '\n' ' ')
expect_eq "goal.md's change column equals resolve --json" "$RESOLVED" "$GOAL_IDS"
expect_contains "goal.md: an archive path is reduced to its id" \
  "| 1 | US-7.1 | us-7-1-first | DONE | Delivered with an archive path |" cat "$GOALF"
expect_contains "goal.md: a directory names the change" \
  "| 3 | US-7.3 | us-7-3-hand-named | READY | Found by its active directory |" cat "$GOALF"
expect_contains "goal.md: a pipe in a title cannot break the table" \
  "| 9 | US-7.9 | us-7-9-pipes-title | READY | Pipes / in a / title |" cat "$GOALF"
expect_eq "goal.md lists the nine stories and no more" "9" "$(grep -c '^| [0-9]* | US-' "$GOALF")"

# Without a Change: line the story's own directory is its change, active first.
expect_action "an active directory names the change" US-7.3 propose US-7.3 us-7-3-hand-named \
  "/ohmyorch:opsx-propose us-7-3-hand-named for US-7.3 $PROPOSE_CONTINUE" \
  "planning incomplete: missing proposal.md, specs/, tasks.md"
expect_action "an archived directory names the change" US-7.4 mark-done US-7.4 us-7-4-archived-name \
  "set 'Status: DONE' for US-7.4 in SPECS.md and point its Change: line at the archived change" \
  "change us-7-4-archived-name is archived but US-7.4 is READY"
mkdir -p openspec/changes/archive/2026-09-24-us-7-3-older
expect_eq "the active directory wins over an archived one" "us-7-3-hand-named" \
  "$(scripts/delivery.sh resolve US-7.3 --json | jq -r '.stories[0].change')"
rmdir openspec/changes/us-7-3-hand-named
expect_eq "then the archived directory is the change" "us-7-3-older" \
  "$(scripts/delivery.sh resolve US-7.3 --json | jq -r '.stories[0].change')"
rmdir openspec/changes/archive/2026-09-24-us-7-3-older
expect_eq "with neither, the id is derived from the title" "us-7-3-found-active-directory" \
  "$(scripts/delivery.sh resolve US-7.3 --json | jq -r '.stories[0].change')"
expect_action "a title of stop words only yields us-n-m-story" US-7.6 propose US-7.6 us-7-6-story \
  "/ohmyorch:opsx-propose us-7-6-story for US-7.6; then set US-7.6 to IN PROGRESS with a Change: line in SPECS.md" \
  "US-7.6 is READY and has no OpenSpec change"
expect_eq "so does a title without an ASCII letter or digit" "us-7-7-story" "$(scripts/delivery.sh next US-7.7 --json | jq -r .change)"
expect_eq "no derived change id ends in a hyphen" "0" \
  "$(scripts/delivery.sh resolve EPIC-7 --json | jq -r '[.stories[].change | select(endswith("-"))] | length')"

# Derived text is escaped as JSON, not pasted between quotes.
ODD_REASON='US-8.1 is "quoted" back\slash, not READY'
ODD_JSON=$(scripts/delivery.sh next US-8.1 --json 2>&1)
expect_eq "a quote and a backslash survive the JSON line" "$ODD_REASON" "$(printf '%s' "$ODD_JSON" | jq -r .reason 2>&1)"
expect_eq "the JSON line escapes them, exactly" \
  '{ "target": "US-8.1", "action": "escalate", "story": "US-8.1", "change": "us-8-1-odd-status", "command": "resolve US-8.1 in SPECS.md (a product decision is required)", "reason": "US-8.1 is \"quoted\" back\\slash, not READY" }' \
  "$ODD_JSON"
expect_eq "the text line carries them as they are" "Reason:  $ODD_REASON" "$(scripts/delivery.sh next US-8.1 2>/dev/null | tail -1)"
scripts/delivery.sh stop >/dev/null 2>&1; rm -f "$LOOPF"
scripts/delivery.sh start US-8.1 >/dev/null 2>&1
ODD_STOP=$(stop_out); ODD_RC=$?
expect_eq "the Stop hook reads that line back"  "0" "$ODD_RC"
expect_eq "and announces the reason unchanged" \
  "Delivery goal US-8.1 recorded BLOCKED — a human decision is required: $ODD_REASON. Resolve it, then run /ohmyorch:deliver US-8.1 to resume." \
  "$(message_of "$ODD_STOP")"
expect_contains "goal.md records the reason unchanged" "| Reason | escalate: $ODD_REASON |" cat "$GOALF"
scripts/delivery.sh stop >/dev/null 2>&1
rm -rf openspec/delivery openspec/changes/archive/2026-09-24-us-7-4-archived-name

# ---------------------------------------------------------------------------
# Cost: no process per delivered story
# ---------------------------------------------------------------------------

section "A derivation costs the same for a long epic as for a short one"

# The Stop hook derives the goal on every stop attempt, and an epic goal lists
# every story. Stories that are DONE and carry a Change: line are read in one
# pass: the processes a call starts do not grow with the delivered stories.
COUNTED="$WORK/counted"
mkdir -p "$COUNTED"
for tool in awk sed grep find tr sort head; do
  printf '#!/bin/sh\nprintf "%%s\\n" %s >> "$SPAWN_LOG"\nexec %s "$@"\n' "$tool" "$(command -v "$tool")" > "$COUNTED/$tool"
  chmod +x "$COUNTED/$tool"
done
# spawned_by <command...> — how many of those processes the command starts.
spawned_by() {
  : > "$WORK/spawn.log"
  SPAWN_LOG="$WORK/spawn.log" PATH="$COUNTED:$PATH" "$@" >/dev/null 2>&1
  wc -l < "$WORK/spawn.log" | tr -d ' '
}
# epic_of <n> — EPIC-9 with n delivered stories and one story still to deliver.
epic_of() {
  awk -v n="$1" 'BEGIN {
    print "# Long epic fixture\n\n# EPIC-9: A long epic\n"
    for (i = 1; i <= n; i++)
      printf "### US-9.%d: Delivered story %d\n\nStatus: DONE\n\nChange: `openspec/changes/archive/2026-09-24-us-9-%d-delivered/`\n\n", i, i, i
    printf "### US-9.%d: The story still to deliver\n\nStatus: IN PROGRESS\n\nChange: `openspec/changes/us-9-next/`\n", n + 1
  }'
}
epic_of 2 > SPECS.md
SHORT_NEXT=$(spawned_by scripts/delivery.sh next EPIC-9 --json)
SHORT_START=$(spawned_by scripts/delivery.sh start EPIC-9)
SHORT_REFRESH=$(spawned_by scripts/delivery.sh refresh --json)
expect_eq "the short goal lists its three stories" "3" "$(grep -c '^| [0-9]* | US-9\.' "$GOALF")"
scripts/delivery.sh stop >/dev/null 2>&1; rm -rf openspec/delivery
epic_of 40 > SPECS.md
LONG_NEXT=$(spawned_by scripts/delivery.sh next EPIC-9 --json)
LONG_START=$(spawned_by scripts/delivery.sh start EPIC-9)
LONG_REFRESH=$(spawned_by scripts/delivery.sh refresh --json)
expect_eq "the long goal lists its 41 stories"  "41" "$(grep -c '^| [0-9]* | US-9\.' "$GOALF")"
expect_contains "the long goal's last delivered row" \
  "| 40 | US-9.40 | us-9-40-delivered | DONE | Delivered story 40 |" cat "$GOALF"
expect_contains "the long goal's story to deliver" \
  "| 41 | US-9.41 | us-9-next | IN PROGRESS | The story still to deliver |" cat "$GOALF"
expect_eq "the long epic derives its first unfinished story" "US-9.41" "$(scripts/delivery.sh next --json | jq -r .story)"
check "the counting shims saw delivery's processes" 0 test "$SHORT_NEXT" -gt 0
expect_eq "next: 40 delivered stories cost what 2 cost" "$SHORT_NEXT" "$LONG_NEXT"
expect_eq "start: 40 delivered stories cost what 2 cost" "$SHORT_START" "$LONG_START"
expect_eq "refresh: 40 delivered stories cost what 2 cost" "$SHORT_REFRESH" "$LONG_REFRESH"
scripts/delivery.sh stop >/dev/null 2>&1
rm -rf openspec/delivery

# The same bound for an epic nobody has proposed yet: READY stories without a
# Change: line. Their ids come from one listing of the change directories and
# one pass over the rows, and they are the ids `resolve` reports story by story.
# fresh_epic <n> — EPIC-9 with n READY stories and no Change: line.
fresh_epic() {
  awk -v n="$1" 'BEGIN {
    print "# Fresh epic fixture\n\n# EPIC-9: A fresh epic\n"
    for (i = 1; i <= n; i++) {
      title = sprintf("The Story of widget %d", i)
      # Six significant words: the id keeps the first four.
      if (i == 6) title = "One two three four five six"
      # U-umlaut and dotted capital I: letters outside ASCII are separators in every locale.
      if (i == 7) title = "\303\234ber \304\260stanbul rollout"
      printf "### US-9.%d: %s\n\nStatus: READY\n\n", i, title
    }
  }'
}
# finds_by <command...> — how many `find` processes the command starts.
finds_by() {
  : > "$WORK/spawn.log"
  SPAWN_LOG="$WORK/spawn.log" PATH="$COUNTED:$PATH" "$@" >/dev/null 2>&1
  grep -c '^find$' "$WORK/spawn.log" || true
}
FRESH_DIRS="openspec/changes/archive/2026-09-24-us-9-1-from-archive
openspec/changes/us-9-2-from-active-dir
openspec/changes/us-9-3-b-active
openspec/changes/archive/2026-09-24-us-9-3-a-archived
openspec/changes/us-9-4-b
openspec/changes/us-9-4-a
openspec/changes/us-9-40-other
openspec/changes/us-9-50-other
openspec/changes/xus-9-5-other
openspec/changes/archive/us-9-5-undated"
for d in $FRESH_DIRS; do mkdir -p "$d"; done
fresh_epic 8 > SPECS.md
FRESH_SHORT_START=$(spawned_by scripts/delivery.sh start EPIC-9)
FRESH_SHORT_REFRESH=$(spawned_by scripts/delivery.sh refresh --json)
FRESH_SHORT_FINDS=$(finds_by scripts/delivery.sh resolve EPIC-9 --json)
expect_eq "the short fresh goal lists its eight stories" "8" "$(grep -c '^| [0-9]* | US-9\.' "$GOALF")"
scripts/delivery.sh stop >/dev/null 2>&1; rm -rf openspec/delivery
fresh_epic 40 > SPECS.md
FRESH_LONG_START=$(spawned_by scripts/delivery.sh start EPIC-9)
FRESH_LONG_REFRESH=$(spawned_by scripts/delivery.sh refresh --json)
FRESH_LONG_FINDS=$(finds_by scripts/delivery.sh resolve EPIC-9 --json)
expect_eq "the long fresh goal lists its 40 stories" "40" "$(grep -c '^| [0-9]* | US-9\.' "$GOALF")"
expect_contains "fresh goal: an archived directory names the change" \
  "| 1 | US-9.1 | us-9-1-from-archive | READY | The Story of widget 1 |" cat "$GOALF"
expect_contains "fresh goal: an active directory names the change" \
  "| 2 | US-9.2 | us-9-2-from-active-dir | READY | The Story of widget 2 |" cat "$GOALF"
expect_contains "fresh goal: an active directory wins over an archived one" \
  "| 3 | US-9.3 | us-9-3-b-active | READY | The Story of widget 3 |" cat "$GOALF"
expect_contains "fresh goal: the first of two active directories, never us-9-40-*" \
  "| 4 | US-9.4 | us-9-4-a | READY | The Story of widget 4 |" cat "$GOALF"
# Nor from xus-9-5-other (the prefix starts the name) or the undated archive entry.
expect_contains "fresh goal: no directory, so the id comes from the title, never us-9-50-*" \
  "| 5 | US-9.5 | us-9-5-story-widget-5 | READY | The Story of widget 5 |" cat "$GOALF"
expect_contains "fresh goal: the id keeps the first four significant words" \
  "| 6 | US-9.6 | us-9-6-one-two-three-four | READY | One two three four five six |" cat "$GOALF"
# The derived id is the same in every locale: a letter outside ASCII is a separator.
UTF8_ROW=$(printf '| 7 | US-9.7 | us-9-7-ber-stanbul-rollout | READY | \303\234ber \304\260stanbul rollout |')
expect_contains "fresh goal: a letter outside ASCII separates words" "$UTF8_ROW" cat "$GOALF"
LC_ALL=en_US.UTF-8 scripts/delivery.sh refresh --json >/dev/null 2>&1
expect_contains "fresh goal: the same id under a UTF-8 locale" "$UTF8_ROW" cat "$GOALF"
expect_eq "resolve: the same id under a UTF-8 locale" "us-9-7-ber-stanbul-rollout" \
  "$(LC_ALL=en_US.UTF-8 scripts/delivery.sh resolve US-9.7 --json | jq -r '.stories[0].change')"
expect_contains "fresh goal: us-9-40-* belongs to US-9.40" \
  "| 40 | US-9.40 | us-9-40-other | READY | The Story of widget 40 |" cat "$GOALF"
expect_eq "fresh goal: the change column is what resolve reports" \
  "$(scripts/delivery.sh resolve EPIC-9 --json | jq -r '.stories[] | .story + " " + .change')" \
  "$(awk -F'|' '/^\| [0-9]+ \| US-9\./ { s = $3; c = $4; gsub(/ /, "", s); gsub(/ /, "", c); print s " " c }' "$GOALF")"
check "the counting shims saw the fresh epic's processes" 0 test "$FRESH_SHORT_REFRESH" -gt 0
expect_eq "start: 40 unproposed stories cost what 8 cost" "$FRESH_SHORT_START" "$FRESH_LONG_START"
expect_eq "refresh: 40 unproposed stories cost what 8 cost" "$FRESH_SHORT_REFRESH" "$FRESH_LONG_REFRESH"
check "the counting shims saw resolve list the directories" 0 test "$FRESH_SHORT_FINDS" -gt 0
expect_eq "resolve: 40 unproposed stories list the directories as often as 8" "$FRESH_SHORT_FINDS" "$FRESH_LONG_FINDS"
# What can never name a change: a target with an escape, a directory name that
# holds a newline, and a Change: id read as a pattern.
check "a target that carries an awk escape is refused" 1 scripts/delivery.sh resolve 'US-9.1\060' --json
mkdir -p "openspec/changes/"$'zz\nus-9-5-evil'
expect_eq "a directory name that holds a newline names no change" "us-9-5-story-widget-5" \
  "$(scripts/delivery.sh resolve US-9.5 --json | jq -r '.stories[0].change')"
rmdir "openspec/changes/"$'zz\nus-9-5-evil'
printf '# Pattern fixture\n\n# EPIC-9: P\n\n### US-9.1: Pattern id\n\nStatus: IN PROGRESS\n\nChange: us-9-1-*\n' > SPECS.md
expect_absent "a Change: id is never matched against the archive as a pattern" '"action": "mark-done"' \
  scripts/delivery.sh next US-9.1 --json
# An archive entry without the date prefix is an archived change; a symbolic
# link under the archive is not a directory of the archive.
printf '# Undated fixture\n\n# EPIC-9: U\n\n### US-9.1: Undated id\n\nStatus: IN PROGRESS\n\nChange: plain-undated\n' > SPECS.md
ln -s "$PWD/openspec/changes/us-9-2-from-active-dir" openspec/changes/archive/plain-undated
expect_absent "a symbolic link under the archive is not an archived change" '"action": "mark-done"' \
  scripts/delivery.sh next US-9.1 --json
rm openspec/changes/archive/plain-undated
mkdir -p openspec/changes/archive/plain-undated
expect_contains "an undated archive entry is an archived change" '"action": "mark-done"' \
  scripts/delivery.sh next US-9.1 --json
rmdir openspec/changes/archive/plain-undated
# An archived id that only starts or ends with the Change: id is another change.
NEAR="openspec/changes/archive/2026-09-24-plain-undated-two openspec/changes/archive/plain-undated-two
openspec/changes/archive/x-plain-undated openspec/changes/archive/2026-09-24-x-plain-undated"
for d in $NEAR; do mkdir -p "$d"; done
expect_absent "an archived id that only starts or ends with the Change: id is another change" '"action": "mark-done"' \
  scripts/delivery.sh next US-9.1 --json
for d in $NEAR; do rmdir "$d"; done
printf '# Dash fixture\n\n# EPIC-9: D\n\n### US-9.1: Dash id\n\nStatus: IN PROGRESS\n\nChange: -/\n' > SPECS.md
mkdir -p openspec/changes/archive/-
expect_absent "a Change: value that reduces to - names no archived change" '"action": "mark-done"' \
  scripts/delivery.sh next US-9.1 --json
rmdir openspec/changes/archive/-
fresh_epic 40 > SPECS.md
scripts/delivery.sh stop >/dev/null 2>&1
rm -rf openspec/delivery
for d in $FRESH_DIRS; do rm -rf "$d"; done
cp "$WORK/specs.orig" SPECS.md

# ---------------------------------------------------------------------------
# Fail open and usage
# ---------------------------------------------------------------------------

section "Fail open and usage"

rm -rf openspec/delivery
check "no goal: Stop is allowed"                0 stop_hook
check "no goal: a write event is not ours"      0 write_hook openspec/changes/us-4-2-x/tasks.md
check "empty payload is allowed"                0 sh -c 'printf "" | scripts/guard-delivery-loop.sh --hook --quiet'
check "a payload that is not an object blocks"  2 sh -c 'printf "[]" | scripts/guard-delivery-loop.sh --hook --quiet'

# A payload without delivery.sh must never trap the session, even with an ACTIVE goal.
scripts/delivery.sh start US-3.2 >/dev/null 2>&1
BARE="$WORK/bare-plugin"
mkdir -p "$BARE/scripts"
cp -R "$OHMYORCH_TEST_PLUGIN_ROOT/lib" "$BARE/lib"
cp "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/guard-delivery-loop.sh" "$BARE/scripts/"
bare_stop() {
  printf '%s' '{"session_id":"s1","hook_event_name":"Stop"}' \
    | OHMYORCH_PROJECT_ROOT="$(pwd -P)" OHMYORCH_SESSION_ID=regression /bin/bash "$BARE/scripts/guard-delivery-loop.sh" --hook --quiet
}
check "no delivery.sh: Stop is allowed"         0 bare_stop
cp "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/delivery.sh" "$BARE/scripts/"
check "the loop needs delivery.sh and nothing else" 2 bare_stop
check "control: the full payload blocks that stop" 2 stop_hook
scripts/delivery.sh stop >/dev/null 2>&1
rm -rf openspec/delivery

check "missing --hook is a usage error"         3 sh -c 'printf "{}" | scripts/guard-delivery-loop.sh'
check "the loop guard has a help text"          0 scripts/guard-delivery-loop.sh --help
for gone in review.md test-report PreToolUse verdict "Any other event"; do
  expect_absent "the loop guard's help no longer mentions $gone" "$gone" scripts/guard-delivery-loop.sh --help
done
expect_eq "the loop guard's help states its one event" \
  "this session can do; records COMPLETE or BLOCKED and allows the stop when the goal is complete, needs a human decision, or made no progress. It acts on the Stop event of the main session only." \
  "$(scripts/guard-delivery-loop.sh --help | sed -n '/^this session can do/,/^Stop event/p' | tr '\n' ' ' | sed 's/ $//')"
check "the loop guard still accepts --quiet"    0 sh -c 'printf "" | scripts/guard-delivery-loop.sh --hook --quiet'
check "a non-numeric --max-stalls is a usage error" 3 sh -c 'printf "{}" | scripts/guard-delivery-loop.sh --hook --max-stalls x'
check "an unknown loop-guard option is a usage error" 3 sh -c 'printf "{}" | scripts/guard-delivery-loop.sh --hook --bogus'
check "block without a goal is refused"         1 scripts/delivery.sh block --reason x
check "stop without a goal is refused"          1 scripts/delivery.sh stop

# ---------------------------------------------------------------------------
# Documentation is checked by tools/check-plugin.mjs and tools/check-links.mjs.

# Summary
# ---------------------------------------------------------------------------

printf '\n=======================================================\n'
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS — goal-driven delivery holds.%s\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL — goal-driven delivery regressed.%s\n' "$c_red" "$c_reset"
exit 1
