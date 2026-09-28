#!/usr/bin/env bash
#
# ohmyorch-post-install.sh — adapt an installed OhMyOrch harness to a host repo.
#
# The script backs up the current guidance surface before writing anything, then
# creates namespaced rules and managed README/CLAUDE sections from PRD.md,
# CODEBASE.md, and SPECS.md. It is deliberately conservative: unmanaged files are
# merged through marked blocks or skipped unless --mode override is explicit.

set -uo pipefail

ROOT=""
MODE="merge"
DRY_RUN=0
QUIET=0
NESTED=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""; c_bold=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { [ "$QUIET" -eq 1 ] || printf '  %sPASS%s  %s\n' "$c_green" "$c_reset" "$*"; }
note() { [ "$QUIET" -eq 1 ] || printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
warn() { printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
step() { printf '\n%s%s%s\n' "$c_bold" "$*" "$c_reset"; }

usage() {
  cat <<'EOF'
Usage: .claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh [options]

Back up .claude and repository guidance, then generate OhMyOrch project-specific
rules and managed README/CLAUDE guidance from CODEBASE.md, PRD.md, and SPECS.md.

Options:
  --root <dir>          Repository root (default: current git root or cwd)
  --mode <mode>         create-only, merge, or override (default: merge)
  --nested             Create nested CLAUDE.md files for CODEBASE-evidenced dirs
  --dry-run            Print the plan; write nothing
  --quiet              Suppress informational output
  -h, --help           Show this help

Exit codes:
  0  success or dry-run success
  1  failed; no writes happen before backup verification
  3  usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || { echo "error: --root needs a value" >&2; exit 3; }
      ROOT="$2"; shift 2 ;;
    --mode)
      [ $# -ge 2 ] || { echo "error: --mode needs a value" >&2; exit 3; }
      MODE="$2"; shift 2 ;;
    --nested) NESTED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

case "$MODE" in
  create-only|merge|override) ;;
  *) echo "error: --mode must be create-only, merge, or override" >&2; exit 3 ;;
esac

if [ -z "$ROOT" ]; then
  if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then ROOT="$git_root"; else ROOT="$PWD"; fi
fi
ROOT=$(cd -- "$ROOT" 2>/dev/null && pwd -P) || {
  echo "error: cannot resolve root '$ROOT'" >&2; exit 3; }

cd "$ROOT" || exit 3

timestamp() { date '+%Y-%m-%d-%H-%M-%S'; }

doc_path() {
  local name="$1"
  if [ -f "docs/$name" ]; then printf 'docs/%s\n' "$name"
  elif [ -f "$name" ]; then printf '%s\n' "$name"
  else return 1
  fi
}

doc_title() {
  local file="$1"
  [ -f "$file" ] || { printf 'missing'; return; }
  sed -n 's/^#\{1,2\}[[:space:]]\{1,\}//p' "$file" | head -1
}

has_managed_marker() {
  [ -f "$1" ] || return 1
  grep -Eq 'distribution:[[:space:]]*ohmyorch|ohmyorch:start|generated-by:[[:space:]]*ohmyorch-adapt' "$1"
}

relative_source_list() {
  local out=""
  [ -n "${CODEBASE:-}" ] && out="${out}- $CODEBASE"$'\n'
  [ -n "${PRD:-}" ] && out="${out}- $PRD"$'\n'
  [ -n "${SPECS:-}" ] && out="${out}- $SPECS"$'\n'
  printf '%s' "$out"
}

replace_block() {
  local target="$1" source="$2" start="$3" end="$4" tmp="$5"
  awk -v start="$start" -v end="$end" -v repl="$source" '
    BEGIN {
      while ((getline line < repl) > 0) {
        replacement = replacement line ORS
      }
      skipping = 0
    }
    $0 == start {
      printf "%s", replacement
      skipping = 1
      next
    }
    $0 == end {
      skipping = 0
      next
    }
    skipping == 0 { print }
  ' "$target" > "$tmp"
}

install_plain_file() {
  local target="$1" source="$2" action
  if [ ! -e "$target" ]; then
    action="create"
  elif has_managed_marker "$target"; then
    action="replace-managed"
  elif [ "$MODE" = "override" ]; then
    action="override"
  else
    [ "$EXECUTE" -eq 0 ] && printf 'skip\t%s\tunmanaged file exists\n' "$target" >> "$PLAN"
    return 0
  fi

  if [ "$EXECUTE" -eq 0 ]; then
    printf '%s\t%s\n' "$action" "$target" >> "$PLAN"
    return 0
  fi
  mkdir -p "$(dirname -- "$target")"
  cp "$source" "$target"
}

install_block_file() {
  local target="$1" source="$2" start="$3" end="$4" tmp
  tmp="$TMPDIR/install-block.$$"

  if [ ! -e "$target" ]; then
    if [ "$EXECUTE" -eq 0 ]; then
      printf 'create\t%s\n' "$target" >> "$PLAN"
      return 0
    fi
    mkdir -p "$(dirname -- "$target")"
    cp "$source" "$target"
    return 0
  fi

  if grep -Fqx "$start" "$target" && grep -Fqx "$end" "$target"; then
    if [ "$EXECUTE" -eq 0 ]; then
      printf 'replace-managed-block\t%s\n' "$target" >> "$PLAN"
      return 0
    fi
    replace_block "$target" "$source" "$start" "$end" "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  case "$MODE" in
    create-only)
      [ "$EXECUTE" -eq 0 ] && printf 'skip\t%s\tfile exists and create-only mode is active\n' "$target" >> "$PLAN" ;;
    merge)
      if [ "$EXECUTE" -eq 0 ]; then
        printf 'append-managed-block\t%s\n' "$target" >> "$PLAN"
        return 0
      fi
      printf '\n' >> "$target"
      cat "$source" >> "$target" ;;
    override)
      if [ "$EXECUTE" -eq 0 ]; then
        printf 'override\t%s\n' "$target" >> "$PLAN"
        return 0
      fi
      cp "$source" "$target" ;;
  esac
}

copy_backup_path() {
  local rel="$1" dest
  [ -e "$rel" ] || return 0
  dest="$BACKUP/$rel"
  mkdir -p "$(dirname -- "$dest")"
  cp -RP "$rel" "$dest"
}

write_backup_manifest() {
  : > "$BACKUP/manifest.tsv"
  ( cd "$BACKUP" || exit 1
    find . -name manifest.tsv -prune -o -type f -print
    find . -name manifest.tsv -prune -o -type l -print
  ) | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ -L "$BACKUP/$rel" ]; then
      printf 'link\t%s\t%s\n' "$rel" "$(readlink "$BACKUP/$rel")" >> "$BACKUP/manifest.tsv"
    else
      printf 'file\t%s\t%s\n' "$rel" "$(shasum -a 256 "$BACKUP/$rel" | awk '{print $1}')" >> "$BACKUP/manifest.tsv"
    fi
  done
}

verify_backup_manifest() {
  local type rel detail actual bad=0
  while IFS="$(printf '\t')" read -r type rel detail; do
    [ -n "$type" ] || continue
    case "$type" in
      file)
        [ -f "$BACKUP/$rel" ] || { fail "backup missing $rel"; bad=1; continue; }
        actual=$(shasum -a 256 "$BACKUP/$rel" | awk '{print $1}')
        [ "$actual" = "$detail" ] || { fail "backup checksum mismatch $rel"; bad=1; } ;;
      link)
        [ -L "$BACKUP/$rel" ] || { fail "backup link missing $rel"; bad=1; continue; }
        actual=$(readlink "$BACKUP/$rel")
        [ "$actual" = "$detail" ] || { fail "backup link mismatch $rel"; bad=1; } ;;
    esac
  done < "$BACKUP/manifest.tsv"
  [ "$bad" -eq 0 ]
}

find_nested_claude_files() {
  find . \
    -path './.git' -prune -o \
    -path './.claude' -prune -o \
    -path './docs/pre-install-backup' -prune -o \
    -path './docs/resets' -prune -o \
    -name CLAUDE.md -type f -print \
  | sed 's|^\./||' | LC_ALL=C sort
}

candidate_nested_dirs() {
  [ -n "${CODEBASE:-}" ] || return 0
  find . -maxdepth 1 -type d \
    ! -name . ! -name .git ! -name .claude ! -name docs ! -name openspec \
    ! -name scripts ! -name node_modules ! -name .venv ! -name venv \
    -print | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      if grep -Eq "(^|[^A-Za-z0-9_.-])${dir}(/|[^A-Za-z0-9_.-]|$)" "$CODEBASE"; then
        printf '%s\n' "$dir"
      fi
    done
}

TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-post-install.XXXXXX") || exit 1
trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM

PLAN="$TMPDIR/plan.tsv"
: > "$PLAN"
EXECUTE=0

CODEBASE=$(doc_path CODEBASE.md 2>/dev/null || true)
PRD=$(doc_path PRD.md 2>/dev/null || true)
SPECS=$(doc_path SPECS.md 2>/dev/null || true)
README_FILE=$(doc_path README.md 2>/dev/null || printf 'README.md')
CLAUDE_FILE="CLAUDE.md"

step "OhMyOrch post-install adaptation"
say "Root: $ROOT"
say "Mode: $MODE"
[ "$DRY_RUN" -eq 1 ] && say "Dry run: yes" || say "Dry run: no"
[ "$NESTED" -eq 1 ] && say "Nested CLAUDE.md generation: enabled" || say "Nested CLAUDE.md generation: disabled"

step "Source artifacts"
if [ -n "$CODEBASE" ]; then pass "CODEBASE source: $CODEBASE"; else warn "CODEBASE.md not found; codebase standards will record unknowns"; fi
if [ -n "$PRD" ]; then pass "PRD source: $PRD"; else warn "PRD.md not found; product rules will record unknowns"; fi
if [ -n "$SPECS" ]; then pass "SPECS source: $SPECS"; else warn "SPECS.md not found; delivery rules will record unknowns"; fi

mkdir -p "$TMPDIR/generated/.claude/rules" "$TMPDIR/generated/.claude/ohmyorch"

cat > "$TMPDIR/generated/.claude/rules/ohmyorch-codebase-standards.md" <<EOF
---
distribution: ohmyorch
generated-by: ohmyorch-adapt
source:
$(relative_source_list)
---

# OhMyOrch Codebase Standards

Generated from: ${CODEBASE:-CODEBASE.md missing}.

## Required context

- Read \`${CODEBASE:-CODEBASE.md}\` before planning or implementing codebase changes.
- Treat CODEBASE content as descriptive evidence, not product intent.
- If architecture, runtime, commands, or integrations are not evidenced, mark them
  unknown instead of inventing them.

## Implementation approach

- Preserve the module boundaries, entry points, and tooling described by
  \`${CODEBASE:-CODEBASE.md}\`.
- Put new work near the existing owner or analogous component named in CODEBASE.
- Prefer existing framework, dependency, validation, and testing conventions over
  new abstractions.
- Escalate when a requested change conflicts with documented constraints.
EOF

cat > "$TMPDIR/generated/.claude/rules/ohmyorch-product-rules.md" <<EOF
---
distribution: ohmyorch
generated-by: ohmyorch-adapt
source:
$(relative_source_list)
---

# OhMyOrch Product Rules

Generated from: ${PRD:-PRD.md missing}.

## Product authority

- Read \`${PRD:-PRD.md}\` before changing user-facing behavior.
- Product intent comes from PRD and explicit human Product Manager decisions.
- CODEBASE may constrain feasibility, but it must not silently become product
  intent.

## Change behavior

- Preserve product terminology from PRD.
- Respect non-goals and business rules from PRD.
- Record missing or contradictory product direction as a clarification need.
EOF

cat > "$TMPDIR/generated/.claude/rules/ohmyorch-delivery-standards.md" <<EOF
---
distribution: ohmyorch
generated-by: ohmyorch-adapt
source:
$(relative_source_list)
---

# OhMyOrch Delivery Standards

Generated from: ${SPECS:-SPECS.md missing}.

## Delivery workflow

- Read \`${SPECS:-SPECS.md}\` before selecting or delivering backlog work.
- Deliver one bounded story or task-focused story at a time.
- Keep OpenSpec artifacts, implementation, review, testing, and archive decisions
  separate.
- Do not mark work done until acceptance evidence exists and archive gates pass.

## Acceptance criteria

- Acceptance criteria must be observable and testable.
- When a story lacks testable acceptance, record the gap before implementation.
EOF

cat > "$TMPDIR/generated/.claude/rules/ohmyorch-testing-standards.md" <<EOF
---
distribution: ohmyorch
generated-by: ohmyorch-adapt
source:
$(relative_source_list)
---

# OhMyOrch Testing Standards

Generated from: ${CODEBASE:-CODEBASE.md missing} and ${SPECS:-SPECS.md missing}.

## Validation approach

- Use the validation commands documented in CODEBASE or README.
- If a project-specific \`scripts/fast-validate.sh\` exists, use it as the fast
  implementation validation command.
- Match each acceptance result to a SPECS scenario or explicit test evidence.
- Record skipped, unavailable, or slow checks as limitations, not passes.
EOF

cat > "$TMPDIR/readme-block.md" <<EOF
<!-- ohmyorch:start README -->
## OhMyOrch Harness

This repository has been adapted for the OhMyOrch \`.claude\` harness.

Primary context:

- \`${CODEBASE:-CODEBASE.md}\` — current-state codebase evidence
- \`${PRD:-PRD.md}\` — product intent
- \`${SPECS:-SPECS.md}\` — backlog and acceptance criteria
- \`.claude/rules/ohmyorch-codebase-standards.md\`
- \`.claude/rules/ohmyorch-product-rules.md\`
- \`.claude/rules/ohmyorch-delivery-standards.md\`
- \`.claude/rules/ohmyorch-testing-standards.md\`

Run post-install adaptation with:

\`\`\`bash
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh --mode merge
\`\`\`

The adapter backs up existing guidance first under
\`docs/pre-install-backup/<timestamp>/\`.
<!-- ohmyorch:end README -->
EOF

cat > "$TMPDIR/claude-block.md" <<EOF
<!-- ohmyorch:start CLAUDE -->
## OhMyOrch Project Guidance

Before planning or implementation, read the project context in this order:

1. \`${PRD:-PRD.md}\` for product intent.
2. \`${CODEBASE:-CODEBASE.md}\` for current architecture and constraints.
3. \`${SPECS:-SPECS.md}\` for backlog scope and acceptance criteria.
4. \`.claude/rules/ohmyorch-*.md\` for generated project standards.

Generated rules:

- \`.claude/rules/ohmyorch-codebase-standards.md\`
- \`.claude/rules/ohmyorch-product-rules.md\`
- \`.claude/rules/ohmyorch-delivery-standards.md\`
- \`.claude/rules/ohmyorch-testing-standards.md\`

Do not invent missing architecture, product behavior, validation commands, or
acceptance evidence. Record unknowns and ask for clarification when the source
artifacts do not support a claim.
<!-- ohmyorch:end CLAUDE -->
EOF

cat > "$TMPDIR/generated/.claude/ohmyorch/adaptation-manifest.tsv" <<EOF
owner	path
ohmyorch	.claude/rules/ohmyorch-codebase-standards.md
ohmyorch	.claude/rules/ohmyorch-product-rules.md
ohmyorch	.claude/rules/ohmyorch-delivery-standards.md
ohmyorch	.claude/rules/ohmyorch-testing-standards.md
ohmyorch	README.md
ohmyorch	CLAUDE.md
EOF

NESTED_TARGETS="$TMPDIR/nested-targets.txt"
: > "$NESTED_TARGETS"
candidate_nested_dirs > "$NESTED_TARGETS"

if [ "$NESTED" -eq 1 ] && [ -s "$NESTED_TARGETS" ]; then
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    printf 'ohmyorch\t%s/CLAUDE.md\n' "$dir" >> "$TMPDIR/generated/.claude/ohmyorch/adaptation-manifest.tsv"
  done < "$NESTED_TARGETS"
fi

apply_generated_files() {
  install_plain_file ".claude/rules/ohmyorch-codebase-standards.md" "$TMPDIR/generated/.claude/rules/ohmyorch-codebase-standards.md"
  install_plain_file ".claude/rules/ohmyorch-product-rules.md" "$TMPDIR/generated/.claude/rules/ohmyorch-product-rules.md"
  install_plain_file ".claude/rules/ohmyorch-delivery-standards.md" "$TMPDIR/generated/.claude/rules/ohmyorch-delivery-standards.md"
  install_plain_file ".claude/rules/ohmyorch-testing-standards.md" "$TMPDIR/generated/.claude/rules/ohmyorch-testing-standards.md"
  install_plain_file ".claude/ohmyorch/adaptation-manifest.tsv" "$TMPDIR/generated/.claude/ohmyorch/adaptation-manifest.tsv"
  install_block_file "$README_FILE" "$TMPDIR/readme-block.md" '<!-- ohmyorch:start README -->' '<!-- ohmyorch:end README -->'
  install_block_file "$CLAUDE_FILE" "$TMPDIR/claude-block.md" '<!-- ohmyorch:start CLAUDE -->' '<!-- ohmyorch:end CLAUDE -->'

  if [ "$NESTED" -eq 1 ]; then
    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
    nested_target="$dir/CLAUDE.md"
    cat > "$TMPDIR/nested-claude.md" <<EOF
<!-- ohmyorch:start CLAUDE -->
## OhMyOrch Local Guidance

This subtree was selected because \`${CODEBASE:-CODEBASE.md}\` names \`$dir\` as
a meaningful codebase boundary.

- Follow the repository-wide guidance in \`../CLAUDE.md\` when applicable.
- Keep changes within this subtree aligned with the architecture and commands
  documented in \`${CODEBASE:-CODEBASE.md}\`.
- Validate behavior with the local test or build commands documented for this
  area; if none are documented, record that limitation.
<!-- ohmyorch:end CLAUDE -->
EOF
      install_block_file "$nested_target" "$TMPDIR/nested-claude.md" '<!-- ohmyorch:start CLAUDE -->' '<!-- ohmyorch:end CLAUDE -->'
    done < "$NESTED_TARGETS"
  elif [ -s "$NESTED_TARGETS" ] && [ "$EXECUTE" -eq 0 ]; then
    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      printf 'skip\t%s/CLAUDE.md\tnested generation requires --nested\n' "$dir" >> "$PLAN"
    done < "$NESTED_TARGETS"
  fi
}

apply_generated_files

step "Write plan"
if [ -s "$PLAN" ]; then
  while IFS="$(printf '\t')" read -r action target detail; do
    [ -n "$action" ] || continue
    case "$action" in
      skip) warn "$target — ${detail:-skipped}" ;;
      *) pass "$action $target" ;;
    esac
  done < "$PLAN"
else
  note "No writes planned."
fi

if [ "$DRY_RUN" -eq 1 ]; then
  step "Dry run complete"
  say "No files were changed."
  exit 0
fi

step "Backup"
BACKUP_BASE="docs/pre-install-backup"
BACKUP="$BACKUP_BASE/$(timestamp)"
mkdir -p "$BACKUP_BASE" || { fail "cannot create $BACKUP_BASE"; exit 1; }
mkdir "$BACKUP" || { fail "backup already exists or cannot be created: $BACKUP"; exit 1; }

copy_backup_path ".claude"
copy_backup_path "CLAUDE.md"
copy_backup_path "PRD.md"
copy_backup_path "docs/PRD.md"
copy_backup_path "CODEBASE.md"
copy_backup_path "docs/CODEBASE.md"
copy_backup_path "SPECS.md"
copy_backup_path "docs/SPECS.md"
copy_backup_path "README.md"
copy_backup_path "docs/README.md"

find_nested_claude_files | while IFS= read -r rel; do
  [ "$rel" = "CLAUDE.md" ] && continue
  copy_backup_path "$rel"
done

write_backup_manifest
if verify_backup_manifest; then
  pass "backup verified: $BACKUP"
else
  fail "backup verification failed; aborting before writes"
  exit 1
fi

step "Apply generated guidance"
EXECUTE=1
apply_generated_files
pass "generated guidance applied"

step "Write report"
REPORT=".claude/ohmyorch/adaptation-report.md"
mkdir -p ".claude/ohmyorch"
{
  printf '# OhMyOrch Post-Install Adaptation Report\n\n'
  printf '| Field | Value |\n|---|---|\n'
  printf '| Timestamp | %s |\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '| Root | `%s` |\n' "$ROOT"
  printf '| Mode | `%s` |\n' "$MODE"
  printf '| Backup | `%s` |\n' "$BACKUP"
  printf '| CODEBASE | `%s` |\n' "${CODEBASE:-missing}"
  printf '| PRD | `%s` |\n' "${PRD:-missing}"
  printf '| SPECS | `%s` |\n\n' "${SPECS:-missing}"
  printf '## Actions\n\n'
  printf '| Action | Target | Detail |\n|---|---|---|\n'
  while IFS="$(printf '\t')" read -r action target detail; do
    [ -n "$action" ] || continue
    printf '| `%s` | `%s` | %s |\n' "$action" "$target" "${detail:-}"
  done < "$PLAN"
  printf '\n## Restore\n\n'
  printf '```bash\ncp -RP %s/. .\n```\n' "$BACKUP"
} > "$REPORT"

pass "wrote $REPORT"

step "Done"
say "Backup: $BACKUP"
say "Restore: cp -RP $BACKUP/. ."
