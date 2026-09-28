#!/usr/bin/env bash
#
# test-status.sh — regression suite for durable workflow state (US-9.1)
#
# Exercises scripts/status.sh (the writer and resume reporter) and
# scripts/validate-status.sh (the contract validator) against staged repository
# states and the fixtures in scripts/fixtures/status/.
#
# The three properties this suite exists to protect:
#
#   1. Derived gates — the table always agrees with workflow-status.sh.
#   2. Authored blockers — a refresh never destroys a human decision.
#   3. Staleness — a status.md that no longer matches the repository is caught
#      rather than trusted, because a resuming session believes what it reads.
#
# Runs in a throwaway copy under ${TMPDIR:-/tmp} and removes it on exit. It never
# modifies the harness repository.
#
# Usage: scripts/test-status.sh
#
# Exit codes: 0 all cases matched, 1 a case mismatched, 2 setup failure.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""; c_yellow=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/harness-status.XXXXXX") || { echo "error: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    printf '  %sok%s    %-54s exit=%s\n' "$c_green" "$c_reset" "$label" "$got"
    PASS=$((PASS + 1))
  else
    printf '  %sFAIL%s  %-54s want=%s got=%s\n' "$c_red" "$c_reset" "$label" "$want" "$got"
    FAIL=$((FAIL + 1))
  fi
}

# expect_contains <label> <needle> <command...>
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    printf '  %sok%s    %-54s found\n' "$c_green" "$c_reset" "$label"
    PASS=$((PASS + 1))
  else
    printf '  %sFAIL%s  %-54s missing: %s\n' "$c_red" "$c_reset" "$label" "$needle"
    FAIL=$((FAIL + 1))
  fi
}

# expect_absent <label> <needle> <command...>
expect_absent() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    printf '  %sFAIL%s  %-54s unexpectedly found: %s\n' "$c_red" "$c_reset" "$label" "$needle"
    FAIL=$((FAIL + 1))
  else
    printf '  %sok%s    %-54s absent\n' "$c_green" "$c_reset" "$label"
    PASS=$((PASS + 1))
  fi
}

section() { printf '\n%s\n' "$1"; }

# ---------------------------------------------------------------------------
# Stage a copy of the harness with one active change
# ---------------------------------------------------------------------------

S="$WORK/repo"
mkdir -p "$S/scripts" "$S/openspec/changes"

cp "$ROOT"/scripts/workflow-status.sh "$ROOT"/scripts/status.sh \
   "$ROOT"/scripts/validate-status.sh "$ROOT"/scripts/validate-*.sh "$S/scripts/" 2>/dev/null
cp -R "$ROOT/scripts/fixtures" "$S/scripts/fixtures"
cp "$ROOT/scripts/templates/status.md" "$S/scripts/templates/status.md" 2>/dev/null || {
  mkdir -p "$S/scripts/templates"; cp "$ROOT/scripts/templates/status.md" "$S/scripts/templates/"
}
chmod +x "$S"/scripts/*.sh

cd "$S" || exit 2

C=openspec/changes/staged
mkdir -p "$C/specs"
cp scripts/fixtures/plans/valid/implementation-plan.md "$C/"
printf '# Proposal\n\nStory: US-2.1\n' > "$C/proposal.md"
printf '# Spec\n' > "$C/specs/spec.md"
printf -- '- [x] first\n- [ ] second\n' > "$C/tasks.md"

# ---------------------------------------------------------------------------
# Writer
# ---------------------------------------------------------------------------

section "status.sh — writes derived state"

check "writes status.md"                 0 scripts/status.sh --change staged --quiet
[ -f "$C/status.md" ] && printf '  %sok%s    %-54s exists\n' "$c_green" "$c_reset" "status.md created" \
  && PASS=$((PASS + 1)) \
  || { printf '  %sFAIL%s  %-54s missing\n' "$c_red" "$c_reset" "status.md created"; FAIL=$((FAIL + 1)); }

expect_contains "story read from the plan, not boilerplate" "| Story | US-2.1 |" cat "$C/status.md"
expect_contains "state reflects the failing gate"           "| State | IMPLEMENTING |" cat "$C/status.md"
expect_contains "owner is the gate's owner"                 "| Current owner | ohmyorch-implementer |" cat "$C/status.md"
expect_contains "resume names the first incomplete gate"    "First incomplete gate: implementation" cat "$C/status.md"
expect_contains "gates table carries real detail"           "1/2 tasks complete" cat "$C/status.md"
expect_absent   "no placeholder leaks into the story"       "US-<n>.<m>" cat "$C/status.md"

check "dry run writes nothing"           0 scripts/status.sh --change staged --dry-run --quiet
check "unknown change is an error"       1 scripts/status.sh --change nope --quiet
check "unknown option is a usage error"  2 scripts/status.sh --bogus

# ---------------------------------------------------------------------------
# Validator
# ---------------------------------------------------------------------------

section "validate-status.sh — enforces the US-9.1 contract"

check "freshly written file validates"    0 scripts/validate-status.sh --change staged --quiet
check "valid fixture validates"           0 scripts/validate-status.sh \
        --status scripts/fixtures/status/valid/status.md --quiet
check "incoherent resume is rejected"     1 scripts/validate-status.sh \
        --status scripts/fixtures/status/incoherent/status.md --quiet
check "malformed fixture is rejected"     1 scripts/validate-status.sh \
        --status scripts/fixtures/status/malformed/status.md --quiet
check "missing file is rejected"          1 scripts/validate-status.sh --status /nonexistent/status.md --quiet
check "usage error"                       2 scripts/validate-status.sh --bogus

expect_contains "incoherence is named precisely" \
  "Resume says 'implementation' but the first failing gate is 'review'" \
  scripts/validate-status.sh --status scripts/fixtures/status/incoherent/status.md --quiet

expect_contains "an invented state is caught" \
  "State 'ALMOST_DONE' is not a defined change state" \
  scripts/validate-status.sh --status scripts/fixtures/status/malformed/status.md --quiet

expect_contains "a missing gate row is caught" \
  "expected 7 gate rows, found 6" \
  scripts/validate-status.sh --status scripts/fixtures/status/malformed/status.md --quiet

# An empty file records no state and must not pass.
: > "$WORK/empty.md"
check "empty file is rejected"            1 scripts/validate-status.sh --status "$WORK/empty.md" --quiet

# ---------------------------------------------------------------------------
# Authored blockers survive a refresh
# ---------------------------------------------------------------------------

section "Authored blockers are preserved"

scripts/status.sh --change staged --blocker "waiting on CI runner" --quiet
expect_contains "blocker recorded"        "- waiting on CI runner" cat "$C/status.md"

scripts/status.sh --change staged --quiet
expect_contains "blocker survives refresh" "- waiting on CI runner" cat "$C/status.md"

scripts/status.sh --change staged --quiet
expect_contains "blocker survives a second refresh" "- waiting on CI runner" cat "$C/status.md"

scripts/status.sh --change staged --clear-blockers --quiet
expect_absent   "clear-blockers removes it" "- waiting on CI runner" cat "$C/status.md"
expect_contains "clear-blockers leaves None." "None." cat "$C/status.md"

# ---------------------------------------------------------------------------
# Staleness
# ---------------------------------------------------------------------------

section "Stale state is detected, not trusted"

printf -- '- [x] first\n- [x] second\n' > "$C/tasks.md"
check "advanced change makes status stale" 1 scripts/validate-status.sh --change staged --quiet

expect_contains "staleness names the gate" "gate 'implementation' recorded as 'fail' but is now 'pass'" \
  scripts/validate-status.sh --change staged --quiet

expect_contains "staleness says STALE, not malformed" "STALE, not malformed" \
  scripts/validate-status.sh --change staged --quiet

scripts/status.sh --change staged --quiet
check "refresh resolves the staleness"     0 scripts/validate-status.sh --change staged --quiet

expect_contains "state advanced with the gates" "| State | REVIEWING |" cat "$C/status.md"

# ---------------------------------------------------------------------------
# Resume reporting
# ---------------------------------------------------------------------------

section "status.sh --resume — where to continue"

check "resume reports without writing"     0 scripts/status.sh --resume --change staged --quiet
expect_contains "resume names the gate"    "First incomplete gate: review" scripts/status.sh --resume --change staged
expect_contains "resume names the owner"   "Next owner:            ohmyorch-reviewer" scripts/status.sh --resume --change staged
expect_contains "resume says read-only"    "status.md was not written" scripts/status.sh --resume --change staged

scripts/status.sh --change staged --blocker "runner down" --quiet
expect_contains "resume surfaces blockers" "runner down" scripts/status.sh --resume --change staged

scripts/status.sh --change staged --clear-blockers --quiet
expect_absent   "resume omits blockers when none" "Recorded blocker(s)" scripts/status.sh --resume --change staged

# ---------------------------------------------------------------------------
# Greenfield: all gates passing
# ---------------------------------------------------------------------------

section "All gates passing"

cp scripts/fixtures/valid/PRD.md scripts/fixtures/valid/SPECS.md \
   scripts/fixtures/valid/CODEBASE.md . 2>/dev/null
printf '\nCODEBASE Context: consumed\n' >> SPECS.md
# SPECS.md must also satisfy the readiness contract for gate 7.
cp scripts/fixtures/reviews/valid/review.md "$C/review.md"
cp scripts/fixtures/test-reports/valid/test-report.md "$C/test-report.md"

scripts/status.sh --change staged --quiet
check "fully passing change validates"     0 scripts/validate-status.sh --change staged --quiet
expect_contains "state is ACCEPTED"        "| State | ACCEPTED |" cat "$C/status.md"
expect_contains "resume says none"         "First incomplete gate: none" cat "$C/status.md"
check "resume reports eligible"            0 scripts/status.sh --resume --change staged --quiet
expect_contains "resume announces eligibility" "archive-eligible" scripts/status.sh --resume --change staged

# ---------------------------------------------------------------------------
# Archived change — `openspec archive` renames the directory to
# archive/<YYYY-MM-DD>-<change>; a resuming session must be told it is done.
# ---------------------------------------------------------------------------

section "Archived change"

mkdir -p openspec/changes/archive
mv "$C" openspec/changes/archive/2026-01-01-staged
check "resume on archived change succeeds"  0 scripts/status.sh --resume --change staged
expect_contains "resume says ARCHIVED"      "is ARCHIVED" scripts/status.sh --resume --change staged
check "gate report on archived change"      0 scripts/workflow-status.sh --change staged
check "refreshing an archived change fails" 1 scripts/status.sh --change staged --quiet

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n=======================================================\n'
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS — durable workflow state holds.%s\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL — durable workflow state regressed.%s\n' "$c_red" "$c_reset"
exit 1
