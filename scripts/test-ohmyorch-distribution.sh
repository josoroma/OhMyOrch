#!/usr/bin/env bash
#
# Regression tests for OhMyOrch distribution packaging and install behavior.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-dist-test.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

PASS=0
FAIL=0
c_reset=""; c_red=""; c_green=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'
fi

ok() { printf '  %sok%s    %-58s %s\n' "$c_green" "$c_reset" "$1" "${2:-}"; PASS=$((PASS + 1)); }
bad() { printf '  %sFAIL%s  %-58s %s\n' "$c_red" "$c_reset" "$1" "${2:-}"; FAIL=$((FAIL + 1)); }
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  [ "$got" = "$want" ] && ok "$label" "exit=$got" || bad "$label" "want=$want got=$got"
}

section() { printf '\n%s\n' "$*"; }

OUT="$WORK/dist"
VERSION="9.9.9-test"

section "package"
check "package command succeeds" 0 bash "$ROOT/scripts/package-ohmyorch.sh" --version "$VERSION" --out "$OUT"
BUNDLE="$OUT/ohmyorch-harness-$VERSION.tar.gz"
STABLE_BUNDLE="$OUT/ohmyorch-harness.tar.gz"
check "bundle exists" 0 test -f "$BUNDLE"
check "stable bundle alias exists" 0 test -f "$STABLE_BUNDLE"
check "checksums exist" 0 test -f "$OUT/checksums.sha256"
check "versioned checksum listed" 0 grep -q "ohmyorch-harness-$VERSION.tar.gz" "$OUT/checksums.sha256"
check "stable checksum listed" 0 grep -q "ohmyorch-harness.tar.gz" "$OUT/checksums.sha256"
check "settings.local.json excluded" 1 bash -c 'tar -tzf "$1" | grep -q ".claude/settings.local.json"' _ "$BUNDLE"
check ".DS_Store excluded" 1 bash -c 'tar -tzf "$1" | grep -q "/.DS_Store$"' _ "$BUNDLE"
check "namespaced ohmyorch-planner agent present" 0 bash -c 'tar -tzf "$1" | grep -q ".claude/agents/ohmyorch-planner.md"' _ "$BUNDLE"
check "namespaced opsx command present" 0 bash -c 'tar -tzf "$1" | grep -q ".claude/commands/ohmyorch/opsx/apply.md"' _ "$BUNDLE"
check "bundle includes payload checksums" 0 bash -c 'tar -tzf "$1" | grep -q "checksums.sha256"' _ "$BUNDLE"

EXTRACT="$WORK/extracted"
mkdir -p "$EXTRACT"
tar -xzf "$BUNDLE" -C "$EXTRACT"
PKG_ROOT="$EXTRACT/ohmyorch-harness-$VERSION"
check "skill frontmatter is namespaced" 0 grep -q '^name: ohmyorch-deliver$' "$PKG_ROOT/payload/.claude/skills/ohmyorch-deliver/SKILL.md"
check "agent frontmatter is namespaced" 0 grep -q '^name: ohmyorch-planner$' "$PKG_ROOT/payload/.claude/agents/ohmyorch-planner.md"
check "slash references are namespaced" 0 grep -q '/ohmyorch-deliver' "$PKG_ROOT/payload/.claude/skills/ohmyorch-deliver/SKILL.md"

section "additive install"
TARGET1="$WORK/target-empty"
mkdir -p "$TARGET1"
check "dry run succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET1" --dry-run
check "install succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET1"
check "managed manifest written" 0 test -f "$TARGET1/.claude/ohmyorch/manifest.tsv"
check "namespaced skill installed" 0 test -f "$TARGET1/.claude/skills/ohmyorch-deliver/SKILL.md"
check "bootstrap file omitted by default" 1 test -f "$TARGET1/CLAUDE.md"

TARGET_ALIAS="$WORK/target-alias"
mkdir -p "$TARGET_ALIAS"
check "stable alias install succeeds" 0 sh "$ROOT/install.sh" --bundle "$STABLE_BUNDLE" --target "$TARGET_ALIAS"

section "upgrade mode"
TARGET_UPGRADE="$WORK/target-upgrade"
mkdir -p "$TARGET_UPGRADE"
check "upgrade into unmanaged target writes nothing" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET_UPGRADE" --upgrade
check "upgrade did not create .claude" 1 test -d "$TARGET_UPGRADE/.claude"
check "initial install for upgrade succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET_UPGRADE"
printf '\nlocal edit\n' >> "$TARGET_UPGRADE/.claude/skills/ohmyorch-deliver/SKILL.md"
check "upgrade refuses local managed edits" 1 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET_UPGRADE" --upgrade
check "forced upgrade over local edit succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET_UPGRADE" --upgrade --force

section "bootstrap install"
TARGET2="$WORK/target-bootstrap"
mkdir -p "$TARGET2"
check "bootstrap succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET2" --bootstrap
check "bootstrap installs CLAUDE.md" 0 test -f "$TARGET2/CLAUDE.md"
check "bootstrap installs scripts" 0 test -f "$TARGET2/scripts/validate-product-artifacts.sh"

section "collision protection"
TARGET3="$WORK/target-collision"
mkdir -p "$TARGET3/.claude/agents"
echo "custom ohmyorch-planner" > "$TARGET3/.claude/agents/ohmyorch-planner.md"
check "unmanaged collision refused" 1 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET3"
check "forced unmanaged collision succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET3" --force
check "backup created" 0 test -d "$TARGET3/.claude/ohmyorch/backups"

section "existing .claude protection"
TARGET4="$WORK/target-existing-claude"
mkdir -p "$TARGET4/.claude/agents"
echo "custom agent" > "$TARGET4/.claude/agents/custom-agent.md"
echo "local secret" > "$TARGET4/.claude/settings.local.json"
echo "dirty worktree marker" > "$TARGET4/UNTRACKED.txt"
CUSTOM_BEFORE=$(shasum -a 256 "$TARGET4/.claude/agents/custom-agent.md" | awk '{print $1}')
LOCAL_BEFORE=$(shasum -a 256 "$TARGET4/.claude/settings.local.json" | awk '{print $1}')
check "install beside unrelated .claude succeeds" 0 sh "$ROOT/install.sh" --bundle "$BUNDLE" --target "$TARGET4"
CUSTOM_AFTER=$(shasum -a 256 "$TARGET4/.claude/agents/custom-agent.md" | awk '{print $1}')
LOCAL_AFTER=$(shasum -a 256 "$TARGET4/.claude/settings.local.json" | awk '{print $1}')
check "custom agent survived byte-identical" 0 test "$CUSTOM_BEFORE" = "$CUSTOM_AFTER"
check "settings.local survived byte-identical" 0 test "$LOCAL_BEFORE" = "$LOCAL_AFTER"
check "dirty worktree marker survived" 0 test -f "$TARGET4/UNTRACKED.txt"

section "uninstall protection"
check "uninstall dry run succeeds" 0 sh "$ROOT/uninstall.sh" --target "$TARGET1" --dry-run
check "uninstall succeeds" 0 sh "$ROOT/uninstall.sh" --target "$TARGET1"
check "managed skill removed" 1 test -f "$TARGET1/.claude/skills/ohmyorch-deliver/SKILL.md"

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
