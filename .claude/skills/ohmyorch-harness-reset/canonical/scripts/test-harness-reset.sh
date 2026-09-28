#!/usr/bin/env bash
#
# test-harness-reset.sh — regression suite for the canonical reset
#
# Exercises .claude/skills/ohmyorch-harness-reset/harness-reset.sh through the launcher
# scripts/harness-reset.sh against throwaway copies of this repository.
#
# The properties this suite protects — read the task brief as a checklist:
#
#   1. Backup first, then reset. A failed backup changes nothing at all.
#   2. The backup is verified, timestamped, and preserves directory structure.
#   3. An existing backup is never overwritten; docs/resets/ never nests.
#   4. The live .claude/ tree is byte-identical afterwards. This is the guarantee
#      a user cares about most, because .claude/ defines the canonical state.
#   5. Scoped artifacts are reset, and nested CLAUDE.md files outside .claude/ go.
#   6. Host-provided files that the canonical baseline does not define survive.
#   7. Nothing outside the scope changes. Application source above all.
#   8. A symlink is never followed out of the repository.
#   9. Missing optional files are handled gracefully, not fatally.
#  10. The resulting project verifies, and a second reset is refused.
#
# Each case builds its own copy under ${TMPDIR:-/tmp} and removes it on exit.
#
# Usage: scripts/test-harness-reset.sh
#
# Exit codes: 0 all cases matched, 1 a case mismatched, 2 setup failure.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd -P)

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-harness-reset-test.XXXXXX") || {
  echo "error: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# ok/bad accept an optional detail. Without one they print the label alone
# rather than tripping `set -u`, which would abort the whole suite.
ok()  { printf '  %sok%s    %-56s %s\n' "$c_green" "$c_reset" "$1" "${2:-}"; PASS=$((PASS + 1)); }
bad() { printf '  %sFAIL%s  %-56s %s\n' "$c_red" "$c_reset" "$1" "${2:-}"; FAIL=$((FAIL + 1)); }
section() { printf '\n%s\n' "$*"; }

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then ok "$label" "exit=$got"; else bad "$label" "want=$want got=$got"; fi
}

# expect_contains <label> <needle> <command...>
# A `case` match, not `grep -q`: under `set -o pipefail` grep's early exit makes a
# present needle read as absent.
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  case "$out" in *"$needle"*) ok "$label" "found" ;; *) bad "$label" "missing: $needle" ;; esac
}

# fresh <name> — a throwaway copy of the repository, .git and backups removed.
fresh() {
  d="$WORK/$1"
  cp -RP "$ROOT" "$d" || { echo "error: cannot copy repository" >&2; exit 2; }
  rm -rf "$d/.git" "$d/docs/resets"
  printf '%s\n' "$d"
}

# tree_hash <dir> — a single hash over a whole tree's contents and layout.
tree_hash() {
  ( cd "$1" && find . -name .git -prune -o \( -type f -o -type l -o -type d \) -print ) \
    | sed 's|^\./||' | grep -v '^$' | LC_ALL=C sort > "$WORK/.paths.$$"
  while IFS= read -r p; do
    if [ -L "$1/$p" ]; then printf 'l %s %s\n' "$p" "$(readlink "$1/$p")"
    elif [ -d "$1/$p" ]; then printf 'd %s\n' "$p"
    else printf 'f %s %s\n' "$p" "$(shasum -a 256 "$1/$p" 2>/dev/null | awk '{print $1}')"
    fi
  done < "$WORK/.paths.$$" | shasum -a 256 | awk '{print $1}'
}

RESET="$ROOT/scripts/harness-reset.sh"

# ---------------------------------------------------------------------------
section "US-1 — dry run writes nothing"
# ---------------------------------------------------------------------------

D1=$(fresh dryrun)
before=$(tree_hash "$D1")
expect_contains "dry run reports the target"   "canonical reset" bash "$D1/scripts/harness-reset.sh" --dry-run
expect_contains "dry run names the backup path" "BACKUP" bash "$D1/scripts/harness-reset.sh" --dry-run
expect_contains "dry run says .claude/ is safe" ".claude/ would not be touched" bash "$D1/scripts/harness-reset.sh" --dry-run
after=$(tree_hash "$D1")
check "dry run changed nothing"                0 test "$before" = "$after"
check "dry run created no backup"              0 test ! -e "$D1/docs/resets"

# ---------------------------------------------------------------------------
section "US-2 — backup is written, verified, and structure-preserving"
# ---------------------------------------------------------------------------

D2=$(fresh backup)
echo "x" > "$D2/scripts/host-tool.sh"
mkdir -p "$D2/packages/api/src"
echo "app" > "$D2/packages/api/src/index.js"
check "the reset succeeds"                     0 bash "$D2/scripts/harness-reset.sh" --quiet

BK=$(find "$D2/docs/resets" -maxdepth 1 -mindepth 1 -type d -not -name '.ohmyorch-harness-reset*' 2>/dev/null | head -1)
if [ -n "$BK" ]; then
  ok "a timestamped backup directory exists" "$(basename "$BK")"
  case "$(basename "$BK")" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      ok "the timestamp is <yyyy-mm-dd-hh-mm-ss>" ;;
    *) bad "the timestamp is <yyyy-mm-dd-hh-mm-ss>" "$(basename "$BK")" ;;
  esac
  check "the backup preserves .claude/agents"   0 test -d "$BK/.claude/agents"
  check "the backup preserves openspec/specs"   0 test -d "$BK/openspec/specs"
  check "the backup preserves scripts/"         0 test -f "$BK/scripts/delivery.sh"
  check "the backup has PRD.md"                 0 test -f "$BK/PRD.md"
  check "the backup has the host tool"          0 test -f "$BK/scripts/host-tool.sh"
  check "the backup has no nested docs/resets"  0 test ! -e "$BK/docs/resets"
else
  bad "a timestamped backup directory exists" "none found"
fi

# ---------------------------------------------------------------------------
section "US-3 — an existing backup is never overwritten"
# ---------------------------------------------------------------------------

# Seed a "previous" backup, then confirm a new run writes a *different* directory
# and leaves the first untouched.
D3=$(fresh noreplace)
mkdir -p "$D3/docs/resets/2020-01-01-00-00-00"
echo "old backup marker" > "$D3/docs/resets/2020-01-01-00-00-00/marker.txt"
check "a run succeeds beside an older backup" 0 bash "$D3/scripts/harness-reset.sh" --quiet
check "the older backup is untouched"          0 test -f "$D3/docs/resets/2020-01-01-00-00-00/marker.txt"
expect_contains "the older backup is intact"   "old backup marker" cat "$D3/docs/resets/2020-01-01-00-00-00/marker.txt"
count=$(find "$D3/docs/resets" -maxdepth 1 -mindepth 1 -type d | grep -c . || true)
check "a second backup directory was added"    0 test "${count:-0}" = "2"

# A backup at the *exact* target path must abort rather than merge. The timestamp
# cannot be predicted from the outside, so this asserts the mechanism the engine
# relies on: `mkdir` without -p fails on an existing directory, which is what
# makes "never overwrite a backup" structural rather than a check that could be
# skipped.
mkdir -p "$D3/docs/resets/occupied"
check "mkdir refuses an existing directory"    1 mkdir "$D3/docs/resets/occupied"
check "the abort path exists in the engine"    0 grep -q 'refusing to overwrite' "$ROOT/.claude/skills/ohmyorch-harness-reset/harness-reset.sh"

# ---------------------------------------------------------------------------
section "US-4 — the live .claude/ tree is never modified"
# ---------------------------------------------------------------------------

D4=$(fresh claude)
mkdir -p "$D4/.claude/agents" "$D4/.claude/commands/custom" "$D4/.claude/hooks"
echo "custom" > "$D4/.claude/agents/custom-agent.md"
echo "command" > "$D4/.claude/commands/custom/do.md"
echo "hook" > "$D4/.claude/hooks/notify.sh"
chmod +x "$D4/.claude/hooks/notify.sh"
CLAUDE_BEFORE=$(tree_hash "$D4/.claude")
CLAUDE_COUNT_BEFORE=$(find "$D4/.claude" -type f | grep -c . || true)

check "the reset succeeds"                     0 bash "$D4/scripts/harness-reset.sh" --quiet
CLAUDE_AFTER=$(tree_hash "$D4/.claude")
CLAUDE_COUNT_AFTER=$(find "$D4/.claude" -type f | grep -c . || true)

check "every .claude/ file is byte-identical"  0 test "$CLAUDE_BEFORE" = "$CLAUDE_AFTER"
check "no .claude/ file was added or removed"  0 test "${CLAUDE_COUNT_BEFORE:-0}" = "${CLAUDE_COUNT_AFTER:-0}"
check "a custom agent survived"                0 test -f "$D4/.claude/agents/custom-agent.md"
check "a custom command survived"              0 test -f "$D4/.claude/commands/custom/do.md"
check "a custom hook survived, still executable" 0 test -x "$D4/.claude/hooks/notify.sh"
check "settings.json survived"                 0 test -f "$D4/.claude/settings.json"
check "the referenced skill is still present"  0 test -d "$D4/.claude/skills/ohmyorch-harness-reset/canonical"

# ---------------------------------------------------------------------------
section "US-5 — scoped artifacts reset; nested CLAUDE.md removed"
# ---------------------------------------------------------------------------

D5=$(fresh scope)
mkdir -p "$D5/openspec/changes/in-flight-change"
echo "proposal" > "$D5/openspec/changes/in-flight-change/proposal.md"
mkdir -p "$D5/openspec/specs/legacy-capability"
echo "legacy" > "$D5/openspec/specs/legacy-capability/spec.md"
echo "goal" > "$D5/openspec/delivery/goal.md"
echo "epic record" > "$D5/SPEC-LOGS/README-EPIC-42.md"
mkdir -p "$D5/packages/api"
echo "nested contract" > "$D5/packages/api/CLAUDE.md"
echo "deeper" > "$D5/CLAUDE.md.nested-not-matched"

check "the reset succeeds"                     0 bash "$D5/scripts/harness-reset.sh" --quiet
check "the active change is gone"              0 test ! -e "$D5/openspec/changes/in-flight-change"
check "the old capability spec is gone"        0 test ! -e "$D5/openspec/specs/legacy-capability"
check "the delivery goal is gone"              0 test ! -e "$D5/openspec/delivery/goal.md"
check "the per-epic record is gone"            0 test ! -e "$D5/SPEC-LOGS/README-EPIC-42.md"
check "a nested CLAUDE.md is removed"          0 test ! -e "$D5/packages/api/CLAUDE.md"
check "the nested package dir survives"        0 test -d "$D5/packages/api"
check "a similarly named file is untouched"    0 test -f "$D5/CLAUDE.md.nested-not-matched"
check "the root CLAUDE.md is restored"         0 test -f "$D5/CLAUDE.md"
check "PRD.md is restored to the skeleton"     0 grep -q '<PRODUCT NAME>' "$D5/PRD.md"
check "SPECS.md is restored with no stories"   0 grep -q 'No epics yet' "$D5/SPECS.md"
check "SPEC-LOGS is reset to its index"        0 test -f "$D5/SPEC-LOGS/README.md"

# ---------------------------------------------------------------------------
section "US-6 — reset is by canonical baseline, not by emptying"
# ---------------------------------------------------------------------------

# The point: a reset restores structure from a source, so the result is a valid
# harness rather than an empty tree.
check "scripts/ has real content"              0 test -s "$D5/scripts/delivery.sh"
check "scripts/ kept its templates"            0 test -d "$D5/scripts/templates"
check "scripts/ kept its fixtures"             0 test -d "$D5/scripts/fixtures"
check "scripts/ kept the README"               0 test -s "$D5/scripts/README.md"
check "openspec/config.yaml is restored"       0 test -s "$D5/openspec/config.yaml"
check "openspec/archive exists"                0 test -d "$D5/openspec/changes/archive"
check "the canonical baseline is intact"       0 test -d "$D5/.claude/skills/ohmyorch-harness-reset/canonical/scripts"

# ---------------------------------------------------------------------------
section "US-7 — host files survive; unrelated files are never touched"
# ---------------------------------------------------------------------------

D7=$(fresh untouched)
echo "host validation" > "$D7/scripts/fast-validate.sh"
chmod +x "$D7/scripts/fast-validate.sh"
mkdir -p "$D7/src/lib" "$D7/tests"
echo "console.log(1)" > "$D7/src/index.js"
echo "export const x = 1" > "$D7/src/lib/util.ts"
echo "test" > "$D7/tests/app.test.js"
echo "payload" > "$D7/package.json"
echo "unrelated" > "$D7/NOTES.md"
mkdir -p "$D7/infra"
echo "resource" > "$D7/infra/main.tf"

APP_BEFORE=$(tree_hash "$D7")
check "the reset succeeds"                     0 bash "$D7/scripts/harness-reset.sh" --quiet
check "the host fast-validate.sh survived"     0 test -f "$D7/scripts/fast-validate.sh"
check "the host fast-validate.sh is executable" 0 test -x "$D7/scripts/fast-validate.sh"
expect_contains "the host file kept its content" "host validation" cat "$D7/scripts/fast-validate.sh"

for f in src/index.js src/lib/util.ts tests/app.test.js package.json NOTES.md infra/main.tf; do
  if [ -f "$D7/$f" ]; then ok "unrelated file untouched: $f"
  else bad "unrelated file untouched: $f" "missing"; fi
done
check "application source is unchanged"        0 test "$(cat "$D7/src/index.js")" = "console.log(1)"

# ---------------------------------------------------------------------------
section "US-8 — symlinks are never followed out of the repository"
# ---------------------------------------------------------------------------

D8=$(fresh symlinks)
mkdir -p "$WORK/outside-symlinks"
echo "secret" > "$WORK/outside-symlinks/target.txt"

# A symlink inside the scope pointing outside it. The reset must refuse rather
# than delete the target through the link.
rm -rf "$D8/SPEC-LOGS"
ln -s "$WORK/outside-symlinks" "$D8/SPEC-LOGS"
check "a scope symlink out of the repo aborts" 1 bash "$D8/scripts/harness-reset.sh" --quiet
check "the symlink target was not deleted"     0 test -f "$WORK/outside-symlinks/target.txt"
expect_contains "the target still has its content" "secret" cat "$WORK/outside-symlinks/target.txt"
check "nothing was changed (no backup made)"   0 test ! -e "$D8/docs/resets"
check "the engine names the reason"            0 grep -q 'resolves outside the repository' "$ROOT/.claude/skills/ohmyorch-harness-reset/harness-reset.sh"

# A symlink *outside* the scope is left alone, not followed, not removed.
D8b=$(fresh symlinks-outside)
mkdir -p "$D8b/assets"
ln -s "$WORK/outside-symlinks/target.txt" "$D8b/assets/link.txt"
check "an out-of-scope symlink does not abort" 0 bash "$D8b/scripts/harness-reset.sh" --quiet
check "the out-of-scope symlink is preserved"  0 test -L "$D8b/assets/link.txt"
check "it is still a symlink, not a copy"      0 test "$(readlink "$D8b/assets/link.txt")" = "$WORK/outside-symlinks/target.txt"

# ---------------------------------------------------------------------------
section "US-9 — missing optional files are handled gracefully"
# ---------------------------------------------------------------------------

D9=$(fresh missing)
# Remove optional entries a host may legitimately not have.
rm -rf "$D9/SPEC-LOGS" "$D9/README.md"
check "a missing SPEC-LOGS/ is not fatal"      0 bash "$D9/scripts/harness-reset.sh" --quiet
check "SPEC-LOGS/ is restored"                 0 test -d "$D9/SPEC-LOGS"
check "README.md is restored"                  0 test -f "$D9/README.md"

D9b=$(fresh empty-openspec)
rm -rf "$D9b/openspec"
check "a missing openspec/ is not fatal"       0 bash "$D9b/scripts/harness-reset.sh" --quiet
check "openspec/ is restored"                  0 test -d "$D9b/openspec/specs"

# ---------------------------------------------------------------------------
section "US-10 — verification, refusal, and abort safety"
# ---------------------------------------------------------------------------

D10=$(fresh verify)
check "the reset succeeds"                     0 bash "$D10/scripts/harness-reset.sh" --quiet

# The reset tree must be internally consistent: baseline-equal artifacts, no
# active change, restored structure.
for f in CLAUDE.md PRD.md SPECS.md README.md; do
  check "$f matches the canonical baseline"    0 cmp -s "$D10/.claude/skills/ohmyorch-harness-reset/canonical/$f" "$D10/$f"
done
count=$(find "$D10/openspec/changes" -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null | grep -c . || true)
check "no active change remains"               0 test "${count:-0}" = "0"
check "scripts/ is runnable after reset"       0 bash -n "$D10/scripts/delivery.sh"

# The reset project must still satisfy the harness's own artifact validator.
check "the reset project validates"            0 bash "$D10/scripts/validate-product-artifacts.sh" --quiet
check "the reset tree's frontmatter validates"  0 node "$D10/scripts/check-frontmatter.js"

# A different repository is never the target by accident: --root is honoured.
D10b=$(fresh otherroot)
check "--root resets the named repository"     0 bash "$D10b/scripts/harness-reset.sh" --root "$D10b" --quiet
check "--root wrote the backup where asked"    0 test -d "$D10b/docs/resets"

# Aborting must leave everything as it was: point the baseline away and confirm
# the live tree is untouched when preflight refuses.
D10c=$(fresh abort)
rm -rf "$D10c/.claude/skills/ohmyorch-harness-reset/canonical"
ABORT_BEFORE=$(tree_hash "$D10c")
check "a missing baseline aborts"              1 bash "$D10c/scripts/harness-reset.sh" --quiet
ABORT_AFTER=$(tree_hash "$D10c")
check "an abort changed nothing at all"        0 test "$ABORT_BEFORE" = "$ABORT_AFTER"
check "an abort wrote no backup"               0 test ! -e "$D10c/docs/resets"

# Refusing to run outside a harness project.
D10d="$WORK/not-a-project"; mkdir -p "$D10d"
check "a non-harness directory is refused"     1 bash "$RESET" --root "$D10d" --quiet

# ---------------------------------------------------------------------------
section "US-11 — the engine's interface"
# ---------------------------------------------------------------------------

check "--help exits 0"                         0 bash "$RESET" --help
check "an unknown option is a usage error"     3 bash "$RESET" --nonsense
check "the launcher resolves the engine"       0 test -x "$ROOT/.claude/skills/ohmyorch-harness-reset/harness-reset.sh"

TAB=$(printf '\t')
check "the manifest declares the backup scope" 0 grep -q "backup${TAB}\.claude" "$ROOT/.claude/skills/ohmyorch-harness-reset/manifest.tsv"
check "the manifest declares 7 reset entries"  0 test "$(grep -c "^reset${TAB}" "$ROOT/.claude/skills/ohmyorch-harness-reset/manifest.tsv")" = "7"
check ".claude/ is not a reset entry"          0 test "$(grep -c "^reset${TAB}\.claude" "$ROOT/.claude/skills/ohmyorch-harness-reset/manifest.tsv")" = "0"
check "the preserve list names fast-validate"  0 grep -q 'scripts/fast-validate.sh' "$ROOT/.claude/skills/ohmyorch-harness-reset/PRESERVE.tsv"
check "the skill documents the scope"          0 grep -q 'never' "$ROOT/.claude/skills/ohmyorch-harness-reset/SKILL.md"

# The backup copies .claude/settings.local.json, which holds credentials. It must
# never be committable, and the skill must say so.
check "docs/resets/ is git-ignored"            0 grep -q '^docs/resets/' "$ROOT/.gitignore"
check "the skill warns about secrets"          0 grep -q 'contains secrets' "$ROOT/.claude/skills/ohmyorch-harness-reset/SKILL.md"
check "the skill names the local settings file" 0 grep -q 'settings.local.json' "$ROOT/.claude/skills/ohmyorch-harness-reset/SKILL.md"
check "the README says not to commit backups"  0 grep -q 'do not commit a backup' "$ROOT/README.md"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n%s\n' "----------------------------------------"
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS%s — the canonical reset holds.\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL%s — reset behaviour regressed.\n' "$c_red" "$c_reset"
exit 1
