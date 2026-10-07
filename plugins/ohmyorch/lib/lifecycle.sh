#!/bin/bash
# All project lifecycle changes use one ownership/transaction implementation.
source "$OHMYORCH_CODE_ROOT/lib/session.sh"
source "$OHMYORCH_CODE_ROOT/lib/managed-files.sh"

ohmyorch_lifecycle_parse() {
  APPLY=0; DRY_RUN=0; WITH_OPENSPEC=0; NESTED=0; MODE=create-only; SCOPE=managed
  DOCS_DIR=''; MAP_PRD=''; MAP_SPECS=''; MAP_CODEBASE=''; REVIEWED_PLAN=''; ROLLBACK=''; INCLUDE_EDITED=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --apply) APPLY=1; shift ;; --dry-run) DRY_RUN=1; shift ;;
      --with-openspec) WITH_OPENSPEC=1; shift ;; --nested) NESTED=1; shift ;;
      --include-edited) INCLUDE_EDITED=1; shift ;; --json) shift ;;
      --docs-dir|--prd|--specs|--codebase|--mode|--scope|--plan-id|--rollback)
        [ "$#" -gt 1 ] || ohmyorch_die "$1 needs a value"
        case "$1" in --docs-dir) DOCS_DIR="$2" ;; --prd) MAP_PRD="$2" ;; --specs) MAP_SPECS="$2" ;;
          --codebase) MAP_CODEBASE="$2" ;; --mode) MODE="$2" ;; --scope) SCOPE="$2" ;;
          --plan-id) REVIEWED_PLAN="$2" ;; --rollback) ROLLBACK="$2" ;; esac; shift 2 ;;
      -h|--help)
        echo "$OHMYORCH_OPERATION --dry-run|--apply [--docs-dir docs] [--prd PATH --specs PATH --codebase PATH] [--with-openspec] [--mode merge|create-only] [--nested] [--scope managed|workflow] [--plan-id HASH] [--rollback OPERATION]"
        exit 0 ;;
      *) ohmyorch_die "unknown lifecycle flag: $1" ;;
    esac
  done
  [ "$APPLY" -eq 0 ] || [ "$DRY_RUN" -eq 0 ] || ohmyorch_die 'choose --apply or --dry-run'
  case "$MODE" in create-only|merge) ;; *) ohmyorch_die 'only create-only and managed merge modes are supported' ;; esac
  case "$SCOPE" in managed|workflow) ;; *) ohmyorch_die 'scope must be managed or workflow' ;; esac
  [ -z "$DOCS_DIR" ] || ohmyorch_path "$DOCS_DIR/PRD.md" >/dev/null || exit 2
  if [ -n "$ROLLBACK" ]; then
    case "$ROLLBACK" in *[!a-zA-Z0-9_-]*|'') ohmyorch_die 'invalid recovery operation id' ;; esac
    journal=".claude/ohmyorch/backups/$ROLLBACK/journal.json"
    ohmyorch_path "$journal" >/dev/null || exit 2
    [ -f "$journal" ] || ohmyorch_die 'recovery operation not found'
    [ "$APPLY" -eq 1 ] || { jq 'del(.files[].source)' "$journal"; exit 0; }
    ohmyorch_operation_lock || exit 2
    trap 'ohmyorch_unlock' EXIT
    ohmyorch_restore_journal "$journal" || exit 2
    jq '.status="rolled-back"' "$journal" > "$journal.next" && mv "$journal.next" "$journal"
    echo "Restored affected paths for $ROLLBACK; unrelated edits were preserved."
    exit 0
  fi
}

ohmyorch_choose_doc() {
  local explicit="$1" name="$2"
  if [ -n "$explicit" ]; then ohmyorch_relative "$explicit"
  elif [ -n "$DOCS_DIR" ]; then ohmyorch_relative "$DOCS_DIR/$name"
  else
    # Ambiguity is a real collision even for byte-identical root/docs documents.
    if [ -e "$name" ] && [ -e "docs/$name" ]; then ohmyorch_error "ambiguous $name; give explicit mapping"; return 2; fi
    if [ -e "docs/$name" ]; then printf 'docs/%s\n' "$name"; else printf '%s\n' "$name"; fi
  fi
}

ohmyorch_prepare_config() {
  [ "$OHMYORCH_CONFIG_VALID" = 1 ] || ohmyorch_die 'repair unsupported project config before initialization'
  if [ -f "$OHMYORCH_CONFIG" ]; then
    cp "$OHMYORCH_CONFIG" "$OHMYORCH_STAGE/project.json"
    if [ -n "$MAP_PRD$MAP_SPECS$MAP_CODEBASE$DOCS_DIR" ]; then
      ohmyorch_die 'existing project mapping is authoritative; change it explicitly, then run doctor'
    fi
  else
    prd=$(ohmyorch_choose_doc "$MAP_PRD" PRD.md) || exit 2
    specs=$(ohmyorch_choose_doc "$MAP_SPECS" SPECS.md) || exit 2
    codebase=$(ohmyorch_choose_doc "$MAP_CODEBASE" CODEBASE.md) || exit 2
    [ "$prd" != "$specs" ] && [ "$prd" != "$codebase" ] && [ "$specs" != "$codebase" ] || ohmyorch_die 'document mappings must be distinct'
    jq -n --arg prd "$prd" --arg specs "$specs" --arg codebase "$codebase" \
      '{schemaVersion:1,enabled:true,documents:{prd:$prd,specs:$specs,codebase:$codebase},openspec:{root:"openspec",schema:"spec-driven"},output:{pages:"docs/pages",epicLogs:"SPEC-LOGS"},delivery:{maxStalls:3},fastValidation:{enabled:false,script:"scripts/fast-validate.sh"}}' \
      > "$OHMYORCH_STAGE/project.json"
  fi
  OHMYORCH_DOC_PRD=$(jq -r .documents.prd "$OHMYORCH_STAGE/project.json")
  OHMYORCH_DOC_SPECS=$(jq -r .documents.specs "$OHMYORCH_STAGE/project.json")
  OHMYORCH_DOC_CODEBASE=$(jq -r .documents.codebase "$OHMYORCH_STAGE/project.json")
  export OHMYORCH_DOC_PRD OHMYORCH_DOC_SPECS OHMYORCH_DOC_CODEBASE
}

ohmyorch_bootstrap_plan() {
  ohmyorch_prepare_config
  for mapping in "prd:$OHMYORCH_DOC_PRD:PRD.md" "specs:$OHMYORCH_DOC_SPECS:SPECS.md"; do
    # Paths with colons are supported: use the actual mapped variables, not splitting user data.
    case "$mapping" in prd:*) path="$OHMYORCH_DOC_PRD"; template=PRD.md ;; *) path="$OHMYORCH_DOC_SPECS"; template=SPECS.md ;; esac
    if [ ! -e "$path" ]; then
      ohmyorch_plan_file "$path" "$OHMYORCH_CODE_ROOT/templates/project/$template" create-only || exit 2
      ohmyorch_record "$path" "$OHMYORCH_CODE_ROOT/templates/project/$template" scaffold || exit 2
    fi
  done
  printf '.claude/ohmyorch/runtime/\n.claude/ohmyorch/backups/\n.claude/ohmyorch/approvals.local.json\n' > "$OHMYORCH_STAGE/ignore-body"
  ohmyorch_plan_block .gitignore "$OHMYORCH_STAGE/ignore-body" ignores comment || exit 2
  cat > "$OHMYORCH_STAGE/guidance" <<EOF
## OhMyOrch project workflow

Use the installed plugin's /ohmyorch:doctor and /ohmyorch:deliver commands.
Project intent: $OHMYORCH_DOC_PRD. Backlog: $OHMYORCH_DOC_SPECS.
Current-state evidence: $OHMYORCH_DOC_CODEBASE (generate it only through analysis).
Delegate implementation, review and testing independently. Specialists persist
their own verdicts; the main session derives resumption from project artifacts.
Generic rules are bundled in the plugin; updates never copy executable code here.
EOF
  if [ ! -e CLAUDE.md ] || [ "$MODE" = merge ]; then
    ohmyorch_plan_block CLAUDE.md "$OHMYORCH_STAGE/guidance" project || exit 2
  fi
  if [ "$WITH_OPENSPEC" -eq 1 ]; then
    if [ -e openspec/config.yaml ]; then
      grep -qE '^schema:[[:space:]]*spec-driven[[:space:]]*$' openspec/config.yaml || ohmyorch_die 'existing OpenSpec schema unsupported; preserve it and resolve manually'
    elif [ -d openspec ]; then
      ohmyorch_die 'existing OpenSpec tree has no config; propose a manual config merge instead of reinitializing it'
    else
      command -v openspec >/dev/null 2>&1 || ohmyorch_die 'OpenSpec 1.13.2 is required for --with-openspec; install explicitly'
      [ "$(openspec --version 2>/dev/null)" = 1.13.2 ] || ohmyorch_die 'OpenSpec initialization target is 1.13.2'
      mkdir "$OHMYORCH_STAGE/openspec-init"
      OPENSPEC_TELEMETRY=0 openspec init --tools none --no-copilot-cloud --no-animation "$OHMYORCH_STAGE/openspec-init" > "$OHMYORCH_STAGE/openspec.log" 2>&1 || {
        cat "$OHMYORCH_STAGE/openspec.log" >&2; exit 2;
      }
      # Initialize in scratch, then use reviewed templates without generated Claude files.
      ohmyorch_plan_file openspec/config.yaml "$OHMYORCH_CODE_ROOT/templates/project/openspec/config.yaml" create-only || exit 2
      ohmyorch_record openspec/config.yaml "$OHMYORCH_CODE_ROOT/templates/project/openspec/config.yaml" scaffold || exit 2
    fi
    for path in openspec/specs/README.md openspec/changes/archive/README.md openspec/delivery/README.md SPEC-LOGS/README.md; do
      if [ ! -e "$path" ]; then
        ohmyorch_plan_file "$path" "$OHMYORCH_CODE_ROOT/templates/project/$path" create-only || exit 2
        ohmyorch_record "$path" "$OHMYORCH_CODE_ROOT/templates/project/$path" scaffold || exit 2
      fi
    done
  fi
  if [ ! -e "$OHMYORCH_CONFIG" ]; then
    ohmyorch_plan_file .claude/ohmyorch/project.json "$OHMYORCH_STAGE/project.json" create-only || exit 2
    ohmyorch_record .claude/ohmyorch/project.json "$OHMYORCH_STAGE/project.json" config || exit 2
  fi
}

ohmyorch_adapt_plan() {
  ohmyorch_require_active
  local subject path source body
  for subject in codebase product delivery testing; do
    path=".claude/rules/ohmyorch-$subject-standards.md"
    body="$OHMYORCH_STAGE/$subject-rule"
    {
      printf '# OhMyOrch %s standards\n\n' "$subject"
      printf 'Generated by plugin %s. Evidence mapping: PRD `%s`, SPECS `%s`, CODEBASE `%s`.\n\n' "$OHMYORCH_VERSION" "$OHMYORCH_DOC_PRD" "$OHMYORCH_DOC_SPECS" "$OHMYORCH_DOC_CODEBASE"
      for source in "$OHMYORCH_DOC_PRD" "$OHMYORCH_DOC_SPECS" "$OHMYORCH_DOC_CODEBASE"; do
        if [ -f "$source" ]; then printf -- '- Evidence `%s`: SHA-256 `%s`.\n' "$source" "$(ohmyorch_hash "$source")"
        else printf -- '- Evidence `%s`: absent; do not invent its contents.\n' "$source"; fi
      done
      printf '\n'
      case "$subject" in
        codebase) printf 'Read configured CODEBASE before planning. Its observations constrain feasibility and never invent product intent. Architecture, entry points and tooling remain unknown unless evidenced there.\n' ;;
        product) printf 'Human decisions and approved source material govern intent. Ingest testable scenarios and explicit unknowns; do not invent READY stories.\n' ;;
        delivery) printf 'One story/change at a time. Derive the next action from gates. Planner returns the handoff; implementer edits product code; reviewer/tester write only their selected verdict. Archive before DONE.\n' ;;
        testing) printf 'Observe evidence for every evaluated criterion. FAIL and UNVERIFIED remain distinct; never label an unrun command PASS. Use documented project checks. Fast validation needs current local hash approval.\n' ;;
      esac
    } > "$body"
    ohmyorch_plan_owned_file "$path" "$body" || exit 2
  done
  printf '## OhMyOrch integration\n\nRun /ohmyorch:doctor, then /ohmyorch:deliver for an approved READY story.\nGuidance comes from the installed plugin plus project-evidenced rules.\n' > "$OHMYORCH_STAGE/readme-body"
  ohmyorch_plan_block README.md "$OHMYORCH_STAGE/readme-body" usage || exit 2
  MODE=merge
  ohmyorch_bootstrap_plan
  if [ "$NESTED" -eq 1 ]; then
    [ -f "$OHMYORCH_DOC_CODEBASE" ] || ohmyorch_die '--nested requires real CODEBASE evidence'
    while IFS= read -r directory; do
      case "$directory" in ./.git*|./.claude*|./node_modules*|./docs*|./openspec*) continue ;; esac
      directory=${directory#./}
      grep -Fq -- "$directory/" "$OHMYORCH_DOC_CODEBASE" || continue
      ohmyorch_path "$directory/CLAUDE.md" >/dev/null || exit 2
      printf '# Area guidance\n\nThis directory is evidenced by `%s`. Read the mapped project documents and existing code before acting. No local architecture or test command is inferred.\n' "$OHMYORCH_DOC_CODEBASE" > "$OHMYORCH_STAGE/nested-body"
      label="area-$(printf '%s' "$directory" | shasum -a 256 | cut -c1-12)"
      ohmyorch_plan_block "$directory/CLAUDE.md" "$OHMYORCH_STAGE/nested-body" "$label" || exit 2
    done < <(find . -mindepth 1 -maxdepth 1 -type d | sort)
  fi
}

ohmyorch_reset_plan() {
  ohmyorch_require_active
  local row path kind expected current begin end
  if [ "$SCOPE" = workflow ]; then
    ohmyorch_plan_file "$OHMYORCH_DOC_PRD" "$OHMYORCH_CODE_ROOT/templates/project/PRD.md" raw-update || exit 2
    ohmyorch_plan_file "$OHMYORCH_DOC_SPECS" "$OHMYORCH_CODE_ROOT/templates/project/SPECS.md" raw-update || exit 2
    while IFS= read -r path; do
      case "$path" in */README.md) continue ;; esac
      ohmyorch_plan_file "$path" DELETE raw-update || exit 2
    done < <(find openspec/specs openspec/changes openspec/delivery -type f 2>/dev/null | sort)
    return
  fi
  while IFS= read -r row; do
    path=$(jq -r .key <<< "$row"); kind=$(jq -r .value.kind <<< "$row"); expected=$(jq -r .value.sha256 <<< "$row")
    case "$path" in .gitignore|.claude/ohmyorch/project.json) continue ;; esac
    case "$kind" in scaffold|config) continue ;; esac
    ohmyorch_path "$path" >/dev/null || exit 2
    [ -f "$path" ] || continue
    if [ "$kind" = block ]; then
      begin=$(jq -r .value.begin <<< "$row"); end=$(jq -r .value.end <<< "$row")
      ohmyorch_block "$path" "$begin" "$end" > "$OHMYORCH_STAGE/reset-block" || exit 2
      current=$(ohmyorch_hash "$OHMYORCH_STAGE/reset-block")
      [ "$current" = "$expected" ] || { ohmyorch_error "SKIP edited managed block: $path"; continue; }
      awk -v begin="$begin" -v end="$end" '$0==begin {skip=1} !skip {print} $0==end {skip=0}' "$path" > "$OHMYORCH_STAGE/reset-file"
      if grep -q '[^[:space:]]' "$OHMYORCH_STAGE/reset-file"; then ohmyorch_plan_file "$path" "$OHMYORCH_STAGE/reset-file" block || exit 2
      else ohmyorch_plan_file "$path" DELETE raw-update || exit 2; fi
    else
      [ "$(ohmyorch_hash "$path")" = "$expected" ] || { ohmyorch_error "SKIP edited managed file: $path"; continue; }
      ohmyorch_plan_file "$path" DELETE raw-update || exit 2
    fi
    jq --arg path "$path" 'del(.files[$path])' "$OHMYORCH_STAGE/ledger.json" > "$OHMYORCH_STAGE/ledger.next"
    mv "$OHMYORCH_STAGE/ledger.next" "$OHMYORCH_STAGE/ledger.json"
  done < <(jq -c '.files | to_entries[]' "$OHMYORCH_STAGE/ledger.json")
}

ohmyorch_upgrade_plan() {
  [ "$OHMYORCH_CONFIG_VALID" = 1 ] || ohmyorch_die 'unsupported schema; no guessed upgrade exists'
  ohmyorch_require_active
  # Initial schema is 1; code updates have no implicit project rewrite.
  if [ -f openspec/delivery/loop.state ]; then
    ohmyorch_plan_file .claude/ohmyorch/runtime/legacy-loop.state openspec/delivery/loop.state create-only || exit 2
    ohmyorch_plan_file openspec/delivery/loop.state DELETE raw-update || exit 2
  fi
}

ohmyorch_legacy_plan() {
  local row path expected actual
  while IFS= read -r row; do
    path=$(jq -r .path <<< "$row"); expected=$(jq -r .sha256 <<< "$row")
    ohmyorch_path "$path" >/dev/null || exit 2
    [ -f "$path" ] || continue
    actual=$(ohmyorch_hash "$path")
    if [ "$actual" != "$expected" ] && [ "$INCLUDE_EDITED" -ne 1 ]; then
      ohmyorch_die "edited legacy component: $path; review an --include-edited plan explicitly"
    fi
    ohmyorch_plan_file "$path" DELETE raw-update || exit 2
  done < <(jq -c '.files[]' "$OHMYORCH_CODE_ROOT/references/legacy-files.json")
  if [ -f .claude/settings.json ]; then
    ohmyorch_path .claude/settings.json >/dev/null || exit 2
    jq --slurpfile known "$OHMYORCH_CODE_ROOT/references/legacy-hooks.json" '
      if .hooks then .hooks |= with_entries(
        .key as $event | .value |= map(
          .matcher as $matcher | .hooks |= map(
            . as $handler | select(any($known[0][];
              .event==$event and .matcher==$matcher and .command==$handler.command) | not)
          ) | select(.hooks|length>0)
        ) | select(.value|length>0)
      ) | if .hooks=={} then del(.hooks) else . end else . end
    ' .claude/settings.json > "$OHMYORCH_STAGE/settings.json" || exit 2
    # Avoid formatting-only edits when no owned registration was removed.
    if ! jq -e --slurpfile new "$OHMYORCH_STAGE/settings.json" '.==$new[0]' .claude/settings.json >/dev/null; then
      ohmyorch_plan_file .claude/settings.json "$OHMYORCH_STAGE/settings.json" raw-update || exit 2
    fi
  fi
  ohmyorch_bootstrap_plan
}

ohmyorch_lifecycle_main() {
  ohmyorch_lifecycle_parse "$@"
  ohmyorch_stage_begin || exit 2
  trap 'ohmyorch_stage_cleanup; ohmyorch_unlock' EXIT
  case "$OHMYORCH_OPERATION" in
    bootstrap) ohmyorch_bootstrap_plan ;;
    adapt-project) ohmyorch_adapt_plan ;;
    upgrade-project) ohmyorch_upgrade_plan ;;
    harness-reset) ohmyorch_reset_plan ;;
    migrate-legacy) ohmyorch_legacy_plan ;;
    *) ohmyorch_die "unknown lifecycle operation: $OHMYORCH_OPERATION" ;;
  esac
  ohmyorch_plan_finish || exit 2
  if [ "$APPLY" -eq 0 ]; then ohmyorch_print_plan; return; fi
  if [ "$OHMYORCH_OPERATION" = migrate-legacy ] ||
     { [ "$OHMYORCH_OPERATION" = harness-reset ] && [ "$SCOPE" = workflow ]; }; then
    [ -n "$REVIEWED_PLAN" ] && [ "$REVIEWED_PLAN" = "$OHMYORCH_PLAN_ID" ] || ohmyorch_die "review --dry-run first, then --apply --plan-id $OHMYORCH_PLAN_ID"
  elif [ -n "$REVIEWED_PLAN" ]; then
    [ "$REVIEWED_PLAN" = "$OHMYORCH_PLAN_ID" ] || ohmyorch_die 'reviewed plan is stale'
  fi
  ohmyorch_apply_plan
}
