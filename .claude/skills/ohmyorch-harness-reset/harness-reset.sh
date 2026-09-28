#!/usr/bin/env bash
#
# harness-reset.sh — back up a project harness, then reset project artifacts to
# the canonical initial state defined by the installed `.claude/` harness.
#
# Scenario implemented:
#   Given a project has run the harness and accumulated project-specific artifacts
#   When  the Product Manager runs /ohmyorch-harness-reset
#   Then  the harness writes a verified timestamped backup and then restores every
#         scoped artifact to its canonical baseline, leaving .claude/ untouched
#
# THE PROPERTIES THIS SCRIPT PROTECTS
#
#   1. Backup before mutation, and never a partial reset. The backup is written
#      and verified first; if any backup step fails the script aborts and the
#      live tree is not touched at all.
#   2. Never overwrite a backup. The timestamped directory is created with mkdir
#      (not -p), so an existing backup makes the run fail rather than merge.
#   3. The live `.claude/` directory is never modified. Agents, skills, hooks,
#      commands, rules, and settings are exactly the mechanism that defines the
#      canonical state, so overwriting them would remove the definition of
#      correct. This is verified by hashing the whole tree before and after.
#   4. Never leave the scope, and never follow a symlink out of it. Files outside
#      the explicit reset scope — application source above all — are byte-identical
#      afterwards, and a symlink is backed up as a link, never dereferenced.
#   5. Reset is by canonical baseline, not by emptying. The baseline shipped with
#      the `.claude/` harness is *copied over* the project, so templates and
#      structure are restored rather than deleted.
#
# SCOPE
#
#   backed up only      .claude/
#   backed up + reset   CLAUDE.md, PRD.md, SPECS.md, README.md,
#                       SPEC-LOGS/, openspec/, scripts/, and every nested
#                       CLAUDE.md outside .claude/
#   never touched       anything else, including the host's own scripts/ files
#                       such as scripts/fast-validate.sh (README, "Add the
#                       Harness Files" — the host supplies that command)
#
# WHERE THE CANONICAL BASELINE LIVES
#
#   .claude/skills/ohmyorch-harness-reset/canonical/
#
# The baseline is a literal tree, not a generator. A generator would have to
# re-derive the canonical state at reset time, so a bug in it would corrupt the
# tree it is supposed to restore; a literal copy cannot. It lives inside
# `.claude/`, which is never modified and never reset — so it cannot be destroyed
# by the operation that reads it.
#
# Usage:
#   .claude/skills/ohmyorch-harness-reset/harness-reset.sh [options]
#
# Options:
#   --root <dir>    Repository root (default: the repository that contains this script)
#   --dry-run       Report what would change; write nothing
#   --quiet         Print only failures and the final report
#   -h, --help      Show this help
#
# This engine lives under `.claude/`, not under `scripts/`, and that placement is
# deliberate. It replaces `scripts/` wholesale, and bash reads a script file
# incrementally, so a script living in `scripts/` would be executing a different
# file halfway through the run. `.claude/` is never written, so the problem cannot
# arise here. A thin launcher at `scripts/harness-reset.sh` delegates to this file
# for conventional invocation; the launcher is inside the replaced tree, which is
# harmless because it is a separate process that finishes immediately.
#
# Exit codes:
#   0  backup and reset both verified
#   1  aborted (nothing changed) or reset verification failed
#   3  usage error
#
# Dependencies: bash, find, cp, mkdir, rm, shasum, readlink, cmp, cut, awk,
# sort, grep, sed, date, mktemp — no Node or Python (NFR-001). Verified on macOS
# bash 3.2 and BSD userland.

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)

ROOT=""
DRY_RUN=0
QUIET=0

# The two scopes. SCOPE_BACKUP_ONLY is captured but never written back. These
# embedded defaults are the fallback; manifest.tsv is the source of truth and is
# loaded in preflight, so a reader can see the whole blast radius in data rather
# than inferring it from this script.
SCOPE_BACKUP_ONLY=".claude"
SCOPE_RESET="CLAUDE.md SPEC-LOGS openspec scripts PRD.md SPECS.md README.md"
SCOPE="$SCOPE_BACKUP_ONLY $SCOPE_RESET"

# Accumulates the preserved-file lines for the final report. A plain string rather
# than an array: macOS bash 3.2 has no associative arrays and `mapfile` is absent.
PRESERVED_LIST=""

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
Usage: scripts/harness-reset.sh [options]

Backs up the project harness to docs/resets/<yyyy-mm-dd-hh-mm-ss>/, verifies the
backup, then restores the scoped artifacts to the canonical baseline shipped with
the installed .claude/ harness. The live .claude/ directory is never modified.

Options:
  --root <dir>    Repository root (default: the repository that contains this script)
  --dry-run       Report what would change; write nothing
  --quiet         Print only failures and the final report
  -h, --help      Show this help

Scopes:
  backed up only       .claude/
  backed up + reset    CLAUDE.md, PRD.md, SPECS.md, README.md, SPEC-LOGS/,
                       openspec/, scripts/, nested CLAUDE.md outside .claude/

Exit codes:
  0  backup and reset both verified
  1  aborted (nothing changed) or reset verification failed
  3  usage error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || { echo "error: --root needs a value" >&2; exit 3; }
      ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve the repository root
# ---------------------------------------------------------------------------
#
# No self re-execution and no temp copy of this script. The reset replaces
# `scripts/` wholesale, and bash reads a script file incrementally — so a script
# that lived in `scripts/` would be reading a different file halfway through.
# This engine therefore lives under `.claude/`, which the reset never touches, and
# the problem does not arise.

if [ -z "$ROOT" ]; then
  # `.claude/skills/ohmyorch-harness-reset/` → three levels up is the repository root.
  if [ -d "$SCRIPT_DIR/../../../.claude" ]; then ROOT="$SCRIPT_DIR/../../.."
  else ROOT="$PWD"; fi
fi
ROOT=$(cd -- "$ROOT" 2>/dev/null && pwd -P) || {
  echo "error: cannot resolve root '$ROOT'" >&2; exit 3; }

CANON="$ROOT/.claude/skills/ohmyorch-harness-reset/canonical"

# The scope is data, not code: the file lists which paths this reset owns. A
# reader can see the whole blast radius without reading the script.
MANIFEST="$ROOT/.claude/skills/ohmyorch-harness-reset/manifest.tsv"
PRESERVE_LIST="$ROOT/.claude/skills/ohmyorch-harness-reset/PRESERVE.tsv"

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

# is_real_dir <path> — true when the path is a directory that is not a symlink
# and whose physical location is inside the repository root.
is_real_dir() {
  [ -d "$1" ] || return 1
  [ -L "$1" ] && return 1
  local phys
  phys=$(cd -- "$1" 2>/dev/null && pwd -P) || return 1
  case "$phys" in
    "$ROOT"|"$ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# all_paths <root> — every file in the repository, excluding .git and anything
# under the backup directory. Relative, physical-canonical form.
#
# The relative form matters: `find . -name .git -prune` still descends into
# .git/worktrees and .git/modules, so an absent explicit prune lets git's own
# bookkeeping files look like out-of-scope edits.
all_paths() {
  ( cd "$1" || exit 1
    find . -name .git -prune -o -type f -print
    find . -name .git -prune -o -type l -print
    find . -name .git -prune -o -type d -print
  ) | sed 's|^\./||' | grep -v '^$' | LC_ALL=C sort -u
}

# in_scope <relative-path> — true when the path is inside a scope entry.
in_scope() {
  local rel="$1" e
  for e in $SCOPE; do
    case "$rel" in "$e"|"$e"/*) return 0 ;; esac
  done
  return 1
}

# is_backup_path <relative-path> — true when the path is under docs/resets/.
is_backup_path() {
  case "$1" in docs/resets|docs/resets/*) return 0 ;; *) return 1 ;; esac
}

# scope_files <root> — every file in the backup+reset scope, relative paths.
scope_files() {
  ( cd "$1" || exit 1
    for e in $SCOPE; do
      if [ -L "$e" ]; then printf '%s\n' "$e"
      elif [ -f "$e" ]; then printf '%s\n' "$e"
      elif [ -d "$e" ]; then find "$e" -type f -print
      fi
    done
  ) | sed 's|^\./||' | LC_ALL=C sort
}

# manifest_scope <root> <out> — sha-256 of every scope file.
manifest_scope() {
  : > "$2"
  scope_files "$1" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s  %s\n' "$(shasum -a 256 "$1/$f" 2>/dev/null | awk '{print $1}')" "$f"
  done >> "$2"
}

# manifest_tree <root> <out> — a full inventory of everything the reset must not
# change: every file, symlink, and directory except the scope and the backups.
#
# Tab-separated, three fields: TYPE, PATH, DETAIL (a hash, a link target, or
# empty). Tabs mean `cut -f2` extracts the path and a path containing spaces is
# not ambiguous, which a space-padded format would make it.
#
# Directories are included deliberately. A scope entry can be removed and
# re-copied without changing any surviving file, so a file-only comparison would
# report "unchanged" while a directory silently vanished.
manifest_tree() {
  : > "$2"
  all_paths "$1" | while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    in_scope "$rel" && continue
    is_backup_path "$rel" && continue
    if [ -L "$1/$rel" ]; then
      printf 'l\t%s\t%s\n' "$rel" "$(readlink "$1/$rel" 2>/dev/null)"
    elif [ -d "$1/$rel" ]; then
      printf 'd\t%s\t\n' "$rel"
    else
      printf 'f\t%s\t%s\n' "$rel" "$(shasum -a 256 "$1/$rel" 2>/dev/null | awk '{print $1}')"
    fi
  done >> "$2"
}

# tree_delta <before> <after> — write three path lists: added, removed, modified.
#
# One awk pass over both manifests, keyed by path. `comm` alone cannot classify an
# edited file: for an edit the before and after lines share a path, so a line diff
# reports "one removed, one added" for what is really one modification. Keying by
# path keeps the three cases distinct, which is what the report has to name.
tree_delta() {
  awk -F'\t' \
      -v added="$TMP/delta.added" \
      -v removed="$TMP/delta.removed" \
      -v modified="$TMP/delta.modified" '
    NR == FNR { before[$2] = $1 "\t" $3; seen[$2] = 1; next }
    { after[$2] = $1 "\t" $3; seen[$2] = 1 }
    END {
      for (p in seen) {
        b = (p in before) ? before[p] : ""
        a = (p in after)  ? after[p]  : ""
        if      (b == "" && a != "") print p > added
        else if (b != "" && a == "") print p > removed
        else if (b != a)             print p > modified
      }
    }
  ' "$1" "$2"
  for f in added removed modified; do
    LC_ALL=C sort "$TMP/delta.$f" -o "$TMP/delta.$f" 2>/dev/null || true
  done
}

# count_scope <root> <entry> — files under one scope entry.
count_scope() {
  if [ -L "$1/$2" ] || [ -f "$1/$2" ]; then printf '1\n'
  elif [ -d "$1/$2" ]; then find "$1/$2" -type f -print | grep -c . || true
  else printf '0\n'; fi
}

# copy_scope <srcroot> <destroot> — copy every scope entry, following no symlink.
copy_scope() {
  for e in $SCOPE; do
    if [ -L "$1/$e" ] || [ -f "$1/$e" ]; then
      mkdir -p "$2" 2>/dev/null
      cp -P "$1/$e" "$2/$e" 2>/dev/null || return 1
    elif [ -d "$1/$e" ]; then
      mkdir -p "$2" 2>/dev/null
      cp -RP "$1/$e" "$2/$e" 2>/dev/null || return 1
    fi
  done
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-harness-reset.XXXXXX") || {
  echo "error: cannot create temp dir" >&2; exit 1; }
# HARNESS_RESET_KEEP=1 preserves the working directory (manifests and deltas) for
# diagnosis instead of deleting it with the process. The documents this tool
# produces are about a tree that no longer exists, so nothing else can reproduce
# them after the fact.
if [ "${HARNESS_RESET_KEEP:-0}" = "1" ]; then
  KEEP_DIR="${TMPDIR:-/tmp}/ohmyorch-harness-reset-debug"
  rm -rf "$KEEP_DIR" 2>/dev/null
  # Copy BEFORE removing: the source is what is being preserved.
  trap 'mkdir -p "$KEEP_DIR"; cp -R "$TMP"/. "$KEEP_DIR"/ 2>/dev/null; rm -rf "$TMP"; printf "\ndebug artifacts: %s\n" "$KEEP_DIR"' EXIT
else
  trap 'rm -rf "$TMP"' EXIT
fi

abort() {
  printf '\n%sABORTED%s  %s\n' "$c_red" "$c_reset" "$1"
  printf '  %sNo scoped file was changed. The project is exactly as it was.%s\n' \
    "$c_dim" "$c_reset"
  exit 1
}

# reset_error <message> — record a failure during the reset phase. It cannot be a
# plain `fail` call, because the reset phase must be able to report a problem and
# still reach verification, which is what turns the run non-zero.
reset_error() {
  fail "$1"
  printf '%s\n' "$1" >> "$TMP/reset-errors"
}

# ---------------------------------------------------------------------------
# Preflight and the scope manifest
# ---------------------------------------------------------------------------

TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_REL="docs/resets/$TIMESTAMP"

# Load the scope from manifest.tsv, which is the source of truth. The embedded
# defaults only stand in when the file is missing. Two sources of truth that can
# disagree is the failure this avoids: a reader would trust the manifest while the
# script did something else.
load_manifest() {
  [ -f "$MANIFEST" ] || return 0
  local b="" r="" mode path note
  while IFS="$(printf '\t')" read -r mode path note; do
    case "$mode" in
      ''|'#'*) continue ;;
      backup) b="$b $path" ;;
      reset)  r="$r $path" ;;
    esac
  done < "$MANIFEST"
  b="${b# }"; r="${r# }"
  [ -n "$b" ] && SCOPE_BACKUP_ONLY="$b"
  [ -n "$r" ] && SCOPE_RESET="$r"
  SCOPE="$SCOPE_BACKUP_ONLY $SCOPE_RESET"
}

# A scope entry that is a symlink is not reset, because removing it would need
# its target removed too and that is outside the repository. Checking is separate
# from removing, so a refused entry is decided before any file is touched.
scope_has_external_symlink() {
  local e
  for e in $SCOPE_RESET; do
    [ -L "$ROOT/$e" ] || continue
    if ! is_real_dir "$ROOT/$e"; then printf '%s\n' "$e"; fi
  done
}

preflight() {
  [ -n "$ROOT" ] && [ "$ROOT" != "/" ] || abort "refusing to operate on '$ROOT'"
  [ "$ROOT" != "$HOME" ] || abort "refusing to operate on the home directory"
  case "$ROOT" in *" "*)
    abort "the repository path contains a space; this script does not support that" ;;
  esac

  [ -d "$ROOT/.claude" ] || abort "no '.claude/' directory in $ROOT — not a harness project"
  [ -d "$CANON" ] || abort "canonical baseline missing at '$CANON'
  The installed .claude/ harness does not carry the baseline this script resets to."

  load_manifest

  for f in CLAUDE.md PRD.md SPECS.md README.md; do
    [ -f "$CANON/$f" ] || abort "canonical baseline is incomplete: missing '$f'"
  done

  # The baseline must not contain the backup directory, or a reset would restore
  # old backups over the live tree.
  if [ -e "$CANON/docs/resets" ]; then
    abort "canonical baseline contains docs/resets/ — refusing to reset"
  fi

  # Every reset entry must be defined by the baseline. An entry the baseline
  # lacks would be deleted and not restored, which is data loss, not a reset.
  local e
  for e in $SCOPE_RESET; do
    [ -e "$CANON/$e" ] || abort "canonical baseline does not define scope entry '$e'
  Refusing to delete a path this reset cannot restore."
  done

  # A symlink pointing outside the repository is never followed or removed.
  local ext
  ext=$(scope_has_external_symlink)
  if [ -n "$ext" ]; then
    abort "scope entry resolves outside the repository: $ext
  A symlink is left in place rather than followed; remove it yourself if it should go."
  fi

  # A second reset while the first is in flight would race the same directories.
  if [ -f "$ROOT/docs/resets/.harness-reset.lock" ]; then
    abort "a reset is already in progress (docs/resets/.harness-reset.lock)"
  fi
}

# ---------------------------------------------------------------------------
# Step 1 — Backup
# ---------------------------------------------------------------------------

BACKUP_VERIFIED=0

do_backup() {
  step "1. Backup"

  if [ -e "$ROOT/$BACKUP_REL" ]; then
    abort "backup already exists at '$BACKUP_REL' — refusing to overwrite it"
  fi

  # mkdir without -p: creates the whole chain only if nothing exists, and fails
  # if any component already exists. That is the "never overwrite" guarantee.
  if ! mkdir -p "$ROOT/docs/resets" 2>/dev/null; then
    abort "cannot create '$ROOT/docs/resets'"
  fi
  if ! mkdir "$ROOT/$BACKUP_REL" 2>/dev/null; then
    abort "cannot create backup directory '$BACKUP_REL' (already present?)"
  fi

  if ! copy_scope "$ROOT" "$ROOT/$BACKUP_REL"; then
    abort "a file could not be copied into '$BACKUP_REL'"
  fi

  # Per-scope counts, for the report.
  for e in $SCOPE; do
    n=$(count_scope "$ROOT" "$e")
    n=${n:-0}
    pass "$e — $n file(s)"
  done

  # Verification: hash every scope file in the live tree and in the backup and
  # require the manifests to be identical. A count alone would miss a truncated
  # file; a hash alone would miss a missing one. Compare both.
  manifest_scope "$ROOT" "$TMP/live.manifest"
  manifest_scope "$ROOT/$BACKUP_REL" "$TMP/backup.manifest"
  live_n=$(grep -c . "$TMP/live.manifest" || true); live_n=${live_n:-0}
  back_n=$(grep -c . "$TMP/backup.manifest" || true); back_n=${back_n:-0}

  if [ "$live_n" != "$back_n" ]; then
    abort "backup incomplete: $live_n file(s) live, $back_n backed up"
  fi
  if ! diff -q "$TMP/live.manifest" "$TMP/backup.manifest" >/dev/null 2>&1; then
    printf '%s\n' "$(diff -u "$TMP/live.manifest" "$TMP/backup.manifest" 2>/dev/null | head -12)"
    abort "backup content differs from the live tree"
  fi

  # A backup that cannot be read back is not a backup.
  if ! ( cd "$ROOT/$BACKUP_REL" && shasum -a 256 -c "$TMP/backup.manifest" >/dev/null 2>&1 ); then
    abort "backup failed its own checksum read-back"
  fi

  BACKUP_VERIFIED=1
  pass "backup verified — $back_n file(s); hashes match and read back clean"

  # The lock lives beside the backups, never inside one.
  printf 'pid %s\nstarted %s\nroot %s\n' "$$" "$TIMESTAMP" "$ROOT" \
    > "$ROOT/docs/resets/.harness-reset.lock" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Step 2 — Reset
# ---------------------------------------------------------------------------

reset_scopes() {
  step "2. Reset to canonical baseline"

  manifest_tree "$ROOT" "$TMP/tree.before"

  # --- remove the reset-owned entries -------------------------------------
  # preflight has already refused if any entry resolves outside the repository,
  # so a symlink here is in-repo and safe to remove as a link.
  for e in $SCOPE_RESET; do
    if [ -L "$ROOT/$e" ] || [ -f "$ROOT/$e" ]; then
      rm -f "$ROOT/$e" 2>/dev/null || reset_error "cannot remove '$e'"
    elif [ -d "$ROOT/$e" ]; then
      rm -rf "$ROOT/$e" 2>/dev/null || reset_error "cannot remove '$e/'"
    fi
  done

  # Nested CLAUDE.md files outside .claude/. A host may keep one per package or
  # per service; all of them are harness-generated contracts, so all of them go.
  #
  # This runs under `set -o pipefail`; a bare `grep -v` exits 1 when it filters
  # everything out, which would abort the whole reset. The `|| true` is load
  # bearing, not cosmetic.
  nested=$(find "$ROOT" -name .git -prune -o -name CLAUDE.md -type f -print 2>/dev/null \
    | grep -v "^$ROOT/\.claude/" || true)
  printf '%s\n' "$nested" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    relf=${f#"$ROOT"/}
    [ "$relf" = "CLAUDE.md" ] && continue
    rm -f "$f" 2>/dev/null || reset_error "cannot remove nested '$relf'"
  done

  # read by reset_error; a subshell's assignment would not survive it, so the
  # count is collected from a file instead.
  if [ -s "$TMP/reset-errors" ]; then
    RESET_ERRORS=$(grep -c . "$TMP/reset-errors" || true)
    RESET_ERRORS=${RESET_ERRORS:-0}
  fi

  # --- copy the canonical baseline over the project -----------------------
  for e in $SCOPE_RESET; do
    [ -e "$CANON/$e" ] || continue
    if [ -L "$CANON/$e" ] || [ -f "$CANON/$e" ]; then
      mkdir -p "$ROOT" 2>/dev/null
      cp -P "$CANON/$e" "$ROOT/$e" 2>/dev/null || reset_error "cannot restore '$e'"
    else
      cp -RP "$CANON/$e" "$ROOT/$e" 2>/dev/null || reset_error "cannot restore '$e/'"
    fi
  done
  pass "canonical baseline restored"

  # --- drop host files the canonical baseline does not define -------------
  #
  # This second pass exists because `cp -RP` merges: a file the project added
  # inside `scripts/` or `openspec/` would otherwise survive the restore.
  prune_extras scripts
  prune_extras openspec
  prune_extras SPEC-LOGS

  # --- then put the host's own commands back ------------------------------
  #
  # Order matters: pruning must run first, or it would remove exactly the files
  # this step exists to keep. scripts/fast-validate.sh is the documented host
  # extension point (README, "Add the Harness Files");
  # run-project-validation.sh calls it. Deleting it would silently disable a
  # configured hook, so anything on the preserve list is copied back from the
  # verified backup.
  preserve_host_files
}

# preserve_host_files — restore files on the preserve list from the backup.
preserve_host_files() {
  [ -f "$PRESERVE_LIST" ] || return 0
  [ -d "$ROOT/$BACKUP_REL" ] || return 0

  while IFS= read -r rel; do
    case "$rel" in ''|'#'*) continue ;; esac
    src="$ROOT/$BACKUP_REL/$rel"
    [ -e "$src" ] || [ -L "$src" ] || continue
    mkdir -p "$(dirname -- "$ROOT/$rel")" 2>/dev/null
    if cp -P "$src" "$ROOT/$rel" 2>/dev/null; then
      PRESERVED_LIST="${PRESERVED_LIST}${rel} (host-provided; restored from the backup)
"
    else
      warn "could not restore preserved file '$rel'"
    fi
  done < "$PRESERVE_LIST"
}

# prune_extras <scope-relative-dir> — remove live files the baseline lacks.
prune_extras() {
  rel="$1"
  live="$ROOT/$rel"
  base="$CANON/$rel"
  [ -d "$live" ] || return 0
  ( cd "$live" && find . -type f -print ) | sed 's|^\./||' | while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -e "$base/$f" ] || rm -f "$live/$f" 2>/dev/null
  done
  # Remove directories that pruning emptied, deepest first.
  find "$live" -mindepth 1 -type d -depth -exec rmdir {} \; 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Step 3 — Verify
# ---------------------------------------------------------------------------

VERIFY_OK=1
RESET_ERRORS=0

verify_reset() {
  step "3. Verify"

  # (0) A failure during the reset phase is fatal on its own, even if the tree
  # happens to look right afterwards.
  if [ "$RESET_ERRORS" -gt 0 ]; then
    fail "$RESET_ERRORS error(s) during the reset phase"
    sed 's/^/        /' "$TMP/reset-errors" 2>/dev/null | head -5
    VERIFY_OK=0
  fi

  # (a) Every canonical artifact is byte-identical to the baseline.
  different=0
  for e in CLAUDE.md PRD.md SPECS.md README.md; do
    if [ -f "$CANON/$e" ]; then
      if ! cmp -s "$CANON/$e" "$ROOT/$e" 2>/dev/null; then
        fail "$e does not match the canonical baseline"; different=$((different + 1))
      fi
    fi
  done
  [ "$different" -eq 0 ] && pass "CLAUDE.md, PRD.md, SPECS.md, README.md match the baseline"

  # (b) openspec/ has the canonical structure and no active change.
  active=$(find "$ROOT/openspec/changes" -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null | grep -c . || true)
  active=${active:-0}
  if [ "$active" -eq 0 ]; then pass "openspec/changes has no active change (archive/ only)"
  else fail "openspec/changes still has $active active change(s)"; VERIFY_OK=0; fi

  for d in "$ROOT/openspec/specs" "$ROOT/openspec/changes/archive" "$ROOT/openspec/delivery"; do
    [ -d "$d" ] || { fail "missing ${d#$ROOT/}"; VERIFY_OK=0; }
  done
  [ -f "$ROOT/openspec/config.yaml" ] || { fail "missing openspec/config.yaml"; VERIFY_OK=0; }

  # (c) scripts/ exists and is runnable.
  if [ -d "$ROOT/scripts" ] && [ -f "$ROOT/scripts/delivery.sh" ]; then
    pass "scripts/ restored ($(count_scope "$ROOT" scripts) file(s))"
  else
    fail "scripts/ was not restored from the canonical baseline"; VERIFY_OK=0
  fi
  chmod +x "$ROOT"/scripts/*.sh 2>/dev/null || true

  # (d) SPEC-LOGS/ is back to its canonical index.
  [ -f "$ROOT/SPEC-LOGS/README.md" ] && pass "SPEC-LOGS/ restored" \
    || { fail "SPEC-LOGS/README.md missing"; VERIFY_OK=0; }

  # (e) No nested CLAUDE.md outside .claude/ survived.
  stray=$(find "$ROOT" -name .git -prune -o -name CLAUDE.md -type f -print 2>/dev/null \
    | grep -v "^$ROOT/.claude/" | grep -vc "^$ROOT/CLAUDE.md$" || true)
  stray=${stray:-0}
  [ "$stray" -eq 0 ] && pass "no nested CLAUDE.md file outside .claude/" \
    || { fail "$stray nested CLAUDE.md file(s) remain"; VERIFY_OK=0; }

  # (f) Everything outside the scope is byte-identical to what it was.
  #
  # Three cases, and they are not the same: a path that appeared, a path that
  # vanished, and a path whose content changed. A count of changes would conflate
  # them, and the report would not be able to say which happened. Only the first
  # two are visible to a line diff of the manifests.
  manifest_tree "$ROOT" "$TMP/tree.after"
  tree_delta "$TMP/tree.before" "$TMP/tree.after"

  if [ -s "$TMP/delta.added" ]; then
    # The reset never adds anything outside the scope.
    fail "$(grep -c . "$TMP/delta.added") unexpected path(s) appeared outside the scope:"
    head -5 "$TMP/delta.added" | sed 's/^/        /'
    VERIFY_OK=0
  fi

  if [ -s "$TMP/delta.removed" ]; then
    # A removal outside the scope is expected only for a nested CLAUDE.md, which
    # the reset owns by name rather than by path.
    unexpected=$(grep -cv 'CLAUDE\.md$' "$TMP/delta.removed" || true)
    unexpected=${unexpected:-0}
    if [ "$unexpected" -eq 0 ]; then
      pass "nested CLAUDE.md file(s) removed, as the reset intends"
    else
      fail "$unexpected path(s) outside the scope were removed:"
      grep -v 'CLAUDE\.md$' "$TMP/delta.removed" | head -5 | sed 's/^/        /'
      VERIFY_OK=0
    fi
  fi

  if [ -s "$TMP/delta.modified" ]; then
    fail "$(grep -c . "$TMP/delta.modified") out-of-scope path(s) changed content:"
    head -5 "$TMP/delta.modified" | sed 's/^/        /'
    VERIFY_OK=0
  fi

  if [ ! -s "$TMP/delta.added" ] && [ ! -s "$TMP/delta.modified" ] \
     && [ ! -s "$TMP/delta.removed" ]; then
    in_claude=$(count_scope "$ROOT" .claude)
    pass ".claude/ and every file outside the scope are unchanged ($in_claude file(s) under .claude/)"
  elif [ "$VERIFY_OK" -eq 1 ]; then
    in_claude=$(count_scope "$ROOT" .claude)
    pass ".claude/ and all $in_claude out-of-scope file(s) untouched; only owned files changed"
  fi
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

print_report() {
  step "Report"
  printf '  %-16s %s\n' "Backup"   "$BACKUP_REL/"
  printf '  %-16s %s\n' "Backed up" "$(grep -c . "$TMP/live.manifest" 2>/dev/null || echo 0) file(s) across $(printf '%s' "$SCOPE" | wc -w | tr -d ' ') scope entries"
  printf '  %-16s %s\n' "Preserved" ".claude/ (agents, skills, hooks, commands, rules, settings) — unchanged"
  if [ -n "$PRESERVED_LIST" ]; then
    printf '%s' "$PRESERVED_LIST" | while IFS= read -r line; do
      [ -n "$line" ] && printf '  %-16s %s\n' "" "$line"
    done
  fi
  printf '  %-16s %s\n' "Reset"     "$(printf '%s' "$SCOPE_RESET" | tr ' ' ', ' | sed 's/, $//')"
  if [ "$BACKUP_VERIFIED" -eq 1 ]; then
    printf '  %-16s %s\n' "Backup check" "PASS"
  else
    printf '  %-16s %s\n' "Backup check" "FAIL"
  fi
  if [ "$VERIFY_OK" -eq 1 ]; then
    printf '  %-16s %s\n' "Reset check" "PASS"
    printf '\n  %sRESULT: PASS%s — backup verified, reset verified\n' "$c_green" "$c_reset"
  else
    printf '  %-16s %s\n' "Reset check" "FAIL"
    printf '\n  %sRESULT: FAIL%s — the backup is intact; the reset did not verify\n' "$c_red" "$c_reset"
  fi
  printf '  Restore with: cd %s && cp -RP %s/. .\n' "$ROOT" "$BACKUP_REL"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

say "OhMyOrch Harness — canonical reset"
say "=================================="
say ""
say "TARGET   $ROOT"
say "BASELINE $CANON"
say "BACKUP   $BACKUP_REL/"

preflight

if [ "$DRY_RUN" -eq 1 ]; then
  step "Dry run — nothing will be written"
  changed=0
  for e in $SCOPE_RESET; do
    if [ -d "$CANON/$e" ]; then
      # A directory entry is always replaced, because a file the project added
      # inside it must not survive.
      say "  replace $e/ ($(count_scope "$ROOT" "$e") live file(s) → baseline)"
      changed=$((changed + 1))
    elif cmp -s "$CANON/$e" "$ROOT/$e" 2>/dev/null; then
      note "$e — already canonical"
    else
      say "  reset   $e"
      changed=$((changed + 1))
    fi
  done

  # Nested CLAUDE.md files are reset by name, so a dry run must name them too.
  nested=$(find "$ROOT" -name .git -prune -o -name CLAUDE.md -type f -print 2>/dev/null \
    | grep -v "^$ROOT/\.claude/" | grep -v "^$ROOT/CLAUDE.md$" || true)
  if [ -n "$nested" ]; then
    printf '%s\n' "$nested" | while IFS= read -r f; do
      [ -n "$f" ] && say "  remove  ${f#$ROOT/}"
    done
    changed=$((changed + 1))
  fi

  say ""
  say "$changed scope entr(ies) would be reset. .claude/ would not be touched."
  say "A backup would be written to $BACKUP_REL/ first and verified."
  exit 0
fi

do_backup
reset_scopes
verify_reset
rm -f "$ROOT/docs/resets/.harness-reset.lock" 2>/dev/null || true
print_report

# A reset that did not verify is a failure, whatever the report prints. The
# backup is intact and the restore command is in the report, so exiting non-zero
# is the only honest outcome.
if [ "$VERIFY_OK" -eq 1 ]; then exit 0; fi
exit 1
