#!/usr/bin/env bash
#
# Build a namespaced OhMyOrch harness distribution bundle.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
VERSION="${OHMYORCH_VERSION:-0.1.0}"
OUT_DIR="$ROOT/dist"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-package.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

PACKAGE="ohmyorch-harness-$VERSION"
PKG="$WORK/$PACKAGE"
PAYLOAD="$PKG/payload"
MANIFEST="$PKG/manifest.tsv"

usage() {
  cat <<EOF
Usage: scripts/package-ohmyorch.sh [--version <version>] [--out <dir>]

Creates dist/ohmyorch-harness-<version>.tar.gz and dist/checksums.sha256.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version) [ $# -ge 2 ] || { echo "error: --version needs a value" >&2; exit 3; }; VERSION="$2"; PACKAGE="ohmyorch-harness-$VERSION"; PKG="$WORK/$PACKAGE"; PAYLOAD="$PKG/payload"; MANIFEST="$PKG/manifest.tsv"; shift 2 ;;
    --out) [ $# -ge 2 ] || { echo "error: --out needs a value" >&2; exit 3; }; OUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

mkdir -p "$PAYLOAD/.claude/agents" "$PAYLOAD/.claude/skills" \
  "$PAYLOAD/.claude/commands/ohmyorch" "$PAYLOAD/.claude/rules" \
  "$PAYLOAD/.claude/ohmyorch/scripts" "$OUT_DIR"

namespace_text() {
  cat
}

copy_md_with_marker() {
  src="$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  namespace_text < "$src" > "$dst.tmp"
  if sed -n '1p' "$dst.tmp" | grep -qx -- '---'; then
    awk -v version="$VERSION" '
      NR == 1 { print; next }
      NR == 2 {
        print "distribution: ohmyorch"
        print "version: \"" version "\""
      }
      { print }
    ' "$dst.tmp" > "$dst"
  else
    {
      printf -- '---\ndistribution: ohmyorch\nversion: "%s"\n---\n\n' "$VERSION"
      cat "$dst.tmp"
    } > "$dst"
  fi
  rm -f "$dst.tmp"
}

set_frontmatter_name() {
  file="$1"; name="$2"
  awk -v new_name="$name" '
    BEGIN { done = 0 }
    /^name:[[:space:]]*/ && done == 0 {
      print "name: " new_name
      done = 1
      next
    }
    { print }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

for f in "$ROOT"/.claude/agents/*.md; do
  base=$(basename "$f")
  [ "$base" = "README.md" ] && continue
  case "$base" in ohmyorch-*) target_base="$base" ;; *) target_base="ohmyorch-$base" ;; esac
  target_file="$PAYLOAD/.claude/agents/$target_base"
  copy_md_with_marker "$f" "$target_file"
  set_frontmatter_name "$target_file" "${target_base%.md}"
done

for d in "$ROOT"/.claude/skills/*; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  case "$name" in ohmyorch-*) target="$name" ;; *) target="ohmyorch-$name" ;; esac
  mkdir -p "$PAYLOAD/.claude/skills/$target"
  find "$d" -type f | while IFS= read -r f; do
    rel=${f#"$d/"}
    case "$rel" in
      SKILL.md)
        copy_md_with_marker "$f" "$PAYLOAD/.claude/skills/$target/$rel"
        set_frontmatter_name "$PAYLOAD/.claude/skills/$target/$rel" "$target" ;;
      *.md) copy_md_with_marker "$f" "$PAYLOAD/.claude/skills/$target/$rel" ;;
      *) mkdir -p "$(dirname "$PAYLOAD/.claude/skills/$target/$rel")"; cp "$f" "$PAYLOAD/.claude/skills/$target/$rel" ;;
    esac
  done
done

if [ -d "$ROOT/.claude/commands/ohmyorch/opsx" ]; then
  mkdir -p "$PAYLOAD/.claude/commands/ohmyorch/opsx"
  for f in "$ROOT"/.claude/commands/ohmyorch/opsx/*.md; do
    copy_md_with_marker "$f" "$PAYLOAD/.claude/commands/ohmyorch/opsx/$(basename "$f")"
  done
fi
if [ -d "$ROOT/.claude/commands/ohmyorch" ]; then
  find "$ROOT/.claude/commands/ohmyorch" -type f | while IFS= read -r f; do
    rel=${f#"$ROOT/.claude/commands/ohmyorch/"}
    copy_md_with_marker "$f" "$PAYLOAD/.claude/commands/ohmyorch/$rel"
  done
fi

for f in "$ROOT"/.claude/rules/*.md; do
  base=$(basename "$f")
  case "$base" in
    README.md) cp "$f" "$PAYLOAD/.claude/rules/README.md" ;;
    ohmyorch-*) copy_md_with_marker "$f" "$PAYLOAD/.claude/rules/$base" ;;
    *) copy_md_with_marker "$f" "$PAYLOAD/.claude/rules/ohmyorch-$base" ;;
  esac
done

cp "$ROOT/.claude/settings.local.example.json" "$PAYLOAD/.claude/settings.local.example.json" 2>/dev/null || true
cat > "$PAYLOAD/.claude/ohmyorch/settings.fragment.json" <<EOF
{
  "ohmyorch": {
    "version": "$VERSION",
    "note": "Review and merge this fragment manually if this repository already has .claude/settings.json."
  }
}
EOF

for f in check-frontmatter.js run-project-validation.sh validate-product-artifacts.sh; do
  [ -f "$ROOT/scripts/$f" ] && cp "$ROOT/scripts/$f" "$PAYLOAD/.claude/ohmyorch/scripts/$f"
done

for p in CLAUDE.md PRD.md SPECS.md README.md openspec scripts; do
  [ -e "$ROOT/$p" ] || continue
  mkdir -p "$PAYLOAD/$(dirname "$p")"
  cp -RP "$ROOT/$p" "$PAYLOAD/$p"
done

rm -f "$PAYLOAD/.claude/settings.local.json"

cp "$ROOT/install.sh" "$PKG/install.sh"
cp "$ROOT/uninstall.sh" "$PKG/uninstall.sh"
chmod +x "$PKG/install.sh" "$PKG/uninstall.sh"

{
  printf 'mode\tpath\tchecksum\tversion\towner\n'
  ( cd "$PAYLOAD" && find . -type f | sed 's|^\./||' | LC_ALL=C sort ) | while IFS= read -r path; do
    case "$path" in
      .claude/*) mode="additive" ;;
      *) mode="bootstrap" ;;
    esac
    printf '%s\t%s\t%s\t%s\tohmyorch\n' "$mode" "$path" "$(shasum -a 256 "$PAYLOAD/$path" | awk '{print $1}')" "$VERSION"
  done
} > "$MANIFEST"

( cd "$PAYLOAD" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | xargs shasum -a 256 ) > "$PKG/checksums.sha256"

( cd "$WORK" && tar -czf "$OUT_DIR/$PACKAGE.tar.gz" "$PACKAGE" )
cp "$OUT_DIR/$PACKAGE.tar.gz" "$OUT_DIR/ohmyorch-harness.tar.gz"
{
  ( cd "$OUT_DIR" && shasum -a 256 "$PACKAGE.tar.gz" )
  ( cd "$OUT_DIR" && shasum -a 256 "ohmyorch-harness.tar.gz" )
} > "$OUT_DIR/checksums.sha256"

printf 'Bundle: %s\n' "$OUT_DIR/$PACKAGE.tar.gz"
printf 'Stable bundle: %s\n' "$OUT_DIR/ohmyorch-harness.tar.gz"
printf 'Checksums: %s\n' "$OUT_DIR/checksums.sha256"
