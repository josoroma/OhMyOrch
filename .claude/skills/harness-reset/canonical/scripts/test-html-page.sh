#!/usr/bin/env bash
#
# test-html-page.sh — regression suite for themed HTML pages (US-14.1)
#
# Exercises scripts/validate-html-page.sh against the fixtures in
# scripts/fixtures/html-pages/ and checks the shipped template, the skill, and the
# example page. The properties this suite protects:
#
#   1. Palette — every Luma light and dark token must be present with its value.
#   2. Toggle — the page flips the "dark" class, persists it, and follows the system.
#   3. Navigation — a table of contents precedes the sections and every link resolves.
#   4. Components — the template ships a table, a list, an SVG diagram with an
#      overlay, an SVG ER diagram, and an SVG infrastructure diagram, all labelled.
#   5. Self-contained — no external script, stylesheet, import, url(), or font.
#   6. Evidence — a status page cites the files and commands behind its figures.
#   7. Rejection — each invalid fixture fails with exit 1 AND names its own rule;
#      each valid fixture passes, including the false-positive guards.
#
# Each invalid fixture is the valid page with exactly one mutation, named after the
# rule it breaks (scripts/fixtures/html-pages/make-fixtures.py).
#
# Usage: scripts/test-html-page.sh
#
# Exit codes: 0 all cases matched, 1 a case mismatched, 2 setup failure.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
V="$ROOT/scripts/validate-html-page.sh"
FIX="$ROOT/scripts/fixtures/html-pages"
TEMPLATE="$ROOT/scripts/templates/html-page.html"
SKILL="$ROOT/.claude/skills/generate-html-page/SKILL.md"
EXAMPLE="$ROOT/docs/pages/harness-overview.html"

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'
fi

ok()  { printf '  %sok%s    %-62s %s\n' "$c_green" "$c_reset" "$1" "$2"; PASS=$((PASS + 1)); }
bad() { printf '  %sFAIL%s  %-62s %s\n' "$c_red" "$c_reset" "$1" "$2"; FAIL=$((FAIL + 1)); }

# check <label> <expected-exit> <command...>
check() {
  label="$1"; want="$2"; shift 2
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then ok "$label" "exit=$got"; else bad "$label" "want=$want got=$got"; fi
}

# expect_contains <label> <needle> <command...>
# A case statement, not grep -q: under pipefail, grep's early exit on a match makes the
# pipeline report failure, so a present needle would read as absent.
expect_contains() {
  label="$1"; needle="$2"; shift 2
  out=$("$@" 2>&1)
  case "$out" in
    *"$needle"*) ok "$label" "found" ;;
    *)           bad "$label" "missing: $needle" ;;
  esac
}

section() { printf '\n%s\n' "$1"; }

[ -x "$V" ] || { echo "error: $V is not executable" >&2; exit 2; }
[ -d "$FIX/invalid" ] || { echo "error: fixtures missing at $FIX" >&2; exit 2; }

# rejects <fixture> <rule>: exit 1, and the failure line names the rule.
rejects() {
  f="$FIX/invalid/$1.html"; rule="$2"
  out=$("$V" --page "$f" --quiet 2>&1); rc=$?
  if [ "$rc" != "1" ]; then bad "$1 is rejected" "want=1 got=$rc"; return; fi
  case "$out" in
    *"FAIL  $rule:"*|*"FAIL"*"$rule:"*) ok "$1 is rejected by rule '$rule'" "exit=1" ;;
    *) bad "$1 is rejected by rule '$rule'" "rejected, but not by '$rule'" ;;
  esac
}

# only_rule <fixture> <rule>: the single mutation fails exactly one rule.
only_rule() {
  f="$FIX/invalid/$1.html"
  n=$("$V" --page "$f" --quiet 2>&1 | grep -c 'FAIL  [a-z0-9-]*:' || true)
  if [ "${n:-0}" = "1" ]; then ok "$1 fails exactly one rule" "= 1"; else bad "$1 fails exactly one rule" "got ${n:-0}"; fi
}

# ---------------------------------------------------------------------------
# Scenario: The page uses the Luma theme in light and dark
# ---------------------------------------------------------------------------

section "The page uses the Luma theme in light and dark"

check "the valid fixture passes"                 0 "$V" --page "$FIX/valid/page.html"
expect_contains "all 32 light tokens are checked" "all 32 :root tokens match" "$V" --page "$FIX/valid/page.html"
expect_contains "all 31 dark tokens are checked"  "all 31 .dark tokens match" "$V" --page "$FIX/valid/page.html"
rejects tokens-light          tokens-light
rejects tokens-light-missing  tokens-light
rejects tokens-dark           tokens-dark
rejects tokens-dark-scoped    tokens-dark
check "a one-line token block still passes"      0 "$V" --page "$FIX/valid/page-compact-tokens.html"
expect_contains "a changed value is named"       "--primary: oklch(0.488 0.243 264.376)" "$V" --page "$FIX/invalid/tokens-light.html"
expect_contains "a slash-and-percent value is compared" "--border: oklch(1 0 0 / 10%)" "$V" --page "$FIX/invalid/tokens-dark.html"

# ---------------------------------------------------------------------------
# Scenario: The reader can switch between light and dark
# ---------------------------------------------------------------------------

section "The reader can switch between light and dark"

rejects toggle-no-button   toggle
rejects toggle-no-class    toggle
rejects toggle-no-storage  toggle
rejects toggle-no-system   toggle
expect_contains "the template sets the theme before first paint" 'document.documentElement.classList.toggle("dark", dark)' cat "$TEMPLATE"
expect_contains "the template stores the choice"  'localStorage.setItem("theme"' cat "$TEMPLATE"
expect_contains "the template reads the stored choice" 'localStorage.getItem("theme")' cat "$TEMPLATE"
expect_contains "the template follows the system" '(prefers-color-scheme: dark)' cat "$TEMPLATE"
expect_contains "the toggle is a labelled button" '<button id="theme-toggle" class="toggle" type="button" aria-label=' cat "$TEMPLATE"

# ---------------------------------------------------------------------------
# Scenario: The page opens with a table of contents
# ---------------------------------------------------------------------------

section "The page opens with a table of contents"

rejects toc-missing          toc
rejects toc-after-section    toc
rejects toc-unlinked-section toc
rejects toc-links-dangling   toc-links
expect_contains "an unlinked section is named"   "lists" "$V" --page "$FIX/invalid/toc-unlinked-section.html"
expect_contains "a dangling link is named"       "#nowhere" "$V" --page "$FIX/invalid/toc-links-dangling.html"
check "a comment mentioning <section> does not move the TOC" 0 "$V" --page "$FIX/valid/page-mentions-markup.html"

# ---------------------------------------------------------------------------
# Scenario: The page presents content through the supported components
# ---------------------------------------------------------------------------

section "The page presents content through the supported components"

check "the template passes (no sources)"         0 "$V" --page "$TEMPLATE" --no-sources
expect_contains "the template ships a table"     'data-component="table"' cat "$TEMPLATE"
expect_contains "the template ships a list"      'data-component="list"' cat "$TEMPLATE"
expect_contains "the template ships an SVG diagram with an overlay" 'data-component="svg-overlay"' cat "$TEMPLATE"
expect_contains "the overlay is a disclosure"    '<details class="overlay-toggle">' cat "$TEMPLATE"
expect_contains "the template ships an SVG ER diagram" 'data-component="svg-er"' cat "$TEMPLATE"
expect_contains "the ER diagram marks keys"      'class="svg-badge-pk"' cat "$TEMPLATE"
expect_contains "the template ships an SVG infrastructure diagram" 'data-component="svg-infra"' cat "$TEMPLATE"
expect_contains "the infrastructure diagram draws a boundary" 'class="svg-zone"' cat "$TEMPLATE"
rejects svg-a11y-no-role        svg-a11y
rejects svg-a11y-no-name        svg-a11y
rejects svg-a11y-dangling-label svg-a11y
# Components must draw from the palette, never from a literal colour.
literal=$(awk '/<style>/{s=1} /<\/style>/{s=0} s && /(#[0-9a-fA-F]{3,6}[;, )]|rgb\(|hsl\()/' "$TEMPLATE" | grep -c . || true)
if [ "${literal:-0}" = "0" ]; then ok "the template styles use tokens, never literal colours" "= 0"
else bad "the template styles use tokens, never literal colours" "found ${literal} literal(s)"; fi

# ---------------------------------------------------------------------------
# Scenario: The page is a self-contained single file
# ---------------------------------------------------------------------------

section "The page is a self-contained single file"

rejects self-contained-script            self-contained
rejects self-contained-uppercase         self-contained
rejects self-contained-link              self-contained
rejects self-contained-preconnect        self-contained
rejects self-contained-link-single-quote    self-contained
rejects self-contained-link-multi-token     self-contained
rejects self-contained-preload-single-quote self-contained
rejects self-contained-link-spaced-equals   self-contained
rejects self-contained-script-spaced-equals self-contained
rejects self-contained-slash-separator      self-contained
rejects self-contained-quoted-gt            self-contained
rejects self-contained-import            self-contained
rejects self-contained-url               self-contained
rejects self-contained-protocol-relative self-contained
rejects self-contained-font              self-contained
check "escaped or commented markup is not a resource" 0 "$V" --page "$FIX/valid/page-mentions-markup.html"
# The Content-Security-Policy is the browser-enforced guarantee behind the static rule.
expect_contains "the template opens <head> with the policy" "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:\">" cat "$TEMPLATE"
rejects csp-missing   csp
rejects csp-weakened  csp
rejects csp-late      csp
rejects csp-commented csp
# The policy tag must be read the way HTML reads it (review r4 F-6).
rejects csp-vt-in-meta        csp
rejects csp-vt-before-content csp
rejects csp-vt-in-html        csp
rejects csp-dotted-i-attr     csp
rejects csp-dotted-i-value    csp
rejects csp-nul-in-tag        csp
rejects csp-nul-in-attr       csp
rejects csp-nul-in-policy     csp
check "a dotted capital I is not folded under a UTF-8 locale" 1 env LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 "$V" --page "$FIX/invalid/csp-dotted-i-attr.html"
check "a vertical tab is not whitespace under a UTF-8 locale" 1 env LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 "$V" --page "$FIX/invalid/csp-vt-in-meta.html"
# Each review-r3 bypass evades the static rule; without the policy, csp rejects it.
for b in form-feed char-ref duplicate-rel comment-quirk script-body svg-script css-escape module-import create-element; do
  rejects "csp-bypass-$b" csp
done

# ---------------------------------------------------------------------------
# Scenario: The page cites the evidence behind its content
# ---------------------------------------------------------------------------

section "The page cites the evidence behind its content"

rejects sources-missing sources
rejects sources-empty   sources
check "--no-sources skips the rule for the template" 0 "$V" --page "$FIX/invalid/sources-missing.html" --no-sources
check "the example page passes with sources"     0 "$V" --page "$EXAMPLE"
expect_contains "the example page cites a command" '<code>' sh -c "awk '/id=\"sources\"/,/<\\/section>/' '$EXAMPLE'"

# ---------------------------------------------------------------------------
# Scenario: The validator rejects a non-conforming page
# ---------------------------------------------------------------------------

section "The validator rejects a non-conforming page"

# Every invalid fixture exits 1, and its single mutation fails exactly one rule.
n_invalid=0
for f in "$FIX"/invalid/*.html; do
  n_invalid=$((n_invalid + 1))
  only_rule "$(basename "$f" .html)"
done
check "the first failure on doctype names its rule" 1 "$V" --page "$FIX/invalid/doctype.html"
rejects doctype doctype
rejects lang    lang
check "a missing --page is a usage error"       2 "$V"
check "a missing file is a usage error"         2 "$V" --page "$FIX/does-not-exist.html"
check "an unknown option is a usage error"      2 "$V" --page "$FIX/valid/page.html" --bogus
check "--help exits 0"                          0 "$V" --help

# ---------------------------------------------------------------------------
# The skill
# ---------------------------------------------------------------------------

section "The generate-html-page skill"

check "the skill exists"                         0 test -f "$SKILL"
expect_contains "the skill names the template"   "scripts/templates/html-page.html" cat "$SKILL"
expect_contains "the skill validates its output" "scripts/validate-html-page.sh" cat "$SKILL"
expect_contains "the skill forbids invented figures" "Never invent a figure" cat "$SKILL"
expect_contains "the skill requires a sources section" 'section#sources' cat "$SKILL"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n=======================================================\n'
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\n  %sRESULT: PASS — the html page contract holds.%s\n' "$c_green" "$c_reset"
  exit 0
fi
printf '\n  %sRESULT: FAIL — the html page contract regressed.%s\n' "$c_red" "$c_reset"
exit 1
