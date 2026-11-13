#!/bin/bash
# Shared code/project boundary. Source only bundled code, never project data.
OHMYORCH_CODE_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 2
export OHMYORCH_CODE_ROOT

ohmyorch_error() { printf 'OhMyOrch: %s\n' "$*" >&2; }
ohmyorch_die() { ohmyorch_error "$*"; exit 2; }
ohmyorch_hash() { shasum -a 256 "$1" | awk '{print $1}'; }
ohmyorch_json_string() { jq -Rn --arg value "$1" '$value'; }

# Every C0 control character and DEL except newline, for the path check below.
OHMYORCH_CNTRL=$'\001\002\003\004\005\006\007\010\011\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177'

# Reject symlink components before touching a target, including missing children.
# Every script and hook resolves several paths, so the string work uses shell
# built-ins only: no process is spawned here.
ohmyorch_path() (
  shopt -s nullglob dotglob
  local raw="$1" part current rel
  # Drop trailing newlines and collapse every run of slashes into one.
  while [[ "$raw" == *$'\n' ]]; do raw=${raw%$'\n'}; done
  while [[ "$raw" == *//* ]]; do raw="${raw%%//*}/${raw#*//}"; done
  case "${OSTYPE:-$(uname -s)}" in darwin*|Darwin*)
    case "$raw" in /var/*|/tmp/*) raw="/private$raw" ;; esac ;;
  esac
  case "$raw" in
    "$OHMYORCH_PROJECT_ROOT"/*) rel=${raw#"$OHMYORCH_PROJECT_ROOT"/} ;;
    "${OHMYORCH_INPUT_ROOT:-$OHMYORCH_PROJECT_ROOT}"/*) rel=${raw#"${OHMYORCH_INPUT_ROOT:-$OHMYORCH_PROJECT_ROOT}"/} ;;
    /*) ohmyorch_error "path is outside project: $raw"; return 2 ;;
    *) rel=${raw#./} ;;
  esac
  [ -n "$rel" ] || { ohmyorch_error 'empty managed path'; return 2; }
  case "$rel" in *["$OHMYORCH_CNTRL"]*)
    ohmyorch_error 'control characters in path'; return 2 ;;
  esac
  current="$OHMYORCH_PROJECT_ROOT"
  local parts=()
  IFS=/ read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    case "$part" in ''|.|..) ohmyorch_error "invalid path component: $raw"; return 2 ;; esac
    parent="$current"
    current="$current/$part"
    # Resolve real entry spelling on case-insensitive hosts before role checks.
    if [ -e "$current" ]; then
      for entry in "$parent"/*; do
        if [ "$current" -ef "$entry" ]; then current="$entry"; break; fi
      done
    fi
    [ ! -L "$current" ] || { ohmyorch_error "symlinked path refused: $rel"; return 2; }
  done
  printf '%s\n' "$current"
)

ohmyorch_relative() {
  local absolute
  absolute=$(ohmyorch_path "$1") || return 2
  printf '%s\n' "${absolute#"$OHMYORCH_PROJECT_ROOT"/}"
}

ohmyorch_default_doc() {
  local name="$1"
  if [ -e "$OHMYORCH_PROJECT_ROOT/$name" ] && [ -e "$OHMYORCH_PROJECT_ROOT/docs/$name" ]; then
    if [ "${OHMYORCH_ALLOW_UNCONFIGURED:-0}" = 1 ]; then printf '%s\n' "$name"; return; fi
    ohmyorch_error "ambiguous $name: specify --prd/--specs/--codebase during bootstrap"; return 2
  fi
  if [ -e "$OHMYORCH_PROJECT_ROOT/docs/$name" ]; then printf 'docs/%s\n' "$name"
  else printf '%s\n' "$name"; fi
}

ohmyorch_load_config() {
  OHMYORCH_CONFIG="$OHMYORCH_PROJECT_ROOT/.claude/ohmyorch/project.json"
  ohmyorch_path .claude/ohmyorch/project.json >/dev/null || return 2
  OHMYORCH_ENABLED=false; OHMYORCH_FAST_VALIDATION=false
  if [ -f "$OHMYORCH_CONFIG" ]; then
    # One jq process validates the schema and emits every value on its own line:
    # nine named fields, then the six configured paths in their file order. The
    # schema rejects control characters, so a value can never span two lines.
    # Every script and hook pays for this, which is why it is a single spawn.
    # The file is slurped so that anything but exactly one document is rejected.
    local values configured index=0
    values=$(jq -rs '
      if length == 1 then .[0] else error("unsupported") end |
      if (
        type == "object" and
        ((keys - ["schemaVersion","enabled","documents","openspec","output","delivery","fastValidation"]) | length == 0) and
        .schemaVersion == 1 and (.enabled | type == "boolean") and
        (.documents | type == "object") and
        ((.documents | keys) == ["codebase","prd","specs"]) and
        ([.documents[]] | all(type == "string" and length > 0 and (test("[\u0000-\u001f\u007f]")|not))) and
        (.openspec | keys == ["root","schema"]) and
        .openspec.root == "openspec" and .openspec.schema == "spec-driven" and
        (.output | keys == ["epicLogs","pages"]) and
        ([.output[]] | all(type == "string" and length > 0 and (test("[\u0000-\u001f\u007f]")|not))) and
        (.delivery | keys == ["maxStalls"]) and
        (.delivery.maxStalls | type == "number" and . >= 0 and . <= 6 and floor == .) and
        (.fastValidation | keys == ["enabled","script"]) and
        (.fastValidation.enabled | type == "boolean") and
        (.fastValidation.script | type == "string" and length > 0 and (test("[\u0000-\u001f\u007f]")|not))
      ) then
        .enabled, .documents.prd, .documents.specs, .documents.codebase,
        .output.pages, .output.epicLogs, .delivery.maxStalls, .fastValidation.enabled,
        .fastValidation.script, .documents[], .output[], .fastValidation.script
      else error("unsupported") end
    ' "$OHMYORCH_CONFIG" 2>/dev/null) || values=''
    while IFS= read -r configured; do
      case "$index" in
        0) OHMYORCH_ENABLED=$configured ;;
        1) OHMYORCH_DOC_PRD=$configured ;;
        2) OHMYORCH_DOC_SPECS=$configured ;;
        3) OHMYORCH_DOC_CODEBASE=$configured ;;
        4) OHMYORCH_PAGES=$configured ;;
        5) OHMYORCH_EPIC_LOGS=$configured ;;
        6) OHMYORCH_MAX_STALLS=$configured ;;
        7) OHMYORCH_FAST_VALIDATION=$configured ;;
      esac
      index=$((index + 1))
    done <<EOF
$values
EOF
    # A valid document yields exactly fifteen lines; anything else yields none.
    [ "$index" -eq 15 ] || {
      OHMYORCH_ENABLED=false; OHMYORCH_FAST_VALIDATION=false
      ohmyorch_error 'invalid/unsupported project config (schema 1, local spec-driven only)'; return 2;
    }
    index=0
    while IFS= read -r configured; do
      index=$((index + 1))
      [ "$index" -gt 9 ] || continue
      [ "$(ohmyorch_relative "$configured")" = "$configured" ] || { ohmyorch_error "config paths must use canonical relative spelling"; return 2; };
    done <<EOF
$values
EOF
    [ "$OHMYORCH_DOC_PRD" != "$OHMYORCH_DOC_SPECS" ] &&
      [ "$OHMYORCH_DOC_PRD" != "$OHMYORCH_DOC_CODEBASE" ] &&
      [ "$OHMYORCH_DOC_SPECS" != "$OHMYORCH_DOC_CODEBASE" ] || {
        ohmyorch_error 'document paths must be distinct'; return 2;
      }
  else
    OHMYORCH_DOC_PRD=$(ohmyorch_default_doc PRD.md) || return 2
    OHMYORCH_DOC_SPECS=$(ohmyorch_default_doc SPECS.md) || return 2
    OHMYORCH_DOC_CODEBASE=$(ohmyorch_default_doc CODEBASE.md) || return 2
    OHMYORCH_PAGES=docs/pages; OHMYORCH_EPIC_LOGS=SPEC-LOGS; OHMYORCH_MAX_STALLS=3
  fi
  export OHMYORCH_ENABLED OHMYORCH_DOC_PRD OHMYORCH_DOC_SPECS OHMYORCH_DOC_CODEBASE
  export OHMYORCH_PAGES OHMYORCH_EPIC_LOGS OHMYORCH_MAX_STALLS OHMYORCH_CONFIG
  export OHMYORCH_FAST_VALIDATION
}

# The initialization itself. It reports a failure on stderr and returns 2, so the
# hook dispatcher can keep its repair route without initializing twice. Scripts
# call ohmyorch_init, which exits instead.
ohmyorch_try_init() {
  command -v jq >/dev/null 2>&1 || { ohmyorch_error 'jq >=1.6 is required; install it explicitly'; return 2; }
  OHMYORCH_ARGS=()
  local root="${OHMYORCH_PROJECT_ROOT:-}" session="${OHMYORCH_SESSION_ID:-}" arg
  OHMYORCH_TAKEOVER=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-root) [ "$#" -gt 1 ] || { ohmyorch_error '--project-root needs a value'; return 2; }; root="$2"; shift 2 ;;
      --session-id) [ "$#" -gt 1 ] || { ohmyorch_error '--session-id needs a value'; return 2; }; session="$2"; shift 2 ;;
      --takeover) OHMYORCH_TAKEOVER=1; shift ;;
      *) OHMYORCH_ARGS+=("$1"); shift ;;
    esac
  done
  case "$root" in /*) ;; *) ohmyorch_error '--project-root must be an explicit absolute directory'; return 2 ;; esac
  [ ! -L "$root" ] || { ohmyorch_error 'symlinked project root refused'; return 2; }
  OHMYORCH_INPUT_ROOT=${root%/}
  export OHMYORCH_INPUT_ROOT
  root=$(cd -- "$root" 2>/dev/null && pwd -P) || { ohmyorch_error 'project root does not exist'; return 2; }
  case "$root" in /|"$HOME"|"$OHMYORCH_CODE_ROOT"|"$OHMYORCH_CODE_ROOT"/*)
    ohmyorch_error 'refusing filesystem/home/plugin root as consumer project'; return 2 ;;
  esac
  OHMYORCH_PROJECT_ROOT="$root"; OHMYORCH_SESSION_ID="$session"
  if [ -n "$session" ]; then
    case "$session" in *[!a-zA-Z0-9_-]*) ohmyorch_error 'invalid session id'; return 2 ;; esac
  fi
  export OHMYORCH_PROJECT_ROOT OHMYORCH_SESSION_ID
  cd -- "$root" || return 2
  OHMYORCH_CONFIG_VALID=1
  if ! ohmyorch_load_config; then
    [ "${OHMYORCH_ALLOW_UNCONFIGURED:-0}" = 1 ] || return 2
    OHMYORCH_CONFIG_VALID=0; OHMYORCH_ENABLED=false
    OHMYORCH_DOC_PRD=PRD.md; OHMYORCH_DOC_SPECS=SPECS.md; OHMYORCH_DOC_CODEBASE=CODEBASE.md
    OHMYORCH_PAGES=docs/pages; OHMYORCH_EPIC_LOGS=SPEC-LOGS; OHMYORCH_MAX_STALLS=3
    OHMYORCH_FAST_VALIDATION=false
  fi
  export OHMYORCH_CONFIG_VALID OHMYORCH_ENABLED OHMYORCH_FAST_VALIDATION
  if [ "$OHMYORCH_ENABLED" = true ] && [ "${OHMYORCH_ALLOW_UNCONFIGURED:-0}" != 1 ]; then
    for arg in delivery validate-product-artifacts; do
      [ -x "$OHMYORCH_CODE_ROOT/scripts/$arg.sh" ] || { ohmyorch_error "missing bundled validator: $arg"; return 2; }
    done
  fi
}

ohmyorch_init() { ohmyorch_try_init "$@" || exit 2; }

ohmyorch_doc_path() {
  case "$1" in
    PRD.md) printf '%s\n' "$OHMYORCH_DOC_PRD" ;;
    SPECS.md) printf '%s\n' "$OHMYORCH_DOC_SPECS" ;;
    CODEBASE.md) printf '%s\n' "$OHMYORCH_DOC_CODEBASE" ;;
    *) ohmyorch_die "unknown document: $1" ;;
  esac
}

ohmyorch_require_active() {
  [ "$OHMYORCH_ENABLED" = true ] || ohmyorch_die 'project inactive; run /ohmyorch:bootstrap explicitly'
}

# Print "<done> <total>" task checkboxes of one tasks.md; "0 0" when it is absent.
# tasks.md is the only tracking file of a change: delivery derivation and the
# archive guard both read progress through this one function.
# The two patterns mirror OpenSpec's own counter (TASK_LINE_PATTERN in
# dist/utils/task-progress.js, OpenSpec 1.13.2): any list marker (-, *, +, 1.,
# 1)), a box holding at most one character, and only x/X counts as done. So
# `- [~]`, `- [-]`, `- []`, `* [ ]` and `1. [ ]` are unfinished tasks, and a
# link bullet such as `- [x](url)` is not a task. Recheck them on an OpenSpec bump.
# The match is exact for ASCII. Two non-ASCII cases differ from OpenSpec and are
# not counted here: a task line right after a byte-order mark, and, in a locale
# without UTF-8, a box that holds one multi-byte character (`- [✓]`).
ohmyorch_tasks_progress() {
  local file="$1" total=0 complete=0
  if [ -f "$file" ]; then
    total=$(grep -cE '^[[:space:]]*([-*+]|[0-9]{1,9}[.)])[[:space:]]*\[([[:space:]]*[^][:space:]]?[[:space:]]*\]([^([]|$)|[[:space:]]+\])' "$file" 2>/dev/null || true)
    complete=$(grep -cE '^[[:space:]]*([-*+]|[0-9]{1,9}[.)])[[:space:]]*\[[[:space:]]*[xX][[:space:]]*\]([^([]|$)' "$file" 2>/dev/null || true)
  fi
  printf '%s %s\n' "${complete:-0}" "${total:-0}"
}

ohmyorch_change_id() {
  case "$1" in ''|.*|*[!a-zA-Z0-9_-]*) ohmyorch_error "invalid change id: $1"; return 2 ;; esac
  ohmyorch_path "openspec/changes/$1" >/dev/null
}
