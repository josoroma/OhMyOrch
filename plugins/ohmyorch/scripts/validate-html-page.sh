#!/usr/bin/env bash
#
# validate-html-page.sh — US-14.1: check a themed single-page HTML document
#
# A harness page is one self-contained HTML file in the shadcn Luma theme, light and
# dark, used to demo codebase status or explain the codebase and spec-driven
# development. This validator checks a page against that contract:
#
#   doctype          the file starts with <!doctype html>
#   lang             <html> carries a lang attribute
#   tokens-light     every Luma light token is defined in :root with its value
#   tokens-dark      every Luma dark token is defined in .dark with its value
#   toggle           a #theme-toggle exists; the script toggles the "dark" class,
#                    uses localStorage, and reads prefers-color-scheme
#   toc              a nav.toc precedes the first <section>, and every
#                    <section id> is linked from it
#   toc-links        every href="#…" resolves to an element id on the page
#   svg-a11y         every <svg> has role="img" with an accessible name, or
#                    aria-hidden="true"
#   self-contained   no external script, stylesheet, import, url(), or font
#   csp              the first element in <head> (after <meta charset>) is the
#                    Content-Security-Policy allowing only inline script and style
#                    and data: images, so the browser itself refuses any load
#   sources          a section#sources with at least one <li> or <code>
#                    (skipped with --no-sources, for the template)
#
# The expected tokens are embedded below: this script is the source of truth for the
# palette, and the template is checked against it (US-14.1 design.md Appendix A,
# under openspec/changes/archive/ once the change is archived).
#
# Limits: the token check confirms each expected token is declared in the :root and
# .dark rules; it does not detect a later rule that overrides one. The self-contained
# check is a static reading of <link>, <script>, and <style> bodies, and HTML and CSS
# have spellings it does not decode. The csp rule closes that gap: the browser, not
# this script, refuses every network load, including ones made by an inline script.
# @font-face is rejected outright, even with local() sources: pages use the system
# font stack.
#
# Usage:
#   validate-html-page.sh --page <file> [--no-sources] [--quiet]
#
# Exit codes: 0 pass, 1 a rule failed (each failure names its rule), 2 usage error.
#
# Dependencies: bash, awk, grep, tr — no Node/Python (NFR-001).

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

PAGE=""
QUIET=0
CHECK_SOURCES=1
FAILURES=0

c_reset=""; c_red=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ${c_green}PASS${c_reset}  $*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }

usage() {
  cat <<'EOF'
Usage: ohmyorch validate-html-page --page <file> [--no-sources] [--quiet]

Check a themed single-page HTML document against the harness page contract
(US-14.1): Luma light and dark tokens, theme toggle, table of contents and its
links, SVG accessibility, no external resources, and a sources section.

Options:
  --page <file>   The HTML page to check (required)
  --no-sources    Skip the sources rule (for the template, which has no evidence)
  --quiet         Print failures and the verdict only
  -h, --help      Show this help

Rules: doctype lang tokens-light tokens-dark toggle toc toc-links svg-a11y
       self-contained sources

Exit codes: 0 pass, 1 a rule failed, 2 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --page)       [ $# -ge 2 ] || { echo "error: --page needs a value" >&2; exit 2; }; PAGE="$2"; shift 2 ;;
    --no-sources) CHECK_SOURCES=0; shift ;;
    --quiet)      QUIET=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$PAGE" ] || { echo "error: --page is required" >&2; usage >&2; exit 2; }
[ -f "$PAGE" ] || { echo "error: page not found: $PAGE" >&2; exit 2; }

# ---------------------------------------------------------------------------
# The Luma palette (design.md Appendix A). One "name: value" per line, exactly as
# it must appear once whitespace is normalised. Values contain "/" and "%", so they
# are compared with grep -F and never passed through printf formats or sed s///.
# ---------------------------------------------------------------------------

LIGHT_TOKENS=$(cat <<'EOF'
--background: oklch(1 0 0)
--foreground: oklch(0.145 0 0)
--card: oklch(1 0 0)
--card-foreground: oklch(0.145 0 0)
--popover: oklch(1 0 0)
--popover-foreground: oklch(0.145 0 0)
--primary: oklch(0.488 0.243 264.376)
--primary-foreground: oklch(0.97 0.014 254.604)
--secondary: oklch(0.967 0.001 286.375)
--secondary-foreground: oklch(0.21 0.006 285.885)
--muted: oklch(0.97 0 0)
--muted-foreground: oklch(0.556 0 0)
--accent: oklch(0.97 0 0)
--accent-foreground: oklch(0.205 0 0)
--destructive: oklch(0.577 0.245 27.325)
--border: oklch(0.922 0 0)
--input: oklch(0.922 0 0)
--ring: oklch(0.708 0 0)
--chart-1: oklch(0.845 0.143 164.978)
--chart-2: oklch(0.696 0.17 162.48)
--chart-3: oklch(0.596 0.145 163.225)
--chart-4: oklch(0.508 0.118 165.612)
--chart-5: oklch(0.432 0.095 166.913)
--radius: 0.625rem
--sidebar: oklch(0.985 0 0)
--sidebar-foreground: oklch(0.145 0 0)
--sidebar-primary: oklch(0.546 0.245 262.881)
--sidebar-primary-foreground: oklch(0.97 0.014 254.604)
--sidebar-accent: oklch(0.97 0 0)
--sidebar-accent-foreground: oklch(0.205 0 0)
--sidebar-border: oklch(0.922 0 0)
--sidebar-ring: oklch(0.708 0 0)
EOF
)

DARK_TOKENS=$(cat <<'EOF'
--background: oklch(0.145 0 0)
--foreground: oklch(0.985 0 0)
--card: oklch(0.205 0 0)
--card-foreground: oklch(0.985 0 0)
--popover: oklch(0.205 0 0)
--popover-foreground: oklch(0.985 0 0)
--primary: oklch(0.424 0.199 265.638)
--primary-foreground: oklch(0.97 0.014 254.604)
--secondary: oklch(0.274 0.006 286.033)
--secondary-foreground: oklch(0.985 0 0)
--muted: oklch(0.269 0 0)
--muted-foreground: oklch(0.708 0 0)
--accent: oklch(0.269 0 0)
--accent-foreground: oklch(0.985 0 0)
--destructive: oklch(0.704 0.191 22.216)
--border: oklch(1 0 0 / 10%)
--input: oklch(1 0 0 / 15%)
--ring: oklch(0.556 0 0)
--chart-1: oklch(0.845 0.143 164.978)
--chart-2: oklch(0.696 0.17 162.48)
--chart-3: oklch(0.596 0.145 163.225)
--chart-4: oklch(0.508 0.118 165.612)
--chart-5: oklch(0.432 0.095 166.913)
--sidebar: oklch(0.205 0 0)
--sidebar-foreground: oklch(0.985 0 0)
--sidebar-primary: oklch(0.623 0.214 259.815)
--sidebar-primary-foreground: oklch(0.97 0.014 254.604)
--sidebar-accent: oklch(0.269 0 0)
--sidebar-accent-foreground: oklch(0.985 0 0)
--sidebar-border: oklch(1 0 0 / 10%)
--sidebar-ring: oklch(0.556 0 0)
EOF
)

# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

# The page on one line, with <!-- … --> comments removed: tags may span lines, and
# every tag search runs on this. A comment that mentions "<section" or "<script src"
# is documentation, not markup, and must not satisfy or fail a rule.
# NUL is mapped to \001 first: shell substitution, grep, and awk stop or drop at a NUL,
# so an unmapped NUL would hide everything after it from every rule (review r5 F-7).
FLAT=$(LC_ALL=C tr '\000\n\t\r' '\001   ' < "$PAGE" | awk '
  {
    s = $0; out = ""
    while ((i = index(s, "<!--")) > 0) {
      out = out substr(s, 1, i - 1)
      rest = substr(s, i + 4); e = index(rest, "-->")
      if (e == 0) { s = ""; break }
      s = substr(rest, e + 3)
    }
    print out s
  }')

# Every <style> body, flattened, with /* … */ comments removed. Comments are stripped
# before the CSS is split into rules: a "}" inside a comment would otherwise end a
# rule early and leave :root empty.
CSS=$(printf '%s' "$FLAT" | awk '
  {
    s = $0; out = ""
    while ((i = index(tolower(s), "<style")) > 0) {
      s = substr(s, i); j = index(s, ">"); if (j == 0) break
      s = substr(s, j + 1)
      k = index(tolower(s), "</style>"); if (k == 0) { out = out s; break }
      out = out substr(s, 1, k - 1) " "
      s = substr(s, k + 8)
    }
    while ((c = index(out, "/*")) > 0) {
      rest = substr(out, c + 2); e = index(rest, "*/")
      if (e == 0) { out = substr(out, 1, c - 1); break }
      out = substr(out, 1, c - 1) " " substr(rest, e + 2)
    }
    print out
  }')

# declarations <selector>: every "name: value" of the top-level rule whose selector
# is exactly <selector>. Matched with ==, never a regex, so ".dark .card" and rules
# inside @media do not match.
declarations() {
  printf '%s' "$CSS" | awk -v want="$1" '
    BEGIN { RS = "}" }
    {
      i = index($0, "{"); if (i == 0) next
      sel = substr($0, 1, i - 1); gsub(/^[ ]+|[ ]+$/, "", sel)
      # A rule nested in an at-rule carries the at-rule prefix: skip it.
      n = split(sel, parts, "{"); sel = parts[n]; gsub(/^[ ]+|[ ]+$/, "", sel)
      if (sel != want) next
      body = substr($0, i + 1)
      m = split(body, decl, ";")
      for (d = 1; d <= m; d++) {
        c = index(decl[d], ":"); if (c == 0) continue
        name = substr(decl[d], 1, c - 1); val = substr(decl[d], c + 1)
        gsub(/^[ ]+|[ ]+$/, "", name); gsub(/^[ ]+|[ ]+$/, "", val)
        gsub(/[ ]+/, " ", val)
        if (name ~ /^--/) print name ": " val
      }
    }'
}

# check_tokens <rule> <selector> <expected-list>
check_tokens() {
  local rule="$1" selector="$2" expected="$3" have missing=0 wrong="" line total
  have=$(declarations "$selector")
  total=$(printf '%s\n' "$expected" | grep -c . || true)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! printf '%s\n' "$have" | grep -xF -- "$line" >/dev/null; then
      missing=$((missing + 1))
      [ -n "$wrong" ] || wrong="$line"
    fi
  done <<EOF
$expected
EOF
  if [ "$missing" -eq 0 ]; then
    pass "$rule: all $total $selector tokens match the Luma palette"
  else
    fail "$rule: $missing of $total $selector tokens missing or changed (first: '$wrong')"
    note "fix: copy the $selector block from ${OHMYORCH_CODE_ROOT}/templates/html-page.html verbatim"
  fi
}

# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

# Predicate pipelines must consume all input. grep -q can close its pipe after a
# match and make the writer fail with SIGPIPE under pipefail, rejecting valid pages.

say "HTML page — $PAGE"

# doctype
if head -c 200 "$PAGE" | LC_ALL=C tr '\000A-Z' '\001a-z' | LC_ALL=C grep '^[[:space:]]*<!doctype html>' >/dev/null; then
  pass "doctype: starts with <!doctype html>"
else
  fail "doctype: the file does not start with <!doctype html>"
fi

# lang
if printf '%s' "$FLAT" | grep -iE '<html[^>]*[[:space:]]lang="[^"]+"' >/dev/null; then
  pass "lang: <html> declares a language"
else
  fail "lang: <html> has no lang attribute"
fi

# tokens
check_tokens "tokens-light" ":root" "$LIGHT_TOKENS"
check_tokens "tokens-dark" ".dark" "$DARK_TOKENS"

# toggle
SCRIPT=$(printf '%s' "$FLAT" | awk '
  {
    s = $0; out = ""
    while ((i = index(tolower(s), "<script")) > 0) {
      s = substr(s, i); j = index(s, ">"); if (j == 0) break
      s = substr(s, j + 1)
      k = index(tolower(s), "</script>"); if (k == 0) { out = out s; break }
      out = out substr(s, 1, k - 1) " "
      s = substr(s, k + 9)
    }
    print out
  }')
toggle_ok=1
if ! printf '%s' "$FLAT" | grep -E 'id="theme-toggle"' >/dev/null; then
  fail "toggle: no element with id=\"theme-toggle\""; toggle_ok=0
fi
# The call itself, not "classList" and "dark" anywhere in the script: a loose match
# passed a page whose toggle flipped a different class, because "dark" appears in
# other strings ("theme", "dark" ? … ).
if ! printf '%s' "$SCRIPT" | grep -E 'classList\.(toggle|add)\([[:space:]]*["'"'"']dark["'"'"']' >/dev/null; then
  fail "toggle: the script does not toggle the \"dark\" class"; toggle_ok=0
fi
case "$SCRIPT" in
  *localStorage*) ;;
  *) fail "toggle: the script does not persist the choice in localStorage"; toggle_ok=0 ;;
esac
case "$SCRIPT" in
  *prefers-color-scheme*) ;;
  *) fail "toggle: the script does not follow prefers-color-scheme"; toggle_ok=0 ;;
esac
[ "$toggle_ok" -eq 1 ] && pass "toggle: #theme-toggle flips the dark class, persists it, and follows the system"

# toc
toc_at=$(printf '%s' "$FLAT" | awk '{ print match($0, /<nav[^>]*class="[^"]*toc[^"]*"/) }')
sec_at=$(printf '%s' "$FLAT" | awk '{ print match($0, /<section[ >]/) }')
TOC=$(printf '%s' "$FLAT" | awk '
  {
    i = match($0, /<nav[^>]*class="[^"]*toc[^"]*"/); if (i == 0) exit
    s = substr($0, i); k = index(s, "</nav>"); if (k == 0) k = length(s)
    print substr(s, 1, k)
  }')
if [ "$toc_at" -eq 0 ]; then
  fail "toc: no <nav class=\"toc\"> on the page"
elif [ "$sec_at" -gt 0 ] && [ "$toc_at" -gt "$sec_at" ]; then
  fail "toc: the table of contents comes after the first <section>"
else
  unlinked=""
  for id in $(printf '%s' "$FLAT" | grep -oE '<section[^>]*[[:space:]]id="[^"]+"' | sed 's/.*id="//; s/"$//'); do
    case "$TOC" in
      *"href=\"#$id\""*) ;;
      *) unlinked="${unlinked:+$unlinked, }$id" ;;
    esac
  done
  if [ -n "$unlinked" ]; then
    fail "toc: section(s) not linked from the table of contents: $unlinked"
  else
    pass "toc: the table of contents precedes every section and links each one"
  fi
fi

# toc-links
IDS=$(printf '%s' "$FLAT" | grep -oE '[[:space:]]id="[^"]+"' | sed 's/.*id="//; s/"$//' | sort -u)
dangling=""
for target in $(printf '%s' "$FLAT" | grep -oE 'href="#[^"]*"' | sed 's/^href="#//; s/"$//' | sort -u); do
  [ -n "$target" ] || continue
  printf '%s\n' "$IDS" | grep -xF -- "$target" >/dev/null || dangling="${dangling:+$dangling, }#$target"
done
if [ -n "$dangling" ]; then
  fail "toc-links: link(s) to no element on the page: $dangling"
else
  pass "toc-links: every in-page link resolves"
fi

# svg-a11y
svg_total=0; svg_bad=""
while IFS= read -r tag; do
  [ -n "$tag" ] || continue
  svg_total=$((svg_total + 1))
  case "$tag" in
    *'aria-hidden="true"'*) continue ;;
  esac
  case "$tag" in
    *'role="img"'*) ;;
    *) svg_bad="${svg_bad:+$svg_bad; }svg #$svg_total has no role=\"img\""; continue ;;
  esac
  label=$(printf '%s' "$tag" | grep -oE 'aria-labelledby="[^"]+"' | sed 's/^aria-labelledby="//; s/"$//')
  if [ -n "$label" ]; then
    for ref in $label; do
      printf '%s\n' "$IDS" | grep -xF -- "$ref" >/dev/null \
        || svg_bad="${svg_bad:+$svg_bad; }svg #$svg_total names missing id '$ref'"
    done
  elif ! printf '%s' "$tag" | grep -E 'aria-label="[^"]+"' >/dev/null; then
    svg_bad="${svg_bad:+$svg_bad; }svg #$svg_total has no accessible name"
  fi
done <<EOF
$(printf '%s' "$FLAT" | grep -oiE '<svg[^>]*>')
EOF
if [ -n "$svg_bad" ]; then
  fail "svg-a11y: $svg_bad"
else
  pass "svg-a11y: all $svg_total SVG(s) are labelled or marked decorative"
fi

# self-contained. Checked on the markup outside text: an HTML-escaped mention such as
# "&lt;script src&gt;" is text, not a tag, and must not fail the page.
external=""
low=$(printf '%s' "$FLAT" | tr '[:upper:]' '[:lower:]')
# <script> and <link> tags are tokenized by HTML attribute rules rather than matched
# by regex: attributes are separated by whitespace or "/", "=" may have whitespace on
# either side, a value is double-quoted, single-quoted, or unquoted, and a quoted value
# may contain ">". rel is a whitespace-separated token list. Prints one finding per
# offending tag: "script-src", "stylesheet", or "preload".
tag_findings() {
  printf '%s' "$low" | awk '
    function ws(ch) { return ch == " " || ch == "\t" }
    {
      s = $0; n = length(s); i = 1
      while (i <= n && match(substr(s, i), /<(script|link)[ \t\/>]/)) {
        start = i + RSTART - 1
        tag = (substr(s, start + 1, 4) == "link") ? "link" : "script"
        j = start + 1 + length(tag)
        rel = ""; src = 0
        while (j <= n) {
          c = substr(s, j, 1)
          if (c == ">") break
          if (ws(c) || c == "/") { j++; continue }
          k = j
          while (k <= n) { c = substr(s, k, 1); if (ws(c) || c == "/" || c == ">" || c == "=") break; k++ }
          name = substr(s, j, k - j)
          if (name == "") { j++; continue }
          j = k
          m = j; while (m <= n && ws(substr(s, m, 1))) m++
          val = ""
          if (substr(s, m, 1) == "=") {
            j = m + 1; while (j <= n && ws(substr(s, j, 1))) j++
            q = substr(s, j, 1)
            if (q == "\"" || q == "\047") {
              e = index(substr(s, j + 1), q)
              if (e == 0) { val = substr(s, j + 1); j = n + 1 }
              else { val = substr(s, j + 1, e - 1); j = j + e + 1 }
            } else {
              k = j; while (k <= n) { c = substr(s, k, 1); if (ws(c) || c == ">") break; k++ }
              val = substr(s, j, k - j); j = k
            }
          }
          if (name == "src") src = 1
          if (name == "rel") rel = val
        }
        if (tag == "script" && src) print "script-src"
        if (tag == "link") {
          t = split(rel, tok, /[ \t]+/)
          for (x = 1; x <= t; x++) {
            if (tok[x] == "stylesheet") print "stylesheet"
            if (tok[x] ~ /^(preload|modulepreload|preconnect|dns-prefetch)$/) print "preload"
          }
        }
        i = j + 1
      }
    }'
}
findings=$(tag_findings)
printf '%s\n' "$findings" | grep -x 'script-src' >/dev/null && external="${external:+$external, }<script src>"
printf '%s\n' "$findings" | grep -x 'stylesheet' >/dev/null && external="${external:+$external, }<link rel=stylesheet>"
printf '%s\n' "$findings" | grep -x 'preload' >/dev/null && external="${external:+$external, }<link preload/preconnect>"
lowcss=$(printf '%s' "$CSS" | tr '[:upper:]' '[:lower:]')
printf '%s' "$lowcss" | grep -E '@import' >/dev/null && external="${external:+$external, }@import"
printf '%s' "$lowcss" | grep -E 'url\([[:space:]]*["'"'"']?(https?:)?//' >/dev/null && external="${external:+$external, }remote url()"
printf '%s' "$lowcss" | grep -E '@font-face' >/dev/null && external="${external:+$external, }@font-face"
if [ -n "$external" ]; then
  fail "self-contained: the page loads external resources: $external"
  note "fix: inline every style, script, and image; use the system font stack"
else
  pass "self-contained: no external script, stylesheet, import, url(), or font"
fi

# csp. The static checks above name the common ways a page loads a resource, but HTML
# and CSS have too many equivalent spellings (form feeds, character references,
# comment quirks, CSS escapes) and scripts can load code at run time. The guarantee is
# the browser's: a Content-Security-Policy that allows inline script and style, data:
# images, and nothing else. A policy applies only to what follows it, so it must be
# the first element in <head>, after an optional <meta charset>. The prefix is matched
# on the raw file (comments NOT stripped) against a fixed pattern.
#
# The match must read the bytes the way an HTML parser does (review r4 F-6):
#  - HTML whitespace is exactly tab, LF, FF, CR, and space. Vertical tab is NOT
#    whitespace, so it is never normalised: "<meta\vhttp-equiv" is not a <meta> tag.
#  - HTML lowercases ASCII letters only. Case is folded in the C locale, so "İ"
#    (U+0130) is never folded to "i" whatever the caller's locale.
#  - Every byte before the end of the policy tag must be printable ASCII or HTML
#    whitespace. A NUL, a control character, or a non-ASCII lookalike there fails the
#    rule, because a byte the pattern cannot see could change how the tag parses.
CSP_POLICY="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:"
csp_re="^ *(<!doctype html> *)?(<html( lang=\"[a-z0-9-]+\")?> *)?<head> *(<meta charset=\"utf-8\"> *)?<meta http-equiv=\"content-security-policy\" content=\"$CSP_POLICY\">"
csp_ok=0
# NUL becomes \001 before anything else reads the bytes, so the printable-ASCII check
# below sees it and fails the rule (review r5 F-7).
raw=$(head -c 4096 "$PAGE" | LC_ALL=C tr '\000\n\r\t\f' '\001    ' | LC_ALL=C tr 'A-Z' 'a-z')
if printf '%s' "$raw" | LC_ALL=C grep -E "$csp_re" >/dev/null; then
  # The bytes up to and including the policy tag: printable ASCII and space only
  # (HTML whitespace was already turned into spaces above).
  # The anchored pattern matched, so the first occurrence of the policy tag is the one
  # it matched: cut there, byte-wise, and inspect everything before it.
  head_part=$(printf '%s' "$raw" | LC_ALL=C awk -v tag="content=\"$CSP_POLICY\">" '
    { buf = buf $0 "\n" } END { i = index(buf, tag); if (i > 0) printf "%s", substr(buf, 1, i + length(tag) - 1) }')
  if [ -n "$head_part" ] && ! printf '%s' "$head_part" | LC_ALL=C tr -d '\n' | LC_ALL=C grep '[^ -~]' >/dev/null; then
    csp_ok=1
  fi
fi
if [ "$csp_ok" -eq 1 ]; then
  pass "csp: the first element in <head> is the self-contained Content-Security-Policy"
else
  fail "csp: <head> does not open with the self-contained Content-Security-Policy"
  note "fix: make the first element in <head> (after <meta charset=\"utf-8\">) exactly:"
  note "  <meta http-equiv=\"Content-Security-Policy\" content=\"$CSP_POLICY\">"
fi

# sources
if [ "$CHECK_SOURCES" -eq 1 ]; then
  SRC=$(printf '%s' "$FLAT" | awk '
    {
      i = match($0, /<section[^>]*[[:space:]]id="sources"/); if (i == 0) exit
      s = substr($0, i); k = index(s, "</section>"); if (k == 0) k = length(s)
      print substr(s, 1, k)
    }')
  if [ -z "$SRC" ]; then
    fail "sources: no <section id=\"sources\"> citing the evidence behind the page"
  else
    case "$SRC" in
      *"<li"*|*"<code"*) pass "sources: the page cites its evidence" ;;
      *) fail "sources: section#sources lists no file or command (<li> or <code>)" ;;
    esac
  fi
else
  say "  ${c_dim}--    sources: skipped (--no-sources)${c_reset}"
fi

say ""
if [ "$FAILURES" -eq 0 ]; then
  printf '  %sRESULT: PASS%s — the page satisfies the harness page contract.\n' "$c_green" "$c_reset"
  exit 0
fi
printf '  %sRESULT: FAIL%s — %s rule(s) failed.\n' "$c_red" "$c_reset" "$FAILURES"
exit 1
