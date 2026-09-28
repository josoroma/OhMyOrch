#!/usr/bin/env sh
#
# OhMyOrch harness installer.
#
# This script can be used two ways:
#   1. Inside an extracted release bundle, where manifest.tsv and payload/ exist.
#   2. As a curl wrapper with --bundle <file-or-url>, OHMYORCH_BUNDLE_URL, or
#      the built-in release asset URL.

set -eu

VERSION="${OHMYORCH_VERSION:-dev}"
DEFAULT_RELEASE_BASE_URL="${OHMYORCH_RELEASE_BASE_URL:-https://github.com/josoroma/claude-dev/releases/latest/download}"
TARGET="."
BUNDLE=""
CHECKSUM=""
DRY_RUN=0
BOOTSTRAP=0
UPGRADE=0
FORCE=0
FORCE_DOWNGRADE=0
QUIET=0

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*" >&2; }
fail() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Install the OhMyOrch .claude harness bundle into a repository.

Options:
  --target <dir>         Target repository root (default: current directory)
  --bundle <path|url>    Bundle tarball to install
  --checksum <path|url>  SHA-256 checksum file for the bundle
  --bootstrap           Also install project-level baseline files when absent
  --upgrade             Update only OhMyOrch-managed files
  --force               Allow replacing unmanaged collisions
  --force-downgrade     Allow installing an older managed version
  --dry-run             Show the write plan without changing files
  --quiet               Reduce output
  -h, --help            Show this help

Environment:
  OHMYORCH_BUNDLE_URL   Bundle URL used when --bundle is omitted
  OHMYORCH_CHECKSUM_URL Checksum URL used when --checksum is omitted
  OHMYORCH_RELEASE_BASE_URL
                         Release asset base URL for curl-only installs
  OHMYORCH_VERSION      Expected version label for reporting
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) [ "$#" -ge 2 ] || fail "--target needs a value"; TARGET="$2"; shift 2 ;;
    --bundle) [ "$#" -ge 2 ] || fail "--bundle needs a value"; BUNDLE="$2"; shift 2 ;;
    --checksum) [ "$#" -ge 2 ] || fail "--checksum needs a value"; CHECKSUM="$2"; shift 2 ;;
    --bootstrap) BOOTSTRAP=1; shift ;;
    --upgrade) UPGRADE=1; shift ;;
    --force) FORCE=1; shift ;;
    --force-downgrade) FORCE_DOWNGRADE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option '$1'" ;;
  esac
done

TARGET=$(cd "$TARGET" 2>/dev/null && pwd -P) || fail "cannot resolve target"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-install.XXXXXX") || fail "cannot create temp directory"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)

if [ -f "$SCRIPT_DIR/manifest.tsv" ] && [ -d "$SCRIPT_DIR/payload" ]; then
  BUNDLE_ROOT="$SCRIPT_DIR"
else
  [ -n "$BUNDLE" ] || BUNDLE="${OHMYORCH_BUNDLE_URL:-}"
  [ -n "$BUNDLE" ] || BUNDLE="$DEFAULT_RELEASE_BASE_URL/ohmyorch-harness.tar.gz"
  [ -n "$CHECKSUM" ] || CHECKSUM="${OHMYORCH_CHECKSUM_URL:-}"
  case "$BUNDLE" in
    http://*|https://*)
      command -v curl >/dev/null 2>&1 || fail "curl is required to download bundle"
      curl -fsSL "$BUNDLE" -o "$WORK/bundle.tar.gz"
      BUNDLE_FILE="$WORK/bundle.tar.gz"
      if [ -z "$CHECKSUM" ]; then
        case "$BUNDLE" in
          */*) CHECKSUM="${BUNDLE%/*}/checksums.sha256" ;;
        esac
      fi ;;
    *)
      [ -f "$BUNDLE" ] || fail "bundle not found: $BUNDLE"
      cp "$BUNDLE" "$WORK/bundle.tar.gz"
      BUNDLE_FILE="$WORK/bundle.tar.gz"
      [ -n "$CHECKSUM" ] || [ ! -f "$(dirname "$BUNDLE")/checksums.sha256" ] || CHECKSUM="$(dirname "$BUNDLE")/checksums.sha256" ;;
  esac
  if [ -n "$CHECKSUM" ]; then
    case "$CHECKSUM" in
      http://*|https://*)
        command -v curl >/dev/null 2>&1 || fail "curl is required to download checksum"
        curl -fsSL "$CHECKSUM" -o "$WORK/checksums.sha256" ;;
      *)
        [ -f "$CHECKSUM" ] || fail "checksum file not found: $CHECKSUM"
        cp "$CHECKSUM" "$WORK/checksums.sha256" ;;
    esac
    expected=$(awk -v f="$(basename "$BUNDLE")" '$2 == f { print $1; found = 1 } END { if (!found && NR == 1) print $1 }' "$WORK/checksums.sha256" | head -1)
    [ -n "$expected" ] || fail "checksum file does not contain an entry for $(basename "$BUNDLE")"
    actual=$(shasum -a 256 "$BUNDLE_FILE" | awk '{print $1}')
    [ "$actual" = "$expected" ] || fail "bundle checksum mismatch"
  else
    warn "no checksum file found; bundle integrity was not externally verified"
  fi
  tar -xzf "$WORK/bundle.tar.gz" -C "$WORK"
  BUNDLE_ROOT=$(find "$WORK" -maxdepth 2 -type f -name manifest.tsv -print | sed 's|/manifest.tsv$||' | head -1)
  [ -n "$BUNDLE_ROOT" ] || fail "bundle does not contain manifest.tsv"
fi

MANIFEST="$BUNDLE_ROOT/manifest.tsv"
PAYLOAD="$BUNDLE_ROOT/payload"
[ -d "$PAYLOAD" ] || fail "bundle payload is missing"
if [ "${OHMYORCH_VERSION:-}" = "" ]; then
  VERSION=$(awk -F "$(printf '\t')" 'NR == 2 { print $4; exit }' "$MANIFEST")
  [ -n "$VERSION" ] || VERSION="dev"
fi

if [ -f "$BUNDLE_ROOT/checksums.sha256" ]; then
  ( cd "$PAYLOAD" && shasum -a 256 -c "$BUNDLE_ROOT/checksums.sha256" >/dev/null ) \
    || fail "payload checksum verification failed"
fi

INSTALLED_MANIFEST="$TARGET/.claude/ohmyorch/manifest.tsv"
PLAN="$WORK/plan.tsv"
: > "$PLAN"

checksum_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

is_managed_path() {
  [ -f "$INSTALLED_MANIFEST" ] || return 1
  awk -F '\t' 'NR > 1 { print $2 }' "$INSTALLED_MANIFEST" | grep -Fx -- "$1" >/dev/null 2>&1
}

installed_version_for() {
  [ -f "$INSTALLED_MANIFEST" ] || return 1
  awk -F '\t' -v p="$1" 'NR > 1 && $2 == p { print $4; exit }' "$INSTALLED_MANIFEST"
}

installed_checksum_for() {
  [ -f "$INSTALLED_MANIFEST" ] || return 1
  awk -F '\t' -v p="$1" 'NR > 1 && $2 == p { print $3; exit }' "$INSTALLED_MANIFEST"
}

classify() {
  mode="$1"; path="$2"; sum="$3"; version="$4"
  src="$PAYLOAD/$path"
  dst="$TARGET/$path"

  [ "$mode" = "bootstrap" ] && [ "$BOOTSTRAP" -eq 0 ] && {
    printf 'skip\t%s\tbootstrap mode not selected\n' "$path" >> "$PLAN"; return; }

  [ "$UPGRADE" -eq 1 ] && ! is_managed_path "$path" && {
    printf 'skip\t%s\tupgrade only touches managed files\n' "$path" >> "$PLAN"; return; }

  if [ ! -e "$dst" ]; then
    printf 'install\t%s\tmissing\n' "$path" >> "$PLAN"
    return
  fi

  current_sum=$(checksum_file "$dst")
  if is_managed_path "$path"; then
    old_sum=$(installed_checksum_for "$path" || true)
    old_version=$(installed_version_for "$path" || true)
    [ "$old_version" \> "$version" ] && [ "$FORCE_DOWNGRADE" -eq 0 ] && {
      printf 'refuse\t%s\tmanaged newer version %s\n' "$path" "$old_version" >> "$PLAN"; return; }
    [ "$current_sum" = "$sum" ] && {
      printf 'skip\t%s\talready installed\n' "$path" >> "$PLAN"; return; }
    [ -n "$old_sum" ] && [ "$current_sum" != "$old_sum" ] && [ "$FORCE" -eq 0 ] && {
      printf 'refuse\t%s\tmanaged file has local edits\n' "$path" >> "$PLAN"; return; }
    printf 'upgrade\t%s\tmanaged %s to %s\n' "$path" "${old_version:-unknown}" "$version" >> "$PLAN"
    return
  fi

  if [ "$FORCE" -eq 1 ]; then
    printf 'replace-unmanaged\t%s\t--force selected\n' "$path" >> "$PLAN"
  else
    printf 'refuse\t%s\tunmanaged collision\n' "$path" >> "$PLAN"
  fi
}

tail -n +2 "$MANIFEST" | while IFS="$(printf '\t')" read -r mode path sum version owner; do
  [ -n "${mode:-}" ] || continue
  classify "$mode" "$path" "$sum" "$version"
done

say "OhMyOrch install plan"
say "Target: $TARGET"
say "Bundle: $BUNDLE_ROOT"
say "Version: $VERSION"
[ "$BOOTSTRAP" -eq 1 ] && say "Mode: additive + bootstrap" || say "Mode: additive"
[ "$UPGRADE" -eq 1 ] && say "Upgrade: managed files only"
[ "$DRY_RUN" -eq 1 ] && say "Dry run: yes"

refusals=$(awk -F '\t' '$1 == "refuse" { c++ } END { print c + 0 }' "$PLAN")
while IFS="$(printf '\t')" read -r action path detail; do
  [ -n "$action" ] || continue
  case "$action" in
    install|upgrade|replace-unmanaged) say "  WRITE  $path  ${detail:-}" ;;
    skip) say "  SKIP   $path  ${detail:-}" ;;
    refuse) warn "$path — ${detail:-refused}" ;;
  esac
done < "$PLAN"

[ "$refusals" -eq 0 ] || fail "$refusals collision(s) refused"
[ "$DRY_RUN" -eq 1 ] && exit 0

writes=$(awk -F '\t' '$1 == "install" || $1 == "upgrade" || $1 == "replace-unmanaged" { c++ } END { print c + 0 }' "$PLAN")
if [ "$writes" -eq 0 ]; then
  say ""
  say "OhMyOrch install: no changes needed."
  exit 0
fi

BACKUP="$TARGET/.claude/ohmyorch/backups/$(date '+%Y-%m-%d-%H-%M-%S')"
mkdir -p "$TARGET/.claude/ohmyorch/backups"
mkdir "$BACKUP" || fail "backup already exists: $BACKUP"

while IFS="$(printf '\t')" read -r action path detail; do
  case "$action" in
    install|upgrade|replace-unmanaged)
      if [ -e "$TARGET/$path" ]; then
        mkdir -p "$BACKUP/$(dirname "$path")"
        cp -RP "$TARGET/$path" "$BACKUP/$path"
      fi ;;
  esac
done < "$PLAN"

while IFS="$(printf '\t')" read -r action path detail; do
  case "$action" in
    install|upgrade|replace-unmanaged)
      mkdir -p "$TARGET/$(dirname "$path")"
      cp -RP "$PAYLOAD/$path" "$TARGET/$path" ;;
  esac
done < "$PLAN"

mkdir -p "$TARGET/.claude/ohmyorch"
{
  printf 'owner\tpath\tchecksum\tversion\tmode\n'
  tail -n +2 "$MANIFEST" | while IFS="$(printf '\t')" read -r mode path sum version owner; do
    [ "$mode" = "bootstrap" ] && [ "$BOOTSTRAP" -eq 0 ] && continue
    [ -f "$TARGET/$path" ] || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "${owner:-ohmyorch}" "$path" "$(checksum_file "$TARGET/$path")" "$version" "$mode"
  done
} > "$INSTALLED_MANIFEST"

validation_failed=0
while IFS="$(printf '\t')" read -r owner path sum version mode; do
  [ "$owner" = "owner" ] && continue
  [ -f "$TARGET/$path" ] || { warn "installed manifest path missing: $path"; validation_failed=1; continue; }
  current=$(checksum_file "$TARGET/$path")
  [ "$current" = "$sum" ] || { warn "installed checksum mismatch: $path"; validation_failed=1; }
done < "$INSTALLED_MANIFEST"
[ "$validation_failed" -eq 0 ] || fail "installed manifest validation failed"

if [ -x "$TARGET/.claude/ohmyorch/scripts/validate-product-artifacts.sh" ] && [ "$BOOTSTRAP" -eq 1 ]; then
  ( cd "$TARGET" && .claude/ohmyorch/scripts/validate-product-artifacts.sh >/dev/null ) \
    || warn "product artifact validation reported findings; run .claude/ohmyorch/scripts/validate-product-artifacts.sh"
fi

say ""
say "OhMyOrch installed."
say "Backup: $BACKUP"
say "Manifest: $INSTALLED_MANIFEST"
say "Next: run /ohmyorch:post-install --mode merge when CODEBASE.md, PRD.md, or SPECS.md are ready."
