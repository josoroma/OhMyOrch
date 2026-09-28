#!/usr/bin/env bash
#
# workflow-status.sh — OhMyOrch Harness gate reporter
#
# Reports which workflow gates a change has passed and which gate is the first
# incomplete one, so a fresh session can resume deterministically (US-3.2) and
# the Product Manager can evaluate the completion gate (US-3.1, US-10.1).
#
# This script is READ-ONLY. It reports; it never advances state, never writes
# workflow artifacts, and never edits product code. The Product Manager agent
# owns every state transition.
#
# Gate order (each gate requires all earlier gates to have passed):
#
#   1 selection      story identified and an OpenSpec change exists
#   2 planning       proposal.md, specs/**, and tasks.md exist
#   3 plan-handoff   implementation-plan.md exists              (EPIC-4)
#   4 implementation every task checkbox in tasks.md is complete
#   5 review         review.md exists with no blocking findings (EPIC-6)
#   6 testing        test-report.md exists with no FAIL          (EPIC-7)
#   7 acceptance     codebase-context + SPECS readiness valid    (EPIC-2/8)
#
# Exit codes:
#   0  reported successfully (regardless of how many gates remain)
#   1  no active change found
#   2  usage error
#
# Dependencies: bash, awk, grep, sed. Optionally uses the `openspec` CLI for
# authoritative artifact status; degrades to direct file inspection without it.

set -uo pipefail

QUIET=0
AS_JSON=0
CHANGE=""

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""; c_bold=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'
fi

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/workflow-status.sh [options]

Reports workflow gate status for an OpenSpec change. Read-only.

Options:
  --change <id>   Change id to inspect. Default: the only active change, or an
                  error if there are zero or several.
  --json          Emit machine-readable JSON instead of text.
  --quiet         Suppress the advisory footer.
  -h, --help      Show this help.

Exit codes:
  0  reported successfully
  1  no active change found
  2  usage error

Examples:
  scripts/workflow-status.sh
  scripts/workflow-status.sh --change add-ohmyorch-codebase-analyst
  scripts/workflow-status.sh --json | jq -r '.firstIncompleteGate'
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --json)   AS_JSON=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

ROOT=$(pwd)
CHANGES_DIR="openspec/changes"

# ---------------------------------------------------------------------------
# Resolve which change to inspect
# ---------------------------------------------------------------------------

if [ -z "$CHANGE" ]; then
  FOUND=$(find "$CHANGES_DIR" -maxdepth 1 -mindepth 1 -type d \
    -not -name archive 2>/dev/null | sed 's|.*/||' | sort)
  FOUND_COUNT=$(printf '%s\n' "$FOUND" | grep -c . || true)

  case "$FOUND_COUNT" in
    0) echo "error: no active change found under $CHANGES_DIR" >&2
       echo "hint: create one with 'openspec new change <id>'" >&2
       exit 1 ;;
    1) CHANGE="$FOUND" ;;
    *) echo "error: multiple active changes; pass --change <id>:" >&2
       printf '  %s\n' $FOUND >&2
       exit 1 ;;
  esac
fi

CDIR="$CHANGES_DIR/$CHANGE"

if [ ! -d "$CDIR" ]; then
  # An archived change is a valid thing to be asked about. `openspec archive`
  # names the directory `<YYYY-MM-DD>-<change>`, so match both that form and a
  # bare `<change>`; checking only the bare name reported every real archived
  # change as "not found".
  ARCHIVED=$(find "$CHANGES_DIR/archive" -maxdepth 1 -mindepth 1 -type d \
    \( -name "$CHANGE" -o -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-$CHANGE" \) \
    2>/dev/null | sort | tail -1)
  if [ -n "$ARCHIVED" ]; then
    echo "change '$CHANGE' is archived ($ARCHIVED) — nothing to resume."
    exit 0
  fi
  echo "error: change '$CHANGE' not found under $CHANGES_DIR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Gate probes
# ---------------------------------------------------------------------------

has() { [ -e "$CDIR/$1" ]; }

# True when at least one file exists under the given directory, recursively.
has_any_under() {
  [ -d "$CDIR/$1" ] && find "$CDIR/$1" -type f 2>/dev/null | head -1 | grep -q .
}

# Tasks: count "- [ ]" vs "- [x]" in tasks.md.
TASKS_TOTAL=0
TASKS_DONE=0
if has tasks.md; then
  TASKS_TOTAL=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[ xX]\]' "$CDIR/tasks.md" 2>/dev/null || true)
  TASKS_DONE=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[xX]\]' "$CDIR/tasks.md" 2>/dev/null || true)
  TASKS_TOTAL=${TASKS_TOTAL:-0}
  TASKS_DONE=${TASKS_DONE:-0}
fi

# Review: blocking findings are detected by an explicit "Blocking:" header or
# an unfilled "Findings:"/"Blocking findings:" section containing non-"None".
REVIEW_STATE="absent"
if has review.md; then
  if grep -qiE '^[[:space:]]*(#+[[:space:]]*)?(blocking|blocking findings)[[:space:]]*:' "$CDIR/review.md" 2>/dev/null; then
    if grep -iE '^[[:space:]]*(#+[[:space:]]*)?(blocking|blocking findings)[[:space:]]*:[[:space:]]*none[[:space:]]*$' "$CDIR/review.md" >/dev/null 2>&1; then
      REVIEW_STATE="pass"
    else
      REVIEW_STATE="blocking"
    fi
  else
    # No explicit blocking section: treat as passing if it declares a verdict.
    if grep -qiE '^[[:space:]]*(#+[[:space:]]*)?(verdict|result|status)[[:space:]]*:[[:space:]]*(pass|approved|no blocking)[[:space:]]*$' "$CDIR/review.md" >/dev/null 2>&1; then
      REVIEW_STATE="pass"
    else
      REVIEW_STATE="unknown"
    fi
  fi
fi

# Review contract, delegated to the EPIC-6 validator when available. A review
# that passes its own contract still counts as `blocking` when it declares
# blocking findings, so the two signals are combined rather than replaced.
REVIEW_CONTRACT="n/a"
REVIEW_DETAIL=""
if has review.md && [ -x scripts/validate-review.sh ]; then
  if scripts/validate-review.sh \
       --review "$CDIR/review.md" --quiet >/dev/null 2>&1; then
    REVIEW_CONTRACT="pass"
  else
    REVIEW_CONTRACT="fail"
    REVIEW_DETAIL=$(scripts/validate-review.sh \
      --review "$CDIR/review.md" --quiet 2>&1 \
      | grep -c '^  FAIL' || true)
    REVIEW_DETAIL=${REVIEW_DETAIL:-0}
  fi
fi

# Testing: any FAIL row in test-report.md that is not the word inside prose.
#
# This is a NEGATIVE check: absence of FAIL is not evidence of testing. An empty
# report has no FAIL row, so it used to pass this gate. The validator below
# supplies the missing positive requirement (criteria were actually evaluated),
# and the two signals are combined.
TEST_STATE="absent"
if has test-report.md; then
  if grep -qE '\|[[:space:]]*FAIL[[:space:]]*\|' "$CDIR/test-report.md" 2>/dev/null \
     || grep -qE '^[[:space:]]*(FAIL)[[:space:]]*:' "$CDIR/test-report.md" 2>/dev/null; then
    TEST_STATE="fail"
  else
    TEST_STATE="pass"
  fi
fi

# Test-report contract, delegated to the EPIC-7 validator when available.
TEST_CONTRACT="n/a"
TEST_DETAIL=""
if has test-report.md && [ -x scripts/validate-test-report.sh ]; then
  if scripts/validate-test-report.sh \
       --report "$CDIR/test-report.md" --quiet >/dev/null 2>&1; then
    TEST_CONTRACT="pass"
  else
    TEST_CONTRACT="fail"
    TEST_DETAIL=$(scripts/validate-test-report.sh \
      --report "$CDIR/test-report.md" --quiet 2>&1 \
      | grep -c '^  FAIL' || true)
    TEST_DETAIL=${TEST_DETAIL:-0}
  fi
fi

# Codebase-context acknowledgment in SPECS.md / PRD.md (EPIC-2 contract).
#
# Product documents may live at the repository root or under docs/. These references
# were root-only, so relocating the docs made gate 7 report a context failure for a
# repository whose SPECS.md did record consuming CODEBASE.md.
DOCS=""
[ -f docs/SPECS.md ] && DOCS="docs/"
SPECS_PATH="${DOCS}SPECS.md"
CODEBASE_PATH="${DOCS}CODEBASE.md"

CONTEXT_STATE="n/a"
if [ -f "$CODEBASE_PATH" ]; then
  if grep -qiE '^[[:space:]>*-]*CODEBASE Context:' "$SPECS_PATH" 2>/dev/null; then
    CONTEXT_STATE="pass"
  else
    CONTEXT_STATE="missing"
  fi
fi

# SPECS readiness contract, delegated to the EPIC-2 validator when available.
SPECS_STATE="n/a"
if [ -x scripts/validate-product-artifacts.sh ] && [ -f "$SPECS_PATH" ]; then
  if scripts/validate-product-artifacts.sh --quiet >/dev/null 2>&1; then
    SPECS_STATE="pass"
  else
    SPECS_STATE="fail"
  fi
fi

# Implementation-plan contract, delegated to the EPIC-4 validator when available.
PLAN_STATE="n/a"
PLAN_DETAIL=""
if has implementation-plan.md; then
  if [ -x scripts/validate-implementation-plan.sh ]; then
    if scripts/validate-implementation-plan.sh \
         --plan "$CDIR/implementation-plan.md" --quiet >/dev/null 2>&1; then
      PLAN_STATE="pass"
    else
      PLAN_STATE="fail"
      PLAN_DETAIL=$(scripts/validate-implementation-plan.sh \
        --plan "$CDIR/implementation-plan.md" --quiet 2>&1 \
        | grep -c '^  FAIL' || true)
      PLAN_DETAIL="${PLAN_DETAIL:-0}"
    fi
  else
    PLAN_STATE="unvalidated"
  fi
fi

# ---------------------------------------------------------------------------
# Evaluate gates
# ---------------------------------------------------------------------------

GATE_NAMES=(selection planning plan-handoff implementation review testing acceptance)
GATE_STATE=()
GATE_DETAIL=()
GATE_OWNER=()

GATE_STATE[0]="pass"; GATE_DETAIL[0]="change '$CHANGE' exists"; GATE_OWNER[0]="ohmyorch-product-manager"

if has proposal.md && has_any_under specs && has tasks.md; then
  GATE_STATE[1]="pass"; GATE_DETAIL[1]="proposal.md, specs/, tasks.md present"
else
  missing=""
  has proposal.md || missing="proposal.md"
  has_any_under specs || missing="${missing:+$missing, }specs/"
  has tasks.md || missing="${missing:+$missing, }tasks.md"
  GATE_STATE[1]="fail"; GATE_DETAIL[1]="missing: $missing"
fi
GATE_OWNER[1]="ohmyorch-planner (via /ohmyorch:opsx:propose)"

if [ ! -e "$CDIR/implementation-plan.md" ]; then
  GATE_STATE[2]="fail"; GATE_DETAIL[2]="implementation-plan.md missing"
  [ "${GATE_STATE[1]}" = "fail" ] && GATE_DETAIL[2]="${GATE_DETAIL[2]} (blocked by planning)"
elif [ "$PLAN_STATE" = "fail" ]; then
  GATE_STATE[2]="fail"
  GATE_DETAIL[2]="implementation-plan.md fails the US-4.1 contract ($PLAN_DETAIL failure(s))"
else
  GATE_STATE[2]="pass"
  if [ "$PLAN_STATE" = "unvalidated" ]; then
    GATE_DETAIL[2]="implementation-plan.md present (validator unavailable)"
  else
    GATE_DETAIL[2]="implementation-plan.md satisfies the Planner-handoff contract"
  fi
fi
GATE_OWNER[2]="ohmyorch-planner (/ohmyorch-plan-feature)"

if [ "$TASKS_TOTAL" -eq 0 ]; then
  GATE_STATE[3]="fail"; GATE_DETAIL[3]="no task checkboxes in tasks.md"
elif [ "$TASKS_DONE" -eq "$TASKS_TOTAL" ]; then
  GATE_STATE[3]="pass"; GATE_DETAIL[3]="$TASKS_DONE/$TASKS_TOTAL tasks complete"
else
  GATE_STATE[3]="fail"; GATE_DETAIL[3]="$TASKS_DONE/$TASKS_TOTAL tasks complete"
fi
GATE_OWNER[3]="ohmyorch-implementer (/ohmyorch:opsx:apply)"

case "$REVIEW_STATE" in
  pass)
    if [ "$REVIEW_CONTRACT" = "fail" ]; then
      GATE_STATE[4]="fail"
      GATE_DETAIL[4]="review.md fails the US-6.1 contract ($REVIEW_DETAIL failure(s))"
    else
      GATE_STATE[4]="pass"; GATE_DETAIL[4]="review.md present, no blocking findings"
    fi
    ;;
  blocking) GATE_STATE[4]="fail"; GATE_DETAIL[4]="review.md reports blocking findings" ;;
  unknown)  GATE_STATE[4]="fail"; GATE_DETAIL[4]="review.md present but no explicit verdict" ;;
  *)        GATE_STATE[4]="fail"; GATE_DETAIL[4]="review.md missing" ;;
esac
GATE_OWNER[4]="ohmyorch-reviewer (/ohmyorch-review-feature)"

case "$TEST_STATE" in
  pass)
    if [ "$TEST_CONTRACT" = "fail" ]; then
      GATE_STATE[5]="fail"
      GATE_DETAIL[5]="test-report.md fails the US-7.1 contract ($TEST_DETAIL failure(s))"
    else
      GATE_STATE[5]="pass"; GATE_DETAIL[5]="test-report.md present, no FAIL rows"
    fi
    ;;
  fail) GATE_STATE[5]="fail"; GATE_DETAIL[5]="test-report.md reports FAIL" ;;
  *)    GATE_STATE[5]="fail"; GATE_DETAIL[5]="test-report.md missing" ;;
esac
GATE_OWNER[5]="ohmyorch-tester (/ohmyorch-test-feature)"

if [ "$CONTEXT_STATE" = "missing" ]; then
  GATE_STATE[6]="fail"; GATE_DETAIL[6]="CODEBASE.md exists but SPECS.md does not record consuming it"
elif [ "$SPECS_STATE" = "fail" ]; then
  GATE_STATE[6]="fail"; GATE_DETAIL[6]="SPECS.md fails the readiness/context contract"
else
  GATE_STATE[6]="pass"; GATE_DETAIL[6]="artifact contracts satisfied"
fi
GATE_OWNER[6]="ohmyorch-product-manager"

FIRST_INCOMPLETE=""
FIRST_INCOMPLETE_OWNER=""
for i in "${!GATE_NAMES[@]}"; do
  if [ "${GATE_STATE[$i]}" != "pass" ]; then
    FIRST_INCOMPLETE="${GATE_NAMES[$i]}"
    FIRST_INCOMPLETE_OWNER="${GATE_OWNER[$i]}"
    break
  fi
done

ARCHIVE_ELIGIBLE="false"
[ -z "$FIRST_INCOMPLETE" ] && ARCHIVE_ELIGIBLE="true"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

if [ "$AS_JSON" -eq 1 ]; then
  printf '{\n'
  printf '  "change": "%s",\n' "$CHANGE"
  printf '  "root": "%s",\n' "$ROOT"
  printf '  "tasks": { "total": %s, "complete": %s },\n' "$TASKS_TOTAL" "$TASKS_DONE"
  printf '  "firstIncompleteGate": %s,\n' "$([ -z "$FIRST_INCOMPLETE" ] && echo null || printf '"%s"' "$FIRST_INCOMPLETE")"
  printf '  "archiveEligible": %s,\n' "$ARCHIVE_ELIGIBLE"
  printf '  "gates": [\n'
  for i in "${!GATE_NAMES[@]}"; do
    sep=","; [ "$i" -eq $(( ${#GATE_NAMES[@]} - 1 )) ] && sep=""
    printf '    { "gate": "%s", "status": "%s", "detail": "%s", "owner": "%s" }%s\n' \
      "${GATE_NAMES[$i]}" "${GATE_STATE[$i]}" "${GATE_DETAIL[$i]}" "${GATE_OWNER[$i]}" "$sep"
  done
  printf '  ]\n}\n'
  exit 0
fi

say "${c_bold}Workflow status${c_reset} — change ${c_bold}$CHANGE${c_reset}"
say "============================================"
say ""

for i in "${!GATE_NAMES[@]}"; do
  case "${GATE_STATE[$i]}" in
    pass) mark="${c_green}PASS${c_reset}" ;;
    *)    mark="${c_red}----${c_reset}" ;;
  esac
  printf '  %s  %-16s %s\n' "$mark" "${GATE_NAMES[$i]}" "${GATE_DETAIL[$i]}"
  [ "${GATE_STATE[$i]}" != "pass" ] && printf '        %snext owner: %s%s\n' "$c_dim" "${GATE_OWNER[$i]}" "$c_reset"
done

# The verdict always prints, including under --quiet: it is the answer the
# caller asked for, not commentary.
if [ -n "$FIRST_INCOMPLETE" ]; then
  printf '\n  First incomplete gate: %s%s%s\n' "$c_yellow" "$FIRST_INCOMPLETE" "$c_reset"
  printf '  Next owner:            %s\n' "$FIRST_INCOMPLETE_OWNER"
  printf '  %sNOT archive-eligible%s\n' "$c_red" "$c_reset"
else
  printf '\n  %sAll gates passed — archive-eligible%s\n' "$c_green" "$c_reset"
fi

if [ "$QUIET" -eq 0 ]; then
  say ""
  say "  ${c_dim}Read-only report. No state was changed. The Product Manager agent${c_reset}"
  say "  ${c_dim}owns every transition; this script only informs the decision.${c_reset}"
fi

exit 0
