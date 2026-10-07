#!/usr/bin/env node
// The Markdown guide is canonical; the public HTML and heading navigation are generated.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import MarkdownIt from 'markdown-it';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'docs/OhMyOrch.md');
const target = path.join(root, 'docs/OhMyOrch.html');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'plugins/ohmyorch/.claude-plugin/plugin.json'), 'utf8'));
const repository = manifest.repository.replace(/\/$/, '');
const md = new MarkdownIt({ html: false, linkify: false, typographer: false });
const escape = md.utils.escapeHtml;
const headings = [];
const ids = new Map();
const tokens = md.parse(fs.readFileSync(source, 'utf8'), {});
for (let i = 0; i < tokens.length; i++) {
  if (tokens[i].type !== 'heading_open') continue;
  const label = tokens[i + 1].content;
  const base = label.normalize('NFKD').toLowerCase().replace(/[^a-z0-9\s-]/g, '').trim().replace(/\s+/g, '-') || 'section';
  const count = (ids.get(base) ?? 0) + 1;
  ids.set(base, count);
  const id = count > 1 ? `${base}-${count}` : base;
  tokens[i].attrSet('id', id);
  if (tokens[i].tag === 'h2') headings.push({ id, label });
}

const originalLink = md.renderer.rules.link_open ?? ((t, i, o, e, self) => self.renderToken(t, i, o));
md.renderer.rules.link_open = (t, i, o, e, self) => {
  const href = t[i].attrGet('href');
  if (href && !/^(?:[a-z][a-z\d+.-]*:|\/\/|#)/i.test(href)) {
    // Pages publishes the guide/assets only. Repository source links belong on GitHub.
    const relative = path.posix.normalize(path.posix.join('docs', href));
    t[i].attrSet('href', `${repository}/blob/main/${relative}`);
  }
  return originalLink(t, i, o, e, self);
};
const originalImage = md.renderer.rules.image;
md.renderer.rules.image = (t, i, o, e, self) => {
  const isBrand = t[i].attrGet('src') === 'images/OhMyOrch.png';
  t[i].attrSet('class', isBrand ? 'brand-image' : 'diagram');
  t[i].attrSet('decoding', 'async');
  if (isBrand) {
    t[i].attrSet('width', '1448');
    t[i].attrSet('height', '1086');
    t[i].attrSet('fetchpriority', 'high');
  } else {
    t[i].attrSet('loading', 'lazy');
    const imageFile = path.resolve(path.dirname(source), t[i].attrGet('src'));
    const viewBox = fs.readFileSync(imageFile, 'utf8').match(/viewBox="0 0 (\d+) (\d+)"/);
    if (viewBox) {
      t[i].attrSet('width', viewBox[1]);
      t[i].attrSet('height', viewBox[2]);
    }
  }
  return originalImage(t, i, o, e, self);
};
md.renderer.rules.table_open = () => '<div class="table-scroll" role="region" aria-label="Reference table" tabindex="0"><table>\n';
md.renderer.rules.table_close = () => '</table></div>\n';

const body = md.renderer.render(tokens, md.options, {});
const toc = headings.map(({ id, label }) => `          <li><a href="#${id}">${escape(label)}</a></li>`).join('\n');
const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self'; style-src 'self'; script-src 'self'; base-uri 'none'; object-src 'none'">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <meta name="description" content="One READY story. Clear handoffs. Independent verdicts. Meet OhMyOrch's resumable Claude Code and OpenSpec delivery loop.">
  <meta name="theme-color" content="#ffffff">
  <title>OhMyOrch — a delivery loop you can follow</title>
  <link rel="icon" href="images/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="assets/guide.css">
  <script src="assets/guide.js" defer></script>
</head>
<body>
  <a class="skip-link" href="#guide">Skip to the guide</a>
  <header class="site-header">
    <a class="wordmark" href="#ohmyorch"><span class="loop-mark" aria-hidden="true">↻</span> OhMyOrch</a>
    <nav aria-label="Project links">
      <a href="${escape(repository)}">Source</a>
      <a href="${escape(repository)}/blob/main/docs/OhMyOrch.md">Markdown</a>
      <button class="theme-toggle" type="button" aria-label="Switch color theme">Theme</button>
    </nav>
  </header>
  <div class="layout">
    <aside class="contents">
      <details open>
        <summary>Explore the loop</summary>
        <nav aria-label="On this page"><ol>
${toc}
        </ol></nav>
      </details>
      <p class="candidate">${escape(manifest.version)}<br>Claude Code plugin</p>
    </aside>
    <main id="guide" tabindex="-1">
      <article>
${body}      </article>
      <footer class="site-footer">
        <p>Built from the Markdown guide. Your project keeps the evidence.</p>
        <a href="#ohmyorch">Back to the beginning ↑</a>
      </footer>
    </main>
  </div>
</body>
</html>
`;

if (process.argv.includes('--check')) {
  if (!fs.existsSync(target) || fs.readFileSync(target, 'utf8') !== html) {
    console.error('docs/OhMyOrch.html is stale. Run npm run docs:build and include the generated file.');
    process.exitCode = 1;
  } else console.log('Guide HTML matches docs/OhMyOrch.md.');
} else {
  fs.writeFileSync(target, html);
  console.log('Rendered docs/OhMyOrch.html from docs/OhMyOrch.md.');
}
