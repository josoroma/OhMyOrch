#!/usr/bin/env bash
#
# test-guards.sh — regression suite for the mechanical guards
#
# Exercises guard-context-preflight.sh, guard-archive.sh, guard-story-done.sh and
# run-project-validation.sh against staged repository states and hook payloads.
#
# The two delivery guards are structural and read nothing but the change
# directory and the mapped SPECS:
#
#   guard-archive     `openspec archive <id>` is refused while tasks.md has an
#                     unfinished task, counted as OpenSpec counts them. Nothing
#                     else is consulted.
#   guard-story-done  a SPECS write that newly sets `Status: DONE` is refused
#                     while a change that stands behind the story is still active.
#
# The openspec CLI is kept off PATH: neither guard may need it.
#
# Runs in throwaway directories under ${TMPDIR:-/tmp} and removes them on exit.
# It never modifies the repository.
#
# Usage: bash tests/run.sh guards
#
# Exit codes: 0 all cases matched, 1 a case mismatched, 2 setup failure.

set -uo pipefail

ROOT="$TEST_HARNESS_ROOT"
SCRIPTS="$ROOT/scripts"
PATH="$OHMYORCH_TEST_UTILITIES:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/harness-guards.XXXXXX") || { echo "error: cannot create temp dir" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# Scratch files the scripts create (mktemp) stay inside the throwaway directory.
mkdir -p "$WORK/tmp"
TMPDIR="$WORK/tmp"
export TMPDIR

ok()  { printf '  %sok%s    %-58s %s\n' "$c_green" "$c_reset" "$1" "$2"; PASS=$((PASS + 1)); }
bad() { printf '  %sFAIL%s  %-58s %s\n' "$c_red" "$c_reset" "$1" "$2"; FAIL=$((FAIL + 1)); }

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then ok "$label" "exit=$got"; else bad "$label" "want=$want got=$got"; fi
}

section() { printf '\n%s\n' "$1"; }

# expect_contains <label> <needle> <command...>
# The match is a case statement, not `grep -q`: under `set -o pipefail`, grep's early
# exit on a match makes the pipeline report failure, so a present needle read as absent.
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  case "$out" in
    *"$needle"*) ok "$label" "found" ;;
    *) bad "$label" "missing: $needle" ;;
  esac
}

# expect_eq <label> <want> <got> — exact string comparison.
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1" "exact"
  else bad "$1" "mismatch"; printf '    want: %s\n    got:  %s\n' "$2" "$3"; fi
}

# stdout_of / stderr_of <command...> — one stream only.
stdout_of() { "$@" 2>/dev/null; }
stderr_of() { "$@" 2>&1 >/dev/null; }

# tree_sum <dir> — one checksum over every file path and content under a directory.
tree_sum() { find "$1" -type f | sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done | cksum; }

section "Staging"
check "openspec CLI is absent on the suite PATH"  1 bash -c 'command -v openspec'

# ---------------------------------------------------------------------------
# CODEBASE context preflight
# ---------------------------------------------------------------------------

section "CODEBASE context preflight"

S2="$WORK/s2"
mkdir -p "$S2/src"
cd "$S2" || exit 2
git init -q .
printf '{"name":"demo"}' > package.json
printf 'export const a=1\n' > src/app.ts
git add -A && git -c user.email=t@t -c user.name=t commit -qm init
REV1=$(git rev-parse HEAD)

PRE="$SCRIPTS/guard-context-preflight.sh"
commit() { git add -A && git -c user.email=t@t -c user.name=t commit -qm "$1"; }

check "brownfield, no CODEBASE.md"       2 "$PRE" --file PRD.md --quiet
# A large repository without a manifest is a codebase too: its long listing of
# source files must not read as "no source file".
S2L="$WORK/s2-large"
mkdir -p "$S2L/src"
( cd "$S2L" && git init -q . && i=0 && while [ "$i" -lt 4000 ]; do : > "src/module-with-a-rather-long-name-$i.ts"; i=$((i + 1)); done )
in_large() { ( cd "$S2L" && "$@" ); }
check "a large manifest-less repository is a codebase" 2 in_large "$PRE" --file PRD.md --quiet
expect_contains "and it is asked for its analysis" "A meaningful codebase is present but CODEBASE.md does not exist." \
  in_large "$PRE" --file PRD.md
# A listing that find could not finish is still a listing.
S2U="$WORK/s2-unreadable"
mkdir -p "$S2U/src" "$S2U/locked"
( cd "$S2U" && git init -q . && : > src/app.ts && chmod 000 locked )
in_unreadable() { ( cd "$S2U" && "$@" ); }
check "a repository with an unreadable directory is still a codebase" 2 in_unreadable "$PRE" --file PRD.md --quiet
chmod 755 "$S2U/locked"
expect_contains "the block prints the skip line to record" \
  "    b) record a deliberate skip by adding this line to PRD.md:
       CODEBASE Context: skipped (<reason>)" "$PRE" --file PRD.md

printf '# PRD\n\nCODEBASE Context: skipped (legacy port)\n' > PRD.md
check "recorded skip decision"           0 "$PRE" --file PRD.md --quiet
check "a skip in the PRD covers the SPECS too" 0 "$PRE" --file SPECS.md --quiet
rm -f PRD.md

# The write that records the decision must pass: the guard reads it from the
# document as the write would leave it (--content-file), not only from disk.
printf '# PRD\n\nCODEBASE Context: skipped (legacy port)\n' > "$WORK/prd.skip"
printf '# PRD\n\nProduct intent.\n' > "$WORK/prd.undecided"
check "a skip in the prospective PRD allows"      0 "$PRE" --file PRD.md --content-file "$WORK/prd.skip" --quiet
check "a skip in the prospective SPECS allows"    0 "$PRE" --file SPECS.md --content-file "$WORK/prd.skip" --quiet
expect_eq "the skip allow message" "ALLOW  codebase analysis explicitly skipped" \
  "$(stderr_of "$PRE" --file PRD.md --content-file "$WORK/prd.skip")"
check "prospective content without a decision blocks" 2 "$PRE" --file PRD.md --content-file "$WORK/prd.undecided" --quiet
check "the prospective content is never written"  1 test -e PRD.md

printf 'Analyzed revision: %s\n' "$REV1" > CODEBASE.md
check "CODEBASE.md current"              0 "$PRE" --file SPECS.md --quiet

printf 'export const b=2\n' > src/other.ts
commit advance
REV2=$(git rev-parse HEAD)
check "CODEBASE.md stale"                2 "$PRE" --file PRD.md --quiet

check "non-target artifact ignored"      0 "$PRE" --file README.md --quiet

# Only the mapped documents are guarded: an unmapped docs/ copy is not a product artifact.
check "unmapped docs/PRD.md ignored"    0 "$PRE" --file docs/PRD.md --quiet
check "unmapped docs/SPECS.md ignored"  0 "$PRE" --file docs/SPECS.md --quiet

# The stale block prints a line that accepts the staleness. It is tied to the
# revision CODEBASE.md records and is read from the document being written.
ACCEPT="CODEBASE Context: consumed ($REV1, staleness accepted)"
expect_contains "the stale block prints the acceptance line" \
  "  To proceed deliberately, put this line in PRD.md:
    $ACCEPT" "$PRE" --file PRD.md
printf '# PRD\n\n%s\n' "$ACCEPT" > "$WORK/prd.accept"
printf '# PRD\n\nCODEBASE Context: consumed (%s, staleness accepted)\n' "$REV2" > "$WORK/prd.other-revision"
printf '# PRD\n\nCODEBASE Context: consumed (%s)\n' "$REV1" > "$WORK/prd.consumed"
check "acceptance in the prospective PRD allows"  0 "$PRE" --file PRD.md --content-file "$WORK/prd.accept" --quiet
check "acceptance in the prospective SPECS allows" 0 "$PRE" --file SPECS.md --content-file "$WORK/prd.accept" --quiet
check "acceptance of another revision blocks"     2 "$PRE" --file PRD.md --content-file "$WORK/prd.other-revision" --quiet
check "plain consumption is not acceptance"       2 "$PRE" --file PRD.md --content-file "$WORK/prd.consumed" --quiet
check "a skip line does not accept a stale analysis" 2 "$PRE" --file PRD.md --content-file "$WORK/prd.skip" --quiet
cp "$WORK/prd.accept" PRD.md
check "acceptance on disk allows the next write"  0 "$PRE" --file PRD.md --quiet
expect_eq "the accepted-stale allow message" \
  "ALLOW  stale CODEBASE.md ($REV1) accepted by the decision recorded in PRD.md" "$(stderr_of "$PRE" --file PRD.md)"
check "a write that removes the acceptance blocks" 2 "$PRE" --file PRD.md --content-file "$WORK/prd.consumed" --quiet
check "acceptance in the PRD does not cover the SPECS" 2 "$PRE" --file SPECS.md --quiet
rm -f PRD.md

# Stale means a commit touched something other than the three mapped documents.
analyzed_at_head() { printf 'Analyzed revision: %s\n' "$(git rev-parse HEAD)" > CODEBASE.md; }
analyzed_at_head
check "a refreshed CODEBASE.md is current before its commit" 0 "$PRE" --file PRD.md --quiet
commit "docs: refresh CODEBASE.md"
check "committing CODEBASE.md alone does not stale it" 0 "$PRE" --file PRD.md --quiet
printf '# PRD\n' > PRD.md; printf '# SPECS\n' > SPECS.md
commit "docs: PRD and SPECS"
check "committing the PRD and the SPECS does not either" 0 "$PRE" --file SPECS.md --quiet
printf 'export const c=3\n' >> src/app.ts; printf 'notes\n' > NOTES.md
commit "feat: source and an unmapped document"
check "a commit touching a source file does"      2 "$PRE" --file PRD.md --quiet
expect_contains "only the other files are counted" "HEAD has moved on (2 file(s) changed)." "$PRE" --file PRD.md

# The same when the project is a subdirectory of the repository: the excluded
# documents are the project's own, and the rest of the repository still counts.
SUB="$WORK/s2sub"
mkdir -p "$SUB/app/src" "$SUB/other"
cd "$SUB" || exit 2
git init -q .
printf '{"name":"demo"}' > app/package.json
printf 'export const a=1\n' > app/src/app.ts
printf 'export const y=1\n' > other/lib.ts
printf '# A repository-level PRD.md, not the mapped one\n' > PRD.md
commit init
cd "$SUB/app" || exit 2
analyzed_at_head
printf '# PRD\n' > PRD.md; printf '# SPECS\n' > SPECS.md
commit "docs: the three mapped documents"
check "subdirectory: its own documents do not stale it" 0 "$PRE" --file PRD.md --quiet
printf '# Changed at the repository root\n' > ../PRD.md
commit "docs: a same-named file at the repository root"
check "subdirectory: a same-named file at the repository root does" 2 "$PRE" --file PRD.md --quiet
analyzed_at_head
check "subdirectory: analysed again, it is current" 0 "$PRE" --file PRD.md --quiet
printf 'export const z=2\n' >> ../other/lib.ts
commit "feat: source outside the project"
check "subdirectory: a source file outside the project does" 2 "$PRE" --file SPECS.md --quiet
analyzed_at_head
printf 'export const b=2\n' >> src/app.ts
commit "feat: source inside the project"
check "subdirectory: a source file inside the project does" 2 "$PRE" --file SPECS.md --quiet
cd "$S2" || exit 2

# PostToolUse half of the same contract: once CODEBASE.md exists, the validator
# must reject a PRD.md *or* SPECS.md that does not record consuming it.
FX="$SCRIPTS/fixtures/valid"
S2V="$WORK/s2v"
mkdir -p "$S2V"
cp "$FX/CODEBASE.md" "$FX/PRD.md" "$S2V/"
grep -v 'CODEBASE Context' "$FX/SPECS.md" > "$S2V/SPECS.md"
check "SPECS.md without context marker fails" 1 "$SCRIPTS/validate-product-artifacts.sh" \
  --specs "$S2V/SPECS.md" --prd "$S2V/PRD.md" --codebase "$S2V/CODEBASE.md" --quiet
check "SPECS.md hook blocks missing marker" 2 sh -c "cd '$S2V' && printf '{\"tool_input\":{\"file_path\":\"$S2V/SPECS.md\"}}' | '$SCRIPTS/validate-product-artifacts.sh' --hook --quiet"
cp "$FX/SPECS.md" "$S2V/SPECS.md"
check "SPECS.md with context marker passes" 0 "$SCRIPTS/validate-product-artifacts.sh" \
  --specs "$S2V/SPECS.md" --prd "$S2V/PRD.md" --codebase "$S2V/CODEBASE.md" --quiet

S3="$WORK/s3"
mkdir -p "$S3"
cd "$S3" || exit 2
check "greenfield: no codebase"          0 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --quiet

# ---------------------------------------------------------------------------
# Task progress — tasks.md is the only tracking file, read in one place
# ---------------------------------------------------------------------------

section "runtime.sh — ohmyorch_tasks_progress prints <done> <total>"

RUNTIME="$OHMYORCH_TEST_PLUGIN_ROOT/lib/runtime.sh"
progress() { /bin/bash -c 'source "$1"; ohmyorch_tasks_progress "$2"' progress "$RUNTIME" "$1"; }
expect_eq "an absent tasks.md is 0 0"            "0 0" "$(progress "$WORK/absent.md" 2>&1)"
: > "$WORK/empty.md"
expect_eq "an empty tasks.md is 0 0"             "0 0" "$(progress "$WORK/empty.md" 2>&1)"
printf -- '# Tasks\n\n- [x] a\n- [ ] b\n  - [X] c\n-[ ] d\n\t- [x] e\n* [x] a star item is a task too\n- [y] any marker but x is unfinished\ntext - [x] not at line start\n' > "$WORK/mixed.md"
expect_eq "done and total on one line"           "4 7" "$(progress "$WORK/mixed.md" 2>&1)"
printf -- '- [x] a\n- [x] b' > "$WORK/no-final-newline.md"
expect_eq "a last line without a newline counts" "2 2" "$(progress "$WORK/no-final-newline.md" 2>&1)"

# Tasks are counted the way OpenSpec 1.13.2 counts them (TASK_LINE_PATTERN): any
# list marker, a box holding at most one character, and only x or X is done.
# counted <label> <want> <one tasks.md line>
counted() { printf '%s\n' "$3" > "$WORK/one-line.md"; expect_eq "$1" "$2" "$(progress "$WORK/one-line.md" 2>&1)"; }
counted "'- [~]' is an unfinished task"           "0 1" '- [~] in progress'
counted "'- [-]' is an unfinished task"           "0 1" '- [-] skipped'
counted "'- []' is an unfinished task"            "0 1" '- [] empty box'
counted "'- [  ]' is an unfinished task"          "0 1" '- [  ] two spaces'
counted "'* [ ]' is an unfinished task"           "0 1" '* [ ] star'
counted "'+ [x]' is a done task"                  "1 1" '+ [x] plus'
counted "'1. [ ]' is an unfinished task"          "0 1" '1. [ ] numbered'
counted "'2) [x]' is a done task"                 "1 1" '2) [x] parenthesis'
counted "'- [ x ]' is a done task"                "1 1" '- [ x ] padded'
counted "a box at the end of the line counts"     "1 1" '- [x]'
counted "a nine-digit number is a list marker"    "0 1" '123456789. [ ] nine digits'
counted "a ten-digit number is not"               "0 0" '1234567890. [ ] ten digits'
counted "a link bullet is not a task"             "0 0" '- [x](./x.md) link'
counted "a reference link is not a task"          "0 0" '- [x][ref] reference'
counted "a link text is not a box"                "0 0" '- [See the design](./design.md)'
counted "a multi-character box is not a task"     "0 0" '- [WIP] several characters'
counted "a plain bullet is not a task"            "0 0" '- plain bullet'
printf -- '- [x] a\r\n- [ ] b\r\n' > "$WORK/crlf.md"
expect_eq "CRLF line endings count the same"     "1 2" "$(progress "$WORK/crlf.md" 2>&1)"
check "the selected-change helper is gone"       1 /bin/bash -c 'source "$1"; declare -F ohmyorch_selected_change' probe "$RUNTIME"

# ---------------------------------------------------------------------------
# guard-archive.sh — no archive while tasks.md has unticked tasks
# ---------------------------------------------------------------------------

section "guard-archive.sh — every task ticked, or no checklist, may archive"

S4="$WORK/s4"
mkdir -p "$S4/openspec/changes/archive"
cd "$S4" || exit 2
GA="$SCRIPTS/guard-archive.sh"

# archive_hook <command> — a realistic Bash payload: `description` follows `command`.
archive_hook() {
  jq -cn --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c,description:"Archive the change",timeout:120000}}' \
    | "$GA" --hook --quiet
}

C=openspec/changes/ticked
mkdir -p "$C"
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > "$C/tasks.md"
check "all tasks ticked is allowed"              0 "$GA" --change ticked --quiet
expect_eq "allow message counts the tasks"       "ALLOW  ticked: 2/2 tasks complete" "$(stderr_of "$GA" --change ticked)"
expect_eq "allow prints nothing on stdout"       "" "$(stdout_of "$GA" --change ticked)"
expect_eq "--quiet suppresses the allow message" "" "$("$GA" --change ticked --quiet 2>&1)"
expect_eq "allow verdict as JSON" \
  '{ "change": "ticked", "archiveEligible": true, "blocked": false }' "$(stdout_of "$GA" --change ticked --json)"
expect_eq "JSON allow keeps stderr empty"        "" "$(stderr_of "$GA" --change ticked --json)"

# Every checkbox spelling the task counter accepts: nested, `-[x]`, upper-case X.
printf -- '- [x] a\n  - [X] nested\n-[x] tight\n\t- [x] tabbed\n' > "$C/tasks.md"
expect_eq "nested, tight and upper-case boxes count" "ALLOW  ticked: 4/4 tasks complete" "$(stderr_of "$GA" --change ticked)"

mkdir -p openspec/changes/no-tasks
check "no tasks.md is allowed"                   0 "$GA" --change no-tasks --quiet
expect_eq "no tasks.md says no checklist"        "ALLOW  no-tasks: no task checklist" "$(stderr_of "$GA" --change no-tasks)"
expect_eq "no tasks.md verdict as JSON" \
  '{ "change": "no-tasks", "archiveEligible": true, "blocked": false }' "$(stdout_of "$GA" --change no-tasks --json)"

mkdir -p openspec/changes/no-boxes
printf -- '# Tasks\n\nNothing to tick here.\n- a plain bullet\n- [See the design](./design.md)\n- [x](./done.md) a link bullet\n' > openspec/changes/no-boxes/tasks.md
check "zero checkboxes is allowed"               0 "$GA" --change no-boxes --quiet
expect_eq "zero checkboxes says no checklist"    "ALLOW  no-boxes: no task checklist" "$(stderr_of "$GA" --change no-boxes)"

check "an unknown change is allowed"             0 "$GA" --change never-existed --quiet
expect_eq "unknown change verdict as JSON" \
  '{ "change": "never-existed", "archiveEligible": true, "blocked": false }' "$(stdout_of "$GA" --change never-existed --json)"
mkdir -p openspec/changes/archive/2026-09-24-shipped
printf -- '- [ ] left open before archival\n' > openspec/changes/archive/2026-09-24-shipped/tasks.md
check "an already archived change is allowed"    0 "$GA" --change shipped --quiet

section "guard-archive.sh — an unticked task blocks"

C=openspec/changes/pending
mkdir -p "$C/specs/cap"
printf '# Proposal\n' > "$C/proposal.md"
printf '# Spec\n' > "$C/specs/cap/spec.md"
printf -- '- [x] 1.1 build\n- [ ] 1.2 test\n- [ ] 1.3 document\n' > "$C/tasks.md"
check "an unticked task blocks"                  2 "$GA" --change pending --quiet
WANT_BLOCK='BLOCKED  archive pending
  1/3 tasks complete in openspec/changes/pending/tasks.md.
  Finish the remaining tasks (/ohmyorch:opsx-apply pending) or remove tasks that no longer apply, then archive.'
expect_eq "block message, exactly"               "$WANT_BLOCK" "$(stderr_of "$GA" --change pending)"
expect_eq "--quiet never hides the block"        "$WANT_BLOCK" "$(stderr_of "$GA" --change pending --quiet)"
expect_eq "block prints nothing on stdout"       "" "$(stdout_of "$GA" --change pending)"
check "JSON mode blocks with exit 2"             2 "$GA" --change pending --json
expect_eq "block verdict as JSON" \
  '{ "change": "pending", "archiveEligible": false, "blocked": true, "reason": "1/3 tasks complete" }' \
  "$(stdout_of "$GA" --change pending --json)"
expect_eq "JSON reason field"                    "1/3 tasks complete" "$(stdout_of "$GA" --change pending --json | jq -r .reason)"
expect_eq "JSON block keeps the stderr message"  "$WANT_BLOCK" "$(stderr_of "$GA" --change pending --json)"
printf -- '- [ ] only\n' > "$C/tasks.md"
expect_contains "nothing ticked reports 0/1"     "0/1 tasks complete in openspec/changes/pending/tasks.md." "$GA" --change pending

# Unfinished is what OpenSpec itself counts as unfinished: `openspec archive -y`
# only warns about these, so the guard is what keeps the archive shut.
C=openspec/changes/markers
mkdir -p "$C"
for marker in '- [~]' '- [-]' '- []' '* [ ]' '+ [ ]' '1. [ ]' '1) [ ]' '- [y]'; do
  printf -- '- [x] 1.1 build\n%s 1.2 test\n' "$marker" > "$C/tasks.md"
  check "'$marker' is an unfinished task: blocked" 2 "$GA" --change markers --quiet
  expect_contains "'$marker' is counted as 1/2"  "1/2 tasks complete in openspec/changes/markers/tasks.md." "$GA" --change markers
done
printf '# Tasks\n\n* [ ] a checklist without a dash\n' > "$C/tasks.md"
expect_eq "a checklist without a dash blocks too" \
'BLOCKED  archive markers
  0/1 tasks complete in openspec/changes/markers/tasks.md.
  Finish the remaining tasks (/ohmyorch:opsx-apply markers) or remove tasks that no longer apply, then archive.' \
  "$(stderr_of "$GA" --change markers)"
printf -- '- [x] a\n- [~] b\n' > "$C/tasks.md"
check "hook mode blocks an unfinished '- [~]'"   2 archive_hook "openspec archive markers -y"
printf -- '* [x] a\n1. [X] b\n+ [ x ] c\n' > "$C/tasks.md"
expect_eq "every marker ticked is allowed"       "ALLOW  markers: 3/3 tasks complete" "$(stderr_of "$GA" --change markers)"

section "guard-archive.sh — tasks.md is the only evidence consulted"

# Files an earlier plugin version left in a change are project history. They are
# neither read nor required, and the guard never touches them.
C=openspec/changes/legacy
mkdir -p "$C/history"
printf -- '- [x] 1.1 build\n' > "$C/tasks.md"
printf '# Review\n\nVerdict: fail\n\nBlocking:\n- F-1: unresolved\n' > "$C/review.md"
printf '# Test Report\n\nVerdict: fail\n\n| 1 | criterion | FAIL |\n' > "$C/test-report.md"
printf '# Status\n\n| State | REVIEWING |\n' > "$C/status.md"
printf '# Completion\n\n| Verdict | not-eligible |\n' > "$C/completion.md"
printf '# Implementation Plan\n' > "$C/implementation-plan.md"
printf '# Review round 1\n' > "$C/history/review-r1.md"
BEFORE=$(tree_sum "$C")
check "ticked change with a failing leftover review archives" 0 "$GA" --change legacy --quiet
check "no proposal, specs or plan is required"   0 "$GA" --change legacy --json
printf -- '- [x] 1.1 build\n- [ ] R1.1 fix\n' > "$C/tasks.md"
check "only the unticked task blocks it"         2 "$GA" --change legacy --quiet
printf -- '- [x] 1.1 build\n' > "$C/tasks.md"
expect_eq "leftover files survive untouched"     "$BEFORE" "$(tree_sum "$C")"

# The guard is self-contained: with every other script removed it decides the same.
ALONE="$WORK/alone"
mkdir -p "$ALONE/scripts"
cp -R "$OHMYORCH_TEST_PLUGIN_ROOT/lib" "$ALONE/lib"
cp "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/guard-archive.sh" "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/guard-story-done.sh" "$ALONE/scripts/"
alone() { name="$1"; shift; OHMYORCH_PROJECT_ROOT="$(pwd -P)" /bin/bash "$ALONE/scripts/$name" "$@"; }
check "alone: ticked change is allowed"          0 alone guard-archive.sh --change ticked --quiet
check "alone: unticked change is blocked"        2 alone guard-archive.sh --change pending --quiet

section "guard-archive.sh — hook payloads"

check "hook mode rejects archive"                2 archive_hook "openspec archive pending --yes"
check "hook mode rejects archive -y"             2 archive_hook "openspec archive pending -y"
expect_contains "hook block names the change"    "BLOCKED  archive pending" archive_hook "openspec archive pending -y"
check "hook mode allows a ticked change"         0 archive_hook "openspec archive ticked -y"
check "hook mode allows an unknown change"       0 archive_hook "openspec archive never-existed -y"
check "hook mode skips the value of --store"     2 archive_hook "openspec archive pending --store ticked"
check "hook mode ignores archive --help"         0 archive_hook "openspec archive --help"
check "hook mode ignores archive -h"             0 archive_hook "openspec archive pending -h"
check "hook mode ignores other commands"         0 archive_hook "git status --short"
check "archive only in description ignored"      0 sh -c "printf '{\"tool_input\":{\"command\":\"ls\",\"description\":\"then openspec archive pending\"}}' | '$GA' --hook --quiet"
check "bare payload without description blocks"  2 sh -c "printf '{\"tool_input\":{\"command\":\"openspec archive pending --yes\"}}' | '$GA' --hook --quiet"
check "hook mode, empty stdin"                   0 sh -c "printf '' | '$GA' --hook --quiet"

section "guard-archive.sh — no change named"

S4B="$WORK/s4b"
mkdir -p "$S4B/openspec/changes/archive"
cd "$S4B" || exit 2
check "no active change: nothing to block"       0 "$GA" --quiet
expect_eq "no active change prints nothing"      "" "$("$GA" 2>&1)"
check "hook: archive with no active change"      0 archive_hook "openspec archive"
mkdir -p openspec/changes/only-one
printf -- '- [ ] open\n' > openspec/changes/only-one/tasks.md
check "falls back to the first active change"    2 "$GA" --quiet
expect_contains "fallback names that change"     "BLOCKED  archive only-one" "$GA"
check "hook: bare archive uses the fallback"     2 archive_hook "openspec archive -y"
printf -- '- [x] open\n' > openspec/changes/only-one/tasks.md
check "fallback change, all ticked"              0 "$GA" --quiet

# ---------------------------------------------------------------------------
# guard-story-done.sh — archive before DONE
# ---------------------------------------------------------------------------

S5="$WORK/s5"
mkdir -p "$S5/openspec/changes/archive/2026-09-24-us-1-9-old"
cd "$S5" || exit 2
GD="$SCRIPTS/guard-story-done.sh"

cat > SPECS.md <<'EOF'
# Stub Specification

# EPIC-1: Delivered epic

### US-1.9: Old story

Status: DONE

Change: `openspec/changes/archive/2026-09-24-us-1-9-old/`

# EPIC-2: Done-guard epic

### US-2.1: Story with a Change line

Status: IN PROGRESS

Change: `openspec/changes/widget-work/`

### US-2.2: Story found by its directory

Status: READY

### US-2.3: Story with no change

Status: READY
EOF
cp SPECS.md "$WORK/specs.s5"

# done_content <story-id>... — the full prospective SPECS with those stories set to DONE.
done_content() {
  ids=" $* "
  awk -v ids="$ids" '
    /^### US-[0-9]+\.[0-9]+:/ { id = $2; sub(/:$/, "", id) }
    /^Status:/ && index(ids, " " id " ") { print "Status: DONE"; next }
    { print }
  ' SPECS.md
}
# done_edit <old_string> <new_string> — a real Edit payload: keys follow new_string.
done_edit() {
  jq -cn --arg f "$PWD/SPECS.md" --arg o "$1" --arg n "$2" \
    '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n,replace_all:false}}' \
    | "$GD" --hook --quiet
}
# done_write <content> — a Write payload carrying the whole prospective file.
done_write() {
  jq -cn --arg f "$PWD/SPECS.md" --arg c "$1" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' \
    | "$GD" --hook --quiet
}

section "guard-story-done.sh — blocked while the change is active (Change: line)"

mkdir -p openspec/changes/widget-work
check "DONE is blocked while the change is active" 2 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
WANT_DONE='BLOCKED  SPECS.md — US-2.1 to DONE
  Change widget-work is still active (openspec/changes/widget-work).
  Archive it first (openspec archive widget-work -y), then set the story to DONE.'
expect_eq "block message, exactly"                "$WANT_DONE" "$(stderr_of "$GD" --file SPECS.md --content "$(done_content US-2.1)")"
expect_eq "--quiet never hides the block"         "$WANT_DONE" "$(stderr_of "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet)"
expect_eq "block prints nothing on stdout"        "" "$(stdout_of "$GD" --file SPECS.md --content "$(done_content US-2.1)")"

# --content-file carries the same content as --content. The dispatcher uses it
# because Linux refuses a single argument of 128 KiB or more.
done_content US-2.1 > "$WORK/prospective.s5"
check "--content-file is judged like --content"   2 "$GD" --file SPECS.md --content-file "$WORK/prospective.s5" --quiet
expect_eq "--content-file block message, exactly" "$WANT_DONE" "$(stderr_of "$GD" --file SPECS.md --content-file "$WORK/prospective.s5")"
{ done_content US-2.1
  awk 'BEGIN { for (i = 0; i < 3000; i++) print "Filler prose that only makes the document larger than one argument." }'
} > "$WORK/large.s5"
check "a SPECS larger than one argument is still blocked" 2 "$GD" --file SPECS.md --content-file "$WORK/large.s5" --quiet
cp SPECS.md "$WORK/unchanged.s5"
check "--content-file of the unchanged file allows" 0 "$GD" --file SPECS.md --content-file "$WORK/unchanged.s5" --quiet
: > "$WORK/empty.s5"
check "an empty --content-file is no DONE write"  0 "$GD" --file SPECS.md --content-file "$WORK/empty.s5" --quiet
check "an unreadable --content-file blocks"       2 "$GD" --file SPECS.md --content-file "$WORK/absent.s5" --quiet
check "--content-file needs a value"              3 "$GD" --file SPECS.md --content-file

# Archive first: a change that merely looks finished is still an active change.
mkdir -p openspec/changes/widget-work/specs/cap
printf '# Proposal\n' > openspec/changes/widget-work/proposal.md
printf '# Spec\n' > openspec/changes/widget-work/specs/cap/spec.md
printf -- '- [x] 1.1 build\n- [x] 1.2 test\n' > openspec/changes/widget-work/tasks.md
check "every task ticked does not permit DONE"    2 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet

# Every change that could stand behind the story is judged: the Change: id the
# write carries and the one on disk. Pointing the line at the archive path does
# not archive the change, and no rewording of the line detaches the story from it.
# reworded <Change: line> — US-2.1 set to DONE with its Change: line replaced.
reworded() { done_content US-2.1 | sed "s|^Change: \`openspec/changes/widget-work/\`\$|$1|"; }
EARLY=$(reworded 'Change: `openspec/changes/archive/2026-11-12-widget-work/`')
check "an early archive path in the write is blocked" 2 "$GD" --file SPECS.md --content "$EARLY" --quiet
expect_contains "the dated path is normalised to the id" "Change widget-work is still active" "$GD" --file SPECS.md --content "$EARLY"
RENAMED=$(reworded 'Change: `openspec/changes/renamed-away/`')
check "a Change: line renamed in the same write is blocked" 2 "$GD" --file SPECS.md --content "$RENAMED" --quiet
expect_eq "the block names the change recorded on disk" "$WANT_DONE" "$(stderr_of "$GD" --file SPECS.md --content "$RENAMED")"
# The spellings a hurried mark-done edit produces. None normalises to the active id.
DETACHED='annotated|Change: `openspec/changes/widget-work/` (archived)
a Markdown link|Change: [widget-work](openspec/changes/widget-work/)
a trailing period|Change: `openspec/changes/widget-work/`.
a mistyped id|Change: `openspec/changes/widget-wrk/`
a shortened id|Change: widget
the word archived|Change: archived
not applicable|Change: n/a
the archive directory|Change: `openspec/changes/archive/`'
while IFS='|' read -r spelling line; do
  check "DONE with the Change: line $spelling is blocked" 2 "$GD" --file SPECS.md --content "$(reworded "$line")" --quiet </dev/null
done <<EOF
$DETACHED
EOF
# The change is not named us-2-1-*, so only the line on disk still names it.
DELETED=$(done_content US-2.1 | grep -vxF 'Change: `openspec/changes/widget-work/`')
check "the staged write really drops the Change: line" 1 grep -q '^Change: .*widget-work' <<EOF
$DELETED
EOF
check "DONE with the Change: line deleted is blocked" 2 "$GD" --file SPECS.md --content "$DELETED" --quiet
expect_eq "the deleted line's change is the one named" "$WANT_DONE" "$(stderr_of "$GD" --file SPECS.md --content "$DELETED")"
# `archive` is the archive directory, never a change: a story with no change
# anywhere is not blocked by a Change: line that names it.
NAMES_ARCHIVE=$(printf '%s\n\nChange: `openspec/changes/archive/`\n' "$(done_content US-2.3)")
check "the archive directory itself is not a change" 0 "$GD" --file SPECS.md --content "$NAMES_ARCHIVE" --quiet
# A story's status on disk is the first Status: line of its first block. A later
# line that only looks like one (an example in the story) or a repeated heading
# must not make the story count as already DONE and so slip past the guard.
awk '{ print } /^Change: `openspec\/changes\/widget-work\/`$/ { print ""; print "```"; print "Status: DONE"; print "```" }' "$WORK/specs.s5" > SPECS.md
check "the staged block carries a later Status: DONE line" 0 grep -qx 'Status: DONE' SPECS.md
check "a later Status: DONE line in the block is not the story's status" 2 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
{ cat "$WORK/specs.s5"; printf '\n### US-2.1: The same id again\n\nStatus: DONE\n'; } > SPECS.md
check "a repeated heading does not make the story DONE on disk" 2 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
cp "$WORK/specs.s5" SPECS.md

mv openspec/changes/widget-work openspec/changes/archive/2026-11-12-widget-work
check "DONE is allowed once the change is archived" 0 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
# The mark-done edit itself: DONE and the Change: line pointed at the archive.
check "DONE with the archived Change: path is allowed" 0 "$GD" --file SPECS.md --content "$EARLY" --quiet
expect_eq "--quiet suppresses the allow message"  "" "$("$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet 2>&1)"
check "once archived, a renamed Change: line is allowed" 0 "$GD" --file SPECS.md --content "$RENAMED" --quiet
check "once archived, a deleted Change: line is allowed" 0 "$GD" --file SPECS.md --content "$DELETED" --quiet
while IFS='|' read -r spelling line; do
  check "once archived, $spelling is allowed"    0 "$GD" --file SPECS.md --content "$(reworded "$line")" --quiet </dev/null
done <<EOF
$DETACHED
EOF
# The story's Change: line names the archived change, yet a directory named for
# the story is still active. delivery.sh escalates in this state instead of
# deriving mark-done, and the guard refuses DONE until it is resolved: an
# earlier write that pointed the line at an archived change detaches nothing.
mkdir -p openspec/changes/us-2-1-still-open
check "an active us-n-m directory blocks beside an archived Change:" 2 "$GD" --file SPECS.md --content "$EARLY" --quiet
check "and blocks the same story's plain DONE edit" 2 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
expect_contains "the active directory is the change named" "Change us-2-1-still-open is still active" \
  "$GD" --file SPECS.md --content "$(done_content US-2.1)"
rmdir openspec/changes/us-2-1-still-open
check "DONE is allowed again once that directory is gone" 0 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
# A directory name that holds a newline names no change, as in delivery.sh: its
# second line must not be read as the id of another active change.
mkdir -p openspec/changes/other-active "openspec/changes/"$'us-2-1-x\nother-active'
check "a directory name that holds a newline names no change" 0 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
rmdir "openspec/changes/"$'us-2-1-x\nother-active' openspec/changes/other-active
mv openspec/changes/archive/2026-11-12-widget-work openspec/changes/widget-work

section "guard-story-done.sh — blocked while the change is active (us-n-m- directory)"

mkdir -p openspec/changes/us-2-2-found-by-directory
check "DONE is blocked via the story's directory"  2 "$GD" --file SPECS.md --content "$(done_content US-2.2)" --quiet
expect_eq "block names the directory change" \
'BLOCKED  SPECS.md — US-2.2 to DONE
  Change us-2-2-found-by-directory is still active (openspec/changes/us-2-2-found-by-directory).
  Archive it first (openspec archive us-2-2-found-by-directory -y), then set the story to DONE.' \
  "$(stderr_of "$GD" --file SPECS.md --content "$(done_content US-2.2)")"
# A Change: line that arrives with the DONE write does not hide the directory.
ADDED=$(done_content US-2.2 | awk '{ print } /^### US-2.2:/ { print ""; print "Change: `openspec/changes/elsewhere/`" }')
check "a Change: line added by the write does not hide the directory" 2 "$GD" --file SPECS.md --content "$ADDED" --quiet
expect_contains "the directory is still the change named" "Change us-2-2-found-by-directory is still active" \
  "$GD" --file SPECS.md --content "$ADDED"
# Candidates are judged in order: the id in the write, the id on disk, the directories.
REPOINTED=$(reworded 'Change: `openspec/changes/us-2-2-found-by-directory/`')
expect_eq "an active id in the write is the one reported" \
'BLOCKED  SPECS.md — US-2.1 to DONE
  Change us-2-2-found-by-directory is still active (openspec/changes/us-2-2-found-by-directory).
  Archive it first (openspec archive us-2-2-found-by-directory -y), then set the story to DONE.' \
  "$(stderr_of "$GD" --file SPECS.md --content "$REPOINTED")"
# `Change: -` on disk is no change id, as delivery.sh reads it: the directory stands in.
awk '{ print } /^### US-2.2:/ { print ""; print "Change: -" }' "$WORK/specs.s5" > SPECS.md
check "Change: - on disk leaves the directory in charge" 2 "$GD" --file SPECS.md --content "$(done_content US-2.2)" --quiet
# The same end state in two writes: an earlier write reworded the Change: line,
# so by the DONE write only the directory still names the active change. The
# story's directories always stand in, whatever the line says.
REWORDED_EARLIER='annotated|Change: `openspec/changes/archive/2026-11-12-us-2-2-found-by-directory/` (archived)
a Markdown link|Change: [us-2-2-found-by-directory](openspec/changes/us-2-2-found-by-directory/)
a mistyped id|Change: `openspec/changes/us-2-2-found-by-directry/`
an id that names nothing|Change: planned-later
a pattern that would match an archive entry|Change: us-2-2-*'
mkdir -p openspec/changes/archive/2026-11-12-us-2-2-older
while IFS='|' read -r spelling line; do
  awk -v l="$line" '{ print } /^### US-2.2:/ { print ""; print l }' "$WORK/specs.s5" > SPECS.md
  check "a Change: line left $spelling by an earlier write is blocked" 2 "$GD" --file SPECS.md --content "$(done_content US-2.2)" --quiet </dev/null
done <<REWORDED
$REWORDED_EARLIER
REWORDED
expect_contains "the directory is the change named then" "Change us-2-2-found-by-directory is still active" \
  "$GD" --file SPECS.md --content "$(done_content US-2.2)"
rmdir openspec/changes/archive/2026-11-12-us-2-2-older
cp "$WORK/specs.s5" SPECS.md
mkdir -p openspec/changes/us-2-20-other-story
check "still blocked beside another story's directory" 2 "$GD" --file SPECS.md --content "$(done_content US-2.2)" --quiet
mv openspec/changes/us-2-2-found-by-directory openspec/changes/archive/2026-11-12-us-2-2-found-by-directory
check "us-2-20-* does not stand in for US-2.2"    0 "$GD" --file SPECS.md --content "$(done_content US-2.2)" --quiet
rmdir openspec/changes/us-2-20-other-story
check "DONE is allowed once that change is archived" 0 "$GD" --file SPECS.md --content "$(done_content US-2.2)" --quiet
mv openspec/changes/archive/2026-11-12-us-2-2-found-by-directory openspec/changes/us-2-2-found-by-directory
# Any directory name is judged, not only a kebab one.
mkdir -p openspec/changes/us-2-3-v1.2
check "an active directory with an unusual name still blocks" 2 "$GD" --file SPECS.md --content "$(done_content US-2.3)" --quiet
expect_contains "and it is the change named" "Change us-2-3-v1.2 is still active" \
  "$GD" --file SPECS.md --content "$(done_content US-2.3)"
rmdir openspec/changes/us-2-3-v1.2

section "guard-story-done.sh — stories that are not a new DONE transition"

check "a story with no change may become DONE"    0 "$GD" --file SPECS.md --content "$(done_content US-2.3)" --quiet
check "re-writing an already DONE story is allowed" 0 "$GD" --file SPECS.md --content "$(cat SPECS.md)" --quiet
expect_eq "already-DONE allow message" "ALLOW  every story set to DONE here is already DONE" \
  "$(stderr_of "$GD" --file SPECS.md --content "$(cat SPECS.md)")"
# Even an active directory named for a story that is already DONE is not a transition.
mkdir -p openspec/changes/us-1-9-old
check "already DONE stays untouched beside an active dir" 0 "$GD" --file SPECS.md --content "$(cat SPECS.md)" --quiet
rmdir openspec/changes/us-1-9-old
check "a READY write is ignored"                  0 "$GD" --file SPECS.md --content "Status: READY" --quiet
check "an indented status line is still a DONE write" 2 "$GD" --file SPECS.md \
  --content "$(done_content US-2.1 | sed 's/^Status: DONE$/  Status: DONE  /')" --quiet
check "non-SPECS file is ignored"                 0 "$GD" --file README.md --content "$(done_content US-2.1)" --quiet
check "an unmapped docs/SPECS.md is ignored"      0 "$GD" --file docs/SPECS.md --content "$(done_content US-2.1)" --quiet

section "guard-story-done.sh — a multi-story Write judges every new DONE"

check "one active change among several blocks"    2 "$GD" --file SPECS.md --content "$(done_content US-2.3 US-2.1)" --quiet
expect_contains "the block names the story that is not archived" "SPECS.md — US-2.1 to DONE" \
  "$GD" --file SPECS.md --content "$(done_content US-2.3 US-2.1)"
check "a later story with an active change blocks" 2 "$GD" --file SPECS.md --content "$(done_content US-2.3 US-2.2)" --quiet
expect_contains "the later story is the one named" "SPECS.md — US-2.2 to DONE" \
  "$GD" --file SPECS.md --content "$(done_content US-2.3 US-2.2)"
# A Write is not judged by its first DONE story, which is usually an old one.
check "a Write behind an old DONE story is blocked" 2 "$GD" --file SPECS.md \
  --content "$(printf '### US-1.9: Old story\n\nStatus: DONE\n\n### US-2.1: Story with a Change line\n\nStatus: DONE\n\nChange: `openspec/changes/widget-work/`\n')" --quiet
check "a Write of only old DONE stories is allowed" 0 "$GD" --file SPECS.md \
  --content "$(printf '### US-1.9: Old story\n\nStatus: DONE\n')" --quiet
mv openspec/changes/widget-work openspec/changes/archive/2026-11-12-widget-work
mv openspec/changes/us-2-2-found-by-directory openspec/changes/archive/2026-11-12-us-2-2-found-by-directory
check "every story archived or unchanged allows"  0 "$GD" --file SPECS.md --content "$(done_content US-2.1 US-2.2 US-2.3)" --quiet
mv openspec/changes/archive/2026-11-12-widget-work openspec/changes/widget-work
mv openspec/changes/archive/2026-11-12-us-2-2-found-by-directory openspec/changes/us-2-2-found-by-directory

section "guard-story-done.sh — a bare Edit is located by --old"

# The common Edit carries no heading: `Status: X` -> `Status: DONE`. The replaced
# text locates the story when it is unique in the file.
OLD_21=$(printf 'Story with a Change line\n\nStatus: IN PROGRESS')
OLD_22=$(printf 'Story found by its directory\n\nStatus: READY')
OLD_23=$(printf 'Story with no change\n\nStatus: READY')
check "--old inside the story with an active change" 2 "$GD" --file SPECS.md --old "$OLD_21" --content "Status: DONE" --quiet
expect_contains "--old names that story"          "SPECS.md — US-2.1 to DONE" "$GD" --file SPECS.md --old "$OLD_21" --content "Status: DONE"
check "--old finds the directory-named change"    2 "$GD" --file SPECS.md --old "$OLD_22" --content "Status: DONE" --quiet
check "--old inside a story with no change"       0 "$GD" --file SPECS.md --old "$OLD_23" --content "Status: DONE" --quiet
check "a unique status line is location enough"   2 "$GD" --file SPECS.md --old "Status: IN PROGRESS" --content "Status: DONE" --quiet
check "--old inside an already DONE story"        0 "$GD" --file SPECS.md --old "$(printf 'Old story\n\nStatus: DONE')" --content "Status: DONE" --quiet
check "hook: real Edit payload is blocked"        2 done_edit "$OLD_21" "Status: DONE"
check "hook: Edit in a story with no change"      0 done_edit "$OLD_23" "Status: DONE"
check "hook: a heading in new_string names the story" 2 done_edit "anything" "$(printf '### US-2.2: Story found by its directory\n\nStatus: DONE')"
check "hook: a Change: line in new_string names the change" 2 done_edit "anything" \
  "$(printf '### US-2.3: Story with no change\n\nStatus: DONE\n\nChange: `openspec/changes/widget-work/`')"
check "hook: full Write content is blocked"       2 done_write "$(done_content US-2.1)"
check "hook: full Write of the unchanged file"    0 done_write "$(cat SPECS.md)"
check "hook: empty stdin fails open"              0 sh -c "printf '' | '$GD' --hook"
check "hook: a payload that is not an object blocks" 2 sh -c "printf '[]' | '$GD' --hook --quiet"

section "guard-story-done.sh — single-active-change fallback"

# `Status: READY` recurs in two stories, so --old cannot locate the edit.
check "two active changes: an unlocatable edit is allowed" 0 "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE" --quiet
mv openspec/changes/us-2-2-found-by-directory "$WORK/parked-us-2-2"
check "one active change, named by a Change: line on disk" 2 "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE" --quiet
expect_contains "the fallback names that story"    "SPECS.md — US-2.1 to DONE" "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE"
check "the fallback also applies with no --old"    2 "$GD" --file SPECS.md --content "Status: DONE" --quiet
mv openspec/changes/widget-work "$WORK/parked-widget-work"
check "no active change: an unlocatable edit is allowed" 0 "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE" --quiet
mv "$WORK/parked-us-2-2" openspec/changes/us-2-2-found-by-directory
check "one active change, story read from its name" 2 "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE" --quiet
expect_contains "the name-derived story is US-2.2" "SPECS.md — US-2.2 to DONE" "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE"
mv openspec/changes/us-2-2-found-by-directory "$WORK/parked-us-2-2"
mkdir -p openspec/changes/misc-cleanup
check "one active change that names no story allows" 0 "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE" --quiet
rmdir openspec/changes/misc-cleanup
mkdir -p openspec/changes/us-1-9-old
check "fallback story already DONE on disk allows" 0 "$GD" --file SPECS.md --old "Status: READY" --content "Status: DONE" --quiet
rmdir openspec/changes/us-1-9-old
mv "$WORK/parked-us-2-2" openspec/changes/us-2-2-found-by-directory
mv "$WORK/parked-widget-work" openspec/changes/widget-work

section "guard-story-done.sh — structural and self-contained"

C=openspec/changes/widget-work
mkdir -p "$C/history"
printf '# Review\n\nVerdict: pass\n\nBlocking: None\n' > "$C/review.md"
printf '# Test Report\n\nVerdict: pass\n' > "$C/test-report.md"
printf '# Completion\n\n| Verdict | eligible |\n' > "$C/completion.md"
printf '# Status\n\n| State | ACCEPTED |\n' > "$C/status.md"
printf '# Review round 1\n' > "$C/history/review-r1.md"
BEFORE=$(tree_sum openspec)
check "passing leftover verdict files do not permit DONE" 2 "$GD" --file SPECS.md --content "$(done_content US-2.1)" --quiet
check "alone: active change blocks DONE"          2 alone guard-story-done.sh --file SPECS.md --content "$(done_content US-2.1)" --quiet
check "alone: story with no change is allowed"    0 alone guard-story-done.sh --file SPECS.md --content "$(done_content US-2.3)" --quiet
expect_eq "the guard changes nothing under openspec/" "$BEFORE" "$(tree_sum openspec)"
check "the guard never rewrites SPECS.md"         0 cmp -s SPECS.md "$WORK/specs.s5"

section "guard-story-done.sh — one pass over the backlog, whatever its length"

# Every SPECS bookkeeping write runs this guard, and a full-file write carries
# every delivered story. The stories already DONE on disk are read in one pass:
# the number of processes the guard starts does not grow with the backlog.
S5B="$WORK/s5b"
mkdir -p "$S5B/openspec/changes/archive" "$S5B/counted"
cd "$S5B" || exit 2
for tool in awk sed grep find; do
  printf '#!/bin/sh\nprintf "%%s\\n" %s >> "$SPAWN_LOG"\nexec %s "$@"\n' "$tool" "$(command -v "$tool")" > "counted/$tool"
  chmod +x "counted/$tool"
done
# backlog <n> — a SPECS with n delivered stories and one story in progress.
backlog() {
  awk -v n="$1" 'BEGIN {
    print "# EPIC-9: A long backlog\n"
    for (i = 1; i <= n; i++) printf "### US-9.%d: Delivered story %d\n\nStatus: DONE\n\n", i, i
    print "### US-9.99: The story being delivered\n\nStatus: IN PROGRESS\n\nChange: `openspec/changes/long-backlog-change/`"
  }'
}
# spawned_by <command...> — how many awk, sed, grep and find processes it starts.
spawned_by() {
  : > "$S5B/spawn.log"
  SPAWN_LOG="$S5B/spawn.log" PATH="$S5B/counted:$PATH" "$@" >/dev/null 2>&1
  wc -l < "$S5B/spawn.log" | tr -d ' '
}
mkdir -p openspec/changes/long-backlog-change
backlog 2 > SPECS.md
SHORT=$(spawned_by "$GD" --file SPECS.md --content "$(sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md)" --quiet)
check "short backlog: the active change blocks DONE" 2 "$GD" --file SPECS.md --content "$(sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md)" --quiet
backlog 40 > SPECS.md
LONG=$(spawned_by "$GD" --file SPECS.md --content "$(sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md)" --quiet)
check "long backlog: the active change blocks DONE" 2 "$GD" --file SPECS.md --content "$(sed 's/^Status: IN PROGRESS$/Status: DONE/' SPECS.md)" --quiet
check "the counting shims saw the guard's processes" 0 test "$SHORT" -gt 0
expect_eq "40 delivered stories start no more processes than 2" "$SHORT" "$LONG"
expect_eq "a rewrite of 40 delivered stories is no transition" "ALLOW  every story set to DONE here is already DONE" \
  "$(stderr_of "$GD" --file SPECS.md --content "$(cat SPECS.md)")"
cd "$S5" || exit 2

# ---------------------------------------------------------------------------
# Project validation adaptation point
# ---------------------------------------------------------------------------

section "Configured fast validation"

S6="$WORK/s6"
mkdir -p "$S6/src" "$S6/scripts"
cd "$S6" || exit 2

check "not configured -> skip, allow"    0 "$SCRIPTS/run-project-validation.sh" --file src/app.ts --quiet
check "non-source file ignored"          0 "$SCRIPTS/run-project-validation.sh" --file README.md --quiet

printf '#!/usr/bin/env bash\nexit 0\n' > scripts/fast-validate.sh
chmod +x scripts/fast-validate.sh
check "configured and passing"           0 "$SCRIPTS/run-project-validation.sh" --file src/app.ts --quiet

printf '#!/usr/bin/env bash\nexit 1\n' > scripts/fast-validate.sh
check "unapproved script never executes"    0 "$SCRIPTS/run-project-validation.sh" --file src/app.ts --quiet

# ---------------------------------------------------------------------------
# Usage errors and the retired guards
# ---------------------------------------------------------------------------

section "Usage errors"

cd "$ROOT" || exit 2
check "context: unknown option"          3 "$SCRIPTS/guard-context-preflight.sh" --bogus
check "context: --content-file needs a value" 3 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --content-file
check "context: an unreadable --content-file is refused" 3 "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --content-file "$WORK/absent.prd"
expect_eq "context: the refusal names the file" "error: cannot read --content-file '$WORK/absent.prd'" \
  "$(stderr_of "$SCRIPTS/guard-context-preflight.sh" --file PRD.md --content-file "$WORK/absent.prd")"
expect_eq "context: usage names --content-file" \
  "Usage: guard-context-preflight.sh (--hook | --file <path> [--content-file <path>]) [--quiet]" \
  "$("$SCRIPTS/guard-context-preflight.sh" --help | head -1)"
check "archive: unknown option"          3 "$GA" --bogus
check "archive: --change needs a value"  3 "$GA" --change
check "story-done: unknown option"       3 "$GD" --bogus
check "story-done: --file needs a value" 3 "$GD" --file
expect_eq "story-done: usage names --old and --quiet" \
  "Usage: guard-story-done.sh (--hook | --file <path> [--content <text> | --content-file <path>] [--old <text>]) [--quiet]" \
  "$("$GD" --help | head -1)"
check "validation: unknown option"       2 "$SCRIPTS/run-project-validation.sh" --bogus

section "Retired guards and validators are not shipped"

for retired in guard-planning-handoff check-write-scope check-scope completion-gate workflow-status status \
               validate-implementation-plan validate-review validate-test-report validate-status validate-verification; do
  check "$retired.sh is gone"            1 test -e "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/$retired.sh"
done
expect_eq "the payload ships exactly thirteen scripts" "13" "$(find "$OHMYORCH_TEST_PLUGIN_ROOT/scripts" -maxdepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')"

# ---------------------------------------------------------------------------
# Skill/agent contracts are checked by tools/check-plugin.mjs.

# Summary
# ---------------------------------------------------------------------------

printf '\n=======================================================\n'
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS — all guard behaviours hold.%s\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL — guard behaviour regressed.%s\n' "$c_red" "$c_reset"
exit 1
