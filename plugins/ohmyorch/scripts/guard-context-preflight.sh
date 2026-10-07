#!/usr/bin/env bash
#
# guard-context-preflight.sh — US-8.2 guards for CODEBASE context
#
# Implements three scenarios:
#
#   Require CODEBASE context before PRD generation
#     Given CODEBASE.md exists
#     When  the harness attempts to generate or materially update PRD.md
#     Then  a pre-generation guard MUST require CODEBASE.md in the specifier context
#
#   Require CODEBASE context before SPECS generation
#     Same, for SPECS.md and the ingest context
#
#   Detect missing brownfield analysis
#     Given a meaningful existing codebase is detected
#     And   CODEBASE.md does not exist
#     When  PRD or SPECS generation is requested
#     Then  the guard MUST require codebase analysis first, or an explicit
#           recorded skip decision
#
# Wired as a PreToolUse hook on Write|Edit|MultiEdit.
#
# IMPORTANT — what this guard CAN and CANNOT check.
#
# A hook runs before the write. At that moment the artifact's new content does not
# exist on disk, so the guard cannot inspect it for the `CODEBASE Context:` marker
# that validate-product-artifacts.sh (US-2.7) requires afterwards. That check is
# therefore a post-write concern and is deliberately NOT duplicated here.
#
# What this guard does instead is enforce the PRECONDITION that makes the marker
# meaningful: the state of the repository at the moment generation starts. It
# blocks the two states in which generation must not begin:
#
#   * CODEBASE.md exists but is stale relative to HEAD  (surface before trusting it)
#   * a meaningful codebase exists but CODEBASE.md is absent, with no recorded skip
#
# Fails open whenever it cannot determine the situation.
#
# Usage:
#   guard-context-preflight.sh --hook
#   guard-context-preflight.sh --file <path>
#
# Exit codes: 0 allow, 2 block, 3 usage error.

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

HOOK_MODE=0
FILE=""
QUIET=0

c_reset=""; c_red=""; c_dim=""; c_yellow=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_yellow=$'\033[33m'
fi

usage() {
  cat <<'EOF'
Usage: guard-context-preflight.sh (--hook | --file <path>)

Blocks PRD.md / SPECS.md generation that starts from missing or stale CODEBASE
context (US-8.2). Fails open when the situation cannot be determined.

Options:
  --hook          Read Claude Code hook JSON on stdin (PreToolUse)
  --file <path>   Check a specific path (direct mode)
  --quiet         Suppress the allow message
  -h, --help      Show this help

Exit codes: 0 allow, 2 blocked, 3 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)  HOOK_MODE=1; shift ;;
    --file)  [ $# -ge 2 ] || { echo "error: --file needs a value" >&2; exit 3; }; FILE="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  [ -z "$HOOK_INPUT" ] && exit 0
  FILE=$(jq -er '.tool_input.file_path // "" | select(type=="string")' <<< "$HOOK_INPUT") || exit 2
  [ -z "$FILE" ] && exit 0
fi

[ -n "$FILE" ] || { echo "error: a path is required (--file, or --hook with file_path)" >&2; exit 3; }

[ -z "$FILE" ] || FILE=$(ohmyorch_relative "$FILE") || exit 2

# ---------------------------------------------------------------------------
# This guard only concerns the two generated product artifacts
# ---------------------------------------------------------------------------

BASE=$(basename -- "$FILE")
case "$FILE" in
  "$OHMYORCH_DOC_PRD"|"$OHMYORCH_DOC_SPECS") ;;
  *) exit 0 ;;
esac

# The fixtures used to test the validator are not real artifacts.
case "$FILE" in */fixtures/*) exit 0 ;; esac

# ---------------------------------------------------------------------------
# Is this a brownfield repository?
# ---------------------------------------------------------------------------
#
# "Meaningful codebase" is judged by the presence of source or a package manifest,
# not by counting files: a docs-only repository is greenfield and must not be
# forced through codebase analysis.

detect_codebase() {
  # A package manifest is the strongest single signal.
  for m in package.json pyproject.toml go.mod Cargo.toml pom.xml build.gradle \
           Gemfile composer.json CMakeLists.txt Makefile; do
    [ -f "$m" ] && return 0
  done
  # Otherwise, any source file outside the harness's own directories.
  find . -maxdepth 3 -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
    -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \
    -o -name '*.rb' -o -name '*.cs' -o -name '*.php' -o -name '*.ex' \
    -o -name '*.swift' -o -name '*.kt' -o -name '*.c' -o -name '*.cc' \
    -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' -o -name '*.sh' \) \
    -not -path './.git/*' -not -path './.claude/*' -not -path './openspec/*' \
    -not -path '*/node_modules/*' \
    2>/dev/null | head -1 | grep -q .
}

# Product documents may live at the repository root or under docs/.
skip_recorded() {
  grep -qiE 'CODEBASE Context:[[:space:]]*skipped' "$OHMYORCH_DOC_PRD" "$OHMYORCH_DOC_SPECS" 2>/dev/null && return 0
  [ -f .codebase-skip ] && return 0
  return 1
}

HAS_CODEBASE=0
detect_codebase && HAS_CODEBASE=1

HAS_CODEBASE_MD=0
[ -f "$OHMYORCH_DOC_CODEBASE" ] && HAS_CODEBASE_MD=1

# ---------------------------------------------------------------------------
# Guard 1 and 2 — CODEBASE.md present: check staleness before trusting it
# ---------------------------------------------------------------------------

if [ "$HAS_CODEBASE_MD" -eq 1 ]; then
  RECORDED=$(awk '
    { line=$0; sub(/^[[:space:]]*/,"",line); sub(/^(\[|[:>*-])[[:space:]]*/,"",line) }
    tolower(line) ~ /^analyzed revision:/ { sub(/^[^:]*:[[:space:]]*/,"",line); gsub(/[[:space:]]+$/,"",line); print line; exit }
  ' "$OHMYORCH_DOC_CODEBASE" 2>/dev/null)

  if [ -n "$RECORDED" ] && [ "$RECORDED" != "unknown" ] \
     && git rev-parse --verify --quiet "$RECORDED" >/dev/null 2>&1; then
    CHANGED=$(git diff --name-only "$RECORDED"..HEAD 2>/dev/null | grep -c . || true)
    CHANGED=${CHANGED:-0}
    if [ "$CHANGED" -gt 0 ]; then
      printf '%sBLOCKED%s  %s\n' "$c_red" "$c_reset" "$FILE" >&2
      printf '  %sCODEBASE.md describes %s, but HEAD has moved on (%s file(s) changed).%s\n' \
        "$c_dim" "$RECORDED" "$CHANGED" "$c_reset" >&2
      printf '\n' >&2
      printf '  %sUS-8.2: surface the stale-context condition before treating CODEBASE.md as current.%s\n' \
        "$c_yellow" "$c_reset" >&2
      printf '  Run /ohmyorch:analyze-codebase to refresh it, or record an explicit decision to proceed.\n' >&2
      printf '  To proceed deliberately, put this line in %s:\n' "$FILE" >&2
      printf '    CODEBASE Context: consumed (%s, staleness accepted)\n' "$RECORDED" >&2
      exit 2
    fi
  fi
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  CODEBASE.md present and current for %s\n' "$FILE" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Guard 3 — meaningful codebase but no CODEBASE.md: require analysis or a skip
# ---------------------------------------------------------------------------

if [ "$HAS_CODEBASE" -eq 1 ]; then
  if skip_recorded; then
    [ "$QUIET" -eq 1 ] || printf 'ALLOW  codebase analysis explicitly skipped\n' >&2
    exit 0
  fi

  printf '%sBLOCKED%s  %s\n' "$c_red" "$c_reset" "$FILE" >&2
  printf '  %sA meaningful codebase is present but CODEBASE.md does not exist.%s\n' \
    "$c_dim" "$c_reset" >&2
  printf '\n' >&2
  printf '  %sUS-8.2: generation must not silently pretend repository context was considered.%s\n' \
    "$c_yellow" "$c_reset" >&2
  printf '  Either:\n' >&2
  printf '    a) run /ohmyorch:analyze-codebase to create CODEBASE.md, then retry; or\n' >&2
  printf '    b) record a deliberate skip by adding this line to %s:\n' "$FILE" >&2
  printf '       CODEBASE Context: skipped (<reason>)\n' >&2
  exit 2
fi

# Greenfield: no meaningful codebase, so there is no context to require.
[ "$QUIET" -eq 1 ] || printf 'ALLOW  no meaningful codebase detected (greenfield)\n' >&2
exit 0
