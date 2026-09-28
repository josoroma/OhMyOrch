#!/usr/bin/env python3
"""Regenerate the html-page fixtures from scripts/templates/html-page.html (US-14.1).

A development-time helper, like check-frontmatter.js: the harness itself never runs
it, and scripts/test-html-page.sh reads the committed fixtures. Each invalid fixture
is the valid page with exactly ONE mutation, so a failing fixture names exactly one
rule and a passing validator cannot hide behind a second defect.

Usage: python3 scripts/fixtures/html-pages/make-fixtures.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TEMPLATE = os.path.join(ROOT, "scripts", "templates", "html-page.html")

base = open(TEMPLATE, encoding="utf-8").read()


def once(text, old, new):
    """Replace exactly one occurrence, or fail loudly: a silent no-op would produce a
    fixture identical to the valid page, and its test would pass for the wrong reason."""
    if text.count(old) < 1:
        sys.exit(f"make-fixtures: pattern not found: {old[:60]!r}")
    return text.replace(old, new, 1)


# The valid page: the template with its placeholders filled.
valid = re.sub(r"\{\{[A-Z0-9_]+\}\}", "sample", base)

TOGGLE_JS = 'document.documentElement.classList.toggle("dark", dark);'

CSP_META = ('<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; '
            'script-src \'unsafe-inline\'; style-src \'unsafe-inline\'; img-src data:">\n')


def no_csp(p):
    return once(p, CSP_META, "")


def bypass(p, snippet):
    """The page without its policy, plus markup that loads a resource."""
    return once(no_csp(p), "</head>", snippet + "\n</head>")

mutations = {
    # structure
    "doctype": lambda p: once(p, "<!doctype html>", ""),
    "lang": lambda p: once(p, '<html lang="en">', "<html>"),
    # tokens
    "tokens-light": lambda p: once(p, "  --primary: oklch(0.488 0.243 264.376);", "  --primary: oklch(0.5 0.2 20);"),
    "tokens-light-missing": lambda p: once(p, "  --radius: 0.625rem;\n", ""),
    "tokens-dark": lambda p: once(p, "  --border: oklch(1 0 0 / 10%);\n  --input: oklch(1 0 0 / 15%);",
                                  "  --border: oklch(1 0 0 / 20%);\n  --input: oklch(1 0 0 / 15%);"),
    # The dark tokens moved under a descendant selector: ".dark" alone no longer has them.
    "tokens-dark-scoped": lambda p: once(p, "\n.dark {\n  --background: oklch(0.145 0 0);",
                                         "\n.dark body {\n  --background: oklch(0.145 0 0);"),
    # toggle
    "toggle-no-button": lambda p: once(p, 'id="theme-toggle"', 'id="theme-switch"'),
    "toggle-no-class": lambda p: p.replace('classList.toggle("dark"', 'classList.toggle("night"'),
    "toggle-no-storage": lambda p: p.replace("localStorage", "sessionStore"),
    "toggle-no-system": lambda p: p.replace("prefers-color-scheme", "prefers-contrast"),
    # table of contents
    "toc-missing": lambda p: once(p, '<nav class="toc"', '<nav class="index"'),
    "toc-after-section": lambda p: once(
        once(p, '  <nav class="toc" aria-labelledby="toc-title">', '  <!--TOC-->'),
        "  <!-- ===== Required when",
        '  <nav class="toc" aria-labelledby="toc-title"><p class="toc-title" id="toc-title2">x</p>'
        '<ol><li><a href="#overview">o</a></li></ol></nav>\n  <!-- ===== Required when'),
    "toc-unlinked-section": lambda p: once(p, '      <li><a href="#lists">Lists</a></li>\n', ""),
    "toc-links-dangling": lambda p: once(p, '<li><a href="#table">Table</a></li>',
                                         '<li><a href="#table">Table</a></li><li><a href="#nowhere">Missing</a></li>'),
    # SVG accessibility
    "svg-a11y-no-role": lambda p: once(p, 'viewBox="0 0 720 180" role="img"', 'viewBox="0 0 720 180"'),
    "svg-a11y-no-name": lambda p: once(p, 'role="img" aria-labelledby="er-title er-desc"', 'role="img"'),
    "svg-a11y-dangling-label": lambda p: once(p, 'aria-labelledby="infra-title infra-desc"',
                                              'aria-labelledby="infra-title infra-missing"'),
    # self-contained
    "self-contained-script": lambda p: once(p, "</head>", '<script src="https://cdn.example.com/app.js"></script>\n</head>'),
    "self-contained-link": lambda p: once(p, "</head>", '<link rel="stylesheet" href="https://cdn.example.com/x.css">\n</head>'),
    "self-contained-import": lambda p: once(p, "/* ---- Base", '@import "https://cdn.example.com/x.css";\n/* ---- Base'),
    "self-contained-url": lambda p: once(p, "/* ---- Base", ".hero { background: url(https://cdn.example.com/bg.png); }\n/* ---- Base"),
    "self-contained-font": lambda p: once(p, "/* ---- Base", '@font-face { font-family: X; src: url("x.woff2"); }\n/* ---- Base'),
    "self-contained-protocol-relative": lambda p: once(p, "/* ---- Base", ".hero { background: url(//cdn.example.com/bg.png); }\n/* ---- Base"),
    "self-contained-uppercase": lambda p: once(p, "</head>", '<SCRIPT SRC="https://cdn.example.com/app.js"></SCRIPT>\n</head>'),
    "self-contained-preconnect": lambda p: once(p, "</head>", '<link rel="preconnect" href="https://fonts.example.com">\n</head>'),
    "self-contained-link-single-quote": lambda p: once(p, "</head>", "<link rel='stylesheet' href='https://cdn.example.com/x.css'>\n</head>"),
    "self-contained-link-multi-token": lambda p: once(p, "</head>", '<link rel="alternate stylesheet" href="https://cdn.example.com/x.css">\n</head>'),
    "self-contained-preload-single-quote": lambda p: once(p, "</head>", "<link rel='preload' as='font' href='https://fonts.example.com/x.woff2'>\n</head>"),
    "self-contained-link-spaced-equals": lambda p: once(p, "</head>", '<link rel = "stylesheet" href="https://cdn.example.com/x.css">\n</head>'),
    "self-contained-script-spaced-equals": lambda p: once(p, "</head>", '<script type="module" src = "https://cdn.example.com/app.js"></script>\n</head>'),
    "self-contained-slash-separator": lambda p: once(p, "</head>", '<link/rel="stylesheet"/href="https://cdn.example.com/x.css">\n</head>'),
    "self-contained-quoted-gt": lambda p: once(p, "</head>", '<link title="a>b" rel="stylesheet" href="https://cdn.example.com/x.css">\n</head>'),
    # csp: the policy itself is missing, weakened, late, or only commented
    "csp-missing": lambda p: no_csp(p),
    "csp-weakened": lambda p: once(p, "default-src 'none';", "default-src *;"),
    "csp-late": lambda p: once(no_csp(p), "</title>", "</title>\n" + CSP_META),
    "csp-commented": lambda p: once(p, CSP_META, "<!-- " + CSP_META + " -->"),
    # csp: each review-r3 bypass (F-4 a–g, F-5) evades the static self-contained rule,
    # so with the policy removed only the csp rule catches it.
    "csp-bypass-form-feed": lambda p: bypass(p, "<link\frel=stylesheet href=https://cdn.example.com/x.css>"),
    "csp-bypass-char-ref": lambda p: bypass(p, '<link rel="style&#115;heet" href="https://cdn.example.com/x.css">'),
    "csp-bypass-duplicate-rel": lambda p: bypass(p, '<link rel="stylesheet" rel="icon" href="https://cdn.example.com/x.css">'),
    "csp-bypass-comment-quirk": lambda p: bypass(p, '<!--> <link rel="stylesheet" href="https://cdn.example.com/x.css"> -->'),
    "csp-bypass-script-body": lambda p: bypass(p, "<script>var s = \"<link title='\";</script>\n"
                                                  '<link rel="stylesheet" href="https://cdn.example.com/x.css">'),
    "csp-bypass-svg-script": lambda p: bypass(p, '<svg aria-hidden="true"><script href="https://cdn.example.com/app.js"></script></svg>'),
    # @import only loads as the first rule of a stylesheet (review r4 O-37).
    "csp-bypass-css-escape": lambda p: once(no_csp(p), "</head>", '<style>@\\69mport "https://cdn.example.com/x.css";</style>\n</head>'),
    # the policy tag spelled so a regex that normalises differently from HTML accepts it
    # (review r4 F-6): vertical tab is not HTML whitespace; HTML folds ASCII case only.
    "csp-vt-in-meta": lambda p: once(p, "<meta http-equiv", "<meta\vhttp-equiv"),
    "csp-vt-before-content": lambda p: once(p, 'Policy" content=', 'Policy"\vcontent='),
    "csp-vt-in-html": lambda p: once(p, '<html lang="en">', '<html\vlang="en">'),
    "csp-dotted-i-attr": lambda p: once(p, 'http-equiv="Content', 'http-equ\u0130v="Content'),
    "csp-dotted-i-value": lambda p: once(p, 'Content-Security-Policy"', 'Content-Security-Pol\u0130cy"'),
    # a NUL in the policy tag: the browser ignores the policy (review r5 F-7)
    "csp-nul-in-tag": lambda p: once(p, "<meta http-equiv", "<me\x00ta http-equiv"),
    "csp-nul-in-attr": lambda p: once(p, 'http-equiv="Content', 'http-eq\x00uiv="Content'),
    "csp-nul-in-policy": lambda p: once(p, "default-src 'none';", "default-src 'no\x00ne';"),
    "csp-bypass-module-import": lambda p: bypass(p, '<script type="module">import "https://cdn.example.com/app.js";</script>'),
    "csp-bypass-create-element": lambda p: bypass(p, '<script>var s = document.createElement("script"); '
                                                     's.src = "https://cdn.example.com/app.js"; document.head.appendChild(s);</script>'),
    # sources
    "sources-missing": lambda p: once(p, '<section id="sources" data-component="sources">', '<section id="references" data-component="sources">')
                                 .replace('href="#sources"', 'href="#references"'),
    "sources-empty": lambda p: re.sub(r'(<section id="sources"[^>]*>).*?(</section>)',
                                      r'\1<h2>Sources</h2><p>None listed.</p>\2', p, count=1, flags=re.S),
}

# Pages that MUST pass: guards against false positives.
passing = {
    "page": valid,
    # Mentioning a script tag in escaped text, in a code sample, and in a comment is
    # documentation, not markup.
    "page-mentions-markup": once(valid, "<p class=\"section-lead\">Headline figures.",
                                 "<p class=\"section-lead\">Never add <code>&lt;script src=\"https://x\"&gt;</code> "
                                 "or <code>@import</code>. <!-- <section id=\"x\"> <script src=\"https://x\"> --> Headline figures."),
    # The dark token block written on one line, with extra spaces.
    "page-compact-tokens": re.sub(r"\.dark \{(.*?)\}",
                                  lambda m: ".dark {" + " ".join(m.group(1).split()) + "}",
                                  valid, count=1, flags=re.S),
}

os.makedirs(os.path.join(HERE, "valid"), exist_ok=True)
os.makedirs(os.path.join(HERE, "invalid"), exist_ok=True)

for name, page in passing.items():
    with open(os.path.join(HERE, "valid", f"{name}.html"), "w", encoding="utf-8") as f:
        f.write(page)

for name, mutate in mutations.items():
    page = mutate(valid)
    if page == valid:
        sys.exit(f"make-fixtures: mutation '{name}' changed nothing")
    with open(os.path.join(HERE, "invalid", f"{name}.html"), "w", encoding="utf-8") as f:
        f.write(page)

print(f"wrote {len(passing)} valid and {len(mutations)} invalid fixtures")
