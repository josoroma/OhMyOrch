#!/bin/bash
# Shared code/project boundary. Source only bundled code, never project data.
OHMYORCH_CODE_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 2
export OHMYORCH_CODE_ROOT

ohmyorch_error() { printf 'OhMyOrch: %s\n' "$*" >&2; }
ohmyorch_die() { ohmyorch_error "$*"; exit 2; }
ohmyorch_hash() { shasum -a 256 "$1" | awk '{print $1}'; }
ohmyorch_json_string() { jq -Rn --arg value "$1" '$value'; }

# Reject symlink components before touching a target, including missing children.
ohmyorch_path() (
  shopt -s nullglob dotglob
  local raw="$1" part current rel
  raw=$(printf '%s' "$raw" | sed 's://*:/:g')
  if [ "$(uname -s)" = Darwin ]; then
    case "$raw" in /var/*|/tmp/*) raw="/private$raw" ;; esac
  fi
  case "$raw" in
    "$OHMYORCH_PROJECT_ROOT"/*) rel=${raw#"$OHMYORCH_PROJECT_ROOT"/} ;;
    "${OHMYORCH_INPUT_ROOT:-$OHMYORCH_PROJECT_ROOT}"/*) rel=${raw#"${OHMYORCH_INPUT_ROOT:-$OHMYORCH_PROJECT_ROOT}"/} ;;
    /*) ohmyorch_error "path is outside project: $raw"; return 2 ;;
    *) rel=${raw#./} ;;
  esac
  [ -n "$rel" ] || { ohmyorch_error 'empty managed path'; return 2; }
  if printf '%s' "$rel" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    ohmyorch_error 'control characters in path'; return 2
  fi
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
  OHMYORCH_ENABLED=false
  if [ -f "$OHMYORCH_CONFIG" ]; then
    jq -e '
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
    ' "$OHMYORCH_CONFIG" >/dev/null 2>&1 || {
      ohmyorch_error 'invalid/unsupported project config (schema 1, local spec-driven only)'; return 2;
    }
    OHMYORCH_ENABLED=$(jq -r .enabled "$OHMYORCH_CONFIG")
    OHMYORCH_DOC_PRD=$(jq -r .documents.prd "$OHMYORCH_CONFIG")
    OHMYORCH_DOC_SPECS=$(jq -r .documents.specs "$OHMYORCH_CONFIG")
    OHMYORCH_DOC_CODEBASE=$(jq -r .documents.codebase "$OHMYORCH_CONFIG")
    OHMYORCH_PAGES=$(jq -r .output.pages "$OHMYORCH_CONFIG")
    OHMYORCH_EPIC_LOGS=$(jq -r .output.epicLogs "$OHMYORCH_CONFIG")
    OHMYORCH_MAX_STALLS=$(jq -r .delivery.maxStalls "$OHMYORCH_CONFIG")
    local configured
    while IFS= read -r configured; do
      [ "$(ohmyorch_relative "$configured")" = "$configured" ] || { ohmyorch_error "config paths must use canonical relative spelling"; return 2; };
    done < <(
      jq -r '.documents[],.output[],.fastValidation.script' "$OHMYORCH_CONFIG")
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
}

ohmyorch_init() {
  command -v jq >/dev/null 2>&1 || ohmyorch_die 'jq >=1.6 is required; install it explicitly'
  OHMYORCH_ARGS=()
  local root="${OHMYORCH_PROJECT_ROOT:-}" session="${OHMYORCH_SESSION_ID:-}" arg
  OHMYORCH_TAKEOVER=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-root) [ "$#" -gt 1 ] || ohmyorch_die '--project-root needs a value'; root="$2"; shift 2 ;;
      --session-id) [ "$#" -gt 1 ] || ohmyorch_die '--session-id needs a value'; session="$2"; shift 2 ;;
      --takeover) OHMYORCH_TAKEOVER=1; shift ;;
      *) OHMYORCH_ARGS+=("$1"); shift ;;
    esac
  done
  case "$root" in /*) ;; *) ohmyorch_die '--project-root must be an explicit absolute directory' ;; esac
  [ ! -L "$root" ] || ohmyorch_die 'symlinked project root refused'
  OHMYORCH_INPUT_ROOT=${root%/}
  export OHMYORCH_INPUT_ROOT
  root=$(cd -- "$root" 2>/dev/null && pwd -P) || ohmyorch_die 'project root does not exist'
  case "$root" in /|"$HOME"|"$OHMYORCH_CODE_ROOT"|"$OHMYORCH_CODE_ROOT"/*)
    ohmyorch_die 'refusing filesystem/home/plugin root as consumer project' ;;
  esac
  OHMYORCH_PROJECT_ROOT="$root"; OHMYORCH_SESSION_ID="$session"
  if [ -n "$session" ]; then
    case "$session" in *[!a-zA-Z0-9_-]*) ohmyorch_die 'invalid session id' ;; esac
  fi
  export OHMYORCH_PROJECT_ROOT OHMYORCH_SESSION_ID
  cd -- "$root" || exit 2
  OHMYORCH_CONFIG_VALID=1
  if ! ohmyorch_load_config; then
    [ "${OHMYORCH_ALLOW_UNCONFIGURED:-0}" = 1 ] || exit 2
    OHMYORCH_CONFIG_VALID=0; OHMYORCH_ENABLED=false
    OHMYORCH_DOC_PRD=PRD.md; OHMYORCH_DOC_SPECS=SPECS.md; OHMYORCH_DOC_CODEBASE=CODEBASE.md
    OHMYORCH_PAGES=docs/pages; OHMYORCH_EPIC_LOGS=SPEC-LOGS; OHMYORCH_MAX_STALLS=3
  fi
  export OHMYORCH_CONFIG_VALID OHMYORCH_ENABLED
  if [ "$OHMYORCH_ENABLED" = true ] && [ "${OHMYORCH_ALLOW_UNCONFIGURED:-0}" != 1 ]; then
    for arg in workflow-status completion-gate validate-product-artifacts validate-implementation-plan validate-review validate-test-report validate-status validate-verification; do
      [ -x "$OHMYORCH_CODE_ROOT/scripts/$arg.sh" ] || ohmyorch_die "missing bundled validator: $arg"
    done
  fi
}

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

ohmyorch_selected_change() {
  local changes count
  if [ -n "${OHMYORCH_SELECTED_CHANGE:-}" ]; then
    printf '%s\n' "$OHMYORCH_SELECTED_CHANGE"; return
  fi
  changes=$(find openspec/changes -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | sort)
  count=$(printf '%s\n' "$changes" | awk 'NF {n++} END {print n+0}')
  [ "$count" -eq 1 ] || { ohmyorch_error 'exactly one selected active change is required'; return 2; }
  basename -- "$changes"
}

ohmyorch_change_id() {
  case "$1" in ''|.*|*[!a-zA-Z0-9_-]*) ohmyorch_error "invalid change id: $1"; return 2 ;; esac
  ohmyorch_path "openspec/changes/$1" >/dev/null
}
