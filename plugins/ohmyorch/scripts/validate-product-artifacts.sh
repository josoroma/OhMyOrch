#!/usr/bin/env bash
#
# validate-product-artifacts.sh — OhMyOrch Harness product-artifact validator
#
# Implements the validation contracts specified by US-2.7:
#
#   SPECS.md     unique Epic and User Story identifiers; every READY story has
#                at least one acceptance scenario; every scenario has Given,
#                When, and Then; every READY story is source-traceable; every
#                status value is in the defined vocabulary.
#
#   CODEBASE.md  when present, carries the required current-state schema
#                (analyzed revision, system summary, repository map, runtime
#                and tooling, evidence paths, unknowns).
#
#   PRD.md       when CODEBASE.md exists, records that CODEBASE.md was part of
#   SPECS.md     the generation context, or records an explicit skip decision.
#
# Exit codes:
#   0  all required checks passed (warnings may still have been reported)
#   1  at least one required check failed
#   2  usage error, unreadable input, or hook mode blocking a write
#
# Dependencies: bash, awk, grep, sed. Deliberately no Node/Python so the
# validator stays portable across arbitrary host repositories (NFR-001).

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

# Resolve a product document, tolerating a docs/ subdirectory.
#
# The harness documentation may live at the repository root or under docs/. These
# defaults previously assumed the root unconditionally, so relocating the docs
# silently broke every default path — the validator reported "SPECS.md not found"
# for a repository that had a perfectly good docs/SPECS.md. Prefer docs/ only when
# the file is actually there, so a root layout keeps working unchanged (NFR-001:
# the harness must adapt to arbitrary host repositories).
doc_path() { ohmyorch_doc_path "$1"; }

SPECS_FILE="$(doc_path SPECS.md)"
PRD_FILE="$(doc_path PRD.md)"
CODEBASE_FILE="$(doc_path CODEBASE.md)"

QUIET=0
HOOK_MODE=0

# Story status vocabulary (PRD.md section 9, FR-004).
VALID_STATUSES=(
  "READY"
  "NEEDS CLARIFICATION"
  "BLOCKED"
  "IN PROGRESS"
  "DONE"
)

# CODEBASE.md headings that must be present (US-2.2 "stable current-state schema").
REQUIRED_CODEBASE_SECTIONS=(
  "System Summary"
  "Repository Map"
  "Runtime and Tooling"
  "Evidence Paths"
  "Unknowns"
)

# CODEBASE.md headings that are expected but conditional on discoverability
# ("...when discoverable"). Absence is a warning, not a failure.
ADVISORY_CODEBASE_SECTIONS=(
  "Architecture"
  "Entry Points"
  "Data and Persistence"
  "External Integrations"
  "Authentication and Authorization"
  "Existing Product Behavior"
  "Tests and Quality Gates"
  "Common Commands"
  "Conventions"
  "Constraints and Technical Debt"
)

FAILURES=0
WARNINGS=0

# ----------------------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------------------

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ${c_green}PASS${c_reset}  $*"; }
# Warnings, failures and their guidance print even under --quiet: suppressing a
# failure would hide the reason a run failed.
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
section() { say ""; say "$*"; }

# ----------------------------------------------------------------------------
# Usage
# ----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: ohmyorch validate-product-artifacts [options]

Validates OhMyOrch Harness product artifacts against the US-2.7 contracts.

Options:
  --specs <file>      Path to SPECS.md      (default: SPECS.md)
  --prd <file>        Path to PRD.md        (default: PRD.md)
  --codebase <file>   Path to CODEBASE.md   (default: CODEBASE.md)
  --hook              Hook mode. Reads the Claude Code hook JSON on stdin,
                      validates only the edited file, and exits 2 on failure
                      with diagnostics on stderr. PostToolUse cannot undo a write.
  --quiet             Suppress passing checks; print only warnings and failures.
  -h, --help          Show this help.

Exit codes:
  0  all required checks passed
  1  at least one required check failed
  2  usage error, unreadable input, or hook-mode block

Examples:
  "${OHMYORCH_CODE_ROOT}/scripts/validate-product-artifacts.sh"
  "${OHMYORCH_CODE_ROOT}/scripts/validate-product-artifacts.sh" --specs SPECS.md --quiet
  printf '%s' "$HOOK_JSON" | ohmyorch validate-product-artifacts --hook
EOF
}

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --specs)     [ $# -ge 2 ] || { echo "error: --specs needs a value" >&2; exit 2; }; SPECS_FILE="$2"; shift 2 ;;
      --prd)       [ $# -ge 2 ] || { echo "error: --prd needs a value" >&2; exit 2; }; PRD_FILE="$2"; shift 2 ;;
      --codebase)  [ $# -ge 2 ] || { echo "error: --codebase needs a value" >&2; exit 2; }; CODEBASE_FILE="$2"; shift 2 ;;
      --hook)      HOOK_MODE=1; shift ;;
      --quiet)     QUIET=1; shift ;;
      -h|--help)   usage; exit 0 ;;
      *)           echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
  done
}

# ----------------------------------------------------------------------------
# SPECS.md checks
# ----------------------------------------------------------------------------

# Emit one TSV record per user story:
#   story_id <TAB> status <TAB> has_source <TAB> scenarios <TAB> bad_scenarios
parse_stories() {
  awk '
    function endscen() {
      if (scen > 0 && !(g && w && t)) badscen++
      g = 0; w = 0; t = 0
    }
    function flush() {
      if (story != "") {
        endscen()
        printf "%s\t%s\t%d\t%d\t%d\n", story, (status == "" ? "MISSING" : status),
               source, scen, badscen
      }
    }
    /^### US-[0-9]+\.[0-9]+:/ {
      flush()
      story = $0
      sub(/^### /, "", story)
      sub(/:.*$/, "", story)
      status = ""; source = 0; scen = 0; badscen = 0
      g = 0; w = 0; t = 0
      next
    }
    /^# EPIC-/ {
      flush()
      story = ""; status = ""; source = 0; scen = 0; badscen = 0
      g = 0; w = 0; t = 0
      next
    }
    story != "" && /^Status:/ {
      status = $0
      sub(/^Status:[ \t]*/, "", status)
      sub(/[ \t]+$/, "", status)
      next
    }
    story != "" && /^Source:/                 { source = 1; next }
    story != "" && /^Scenario:/               { endscen(); scen++; next }
    story != "" && /^[ \t]*Given[ \t]/       { g = 1; next }
    story != "" && /^[ \t]*When[ \t]/        { w = 1; next }
    story != "" && /^[ \t]*Then[ \t]/        { t = 1; next }
    END { flush() }
  ' "$1"
}

status_is_valid() {
  local candidate="$1" v
  for v in "${VALID_STATUSES[@]}"; do
    [ "$candidate" = "$v" ] && return 0
  done
  return 1
}

check_specs() {
  local file="$1"

  section "SPECS.md — $file"

  if [ ! -f "$file" ]; then
    fail "SPECS.md not found at '$file'"
    note "fix: create SPECS.md, or pass --specs <path>"
    return
  fi

  # --- unique identifiers -------------------------------------------------
  local epic_count story_count dup
  epic_count=$(grep -cE '^# EPIC-[0-9]+:' "$file" || true)
  story_count=$(grep -cE '^### US-[0-9]+\.[0-9]+:' "$file" || true)

  dup=$(grep -oE '^# EPIC-[0-9]+:' "$file" | sort | uniq -d || true)
  if [ -n "$dup" ]; then
    while IFS= read -r d; do
      [ -n "$d" ] && fail "duplicate Epic identifier: ${d#\# }"
    done <<< "$dup"
    note "fix: renumber the duplicated Epic so every Epic identifier is unique"
  else
    pass "Epic identifiers unique ($epic_count found)"
  fi

  dup=$(grep -oE '^### US-[0-9]+\.[0-9]+:' "$file" | sort | uniq -d || true)
  if [ -n "$dup" ]; then
    while IFS= read -r d; do
      [ -n "$d" ] && fail "duplicate User Story identifier: ${d#\#\#\# }"
    done <<< "$dup"
    note "fix: renumber the duplicated story so every User Story identifier is unique"
  else
    pass "User Story identifiers unique ($story_count found)"
  fi

  if [ "$story_count" -eq 0 ]; then
    warn "no User Story headers found (expected '### US-N.M: <title>')"
    return
  fi

  # --- per-story rules ----------------------------------------------------
  local bad_status=0 bad_ready=0 bad_source=0 untested=0
  local story status has_source scenarios bad_scenarios

  while IFS=$'\t' read -r story status has_source scenarios bad_scenarios; do
    [ -z "$story" ] && continue

    if [ "$status" = "MISSING" ]; then
      fail "$story: missing 'Status:' line"
      note "fix: add 'Status: <READY|NEEDS CLARIFICATION|BLOCKED|IN PROGRESS|DONE>'"
      bad_status=$((bad_status + 1))
      continue
    fi

    if ! status_is_valid "$status"; then
      fail "$story: invalid status '$status'"
      note "allowed: READY, NEEDS CLARIFICATION, BLOCKED, IN PROGRESS, DONE"
      bad_status=$((bad_status + 1))
      continue
    fi

    # Acceptance criteria and traceability gate on READY only (US-2.7).
    if [ "$status" = "READY" ]; then
      if [ "$scenarios" -eq 0 ]; then
        fail "$story: READY but contains no acceptance scenario"
        note "fix: add at least one gherkin scenario, or move the story out of READY"
        bad_ready=$((bad_ready + 1))
      elif [ "$bad_scenarios" -gt 0 ]; then
        fail "$story: $bad_scenarios of $scenarios scenario(s) lack Given/When/Then"
        note "fix: every acceptance scenario needs all three of Given, When, Then"
        bad_ready=$((bad_ready + 1))
      fi

      if [ "$has_source" -eq 0 ]; then
        fail "$story: READY but has no 'Source:' reference"
        note "fix: cite the product source or the explicit Product Manager decision"
        bad_source=$((bad_source + 1))
      fi
    else
      untested=$((untested + 1))
    fi
  done < <(parse_stories "$file")

  [ "$bad_status" -eq 0 ] && pass "every story declares a valid status"
  [ "$bad_ready" -eq 0 ]  && pass "every READY story has complete Given/When/Then acceptance criteria"
  [ "$bad_source" -eq 0 ] && pass "every READY story is source-traceable"

  if [ "$untested" -gt 0 ]; then
    note "$untested story/stories are not READY — acceptance checks not applied (correct unless they should be READY)"
  fi
}

# ----------------------------------------------------------------------------
# CODEBASE.md checks
# ----------------------------------------------------------------------------

check_codebase() {
  local file="$1"

  section "CODEBASE.md — $file"

  if [ ! -f "$file" ]; then
    note "not present — skipping schema validation"
    note "(absent is valid for greenfield; it MUST be present once a brownfield analysis runs)"
    return
  fi

  # Analyzed revision / snapshot identifier.
  if grep -qiE '^[[:space:]>*-]*Analyzed revision:' "$file"; then
    local rev
    rev=$(grep -iE '^[[:space:]>*-]*Analyzed revision:' "$file" | head -1 | sed 's/.*Analyzed revision:[[:space:]]*//')
    if [ -z "$rev" ] || [ "$rev" = "unknown" ]; then
      warn "analyzed revision recorded but empty or 'unknown'"
      note "record the git revision or other snapshot identifier when available"
    else
      pass "records an analyzed revision ($rev)"
    fi
  else
    fail "missing 'Analyzed revision:' metadata"
    note "fix: add 'Analyzed revision: <git-sha-or-snapshot>' near the top (NFR-005)"
  fi

  # Required headings.
  local missing_required=0 s
  for s in "${REQUIRED_CODEBASE_SECTIONS[@]}"; do
    if grep -qiE "^##[[:space:]]+${s}[[:space:]]*$" "$file"; then
      pass "has required section: ## $s"
    else
      fail "missing required section: ## $s"
      missing_required=$((missing_required + 1))
    fi
  done
  [ "$missing_required" -gt 0 ] && note "fix: add the missing sections listed above"

  # Advisory headings (discoverability-dependent).
  local missing_advisory=""
  for s in "${ADVISORY_CODEBASE_SECTIONS[@]}"; do
    grep -qiE "^##[[:space:]]+${s}[[:space:]]*$" "$file" || missing_advisory="${missing_advisory:+$missing_advisory, }$s"
  done
  if [ -n "$missing_advisory" ]; then
    warn "no section for: $missing_advisory"
    note "these are conditional on discoverability; confirm they were genuinely not discoverable"
  else
    pass "all advisory sections present"
  fi
}

# ----------------------------------------------------------------------------
# PRD.md / SPECS.md context-consumption checks
# ----------------------------------------------------------------------------

# Recognises the explicit acknowledgment marker:
#   CODEBASE Context: consumed (<revision>) | skipped (<reason>) | absent
has_context_marker() {
  grep -qiE '^[[:space:]>*-]*CODEBASE Context:' "$1"
}

describe_marker() {
  grep -iE '^[[:space:]>*-]*CODEBASE Context:' "$1" | head -1 | sed 's/^[[:space:]>*-]*//'
}

check_context_consumption() {
  local label="$1" file="$2"

  section "$label — $file"

  if [ ! -f "$file" ]; then
    note "not present — skipping context-consumption check"
    return
  fi

  if [ ! -f "$CODEBASE_FILE" ]; then
    if has_context_marker "$file" && describe_marker "$file" | grep -qiE 'CODEBASE Context:[[:space:]]*absent'; then
      pass "records greenfield context: $(describe_marker "$file")"
    elif has_context_marker "$file"; then
      warn "$file declares codebase context but $CODEBASE_FILE does not exist"
      note "remove the marker, or run /ohmyorch:analyze-codebase to create $CODEBASE_FILE"
    else
      pass "no $CODEBASE_FILE present, so no context acknowledgment is required"
    fi
    return
  fi

  # CODEBASE.md exists, so the artifact must record that it was consumed.
  if has_context_marker "$file"; then
    local marker
    marker=$(describe_marker "$file")
    if printf '%s' "$marker" | grep -qiE 'skipped'; then
      warn "records an explicit skip decision: $marker"
      note "verify the Product Manager intended to skip codebase context (FR-017)"
    else
      pass "records codebase context consumption: $marker"
    fi
  else
    fail "$CODEBASE_FILE exists but $file does not record consuming it"
    note "fix: add a line such as 'CODEBASE Context: consumed (<revision>)' (BR-006, FR-017)"
    note "     or record a deliberate skip: 'CODEBASE Context: skipped (<reason>)'"
  fi
}

# ----------------------------------------------------------------------------
# Hook mode
# ----------------------------------------------------------------------------

run_hook() {
  local hook_input file_path relative_path base

  hook_input=$(cat)
  [ -z "$hook_input" ] && exit 0

  jq -e 'type == "object" and
    (.tool_input.file_path == null or (.tool_input.file_path | type == "string"))' \
    >/dev/null 2>&1 <<< "$hook_input" || { printf 'invalid product-validation hook payload\n' >&2; exit 2; }
  file_path=$(jq -r '.tool_input.file_path // ""' <<< "$hook_input")

  [ -z "$file_path" ] && exit 0

  relative_path=$(ohmyorch_relative "$file_path") || exit 2
  file_path="$OHMYORCH_PROJECT_ROOT/$relative_path"
  base=$(basename -- "$file_path")
  case "$relative_path" in
    "$OHMYORCH_DOC_SPECS") check_specs "$file_path"
                  check_context_consumption "SPECS.md" "$file_path" ;;
    "$OHMYORCH_DOC_CODEBASE") check_codebase "$file_path" ;;
    "$OHMYORCH_DOC_PRD") check_context_consumption "PRD.md" "$file_path" ;;
    *)            exit 0 ;;
  esac

  if [ "$FAILURES" -gt 0 ]; then
    printf '\n%s: %d validation failure(s). Fix them before proceeding.\n' \
      "$base" "$FAILURES" >&2
    exit 2
  fi
  exit 0
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

parse_args "$@"

if [ "$HOOK_MODE" -eq 1 ]; then
  run_hook >&2
fi

say "OhMyOrch Harness — product artifact validation"
say "============================================"

check_specs "$SPECS_FILE"
check_codebase "$CODEBASE_FILE"
check_context_consumption "PRD.md" "$PRD_FILE"
# SPECS.md carries the same obligation (US-2.7 scenario 5, BR-006). This call was
# missing, so a SPECS.md that ignored an existing CODEBASE.md passed validation.
check_context_consumption "SPECS.md" "$SPECS_FILE"

section "Summary"
say "  failures: $FAILURES"
say "  warnings: $WARNINGS"

if [ "$FAILURES" -gt 0 ]; then
  say ""
  printf '  %sRESULT: FAIL%s — %s required check(s) failed.\n' "$c_red" "$c_reset" "$FAILURES"
  exit 1
fi

say ""
say "  ${c_green}RESULT: PASS${c_reset} — all required checks passed${WARNINGS:+, $WARNINGS warning(s)}."
exit 0
