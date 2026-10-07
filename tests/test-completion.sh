#!/usr/bin/env bash
#
# test-completion.sh — regression suite for the US-10.1 completion gate
#
# Exercises scripts/completion-gate.sh (the four-condition evaluator) and
# scripts/validate-verification.sh (the completion-record contract), and proves
# that guard-archive.sh now enforces the completion gate rather than the gate
# chain alone.
#
# The property this suite exists to protect is stated in one case: a change that
# passes all seven workflow gates but declares a blocking OpenSpec verification
# mismatch MUST be rejected. The gate chain cannot see that condition, so before
# EPIC-10 the harness would have archived it.
#
# Runs in a throwaway copy under ${TMPDIR:-/tmp} and removes it on exit.
#
# Usage: scripts/test-completion.sh
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

WORK=$(mktemp -d "${TMPDIR:-/tmp}/harness-completion.XXXXXX") || { echo "error: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  output=$("$@" 2>&1)
  got=$?
  if [ "$got" = "$want" ]; then
    printf '  %sok%s    %-56s exit=%s\n' "$c_green" "$c_reset" "$label" "$got"
    PASS=$((PASS + 1))
  else
    printf '  %sFAIL%s  %-56s want=%s got=%s\n' "$c_red" "$c_reset" "$label" "$want" "$got"
    FAIL=$((FAIL + 1))
    printf '%s\n' "$output"
  fi
}

# expect_contains <label> <needle> <command...>
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -F -- "$needle" >/dev/null; then
    printf '  %sok%s    %-56s found\n' "$c_green" "$c_reset" "$label"
    PASS=$((PASS + 1))
  else
    printf '  %sFAIL%s  %-56s missing: %s\n' "$c_red" "$c_reset" "$label" "$needle"
    FAIL=$((FAIL + 1))
    printf '%s\n' "$out"
  fi
}

section() { printf '\n%s\n' "$1"; }

# ---------------------------------------------------------------------------
# Stage a copy of the harness with one change, all conditions passing
# ---------------------------------------------------------------------------

S="$WORK/repo"
mkdir -p "$S/scripts" "$S/openspec/changes"

cp "$ROOT"/scripts/workflow-status.sh "$ROOT"/scripts/completion-gate.sh \
   "$ROOT"/scripts/validate-verification.sh "$ROOT"/scripts/guard-archive.sh \
   "$ROOT"/scripts/validate-*.sh "$S/scripts/" 2>/dev/null
cp -R "$ROOT/scripts/fixtures" "$S/scripts/fixtures"
mkdir -p "$S/scripts/templates"
cp "$ROOT/scripts/templates/completion.md" "$S/scripts/templates/" 2>/dev/null
chmod +x "$S"/scripts/*.sh

cd "$S" || exit 2

cp scripts/fixtures/valid/PRD.md scripts/fixtures/valid/SPECS.md scripts/fixtures/valid/CODEBASE.md . 2>/dev/null
printf '\nCODEBASE Context: consumed\n' >> SPECS.md

C=openspec/changes/staged
mkdir -p "$C/specs/workflow"
cp scripts/fixtures/plans/valid/implementation-plan.md "$C/"
cp scripts/fixtures/reviews/valid/review.md "$C/"
cp scripts/fixtures/test-reports/valid/test-report.md "$C/"
printf '# Proposal\n\nStory: US-2.1\n' > "$C/proposal.md"
printf '# Delta\n\n## ADDED Requirements\n\n### Requirement: Demo\nThe system SHALL work.\n\n#### Scenario: Works\n- **WHEN** run\n- **THEN** it works\n' \
  > "$C/specs/workflow/spec.md"
printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"

# ---------------------------------------------------------------------------
# All four conditions pass
# ---------------------------------------------------------------------------

section "completion-gate.sh — all four conditions pass"

check "eligible change evaluates clean"     0 scripts/completion-gate.sh --change staged --quiet
check "json mode exits 0"                  0 scripts/completion-gate.sh --change staged --json --quiet

expect_contains "reports eligible"         '"eligible": true' scripts/completion-gate.sh --change staged --json
expect_contains "all four conditions"      '"condition": "openspec-verification"' scripts/completion-gate.sh --change staged --json
expect_contains "openspec validate ran"    '"openspecValidateState": "pass"' scripts/completion-gate.sh --change staged --json
expect_contains "verdict is announced"     "ELIGIBLE FOR ARCHIVE" scripts/completion-gate.sh --change staged

# ---------------------------------------------------------------------------
# Each condition independently blocks
# ---------------------------------------------------------------------------

section "Each condition independently blocks archival"

printf -- '- [x] first\n- [ ] second\n' > "$C/tasks.md"
check "incomplete task blocks"             1 scripts/completion-gate.sh --change staged --quiet
expect_contains "names tasks as blocker"   "First failing condition: tasks" scripts/completion-gate.sh --change staged --quiet
printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"

cp scripts/fixtures/reviews/blocking/review.md "$C/review.md"
check "blocking review blocks"             1 scripts/completion-gate.sh --change staged --quiet
expect_contains "names review as blocker"  "First failing condition: review" scripts/completion-gate.sh --change staged --quiet
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"

cp scripts/fixtures/test-reports/failing/test-report.md "$C/test-report.md"
check "failing acceptance blocks"          1 scripts/completion-gate.sh --change staged --quiet
expect_contains "names acceptance as blocker" "First failing condition: acceptance" scripts/completion-gate.sh --change staged --quiet
cp scripts/fixtures/test-reports/valid/test-report.md "$C/test-report.md"

section "Fail-open probes — absence of evidence is not evidence"

: > "$C/tasks.md"
check "empty checklist blocks"             1 scripts/completion-gate.sh --change staged --quiet
expect_contains "empty checklist is not completion" "tasks.md has no task checkboxes" \
  scripts/completion-gate.sh --change staged --quiet
printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"

cp "$C/test-report.md" "$WORK/tr.bak"
: > "$C/test-report.md"
check "empty test report blocks"           1 scripts/completion-gate.sh --change staged --quiet
cp "$WORK/tr.bak" "$C/test-report.md"

# ---------------------------------------------------------------------------
# Condition 4 — the condition the gate chain cannot see
# ---------------------------------------------------------------------------

section "Condition 4 — OpenSpec verification (invisible to the gate chain)"

# All seven gates pass, yet the review declares a blocking verify mismatch.
sed 's/^OpenSpec verify: .*/OpenSpec verify: MISMATCH — 4 blocking mismatches found/' \
  scripts/fixtures/reviews/valid/review.md > "$C/review.md"

expect_contains "the gate chain still reports eligible" '"archiveEligible": true' \
  scripts/workflow-status.sh --change staged --json

check "the completion gate rejects it"     1 scripts/completion-gate.sh --change staged --quiet
expect_contains "names verification as blocker" "recorded /ohmyorch:opsx-verify outcome reports a blocking mismatch" \
  scripts/completion-gate.sh --change staged --quiet

check "guard-archive now blocks it"        2 scripts/guard-archive.sh --change staged --quiet
expect_contains "guard names the condition" "openspec-verification" \
  scripts/guard-archive.sh --change staged --json

# An OpenSpec validation error also blocks, independent of the recorded line.
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
mkdir -p "$C/specs-workflow-bak"
DELTA="$C/specs/workflow/spec.md"; DELTA_BAK="$WORK/delta.bak"
cp "$DELTA" "$DELTA_BAK"
printf '# Delta\n\nbroken\n' > "$DELTA"
check "invalid delta spec blocks"          1 scripts/completion-gate.sh --change staged --quiet
expect_contains "an empty recorded line is not a pass" "openspec validate" \
  scripts/completion-gate.sh --change staged --json
cp "$DELTA_BAK" "$DELTA"
rmdir "$C/specs-workflow-bak" 2>/dev/null

# ---------------------------------------------------------------------------
# guard-archive.sh delegation
# ---------------------------------------------------------------------------

section "guard-archive.sh enforces the completion gate"

check "eligible change is allowed"         0 scripts/guard-archive.sh --change staged --quiet
check "hook mode allows archival"          0 sh -c "printf '{\"tool_input\":{\"command\":\"openspec archive staged --yes\"}}' | scripts/guard-archive.sh --hook --quiet"
check "hook mode ignores --help"           0 sh -c "printf '{\"tool_input\":{\"command\":\"openspec archive --help\"}}' | scripts/guard-archive.sh --hook --quiet"

printf -- '- [ ] unfinished\n' > "$C/tasks.md"
check "incomplete task blocks archival"    2 scripts/guard-archive.sh --change staged --quiet
check "hook mode blocks archival"          2 sh -c "printf '{\"tool_input\":{\"command\":\"openspec archive staged --yes\"}}' | scripts/guard-archive.sh --hook --quiet"
printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"

# ---------------------------------------------------------------------------
# Recording and validating the completion record
# ---------------------------------------------------------------------------

section "completion-gate.sh --record and validate-verification.sh"

check "record writes completion.md"        0 scripts/completion-gate.sh --change staged --record --quiet
check "recorded file validates"            0 scripts/validate-verification.sh --change staged --quiet
expect_contains "record names the story"   "| Story | US-2.1 |" cat "$C/completion.md"
expect_contains "record verdict is eligible" "| Verdict | eligible |" cat "$C/completion.md"

check "valid fixture validates"            0 scripts/validate-verification.sh \
        --verification scripts/fixtures/completion/valid/completion.md --quiet
check "false certificate is rejected"      1 scripts/validate-verification.sh \
        --verification scripts/fixtures/completion/incoherent/completion.md --quiet
check "malformed record is rejected"       1 scripts/validate-verification.sh \
        --verification scripts/fixtures/completion/malformed/completion.md --quiet

expect_contains "the false certificate is named" \
  "Verdict 'eligible' while condition 'acceptance' fails" \
  scripts/validate-verification.sh --verification scripts/fixtures/completion/incoherent/completion.md --quiet

# A record that is malformed in several ways reports each one.
expect_contains "a missing condition row is caught" "expected 4 condition rows, found 3" \
  scripts/validate-verification.sh --verification scripts/fixtures/completion/malformed/completion.md --quiet
expect_contains "an invented verdict is caught" "Verdict 'probably-fine' is not eligible or not-eligible" \
  scripts/validate-verification.sh --verification scripts/fixtures/completion/malformed/completion.md --quiet

# Staleness: the record says eligible, then a condition starts failing.
printf -- '- [x] first\n- [ ] second\n' > "$C/tasks.md"
check "stale record is detected"           1 scripts/validate-verification.sh --change staged --quiet
expect_contains "staleness says STALE"     "STALE, not malformed" \
  scripts/validate-verification.sh --change staged --quiet

# Re-recording a not-eligible change exits 1 — that is the correct signal, since
# the change is genuinely not eligible. The record itself must still be written
# and must agree with the evaluation.
check "re-record reports not-eligible"     1 scripts/completion-gate.sh --change staged --record --quiet
expect_contains "the record now says not-eligible" "| Verdict | not-eligible |" cat "$C/completion.md"
check "the re-recorded file still validates" 0 scripts/validate-verification.sh --change staged --quiet

# And once the condition passes again, the record becomes eligible.
printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"
check "record returns to eligible"         0 scripts/completion-gate.sh --change staged --record --quiet
expect_contains "the record says eligible again" "| Verdict | eligible |" cat "$C/completion.md"
check "eligible record validates"          0 scripts/validate-verification.sh --change staged --quiet

# ---------------------------------------------------------------------------
# The DONE transition (US-10.1 task 3)
# ---------------------------------------------------------------------------

section "guard-story-done.sh — DONE only after archival"

cp "$ROOT/scripts/guard-story-done.sh" scripts/ 2>/dev/null
chmod +x scripts/guard-story-done.sh 2>/dev/null

printf -- '- [x] first\n- [ ] second\n' > "$C/tasks.md"
check "DONE is blocked while ineligible"   2 sh -c "printf '{\"tool_input\":{\"file_path\":\"$S/SPECS.md\",\"new_string\":\"### US-2.1: Demo\\\\n\\\\nStatus: DONE\"}}' | scripts/guard-story-done.sh --hook --quiet"
expect_contains "names the failing condition" "First failing condition: tasks" \
  sh -c "printf '{\"tool_input\":{\"file_path\":\"$S/SPECS.md\",\"new_string\":\"### US-2.1: Demo\\\\n\\\\nStatus: DONE\"}}' | scripts/guard-story-done.sh --hook"

printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"
check "DONE is allowed once eligible"      0 sh -c "printf '{\"tool_input\":{\"file_path\":\"$S/SPECS.md\",\"new_string\":\"### US-2.1: Demo\\\\n\\\\nStatus: DONE\"}}' | scripts/guard-story-done.sh --hook --quiet"

# The natural edits. Previously every one of these was allowed unchecked: a bare
# `Status: READY -> Status: DONE` Edit carries no story heading, and a full-file
# Write was judged only by its FIRST DONE story, which is usually an old one.
cp SPECS.md SPECS.md.bak
printf '### US-1.9: Old\n\nStatus: DONE\n\n### US-2.1: Demo\n\nStatus: READY\n\n### US-2.2: Other\n\nStatus: READY\n' > SPECS.md
printf -- '- [x] first\n- [ ] second\n' > "$C/tasks.md"
check "bare Edit is blocked while ineligible" 2 scripts/guard-story-done.sh --file SPECS.md \
  --old "Status: READY" --content "Status: DONE" --quiet
check "hook bare Edit is blocked"             2 sh -c "printf '{\"tool_input\":{\"file_path\":\"$S/SPECS.md\",\"old_string\":\"Status: READY\",\"new_string\":\"Status: DONE\"}}' | scripts/guard-story-done.sh --hook --quiet"
# Real Edit payloads carry keys after new_string; a greedy parse swallowed them.
check "real Edit payload key order is blocked" 2 sh -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$S/SPECS.md\",\"old_string\":\"Status: READY\",\"new_string\":\"Status: DONE\",\"replace_all\":false}}' | scripts/guard-story-done.sh --hook --quiet"
check "full Write behind an old DONE is blocked" 2 scripts/guard-story-done.sh --file SPECS.md \
  --content "$(printf '### US-1.9: Old\n\nStatus: DONE\n\n### US-2.1: Demo\n\nStatus: DONE\n')" --quiet
check "Edit located in another story is allowed" 0 scripts/guard-story-done.sh --file SPECS.md \
  --old "$(printf 'Other\n\nStatus: READY')" --content "Status: DONE" --quiet
check "re-writing only old DONE is allowed"   0 scripts/guard-story-done.sh --file SPECS.md \
  --content "$(printf '### US-1.9: Old\n\nStatus: DONE\n')" --quiet
printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"
check "bare Edit is allowed once eligible"    0 scripts/guard-story-done.sh --file SPECS.md \
  --old "Status: READY" --content "Status: DONE" --quiet
mv SPECS.md.bak SPECS.md

check "non-SPECS file is ignored"          0 scripts/guard-story-done.sh --file README.md --content "Status: DONE" --quiet
check "a READY write is ignored"           0 scripts/guard-story-done.sh --file SPECS.md --content "Status: READY" --quiet
check "empty stdin fails open"             0 sh -c "printf '' | scripts/guard-story-done.sh --hook"
check "DONE guard usage error"             3 scripts/guard-story-done.sh --bogus

# ---------------------------------------------------------------------------
# Usage errors
# ---------------------------------------------------------------------------

section "Usage errors"

cd "$ROOT" || exit 2
check "completion: unknown option"         2 scripts/completion-gate.sh --bogus
check "completion: unknown change"         2 scripts/completion-gate.sh --change nope-not-real
check "verification: unknown option"       2 scripts/validate-verification.sh --bogus
check "verification: missing file"         1 scripts/validate-verification.sh --verification /nonexistent.md --quiet

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n=======================================================\n'
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS — the definition of done holds.%s\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL — the completion gate regressed.%s\n' "$c_red" "$c_reset"
exit 1
