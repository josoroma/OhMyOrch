#!/bin/bash
ohmyorch_owner_path() { printf '%s/.claude/ohmyorch/runtime/delivery.owner\n' "$OHMYORCH_PROJECT_ROOT"; }
ohmyorch_owner_session() { jq -er '.sessionId' "$(ohmyorch_owner_path)/owner.json" 2>/dev/null; }
ohmyorch_acquire_owner() {
  ohmyorch_require_active
  [ -n "$OHMYORCH_SESSION_ID" ] || ohmyorch_die 'delivery mutation requires --session-id; use explicit --takeover to resume'
  local dir owner
  dir=$(ohmyorch_owner_path)
  ohmyorch_path .claude/ohmyorch/runtime/delivery.owner/owner.json >/dev/null || return 2
  umask 077
  mkdir -p "$(dirname -- "$dir")" || return 2
  if ! mkdir "$dir" 2>/dev/null; then
    owner=$(ohmyorch_owner_session) || owner=interrupted
    if [ "$owner" = "$OHMYORCH_SESSION_ID" ]; then return 0; fi
    [ "$OHMYORCH_TAKEOVER" -eq 1 ] || {
      ohmyorch_error "delivery is owned by session $owner; explicit --takeover required"; return 2;
    }
    # Takeover is serialized independently of the existing owner directory.
    mkdir "$dir.takeover" 2>/dev/null || { ohmyorch_error 'takeover already in progress'; return 2; }
    mv "$dir" "$dir.takeover/prior" || { rmdir "$dir.takeover"; return 2; }
    mkdir "$dir" || { mv "$dir.takeover/prior" "$dir"; rmdir "$dir.takeover"; return 2; }
    rm -f "$dir.takeover/prior/owner.json"
    rmdir "$dir.takeover/prior" "$dir.takeover" || return 2
  fi
  local record
  record=$(mktemp "$dir/.owner.XXXXXX") || return 2
  jq -n --arg session "$OHMYORCH_SESSION_ID" --arg root "$OHMYORCH_PROJECT_ROOT" \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{schemaVersion:1,sessionId:$session,projectRoot:$root,acquiredAt:$now,updatedAt:$now,goalTarget:null}' > "$record" || return 2
  mv "$record" "$dir/owner.json"
}
ohmyorch_touch_owner() {
  local dir record target
  dir=$(ohmyorch_owner_path)
  [ "$(ohmyorch_owner_session)" = "$OHMYORCH_SESSION_ID" ] || return 0
  target=$(awk -F'|' '$2 ~ /^[ ]*Target[ ]*$/ {v=$3; gsub(/^[ ]+|[ ]+$/, "", v); print v; exit}' openspec/delivery/goal.md 2>/dev/null)
  record=$(mktemp "$dir/.owner.XXXXXX") || return 2
  jq --arg target "$target" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.goalTarget=$target | .updatedAt=$now' "$dir/owner.json" > "$record" && mv "$record" "$dir/owner.json"
}
ohmyorch_release_owner() {
  local dir
  dir=$(ohmyorch_owner_path)
  [ "$(ohmyorch_owner_session)" = "$OHMYORCH_SESSION_ID" ] || return 0
  rm -f "$dir/owner.json"
  rmdir "$dir"
}
ohmyorch_operation_lock() {
  local dir="$OHMYORCH_PROJECT_ROOT/.claude/ohmyorch/runtime/operation.lock"
  ohmyorch_path .claude/ohmyorch/runtime/operation.lock >/dev/null || return 2
  umask 077; mkdir -p "$(dirname -- "$dir")" || return 2
  mkdir "$dir" 2>/dev/null || { ohmyorch_error 'another transaction is active; recover its journal before retrying'; return 2; }
  OHMYORCH_LOCK="$dir"
}
ohmyorch_unlock() { [ -z "${OHMYORCH_LOCK:-}" ] || rmdir "$OHMYORCH_LOCK"; }
