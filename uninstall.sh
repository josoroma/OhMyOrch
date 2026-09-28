#!/usr/bin/env sh
#
# Remove files installed by the OhMyOrch harness installer.

set -eu

TARGET="."
DRY_RUN=0
QUIET=0
FORCE=0

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*" >&2; }
fail() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Remove OhMyOrch-managed files whose current checksum matches the installed
manifest. Locally edited managed files are left in place unless --force is used.

Options:
  --target <dir>   Target repository root (default: current directory)
  --dry-run        Show what would be removed
  --force          Remove managed files even when locally edited
  --quiet          Reduce output
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) [ "$#" -ge 2 ] || fail "--target needs a value"; TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option '$1'" ;;
  esac
done

TARGET=$(cd "$TARGET" 2>/dev/null && pwd -P) || fail "cannot resolve target"
MANIFEST="$TARGET/.claude/ohmyorch/manifest.tsv"
[ -f "$MANIFEST" ] || fail "no OhMyOrch manifest found: $MANIFEST"

checksum_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

say "OhMyOrch uninstall plan"
tail -n +2 "$MANIFEST" | while IFS="$(printf '\t')" read -r owner path sum version mode; do
  [ -n "${path:-}" ] || continue
  target="$TARGET/$path"
  if [ ! -e "$target" ]; then
    say "  SKIP   $path  already absent"
    continue
  fi
  current=$(checksum_file "$target")
  if [ "$current" != "$sum" ] && [ "$FORCE" -eq 0 ]; then
    warn "$path has local edits; leaving in place"
    continue
  fi
  say "  REMOVE $path"
  [ "$DRY_RUN" -eq 1 ] && continue
  rm -f "$target"
done

[ "$DRY_RUN" -eq 1 ] && exit 0
say "OhMyOrch managed files removed. Empty directories may remain for inspection."
