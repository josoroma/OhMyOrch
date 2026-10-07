#!/usr/bin/env bash
#
# guard-archive.sh — US-8.2 guard: no premature archival
#
# Scenario implemented:
#   Given a change has blocking review findings or failing acceptance tests
#   When  archive is requested through the harness
#   Then  the harness MUST reject archival
#
# The verdict is not recomputed here. It is delegated to workflow-status.sh, the
# single owner of the 7-gate state model (US-3.1), and read from its
# `archiveEligible` field. Duplicating the gate logic would create a second
# source of truth that could silently disagree with the first.
#
# Wired as a PreToolUse hook on Bash. Archival reaches OpenSpec through the CLI,
# so intercepting the command is what actually prevents the state change; the
# bundled references/rules/openspec.md tells the agent what it should do.
#
# Fails open when the harness is not in use or no change is active.
#
# Usage:
#   guard-archive.sh --hook                     # PreToolUse JSON on stdin
#   guard-archive.sh --change <name>            # direct check
#   guard-archive.sh --change <name> --json     # machine-readable verdict
#
# Exit codes: 0 allow, 2 block, 3 usage error.

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

HOOK_MODE=0
CHANGE=""
AS_JSON=0
QUIET=0

c_reset=""; c_red=""; c_dim=""; c_yellow=""; c_green=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'
  c_yellow=$'\033[33m'; c_green=$'\033[32m'
fi

usage() {
  cat <<'EOF'
Usage: guard-archive.sh (--hook | --change <name>) [--json] [--quiet]

Rejects archive when the change is not archive-eligible (US-8.2): unresolved
review findings, failing acceptance tests, or any other incomplete gate.

Options:
  --hook            Read Claude Code hook JSON on stdin (PreToolUse)
  --change <name>   Check a specific change (direct mode)
  --json            Emit a machine-readable verdict
  --quiet           Suppress the allow message
  -h, --help        Show this help

Exit codes: 0 allow, 2 blocked, 3 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)   HOOK_MODE=1; shift ;;
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 3; }; CHANGE="$2"; shift 2 ;;
    --json)   AS_JSON=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  [ -z "$HOOK_INPUT" ] && exit 0

  # Only Bash tool invocations that actually archive are of interest.
  case "$HOOK_INPUT" in
    *openspec*archive*) ;;
    *) exit 0 ;;
  esac

  # The command string alone. A greedy sed capture (`"\(.*\)"`) ran to the LAST
  # quote in the payload, and Claude Code's Bash payload always carries a
  # `description` after `command` — so the parsed change name became
  # `the change"}}`, the gates were evaluated for a change that does not exist, and
  # archival was ALLOWED. This reads exactly one JSON string, decoding escapes.
  CMD=$(jq -er '.tool_input.command // "" | select(type=="string")' <<< "$HOOK_INPUT") || exit 2

  # Judge the command, not the description: "archive" in prose is not archival.
  case "$CMD" in
    *openspec*archive*) ;;
    "") ;;   # unparseable payload: fall through to the raw-text check below
    *) exit 0 ;;
  esac

  # `--help` / `-h` describes archival; it does not perform it. Match whole tokens:
  # the old `*archive*-h*` glob also matched `-hooks`, `--hard`, `-hello`.
  if printf ' %s ' "${CMD:-$HOOK_INPUT}" | grep -qE '[[:space:]](-h|--help)[[:space:]"]'; then
    exit 0
  fi

  # Recover the change name if one was given: the last bare token after
  # `archive`, skipping options and the value of --store.
  if [ -n "$CMD" ]; then
    CHANGE=$(printf '%s' "$CMD" | tr -d '\\' | awk '
      { for (i=1; i<=NF; i++) if ($i == "archive") { found=i; break } }
      found { for (i=found+1; i<=NF; i++) {
                 if ($i == "--store") { i++; continue }
                 if ($i ~ /^-/) continue
                 last=$i
               } }
      END { if (last) print last }
    ')
    case "$CHANGE" in *archive*|"") CHANGE="" ;; esac
  fi
fi

[ -n "$CHANGE" ] || CHANGE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d \
  -not -name archive 2>/dev/null | sed 's|.*/||' | sort | head -1)

# Nothing to archive: do not stand in the way of a no-op.
[ -n "$CHANGE" ] || exit 0

# Delegate the verdict. A missing reporter means the harness is not installed
# here, in which case this guard has no opinion.
if [ ! -x "${OHMYORCH_CODE_ROOT}/scripts/workflow-status.sh" ]; then
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  workflow-status.sh unavailable; no gate data\n' >&2
  exit 0
fi

STATUS_JSON=$("${OHMYORCH_CODE_ROOT}/scripts/workflow-status.sh" --change "$CHANGE" --json 2>/dev/null)
STATUS_RC=$?
# 1 = no active change, 2 = usage. Neither is a reason to block archival.
[ "$STATUS_RC" -ne 0 ] && exit 0

# Note: BSD sed BRE has no `\|` alternation, so this is two separate commands
# rather than one pattern with a `true|false` group. A single alternation group
# matches nothing on macOS and would silently report "no verdict".
ELIGIBLE=$(printf '%s' "$STATUS_JSON" \
  | sed -n 's/.*"archiveEligible":[[:space:]]*\(true\).*/\1/p; s/.*"archiveEligible":[[:space:]]*\(false\).*/\1/p' \
  | head -1)
FIRST=$(printf '%s' "$STATUS_JSON" \
  | sed -n 's/.*"firstIncompleteGate":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Unparseable status cannot be treated as approval.
if [ -z "$ELIGIBLE" ]; then
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  could not read archive eligibility; not blocking\n' >&2
  exit 0
fi

# Completion gate — the US-10.1 four conditions (EPIC-10).
#
# The gate chain and the definition of done are not the same list, and neither is a
# superset of the other. Two conditions are checked nowhere else:
#
#   * OpenSpec verification (condition 4) has no gate at all.
#   * A review that DECLARES a blocking verify mismatch passes the gate chain, since
#     the recorded `OpenSpec verify:` line was never evaluated.
#
# So when the completion gate is available its verdict is authoritative for archival,
# and the gate chain is reported alongside it rather than instead of it.
COMPLETION=""
if [ -x "${OHMYORCH_CODE_ROOT}/scripts/completion-gate.sh" ]; then
  COMPLETION=$("${OHMYORCH_CODE_ROOT}/scripts/completion-gate.sh" --change "$CHANGE" --json 2>/dev/null)
  C_ELIGIBLE=$(printf '%s' "$COMPLETION" \
    | sed -n 's/.*"eligible":[[:space:]]*\(true\).*/\1/p; s/.*"eligible":[[:space:]]*\(false\).*/\1/p' | head -1)
  if [ -n "$C_ELIGIBLE" ]; then
    ELIGIBLE="$C_ELIGIBLE"
    C_FIRST=$(printf '%s' "$COMPLETION" \
      | sed -n 's/.*"firstFailingCondition":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$C_FIRST" ] && FIRST="$C_FIRST"
  fi
fi

if [ "$ELIGIBLE" = "true" ]; then
  if [ "$AS_JSON" -eq 1 ]; then
    printf '{ "change": "%s", "archiveEligible": true, "blocked": false }\n' "$CHANGE"
  else
    [ "$QUIET" -eq 1 ] || printf '%sALLOW%s  %s is archive-eligible\n' "$c_green" "$c_reset" "$CHANGE" >&2
  fi
  exit 0
fi

if [ "$AS_JSON" -eq 1 ]; then
  printf '{ "change": "%s", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "%s" }\n' \
    "$CHANGE" "$FIRST"
else
  printf '%sBLOCKED%s  archive %s\n' "$c_red" "$c_reset" "$CHANGE" >&2
  printf '  %sChange is not archive-eligible.%s\n' "$c_dim" "$c_reset" >&2
  [ -n "$FIRST" ] && printf '  First failing condition: %s\n' "$FIRST" >&2
  printf '\n' >&2
  printf '  %sUS-10.1: every completion condition must pass before a change is archived.%s\n' \
    "$c_yellow" "$c_reset" >&2
  printf '  Run ohmyorch completion-gate --change %s for the four conditions.\n' "$CHANGE" >&2
fi
exit 2
