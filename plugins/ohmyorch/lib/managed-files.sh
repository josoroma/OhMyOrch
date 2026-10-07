#!/bin/bash
# Staging, ownership, verified affected-file recovery and per-file atomic writes.
ohmyorch_mode() {
  if [ "$(uname -s)" = Darwin ]; then stat -f %Lp "$1"; else stat -c %a "$1"; fi
}
ohmyorch_file_hash() { if [ -f "$1" ]; then ohmyorch_hash "$1"; else printf 'ABSENT\n'; fi; }

ohmyorch_stage_begin() {
  umask 077
  OHMYORCH_STAGE=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-operation.XXXXXX") || return 2
  OHMYORCH_PLAN='[]'
  OHMYORCH_LEDGER=.claude/ohmyorch/managed-files.json
  ohmyorch_path "$OHMYORCH_LEDGER" >/dev/null || return 2
  if [ -f "$OHMYORCH_LEDGER" ]; then
    jq -e '.schemaVersion==1 and (.files|type=="object")' "$OHMYORCH_LEDGER" >/dev/null || return 2
    cp "$OHMYORCH_LEDGER" "$OHMYORCH_STAGE/ledger.json"
  else printf '{"schemaVersion":1,"files":{}}\n' > "$OHMYORCH_STAGE/ledger.json"; fi
  OHMYORCH_VERSION=$(jq -r .version "$OHMYORCH_CODE_ROOT/.claude-plugin/plugin.json")
}
ohmyorch_stage_cleanup() { [ -z "${OHMYORCH_STAGE:-}" ] || rm -rf "$OHMYORCH_STAGE"; }

ohmyorch_record() {
  local path="$1" source="$2" kind="$3" begin="${4:-}" end="${5:-}" hash
  hash=$(ohmyorch_hash "$source") || return 2
  jq --arg path "$path" --arg hash "$hash" --arg kind "$kind" --arg version "$OHMYORCH_VERSION" \
    --arg begin "$begin" --arg end "$end" \
    '.files[$path]={kind:$kind,sha256:$hash,base:$hash,pluginVersion:$version,begin:$begin,end:$end}' \
    "$OHMYORCH_STAGE/ledger.json" > "$OHMYORCH_STAGE/ledger.next" || return 2
  mv "$OHMYORCH_STAGE/ledger.next" "$OHMYORCH_STAGE/ledger.json"
  ohmyorch_plan_file ".claude/ohmyorch/managed-bases/$hash" "$source" raw-create || return 2
}

# Policies: create-only adopts existing bytes without claiming them; managed
# requires a matching ownership hash; raw-update is limited to explicit engines.
ohmyorch_plan_file() {
  local path="$1" source="$2" policy="${3:-create-only}" target before after action old_hash mode stage_file
  target=$(ohmyorch_path "$path") || return 2
  path=${target#"$OHMYORCH_PROJECT_ROOT"/}
  [ ! -e "$target" ] || [ -f "$target" ] || { ohmyorch_error "not a regular file: $path"; return 2; }
  before=$(ohmyorch_file_hash "$target") || return 2
  if [ "$source" = DELETE ]; then
    [ "$before" != ABSENT ] || return 0
    after=ABSENT; action=delete; stage_file=''; mode=$(ohmyorch_mode "$target")
  else
    after=$(ohmyorch_hash "$source") || return 2
    [ "$before" != "$after" ] || return 0
    if [ "$before" != ABSENT ]; then
      case "$policy" in create-only|raw-create) return 0 ;;
        managed)
          old_hash=$(jq -r --arg path "$path" '.files[$path].sha256 // ""' "$OHMYORCH_STAGE/ledger.json")
          [ "$old_hash" = "$before" ] || { ohmyorch_error "conflict: locally edited/unowned $path"; return 2; } ;;
        raw-update|block) ;;
        *) ohmyorch_error "unknown file policy $policy"; return 2 ;;
      esac
      action=update; mode=$(ohmyorch_mode "$target")
    else action=create; mode=644; fi
    stage_file="$OHMYORCH_STAGE/content-$(printf '%s' "$path" | shasum -a 256 | awk '{print $1}')"
    cp "$source" "$stage_file" || return 2
  fi
  if jq -e --arg path "$path" 'any(.[]; .path==$path)' <<< "$OHMYORCH_PLAN" >/dev/null; then
    [ "$(jq -r --arg path "$path" '.[]|select(.path==$path)|.after' <<< "$OHMYORCH_PLAN")" = "$after" ] && return 0
    ohmyorch_error "conflicting planned target $path"; return 2
  fi
  OHMYORCH_PLAN=$(jq --arg path "$path" --arg action "$action" --arg before "$before" \
    --arg after "$after" --arg source "$stage_file" --arg mode "$mode" \
    '. + [{path:$path,action:$action,before:$before,after:$after,source:$source,mode:$mode}]' <<< "$OHMYORCH_PLAN")
}

ohmyorch_block() {
  local file="$1" begin="$2" end="$3"
  awk -v begin="$begin" -v end="$end" '
    $0==begin {if (inside || starts++) bad=1; inside=1}
    inside {print}
    $0==end {if (!inside || ends++) bad=1; inside=0}
    END {if (bad || inside || starts!=ends || starts>1) exit 2}
  ' "$file"
}

ohmyorch_plan_block() {
  local path="$1" body="$2" label="$3" prefix="${4:-html}" begin end target old installed_hash old_hash merged block
  if [ "$prefix" = comment ]; then begin="# OHMYORCH:BEGIN $label"; end="# OHMYORCH:END $label"
  else begin="<!-- OHMYORCH:BEGIN $label -->"; end="<!-- OHMYORCH:END $label -->"; fi
  target=$(ohmyorch_path "$path") || return 2
  block="$OHMYORCH_STAGE/block-$label"
  { printf '%s\n' "$begin"; cat "$body"; printf '\n%s\n' "$end"; } > "$block"
  merged="$OHMYORCH_STAGE/merged-$label"
  if [ -f "$target" ]; then
    old="$OHMYORCH_STAGE/old-$label"
    ohmyorch_block "$target" "$begin" "$end" > "$old" || { ohmyorch_error "malformed markers: $path"; return 2; }
    if [ -s "$old" ]; then
      installed_hash=$(jq -r --arg path "$path" '.files[$path].sha256 // ""' "$OHMYORCH_STAGE/ledger.json")
      old_hash=$(ohmyorch_hash "$old")
      [ "$installed_hash" = "$old_hash" ] || { ohmyorch_error "managed block conflict: $path"; return 2; }
      if cmp -s "$old" "$block"; then return 0; fi
      # No invented merge: edited bases/blocks conflict; unchanged owned blocks can advance.
      base=$(jq -r --arg path "$path" '.files[$path].base' "$OHMYORCH_STAGE/ledger.json")
      [ -f ".claude/ohmyorch/managed-bases/$base" ] &&
        [ "$(ohmyorch_hash ".claude/ohmyorch/managed-bases/$base")" = "$installed_hash" ] || {
          ohmyorch_error "missing/corrupt merge base: $path"; return 2;
        }
      awk -v begin="$begin" -v end="$end" -v replacement="$block" '
        $0==begin {while ((getline line < replacement)>0) print line; close(replacement); skip=1}
        !skip {print}
        $0==end {skip=0}
      ' "$target" > "$merged" || return 2
    else
      cat "$target" > "$merged"; printf '\n' >> "$merged"; cat "$block" >> "$merged"
    fi
  else cp "$block" "$merged"; fi
  ohmyorch_plan_file "$path" "$merged" block || return 2
  ohmyorch_record "$path" "$block" block "$begin" "$end"
}

ohmyorch_plan_owned_file() {
  local path="$1" source="$2" existed before_count after_count
  existed=0; [ ! -e "$path" ] || existed=1
  before_count=$(jq length <<< "$OHMYORCH_PLAN")
  if [ "$existed" -eq 0 ]; then ohmyorch_plan_file "$path" "$source" create-only || return 2
  else ohmyorch_plan_file "$path" "$source" managed || return 2; fi
  after_count=$(jq length <<< "$OHMYORCH_PLAN")
  [ "$before_count" = "$after_count" ] || ohmyorch_record "$path" "$source" file
}

ohmyorch_plan_finish() {
  jq -S . "$OHMYORCH_STAGE/ledger.json" > "$OHMYORCH_STAGE/ledger.sorted"
  ohmyorch_plan_file "$OHMYORCH_LEDGER" "$OHMYORCH_STAGE/ledger.sorted" raw-update || return 2
  OHMYORCH_PLAN=$(jq 'sort_by(if .path==".claude/ohmyorch/project.json" then 1 else 0 end)' <<< "$OHMYORCH_PLAN")
  OHMYORCH_PLAN_ID=$(jq -Sc 'map(del(.source)) | sort_by(.path)' <<< "$OHMYORCH_PLAN" | shasum -a 256 | awk '{print $1}')
  export OHMYORCH_PLAN_ID
}
ohmyorch_print_plan() {
  jq -n --arg id "$OHMYORCH_PLAN_ID" --arg operation "$OHMYORCH_OPERATION" --argjson files "$OHMYORCH_PLAN" \
    '{planId:$id,operation:$operation,files:($files|map(del(.source))),note:"Dry-run creates no project files. Apply rechecks destination hashes and uses affected-file recovery."}'
}

ohmyorch_restore_journal() {
  local journal="$1" backup_root path before after actual backup mode conflict=0
  backup_root=$(dirname -- "$journal")
  while IFS= read -r row; do
    path=$(jq -r .path <<< "$row"); before=$(jq -r .before <<< "$row"); after=$(jq -r .after <<< "$row")
    ohmyorch_path "$path" >/dev/null || { conflict=1; continue; }
    actual=$(ohmyorch_file_hash "$path")
    [ "$actual" != "$before" ] || continue
    [ "$actual" = "$after" ] || { ohmyorch_error "rollback conflict: $path changed since apply"; conflict=1; continue; }
    if [ "$before" = ABSENT ]; then rm -f "$path" || conflict=1
    else
      backup="$backup_root/files/$path"; mode=$(jq -r .mode <<< "$row")
      [ -f "$backup" ] && [ "$(ohmyorch_hash "$backup")" = "$before" ] || { ohmyorch_error "corrupt recovery copy: $path"; conflict=1; continue; }
      mkdir -p "$(dirname -- "$path")"
      tmp=$(mktemp "$(dirname -- "$path")/.ohmyorch-restore.XXXXXX") || { conflict=1; continue; }
      cp "$backup" "$tmp" && chmod "$mode" "$tmp" && mv "$tmp" "$path" || conflict=1
    fi
  done < <(jq -c '.files | reverse[]' "$journal")
  [ "$conflict" -eq 0 ]
}

ohmyorch_apply_plan() {
  [ "$(jq length <<< "$OHMYORCH_PLAN")" -gt 0 ] || { echo 'SKIP: identical operation; no project writes'; return 0; }
  local owner operation_id backup journal row path before after source mode actual temp completed=0 failed=0
  owner=$(ohmyorch_owner_session 2>/dev/null || true)
  [ -z "$owner" ] || { ohmyorch_error "delivery owned by $owner; stop it before lifecycle changes"; return 2; }
  ohmyorch_operation_lock || return 2
  operation_id="$(date -u +%Y%m%dT%H%M%SZ)-${OHMYORCH_STAGE##*.}"
  backup=".claude/ohmyorch/backups/$operation_id"
  ohmyorch_path "$backup/journal.json" >/dev/null || return 2
  umask 077
  mkdir -p "$backup/files" || return 2
  # Local self-ignore protects the very first backup before root guidance exists.
  if [ ! -f .claude/ohmyorch/backups/.gitignore ]; then printf '*\n' > .claude/ohmyorch/backups/.gitignore; fi
  if [ ! -f .claude/ohmyorch/runtime/.gitignore ]; then printf '*\n' > .claude/ohmyorch/runtime/.gitignore; fi
  journal="$backup/journal.json"
  jq -n --arg id "$operation_id" --arg op "$OHMYORCH_OPERATION" --arg plan "$OHMYORCH_PLAN_ID" --argjson files "$OHMYORCH_PLAN" \
    '{schemaVersion:1,operationId:$id,operation:$op,planId:$plan,status:"prepared",files:($files|map(del(.source)))}' > "$journal" || return 2
  # Verify all original copies before any planned destination changes.
  while IFS= read -r row; do
    path=$(jq -r .path <<< "$row"); before=$(jq -r .before <<< "$row")
    ohmyorch_path "$path" >/dev/null || return 2
    actual=$(ohmyorch_file_hash "$path")
    [ "$actual" = "$before" ] || { ohmyorch_error "concurrent edit: $path"; return 2; }
    if [ "$before" != ABSENT ]; then
      mkdir -p "$backup/files/$(dirname -- "$path")" || return 2
      cp -p "$path" "$backup/files/$path" || return 2
      [ "$(ohmyorch_hash "$backup/files/$path")" = "$before" ] || { ohmyorch_error "backup verification failed: $path"; return 2; }
    fi
  done < <(jq -c '.[]' <<< "$OHMYORCH_PLAN")
  while IFS= read -r row; do
    path=$(jq -r .path <<< "$row"); before=$(jq -r .before <<< "$row"); after=$(jq -r .after <<< "$row")
    source=$(jq -r .source <<< "$row"); mode=$(jq -r .mode <<< "$row")
    ohmyorch_path "$path" >/dev/null || { failed=1; break; }
    [ "$(ohmyorch_file_hash "$path")" = "$before" ] || { failed=1; break; }
    if [ "$after" = ABSENT ]; then rm -f "$path" || { failed=1; break; }
    else
      [ "$(ohmyorch_hash "$source")" = "$after" ] || { failed=1; break; }
      mkdir -p "$(dirname -- "$path")" || { failed=1; break; }
      temp=$(mktemp "$(dirname -- "$path")/.ohmyorch-write.XXXXXX") || { failed=1; break; }
      cp "$source" "$temp" && chmod "$mode" "$temp" && mv "$temp" "$path" || { rm -f "$temp"; failed=1; break; }
    fi
    completed=$((completed+1))
    jq --arg path "$path" '.completed=(.completed // [])+[$path] | .status="applying"' "$journal" > "$journal.next" && mv "$journal.next" "$journal" || { failed=1; break; }
    if [ "${OHMYORCH_FAIL_AFTER:-0}" = "$completed" ]; then failed=1; break; fi
  done < <(jq -c '.[]' <<< "$OHMYORCH_PLAN")
  if [ "$failed" -ne 0 ]; then
    ohmyorch_restore_journal "$journal" || { ohmyorch_error "incomplete rollback; recover $operation_id explicitly"; return 2; }
    jq '.status="rolled-back"' "$journal" > "$journal.next" && mv "$journal.next" "$journal"
    ohmyorch_error "apply failed; affected originals restored ($operation_id)"; return 2
  fi
  jq '.status="complete"' "$journal" > "$journal.next" && mv "$journal.next" "$journal"
  printf 'Applied %s files. Recovery operation: %s\n' "$completed" "$operation_id"
}
