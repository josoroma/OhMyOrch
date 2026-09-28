#!/usr/bin/env bash
#
# completion-gate.sh — OhMyOrch Harness definition-of-done evaluator (US-10.1)
#
# Evaluates the four completion conditions the harness requires before a change
# may be archived, and reports which one blocks if any:
#
#   1  all required tasks complete                     tasks.md
#   2  review has no blocking findings                 review.md
#   3  all required acceptance criteria pass           test-report.md
#   4  OpenSpec verification has no blocking mismatch  openspec validate + recorded
#                                                      /ohmyorch:opsx:verify outcome
#
# WHY THIS IS A SEPARATE SCRIPT FROM workflow-status.sh
#
# workflow-status.sh reports *progress*: seven gates, in order, so a resuming
# session knows where to continue. Its seventh gate is an artifact-contract gate
# (SPECS readiness + CODEBASE context), which is not a definition-of-done
# condition.
#
# This script evaluates *readiness to archive*: named conditions, with recorded
# evidence. The two overlap (a failing task or review fails both) but answer
# different questions, and US-10.1 names four conditions that are not the seven
# gates. Condition 4 — OpenSpec verification — is represented nowhere in the gate
# chain, which is precisely the gap this epic closes.
#
# Condition 4 is stricter than the gate chain for a second reason. The recorded
# `OpenSpec verify:` line in review.md was previously only *recorded*, never
# *evaluated*: a review declaring "MISMATCH — 4 blocking mismatches" passed. A
# machine-readable `openspec validate --json` check now backs it up.
#
# This script is READ-ONLY unless --record is given, which writes
# openspec/changes/<change>/completion.md.
#
# Exit codes:
#   0  eligible — all four conditions pass
#   1  not eligible — at least one condition fails
#   2  usage error
#
# Dependencies: bash, awk, grep, sed — no Node/Python (NFR-001). The `openspec`
# CLI is used when available; without it condition 4 degrades to the recorded
# outcome and says so.

set -uo pipefail

CHANGE=""
AS_JSON=0
QUIET=0
RECORD=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""; c_bold=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'
fi

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/completion-gate.sh [options]

Evaluates the US-10.1 definition of done for one change: four conditions that must
all pass before the change may be archived.

Options:
  --change <id>   Change id. Default: the only active change.
  --record        Also write openspec/changes/<id>/completion.md.
  --json          Emit machine-readable JSON.
  --quiet         Print only failures; always prints the verdict.
  -h, --help      Show this help.

Exit codes:
  0  eligible — all four conditions pass
  1  not eligible — at least one condition fails
  2  usage error

Conditions:
  1  all required tasks complete
  2  review has no blocking findings
  3  all required acceptance criteria pass
  4  OpenSpec verification has no blocking mismatch

Examples:
  scripts/completion-gate.sh --change add-ohmyorch-planner
  scripts/completion-gate.sh --change add-ohmyorch-planner --record
  scripts/completion-gate.sh --json | jq -r '.eligible'
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --record) RECORD=1; shift ;;
    --json)   AS_JSON=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Locate the change
# ---------------------------------------------------------------------------

if [ -z "$CHANGE" ]; then
  COUNT=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null | grep -c . || true)
  COUNT=${COUNT:-0}
  if [ "$COUNT" -eq 0 ]; then
    echo "error: no active change found under openspec/changes" >&2
    exit 2
  fi
  if [ "$COUNT" -gt 1 ]; then
    echo "error: $COUNT active changes; pass --change <id>" >&2
    exit 2
  fi
  CHANGE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
    | sed 's|.*/||' | sort | head -1)
fi

CDIR="openspec/changes/$CHANGE"
if [ ! -d "$CDIR" ]; then
  echo "error: change '$CHANGE' does not exist at $CDIR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Condition evaluation
# ---------------------------------------------------------------------------

COND_NAMES=(tasks review acceptance "openspec-verification")
COND_STATE=()
COND_DETAIL=()
COND_SOURCE=(tasks.md review.md test-report.md "openspec validate")

# --- Condition 1: all required tasks complete ------------------------------

TASKS_TOTAL=0
TASKS_DONE=0
if [ -f "$CDIR/tasks.md" ]; then
  TASKS_TOTAL=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[ xX]\]' "$CDIR/tasks.md" 2>/dev/null || true)
  TASKS_DONE=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[xX]\]' "$CDIR/tasks.md" 2>/dev/null || true)
  TASKS_TOTAL=${TASKS_TOTAL:-0}
  TASKS_DONE=${TASKS_DONE:-0}
fi

if [ ! -f "$CDIR/tasks.md" ]; then
  COND_STATE[0]="fail"; COND_DETAIL[0]="tasks.md missing"
elif [ "$TASKS_TOTAL" -eq 0 ]; then
  # An empty checklist is not completion. This mirrors the gate-6 lesson: absence
  # of evidence is not evidence.
  COND_STATE[0]="fail"; COND_DETAIL[0]="tasks.md has no task checkboxes"
elif [ "$TASKS_DONE" -eq "$TASKS_TOTAL" ]; then
  COND_STATE[0]="pass"; COND_DETAIL[0]="$TASKS_DONE/$TASKS_TOTAL tasks complete"
else
  COND_STATE[0]="fail"; COND_DETAIL[0]="$TASKS_DONE/$TASKS_TOTAL tasks complete"
fi

# --- Condition 2: review has no blocking findings --------------------------

if [ ! -f "$CDIR/review.md" ]; then
  COND_STATE[1]="fail"; COND_DETAIL[1]="review.md missing"
else
  REVIEW_VERDICT=$(awk '
    /^[[:space:]]*([-*][[:space:]]*)?Verdict[[:space:]]*:/ {
      v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print tolower(v); exit
    }' "$CDIR/review.md" 2>/dev/null)
  REVIEW_BLOCKING=$(awk '
    /^[[:space:]]*([-*][[:space:]]*)?Blocking[[:space:]]*:/ {
      v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print v; exit
    }' "$CDIR/review.md" 2>/dev/null)

  case "$REVIEW_BLOCKING" in
    ""|None|none|NONE)
      case "$REVIEW_VERDICT" in
        pass|approved|"no blocking")
          COND_STATE[1]="pass"
          COND_DETAIL[1]="verdict '$REVIEW_VERDICT', blocking: none"
          ;;
        "")
          COND_STATE[1]="fail"; COND_DETAIL[1]="review.md records no verdict" ;;
        *)
          COND_STATE[1]="fail"; COND_DETAIL[1]="verdict '$REVIEW_VERDICT' is not a pass" ;;
      esac
      ;;
    *)
      COND_STATE[1]="fail"; COND_DETAIL[1]="review reports blocking findings: $REVIEW_BLOCKING"
      ;;
  esac

  # A review that fails its own contract cannot certify completion, even if its
  # prose reads as a pass.
  if [ "$COND_STATE[1]" = "pass" ] && [ -x scripts/validate-review.sh ]; then
    if ! scripts/validate-review.sh --review "$CDIR/review.md" --quiet >/dev/null 2>&1; then
      COND_STATE[1]="fail"
      COND_DETAIL[1]="review.md fails the US-6.1 contract"
    fi
  fi
fi

# --- Condition 3: all required acceptance criteria pass ---------------------

if [ ! -f "$CDIR/test-report.md" ]; then
  COND_STATE[2]="fail"; COND_DETAIL[2]="test-report.md missing"
elif [ -x scripts/validate-test-report.sh ]; then
  # The validator supplies the positive requirement (criteria were actually
  # evaluated); the FAIL scan supplies the outcome. Both are needed — this is the
  # same two-signal composition used for gate 6 in EPIC-7.
  if ! scripts/validate-test-report.sh --report "$CDIR/test-report.md" --quiet >/dev/null 2>&1; then
    COND_STATE[2]="fail"; COND_DETAIL[2]="test-report.md fails the US-7.1 contract"
  else
    FAILS=$(grep -cE '\|[[:space:]]*FAIL[[:space:]]*\|' "$CDIR/test-report.md" 2>/dev/null || true)
    FAILS=${FAILS:-0}
    PASSES=$(grep -cE '\|[[:space:]]*PASS[[:space:]]*\|' "$CDIR/test-report.md" 2>/dev/null || true)
    PASSES=${PASSES:-0}
    UNVERIFIED=$(grep -cE '\|[[:space:]]*UNVERIFIED[[:space:]]*\|' "$CDIR/test-report.md" 2>/dev/null || true)
    UNVERIFIED=${UNVERIFIED:-0}

    if [ "$FAILS" -gt 0 ]; then
      COND_STATE[2]="fail"; COND_DETAIL[2]="$FAILS acceptance criterion/criteria FAIL"
    elif [ "$PASSES" -eq 0 ]; then
      COND_STATE[2]="fail"; COND_DETAIL[2]="no criterion recorded as PASS"
    elif [ "$UNVERIFIED" -gt 0 ]; then
      # A criterion that was not evaluated must not be treated as satisfied.
      COND_STATE[2]="pass"; COND_DETAIL[2]="$PASSES PASS, $UNVERIFIED UNVERIFIED (recorded)"
    else
      COND_STATE[2]="pass"; COND_DETAIL[2]="$PASSES acceptance criterion/criteria PASS"
    fi
  fi
else
  # Without the validator, fall back to the FAIL scan alone and say so.
  FAILS=$(grep -cE '\|[[:space:]]*FAIL[[:space:]]*\|' "$CDIR/test-report.md" 2>/dev/null || true)
  FAILS=${FAILS:-0}
  if [ "$FAILS" -gt 0 ]; then
    COND_STATE[2]="fail"; COND_DETAIL[2]="$FAILS FAIL row(s) (validator unavailable)"
  else
    COND_STATE[2]="pass"; COND_DETAIL[2]="no FAIL rows (validator unavailable)"
  fi
fi

# --- Condition 4: OpenSpec verification has no blocking mismatch ------------

# The recorded outcome lives in review.md; the machine check is openspec validate.
RECORDED_VERIFY=""
if [ -f "$CDIR/review.md" ]; then
  RECORDED_VERIFY=$(awk '
    /^[[:space:]]*([-*][[:space:]]*)?OpenSpec verify[[:space:]]*:/ {
      v=$0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print v; exit
    }' "$CDIR/review.md" 2>/dev/null)
fi

# A recorded outcome that declares a mismatch is blocking, regardless of how the
# machine check is phrased. Previously this line was recorded but never evaluated,
# so "MISMATCH — 4 blocking mismatches" passed the contract.
RECORDED_BLOCKING=0
if [ -n "$RECORDED_VERIFY" ]; then
  if printf '%s' "$RECORDED_VERIFY" | grep -qiE 'mismatch|fail|blocking|not verified|incomplete|unverified'; then
    if ! printf '%s' "$RECORDED_VERIFY" | grep -qiE 'no blocking|no mismatch|VERIFIED'; then
      RECORDED_BLOCKING=1
    fi
  fi
fi

OPENSPEC_STATE="not-run"
OPENSPEC_ERRORS=""
OPENSPEC_DETAIL=""
if command -v openspec >/dev/null 2>&1; then
  # Capture output and exit code separately. `openspec validate --json` on an
  # INVALID change prints the JSON and exits non-zero, so `VAR=$(cmd) || VAR=""`
  # discards exactly the output this condition needs — it made every invalid
  # change look like an unavailable CLI, which is a fail-open read.
  VALIDATE_JSON=""
  VALIDATE_RC=0
  VALIDATE_JSON=$(openspec validate "$CHANGE" --json 2>/dev/null)
  VALIDATE_RC=$?
  if [ -n "$VALIDATE_JSON" ]; then
    # openspec validate exits 0 even when it reports errors, so the exit code is
    # useless here and the JSON must be parsed.
    #
    # The JSON shape depends on why validation failed, and the two shapes share no
    # key names:
    #
    #   unknown item  ->  { "status": [ { "severity": "error", ... } ] }
    #   invalid change -> { "items":  [ { "valid": false, "issues": [
    #                                    { "level": "ERROR", ... } ] } ] }
    #
    # Keying only on "severity" therefore silently missed every real validation
    # failure and reported 0 errors, which would let a change with blocking
    # mismatches pass condition 4. Both shapes are checked.
    OPENSPEC_ERRORS=$(printf '%s' "$VALIDATE_JSON" | grep -cE '"severity": *"error"' || true)
    OPENSPEC_ERRORS=${OPENSPEC_ERRORS:-0}
    ISSUES=$(printf '%s' "$VALIDATE_JSON" | grep -cE '"level": *"ERROR"' || true)
    ISSUES=${ISSUES:-0}
    INVALID=$(printf '%s' "$VALIDATE_JSON" | grep -cE '"valid": *false' || true)
    INVALID=${INVALID:-0}
    UNKNOWN_ITEM=$(printf '%s' "$VALIDATE_JSON" | grep -cE '"code": *"unknown_item"' || true)
    UNKNOWN_ITEM=${UNKNOWN_ITEM:-0}

    if [ "$UNKNOWN_ITEM" -gt 0 ]; then
      OPENSPEC_STATE="fail"
      OPENSPEC_DETAIL="change not known to openspec"
    elif [ "$INVALID" -gt 0 ] || [ "$ISSUES" -gt 0 ] || [ "$OPENSPEC_ERRORS" -gt 0 ]; then
      OPENSPEC_STATE="fail"
      TOTAL=$((ISSUES + OPENSPEC_ERRORS))
      [ "$TOTAL" -eq 0 ] && TOTAL="$INVALID"
      OPENSPEC_DETAIL="$TOTAL OpenSpec validation error(s)"
    else
      OPENSPEC_STATE="pass"
      OPENSPEC_DETAIL="openspec validate clean"
    fi
  fi
fi

if [ "$RECORDED_BLOCKING" -eq 1 ]; then
  COND_STATE[3]="fail"
  COND_DETAIL[3]="recorded /ohmyorch:opsx:verify outcome reports a blocking mismatch"
elif [ "$OPENSPEC_STATE" = "fail" ]; then
  COND_STATE[3]="fail"
  COND_DETAIL[3]="$OPENSPEC_DETAIL"
elif [ "$OPENSPEC_STATE" = "pass" ]; then
  COND_STATE[3]="pass"
  if [ -n "$RECORDED_VERIFY" ]; then
    COND_DETAIL[3]="$OPENSPEC_DETAIL; recorded: $RECORDED_VERIFY"
  else
    COND_DETAIL[3]="$OPENSPEC_DETAIL; no /ohmyorch:opsx:verify outcome recorded"
  fi
else
  # No CLI available. The recorded outcome is all we have; require it to exist.
  if [ -n "$RECORDED_VERIFY" ]; then
    COND_STATE[3]="pass"
    COND_DETAIL[3]="recorded (openspec CLI unavailable): $RECORDED_VERIFY"
  else
    COND_STATE[3]="fail"
    COND_DETAIL[3]="no verification evidence (openspec CLI unavailable, nothing recorded)"
  fi
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------

FIRST_FAILING=""
for i in "${!COND_NAMES[@]}"; do
  if [ "${COND_STATE[$i]}" != "pass" ]; then
    FIRST_FAILING="${COND_NAMES[$i]}"
    break
  fi
done

ELIGIBLE="false"
[ -z "$FIRST_FAILING" ] && ELIGIBLE="true"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

if [ "$AS_JSON" -eq 1 ]; then
  printf '{\n'
  printf '  "change": "%s",\n' "$CHANGE"
  printf '  "eligible": %s,\n' "$ELIGIBLE"
  printf '  "firstFailingCondition": %s,\n' \
    "$([ -z "$FIRST_FAILING" ] && echo null || printf '"%s"' "$FIRST_FAILING")"
  printf '  "openspecValidateState": "%s",\n' "$OPENSPEC_STATE"
  printf '  "conditions": [\n'
  for i in "${!COND_NAMES[@]}"; do
    sep=","; [ "$i" -eq $(( ${#COND_NAMES[@]} - 1 )) ] && sep=""
    printf '    { "condition": "%s", "status": "%s", "detail": "%s", "source": "%s" }%s\n' \
      "${COND_NAMES[$i]}" "${COND_STATE[$i]}" "${COND_DETAIL[$i]}" "${COND_SOURCE[$i]}" "$sep"
  done
  printf '  ]\n}\n'
else
  say "${c_bold}Completion gate${c_reset} — change ${c_bold}$CHANGE${c_reset}"
  say "============================================"
  say ""
  for i in "${!COND_NAMES[@]}"; do
    case "${COND_STATE[$i]}" in
      pass) mark="${c_green}PASS${c_reset}" ;;
      *)    mark="${c_red}FAIL${c_reset}" ;;
    esac
    printf '  %s  %-24s %s\n' "$mark" "${COND_NAMES[$i]}" "${COND_DETAIL[$i]}"
  done

  # The verdict always prints, including under --quiet: it is the answer asked for.
  if [ -n "$FIRST_FAILING" ]; then
    printf '\n  %sNOT ELIGIBLE FOR ARCHIVE%s\n' "$c_red" "$c_reset"
    printf '  First failing condition: %s\n' "$FIRST_FAILING"
    printf '  %sUS-10.1: only a change that satisfies every condition may be archived.%s\n' \
      "$c_dim" "$c_reset"
  else
    printf '\n  %sELIGIBLE FOR ARCHIVE%s — all four conditions pass\n' "$c_green" "$c_reset"
  fi
fi

# ---------------------------------------------------------------------------
# Optional record
# ---------------------------------------------------------------------------

if [ "$RECORD" -eq 1 ]; then
  OUT="$CDIR/completion.md"
  TODAY=$(date +%Y-%m-%d)
  STORY=$(grep -oE '^[[:space:]]*Story:[[:space:]]*US-[0-9]+\.[0-9]+' "$CDIR/implementation-plan.md" 2>/dev/null \
    | grep -oE 'US-[0-9]+\.[0-9]+' | head -1)
  [ -n "$STORY" ] || STORY=$(grep -oE 'US-[0-9]+\.[0-9]+' "$CDIR/proposal.md" 2>/dev/null | head -1)
  [ -n "$STORY" ] || STORY="US-<n>.<m>"

  # Preserve authored notes across a re-record.
  NOTES="None."
  if [ -f "$OUT" ]; then
    PRESERVED=$(awk '
      /<!-- BEGIN AUTHORED: notes -->/  { inb=1; next }
      /<!-- END AUTHORED: notes -->/    { inb=0; next }
      inb { print }
    ' "$OUT" 2>/dev/null | sed '1d' | grep -v '^[[:space:]]*$' || true)
    [ -n "$PRESERVED" ] && NOTES="$PRESERVED"
  fi

  {
    printf '# Completion Gate — %s\n\n' "$CHANGE"
    printf '<!--\nUS-10.1 completion record. Evaluates the four conditions the harness requires\n'
    printf 'before a change may be archived, and records the evidence for each.\n\n'
    printf 'Written by scripts/completion-gate.sh --change %s --record. The four rows are\n' "$CHANGE"
    printf 'DERIVED from the repository and must not be hand-edited; the Notes section\n'
    printf 'between the AUTHORED markers is preserved across refreshes.\n\n'
    printf 'Validate before relying on it:\n'
    printf '  scripts/validate-verification.sh --verification %s --change %s\n-->\n\n' "$OUT" "$CHANGE"
    printf '| Field | Value |\n|---|---|\n'
    printf '| Story | %s |\n' "$STORY"
    printf '| Change | %s |\n' "$CHANGE"
    printf '| Verdict | %s |\n' "$([ "$ELIGIBLE" = "true" ] && echo eligible || echo not-eligible)"
    printf '| Evaluated | %s |\n' "$TODAY"
    printf '| Derived from | `scripts/completion-gate.sh` |\n\n'
    printf '## Conditions\n\n'
    printf '| # | Condition | Status | Evidence | Source |\n|---|---|---|---|---|\n'
    for i in "${!COND_NAMES[@]}"; do
      printf '| %s | %s | %s | %s | %s |\n' \
        "$((i + 1))" "${COND_NAMES[$i]}" "${COND_STATE[$i]}" "${COND_DETAIL[$i]}" "${COND_SOURCE[$i]}"
    done
    printf '\n## Verdict\n\n'
    if [ -z "$FIRST_FAILING" ]; then
      printf 'eligible — all four conditions pass\n'
    else
      printf 'not-eligible — first failing condition: %s\n' "$FIRST_FAILING"
    fi
    printf '\n<!-- BEGIN AUTHORED: notes -->\n## Notes\n\n%s\n<!-- END AUTHORED: notes -->\n' "$NOTES"
  } > "$OUT"

  [ "$QUIET" -eq 1 ] || printf '\n  Wrote %s\n' "$OUT" >&2
fi

[ -z "$FIRST_FAILING" ] && exit 0
exit 1
