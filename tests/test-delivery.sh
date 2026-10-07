#!/usr/bin/env bash
#
# test-delivery.sh — regression suite for goal-driven delivery (US-12.1, US-12.2)
#
# Exercises scripts/delivery.sh (target resolution, next-action derivation,
# goal record, reopen) against a staged copy of the harness with a stub SPECS.md
# and the review / test-report fixtures in scripts/fixtures/.
#
# The properties this suite protects:
#
#   1. Resolution — an epic lists its stories in order, a task resolves to its
#      parent story, and an unknown target is refused without recording a goal.
#   2. Derivation — every gate and completion condition maps to one action and
#      owner, recomputed from the repository, never read back from goal.md.
#   3. Escalation — a story that is not READY, or whose dependency is unfinished,
#      escalates and creates no change.
#   4. Reopen — a failing verdict is preserved verbatim, never deleted, and the
#      loop returns to implementation with one remediation task per finding.
#   5. The loop (US-12.2, guard-delivery-loop.sh) — a Stop hook blocks the stop
#      while work remains, allows it and records BLOCKED on escalation or lack of
#      progress, records COMPLETE when every story is DONE, keeps the orchestrator
#      from authoring review.md / test-report.md, and cannot bypass the archive
#      guard. Hooks are driven with realistic multi-key Claude Code payloads.
#
# The openspec CLI is kept off PATH so completion condition 4 is decided by the
# recorded `OpenSpec verify:` line alone, and the suite does not depend on the CLI.
# Runs in a throwaway copy under ${TMPDIR:-/tmp} and removes it on exit.
#
# Usage: scripts/test-delivery.sh
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
trap 'rm -rf "$WORK"' EXIT

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

# expect_eq <label> <want> <got>
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1" "= $3"; else bad "$1" "want '$2' got '$3'"; fi
}

section() { printf '\n%s\n' "$1"; }

action_of() { scripts/delivery.sh next "$@" 2>/dev/null | sed -n 's/^Action:  //p'; }
owner_of()  { scripts/delivery.sh next "$@" 2>/dev/null | sed -n 's/^Owner:   //p'; }
changes_snapshot() { find openspec/changes -maxdepth 1 -mindepth 1 -type d | sort; }

# ---------------------------------------------------------------------------
# Stage a copy of the harness
# ---------------------------------------------------------------------------

S="$WORK/repo"
mkdir -p "$S/scripts" "$S/openspec/changes/archive"
for f in delivery.sh workflow-status.sh completion-gate.sh status.sh \
         validate-review.sh validate-test-report.sh validate-implementation-plan.sh \
         guard-delivery-loop.sh guard-archive.sh; do
  cp "$ROOT/scripts/$f" "$S/scripts/" || { echo "error: cannot stage $f" >&2; exit 2; }
done
# validate-product-artifacts.sh is deliberately NOT staged: gate 7 then depends on
# the CODEBASE context marker alone, so the stub SPECS.md need not satisfy the full
# artifact contract.
cp -R "$ROOT/scripts/fixtures" "$S/scripts/fixtures"
cp -R "$ROOT/scripts/templates" "$S/scripts/templates"
# The US-12.4 cases assert the documentation, so stage the docs they read.
mkdir -p "$S/.claude/rules"
cp "$ROOT/README.md" "$S/"
cp "$ROOT/.claude/rules/ohmyorch:delivery-loop.md" "$S/.claude/rules/"
cp "$ROOT/scripts/README.md" "$S/scripts/"
chmod +x "$S"/scripts/*.sh
cd "$S" || exit 2

PATH="$OHMYORCH_TEST_UTILITIES:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

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
# Give every fixture story real acceptance evidence for the mandatory product validator.
awk '
  /^### US-/ {print; print "\nSource:\n- PRD.md fixture\n\nAcceptance Criteria:\n\n```gherkin\nScenario: Fixture acceptance\n  Given a fixture\n  When it runs\n  Then it succeeds\n```\n"; next}
  {print}
' SPECS.md > SPECS.enriched
mv SPECS.enriched SPECS.md
printf '# Fixture PRD\n\nCODEBASE Context: absent (greenfield)\n' > PRD.md

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

scripts/delivery.sh start 'US-1.1#2' >/dev/null 2>&1
expect_contains "goal records the task as Focus" "| Focus | Wire the widget renderer. |" cat openspec/delivery/goal.md
expect_contains "goal records kind task"        "| Kind | task |" cat openspec/delivery/goal.md
expect_contains "goal delivers the parent story" "| 1 | US-1.1 |" cat openspec/delivery/goal.md
expect_contains "goal is ACTIVE"                "| Status | ACTIVE |" cat openspec/delivery/goal.md
scripts/delivery.sh stop >/dev/null 2>&1
expect_contains "stop records STOPPED"          "| Status | STOPPED |" cat openspec/delivery/goal.md

# ---------------------------------------------------------------------------
# Scenario: Reject an unknown target
# ---------------------------------------------------------------------------

section "Reject an unknown target"

check "unknown epic is refused"                 1 scripts/delivery.sh resolve EPIC-99
expect_contains "refusal names the epic"        "EPIC-99" scripts/delivery.sh resolve EPIC-99
check "unknown story is refused"                1 scripts/delivery.sh resolve US-9.9
expect_contains "refusal names the story"       "US-9.9" scripts/delivery.sh resolve US-9.9
check "unknown task text is refused"            1 scripts/delivery.sh resolve 'no such task anywhere'
check "missing target is a usage error"         2 scripts/delivery.sh resolve
check "unknown command is a usage error"        2 scripts/delivery.sh frobnicate

rm -rf openspec/delivery
check "start with an unknown target fails"      1 scripts/delivery.sh start US-9.9
check "no goal recorded for an unknown target"  1 test -e openspec/delivery/goal.md

scripts/delivery.sh start EPIC-1 >/dev/null 2>&1
cp openspec/delivery/goal.md "$WORK/goal.before"
scripts/delivery.sh start EPIC-99 >/dev/null 2>&1
check "a rejected start leaves the goal untouched" 0 cmp -s "$WORK/goal.before" openspec/delivery/goal.md
check "a different target needs stop first"     1 scripts/delivery.sh start EPIC-3

# ---------------------------------------------------------------------------
# Scenario: Escalate a story that cannot proceed
# ---------------------------------------------------------------------------

section "Escalate a story that cannot proceed"

before=$(changes_snapshot)
expect_eq "NEEDS CLARIFICATION escalates"       "escalate" "$(action_of EPIC-2)"
expect_contains "reason names the status"       "NEEDS CLARIFICATION" scripts/delivery.sh next EPIC-2
expect_eq "unfinished dependency escalates"     "escalate" "$(action_of US-3.1)"
expect_contains "reason names the dependency"   "US-3.2 (READY)" scripts/delivery.sh next US-3.1
expect_eq "escalation is owned by the human PM" "human-product-manager" "$(owner_of US-3.1)"
expect_eq "inline Dependencies: line escalates" "escalate" "$(action_of US-3.3)"
expect_eq "on-hold story with archived change escalates" "escalate" "$(action_of US-3.4)"
expect_contains "on-hold reason names the status" "US-3.4 is NEEDS CLARIFICATION" scripts/delivery.sh next US-3.4
expect_eq "archived change, unfinished dependency escalates" "escalate" "$(action_of US-3.5)"
expect_contains "archived-change reason names the dependency" "US-3.5 depends on unfinished US-3.2 (READY)" scripts/delivery.sh next US-3.5
expect_eq "no change created by escalation"     "$before" "$(changes_snapshot)"
expect_eq "a READY story with no change selects" "select" "$(action_of US-3.2)"
expect_eq "select does not create the change"   "$before" "$(changes_snapshot)"

# ---------------------------------------------------------------------------
# Scenario: Derive the next action from repository artifacts
# ---------------------------------------------------------------------------

section "Derive the next action from repository artifacts"

scripts/delivery.sh stop >/dev/null 2>&1
scripts/delivery.sh start EPIC-4 >/dev/null 2>&1
C=openspec/changes/us-4-2-x
mkdir -p "$C"
printf '# Proposal\n\nStory: US-4.2\n' > "$C/proposal.md"
printf -- '- [ ] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"

expect_eq "no specs/ -> propose"                "propose" "$(action_of)"
expect_eq "propose is owned by the ohmyorch:planner"     "ohmyorch:planner" "$(owner_of)"
expect_contains "the command is named"          "Command: /ohmyorch:opsx-explore US-4.2 then /ohmyorch:opsx-propose us-4-2-x" scripts/delivery.sh next

mkdir -p "$C/specs/cap"; printf '# Spec\n' > "$C/specs/cap/spec.md"
expect_eq "no plan -> plan"                     "plan" "$(action_of)"
expect_contains "plan command"                  "Command: /ohmyorch:plan-feature us-4-2-x" scripts/delivery.sh next

cp scripts/fixtures/plans/valid/implementation-plan.md "$C/"
expect_eq "unticked task -> implement"          "implement" "$(action_of)"
expect_eq "implement is owned by the ohmyorch:implementer" "ohmyorch:implementer" "$(owner_of)"

printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"
expect_eq "no review.md -> review"              "review" "$(action_of)"
expect_eq "review is owned by the ohmyorch:reviewer"     "ohmyorch:reviewer" "$(owner_of)"

cp scripts/fixtures/reviews/blocking/review.md "$C/review.md"
expect_eq "blocking review -> reopen"           "reopen" "$(action_of)"

cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
expect_eq "passing review, no report -> test"   "test" "$(action_of)"
expect_eq "test is owned by the ohmyorch:tester"         "ohmyorch:tester" "$(owner_of)"

cp scripts/fixtures/test-reports/failing/test-report.md "$C/test-report.md"
expect_eq "failing test report -> reopen"       "reopen" "$(action_of)"

cp scripts/fixtures/test-reports/valid/test-report.md "$C/test-report.md"
expect_eq "all gates and conditions pass -> archive" "archive" "$(action_of)"
expect_contains "archive records completion first" "completion-gate --change us-4-2-x --record" scripts/delivery.sh next

grep -v '^OpenSpec verify:' scripts/fixtures/reviews/valid/review.md > "$C/review.md"
expect_eq "completion condition fails -> escalate" "escalate" "$(action_of)"
expect_contains "reason names the failing condition" "openspec-verification" scripts/delivery.sh next
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"

printf '# CODEBASE\n' > CODEBASE.md
sed 's/^CODEBASE Context:.*$//' SPECS.md > "$WORK/specs.nomarker"; cp SPECS.md "$WORK/specs.orig"
cp "$WORK/specs.nomarker" SPECS.md
expect_eq "acceptance gate fails -> escalate"   "escalate" "$(action_of)"
cp "$WORK/specs.orig" SPECS.md; rm -f CODEBASE.md

scripts/delivery.sh refresh >/dev/null 2>&1
sed 's/^Action: .*/Action: complete/' openspec/delivery/goal.md > "$WORK/g" && cp "$WORK/g" openspec/delivery/goal.md
printf -- '- [x] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"
expect_eq "a hand-edited goal.md does not steer next" "implement" "$(action_of)"
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"

mkdir -p openspec/changes/other-change
expect_eq "another active change still reports its gates" "archive" "$(action_of)"
rmdir openspec/changes/other-change

check "next --json is machine-readable"         0 sh -c 'scripts/delivery.sh next --json | grep -q "\"action\": \"archive\""'

mv "$C" openspec/changes/archive/2026-09-24-us-4-2-x
expect_eq "archived but not DONE -> mark-done"  "mark-done" "$(action_of)"
sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md > "$WORK/s" && cp "$WORK/s" SPECS.md
expect_eq "every story DONE -> complete"        "complete" "$(action_of)"
scripts/delivery.sh refresh >/dev/null 2>&1
expect_contains "a complete goal records COMPLETE" "| Status | COMPLETE |" cat openspec/delivery/goal.md

# Single active change at a time: a second change blocks selecting a new one.
cp "$WORK/specs.orig" SPECS.md
mkdir -p openspec/changes/other-change
expect_eq "selecting beside another change escalates" "escalate" "$(action_of US-3.2)"
expect_contains "reason names the other change" "other-change" scripts/delivery.sh next US-3.2
rmdir openspec/changes/other-change

# ---------------------------------------------------------------------------
# Scenario: Reopen a change after a failed review or acceptance test
# ---------------------------------------------------------------------------

section "Reopen a change after a failed review or acceptance test"

rm -rf openspec/delivery openspec/changes/archive/2026-09-24-us-4-2-x
C=openspec/changes/us-4-2-x
mkdir -p "$C/specs/cap"
printf '# Proposal\n\nStory: US-4.2\n' > "$C/proposal.md"
printf '# Spec\n' > "$C/specs/cap/spec.md"
cp scripts/fixtures/plans/valid/implementation-plan.md "$C/"
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"
scripts/delivery.sh start US-4.2 >/dev/null 2>&1

cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
cp "$C/tasks.md" "$WORK/tasks.before"
check "nothing to reopen on a passing review"   1 scripts/delivery.sh reopen --change us-4-2-x
check "a refused reopen leaves tasks.md alone"  0 cmp -s "$WORK/tasks.before" "$C/tasks.md"

cp scripts/fixtures/reviews/blocking/review.md "$C/review.md"
check "reopen a blocking review"                0 scripts/delivery.sh reopen --change us-4-2-x
check "review preserved under history/"         0 test -f "$C/history/review-r1.md"
check "preserved review is byte-identical"      0 cmp -s scripts/fixtures/reviews/blocking/review.md "$C/history/review-r1.md"
check "review.md moved aside"                   1 test -e "$C/review.md"
n=$(grep -c '^- \[ \] R1\.' "$C/tasks.md" || true)
expect_eq "one remediation task per finding"    "2" "${n:-0}"
expect_contains "task carries the remediation"  "remove \`Write\` and \`Edit\` from the frontmatter" cat "$C/tasks.md"
expect_contains "task names the finding"        "F-2: evidence rule is unenforceable" cat "$C/tasks.md"
expect_eq "after reopen -> implement"           "implement" "$(action_of)"
expect_contains "goal refreshed after reopen"   "Action: implement" cat openspec/delivery/goal.md

sed 's/^- \[ \]/- [x]/' "$C/tasks.md" > "$WORK/t" && cp "$WORK/t" "$C/tasks.md"
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
cp scripts/fixtures/test-reports/failing/test-report.md "$C/test-report.md"
check "reopen a failing test report"            0 scripts/delivery.sh reopen
check "test report preserved as round 2"        0 test -f "$C/history/test-report-r2.md"
check "review also moved (re-review required)"  0 test -f "$C/history/review-r2.md"
check "round 1 is not overwritten"              0 cmp -s scripts/fixtures/reviews/blocking/review.md "$C/history/review-r1.md"
check "test-report.md moved aside"              1 test -e "$C/test-report.md"
n=$(grep -c '^- \[ \] R2\.' "$C/tasks.md" || true)
expect_eq "one remediation task per failure"    "1" "${n:-0}"
expect_contains "task carries the expected behavior" "the tool list omits \`Write\` and \`Edit\`" cat "$C/tasks.md"
expect_eq "after test reopen -> implement"      "implement" "$(action_of)"
check "reopen never authors review.md"          1 test -e "$C/review.md"
check "reopen never authors test-report.md"     1 test -e "$C/test-report.md"

# ---------------------------------------------------------------------------
# US-12.2 — the delivery goal loop (scripts/guard-delivery-loop.sh)
# ---------------------------------------------------------------------------

GOALF=openspec/delivery/goal.md
LOOPF=.claude/ohmyorch/runtime/regression/loop.state
MAXS=100

# Realistic payloads: several keys, and the value of interest is not the last one.
stop_hook() { # stop_hook [stop_hook_active]
  printf '{"session_id":"s1","transcript_path":"/tmp/t.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":%s,"last_assistant_message":"Done for now.","background_tasks":[],"session_crons":[]}' \
    "$PWD" "${1:-false}" | scripts/guard-delivery-loop.sh --hook --quiet --max-stalls "$MAXS"
}
stop_sub() {
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop","agent_id":"a1","agent_type":"ohmyorch:reviewer","stop_hook_active":false}' \
    "$PWD" | scripts/guard-delivery-loop.sh --hook --quiet
}
write_hook() { # write_hook <repo-relative path> [agent_type]
  ag=""; [ -n "${2:-}" ] && ag="\"agent_id\":\"a1\",\"agent_type\":\"$2\","
  printf '{"session_id":"s1","cwd":"%s",%s"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/%s","content":"# Review"},"tool_use_id":"t1"}' \
    "$PWD" "$ag" "$PWD" "$1" | scripts/guard-delivery-loop.sh --hook --quiet
}
write_mention() { # the content mentions agent_id, JSON-escaped; this is still the main session
  printf '%s' "{\"session_id\":\"s1\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$PWD/openspec/changes/us-3-2-x/review.md\",\"content\":\"subagents carry \\\"agent_id\\\": 1\"}}" \
    | scripts/guard-delivery-loop.sh --hook --quiet
}
bash_hook() { # bash_hook <command> <guard>
  printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"Archive the change","timeout":120000},"tool_use_id":"t2"}' \
    "$1" | "scripts/$2" --hook --quiet
}

# ---------------------------------------------------------------------------
# Scenario: Start a delivery goal
# ---------------------------------------------------------------------------

section "Start a delivery goal"

rm -rf openspec/delivery openspec/changes/us-4-2-x
check "start a READY story records a goal"      0 scripts/delivery.sh start US-3.2
expect_contains "goal records the target"       "| Target | US-3.2 |" cat "$GOALF"
expect_contains "goal records its stories"      "| 1 | US-3.2 |" cat "$GOALF"
expect_contains "goal status is ACTIVE"         "| Status | ACTIVE |" cat "$GOALF"
expect_eq "the next action names its owner"     "ohmyorch:product-manager" "$(owner_of)"
check "orchestrator write to review.md is blocked" 2 write_hook openspec/changes/us-3-2-x/review.md
check "orchestrator write to test-report.md is blocked" 2 write_hook openspec/changes/us-3-2-x/test-report.md
expect_contains "the block names the owning role" "ohmyorch:reviewer subagent" write_hook openspec/changes/us-3-2-x/review.md
check "ohmyorch:reviewer subagent may write review.md"   0 write_hook openspec/changes/us-3-2-x/review.md ohmyorch:reviewer
check "ohmyorch:tester subagent may write test-report.md" 0 write_hook openspec/changes/us-3-2-x/test-report.md ohmyorch:tester
check "an escaped agent_id mention is not a subagent" 2 write_mention
check "orchestrator may write SPECS.md"         0 write_hook SPECS.md
check "a preserved history/ review is not a verdict write" 0 write_hook openspec/changes/us-3-2-x/history/review-r1.md
check "a case-variant REVIEW.md is still blocked" 2 write_hook openspec/changes/us-3-2-x/REVIEW.md

# ---------------------------------------------------------------------------
# Scenario: Continue while work remains
# ---------------------------------------------------------------------------

section "Continue while work remains"

rm -f "$LOOPF"
check "Stop is blocked while work remains"      2 stop_hook
expect_contains "the block names the next action" "Next action: select" stop_hook
expect_contains "the block names the owner"     "owner: ohmyorch:product-manager" stop_hook
expect_contains "the block names the command"   "Command: openspec new change" stop_hook
check "stop_hook_active does not bypass the loop" 2 stop_hook true
check "a subagent's Stop is never blocked"      0 stop_sub
expect_contains "goal stays ACTIVE"             "| Status | ACTIVE |" cat "$GOALF"
expect_contains "goal.md Next Action is refreshed" "Action: select" cat "$GOALF"

# ---------------------------------------------------------------------------
# Scenario: Halt when the loop stops making progress
# ---------------------------------------------------------------------------

section "Halt when the loop stops making progress"

rm -f "$LOOPF"; MAXS=2
check "unchanged stop attempt 1 blocks"         2 stop_hook
check "unchanged stop attempt 2 blocks"         2 stop_hook
check "unchanged stop attempt 3 is allowed"     0 stop_hook
expect_contains "goal recorded BLOCKED"         "| Status | BLOCKED |" cat "$GOALF"
expect_contains "reason is lack of progress"    "no progress: next action 'select'" cat "$GOALF"
check "loop.state is cleared"                   1 test -e "$LOOPF"
check "a BLOCKED goal no longer blocks Stop"    0 stop_hook
check "start resumes the same goal"             0 scripts/delivery.sh start US-3.2
expect_contains "a resumed goal is ACTIVE"      "| Status | ACTIVE |" cat "$GOALF"
check "after resume, Stop blocks again"         2 stop_hook
check "a second unchanged attempt still blocks" 2 stop_hook
C32=$(scripts/delivery.sh next --json | sed -n 's/.*"change": "\([^"]*\)".*/\1/p')
mkdir -p "openspec/changes/$C32"
check "progress: the derived state changed"     2 stop_hook
expect_eq "progress resets the stall count"     "count=1" "$(grep '^count=' "$LOOPF")"
expect_contains "goal.md follows the new action" "Action: propose" cat "$GOALF"
rm -rf "openspec/changes/$C32"; MAXS=100

# Every goal transition clears the stall counter (review O-1).
stop_hook >/dev/null 2>&1
check "a blocked stop leaves a stall counter"   0 test -e "$LOOPF"
scripts/delivery.sh stop >/dev/null 2>&1
check "stop clears the stall counter"           1 test -e "$LOOPF"
scripts/delivery.sh start US-3.2 >/dev/null 2>&1; stop_hook >/dev/null 2>&1
scripts/delivery.sh start US-3.2 >/dev/null 2>&1
check "start (resume) clears the stall counter" 1 test -e "$LOOPF"
stop_hook >/dev/null 2>&1
scripts/delivery.sh block --reason "manual" >/dev/null 2>&1
check "block clears the stall counter"          1 test -e "$LOOPF"
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
expect_contains "the user is told a decision is needed" "human Product Manager decision" stop_hook
expect_contains "goal recorded BLOCKED"         "| Status | BLOCKED |" cat "$GOALF"
expect_contains "reason carries the escalation" "US-2.1 is NEEDS CLARIFICATION" cat "$GOALF"
scripts/delivery.sh start EPIC-2 >/dev/null 2>&1
check "Stop is allowed on escalate"             0 stop_hook
scripts/delivery.sh stop >/dev/null 2>&1
scripts/delivery.sh start US-3.1 >/dev/null 2>&1
check "an unfinished dependency allows the stop" 0 stop_hook
expect_contains "reason names the dependency"   "US-3.2 (READY)" cat "$GOALF"
expect_eq "no change created by the halt"       "$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive | wc -l | tr -d ' ')" "0"

# The recorded target no longer resolves: the halt is still recorded, never a trap.
sed 's/^| Target | .*/| Target | US-9.9 |/; s/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
check "an underivable goal allows the stop"     0 stop_hook
expect_contains "an underivable goal is BLOCKED" "| Status | BLOCKED |" cat "$GOALF"
expect_contains "reason says it could not be derived" "could not be derived" cat "$GOALF"
expect_contains "block preserves the target"    "| Target | US-9.9 |" cat "$GOALF"

# US-12.4: `stop` records the halt even when the target no longer resolves.
sed 's/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
check "stop with an underivable target exits 0" 0 scripts/delivery.sh stop --reason "manual halt"
expect_contains "stop records STOPPED"          "| Status | STOPPED |" cat "$GOALF"
expect_contains "stop preserves the target"     "| Target | US-9.9 |" cat "$GOALF"
expect_contains "stop records the reason"       "| Reason | manual halt |" cat "$GOALF"

# SPECS.md missing entirely: the halt is still recorded, and never mis-reported (O-2).
sed 's/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
mv SPECS.md "$WORK/specs.away"
check "no SPECS.md: the stop is allowed"        0 stop_hook
expect_contains "no SPECS.md: the halt is recorded" "| Status | BLOCKED |" cat "$GOALF"
mv "$WORK/specs.away" SPECS.md
sed 's/^| Status | .*/| Status | ACTIVE |/' "$GOALF" > "$WORK/g" && cp "$WORK/g" "$GOALF"
chmod 0444 "$GOALF"; chmod 0555 openspec/delivery
expect_contains "an unrecordable halt is reported honestly" "could NOT be recorded as BLOCKED" stop_hook
chmod 0755 openspec/delivery; chmod 0644 "$GOALF"

# ---------------------------------------------------------------------------
# Scenario: Complete the goal
# ---------------------------------------------------------------------------

section "Complete the goal"

rm -rf openspec/delivery
scripts/delivery.sh start EPIC-4 >/dev/null 2>&1
check "Stop blocks while US-4.2 is undelivered" 2 stop_hook
sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md > "$WORK/s" && cp "$WORK/s" SPECS.md
expect_contains "the user is told the goal is complete" "is COMPLETE" stop_hook
expect_contains "goal recorded COMPLETE"        "| Status | COMPLETE |" cat "$GOALF"
check "loop.state is cleared on completion"     1 test -e "$LOOPF"
check "a COMPLETE goal allows every stop"       0 stop_hook
cp "$WORK/specs.orig" SPECS.md

# ---------------------------------------------------------------------------
# Scenario: The loop cannot bypass a gate
# ---------------------------------------------------------------------------

section "The loop cannot bypass a gate"

rm -rf openspec/delivery
C=openspec/changes/us-4-2-x
mkdir -p "$C/specs/cap"
printf '# Proposal\n\nStory: US-4.2\n' > "$C/proposal.md"
printf '# Spec\n' > "$C/specs/cap/spec.md"
cp scripts/fixtures/plans/valid/implementation-plan.md "$C/"
printf -- '- [x] 1.1 build\n- [ ] 1.2 test\n' > "$C/tasks.md"
scripts/delivery.sh start US-4.2 >/dev/null 2>&1
expect_eq "the loop derives implement, not archive" "implement" "$(action_of)"
check "archive guard rejects archival mid-goal" 2 bash_hook "openspec archive us-4-2-x -y" guard-archive.sh
check "archive guard rejects a blocking review" 2 sh -c "printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > $C/tasks.md; cp scripts/fixtures/reviews/blocking/review.md $C/review.md; printf '%s' '{\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"openspec archive us-4-2-x\",\"description\":\"x\"}}' | scripts/guard-archive.sh --hook --quiet"
check "the loop guard has no archive bypass"    0 bash_hook "openspec archive us-4-2-x -y" guard-delivery-loop.sh
check "Stop keeps the loop working instead"     2 stop_hook
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
cp scripts/fixtures/test-reports/valid/test-report.md "$C/test-report.md"
expect_eq "control: an eligible change derives archive" "archive" "$(action_of)"
check "control: the guard allows an eligible archive" 0 bash_hook "openspec archive us-4-2-x -y" guard-archive.sh

# ---------------------------------------------------------------------------
# Fail open and usage
# ---------------------------------------------------------------------------

section "Fail open and usage"

rm -rf openspec/delivery
check "no goal: Stop is allowed"                0 stop_hook
check "no goal: a review.md write is not ours"  0 write_hook openspec/changes/us-4-2-x/review.md
check "empty payload is allowed"                0 sh -c 'printf "" | scripts/guard-delivery-loop.sh --hook --quiet'
mkdir -p "$WORK/bare/scripts"; cp scripts/guard-delivery-loop.sh "$WORK/bare/scripts/"
check "no delivery.sh: Stop is allowed"         0 sh -c "printf '%s' '{\"hook_event_name\":\"Stop\"}' | '$WORK/bare/scripts/guard-delivery-loop.sh' --hook --quiet"
check "missing --hook is a usage error"         3 sh -c 'printf "{}" | scripts/guard-delivery-loop.sh'
check "a non-numeric --max-stalls is a usage error" 3 sh -c 'printf "{}" | scripts/guard-delivery-loop.sh --hook --max-stalls x'
check "block without a goal is refused"         1 scripts/delivery.sh block --reason x

# ---------------------------------------------------------------------------
# Documentation assertions moved to tools/check-plugin.mjs.

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
