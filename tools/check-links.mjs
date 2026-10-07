#!/usr/bin/env node
// Validate durable local documentation references without network-dependent CI.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import MarkdownIt from 'markdown-it';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const md = new MarkdownIt({ html: true, linkify: true });
const ignoredDirectories = new Set([
  '.git', 'node_modules', 'dist', 'build', 'coverage', '__pycache__',
  '.pages-artifact', '.cache', '.venv', 'venv', '.claude',
]);
const ignoredPaths = new Set(['tests/fixtures', 'docs/resets', 'docs/pre-install-backup']);
function documentationFiles(directory = '') {
  const result = [];
  for (const entry of fs.readdirSync(path.join(root, directory), { withFileTypes: true })) {
    const relative = path.posix.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name) && !ignoredPaths.has(relative)) result.push(...documentationFiles(relative));
    } else if (entry.isFile() && /\.(?:md|html|hml|svg)$/.test(entry.name)) {
      result.push(relative);
    }
  }
  return result.sort();
}
const files = documentationFiles();
const errors = [];
const fragmentCache = new Map();
let references = 0;

function markupOnly(source) {
  // Inline code can contain HTML strings that are not document references.
  // Keep opening tags so actual script src attributes are still checked.
  return source.replace(/<!--[\s\S]*?-->/g, '')
    .replace(/(<(?:script|style)\b[^>]*>)[\s\S]*?<\/(?:script|style)\s*>/gi, '$1');
}

function fragments(target) {
  if (fragmentCache.has(target)) return fragmentCache.get(target);
  const source = fs.readFileSync(target, 'utf8');
  const ids = new Set();
  for (const match of markupOnly(source).matchAll(/\b(?:id|name)\s*=\s*(["'])(.*?)\1/gi)) ids.add(match[2]);
  if (target.endsWith('.md')) {
    const tokens = md.parse(source, {});
    const duplicates = new Map();
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i].type !== 'heading_open') continue;
      const inline = tokens[i + 1];
      const text = (inline.children ?? []).filter(token => ['text', 'code_inline'].includes(token.type)).map(token => token.content).join('');
      // GitHub heading IDs preserve consecutive spaces as consecutive hyphens.
      const base = text.toLowerCase().replace(/[^\p{L}\p{N}_\-\s]/gu, '').replace(/\s/g, '-');
      const count = duplicates.get(base) ?? 0;
      duplicates.set(base, count + 1);
      ids.add(count ? `${base}-${count}` : base);
    }
  }
  fragmentCache.set(target, ids);
  return ids;
}

function check(file, url) {
  if (!url || url.includes('${') || url.includes('{{')) return;
  let local = url;
  const github = url.match(/^https:\/\/github\.com\/josoroma\/OhMyOrch\/(?:blob|tree)\/main\/(.+)$/);
  if (github) local = github[1];
  else if (/^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(url)) return;
  const hash = local.indexOf('#');
  const rawPath = (hash < 0 ? local : local.slice(0, hash)).split('?')[0];
  const anchor = hash < 0 ? '' : decodeURIComponent(local.slice(hash + 1));
  const target = rawPath
    ? path.resolve(github ? root : path.dirname(path.join(root, file)), decodeURIComponent(rawPath))
    : path.join(root, file);
  references++;
  if (!fs.existsSync(target)) {
    errors.push(`${file}: ${url} — target does not exist`);
    return;
  }
  if (anchor && fs.statSync(target).isFile() && /\.(?:md|html|hml|svg)$/.test(target) && !fragments(target).has(anchor)) {
    errors.push(`${file}: ${url} — fragment does not exist`);
  }
}

function inspectHtml(file, source) {
  for (const match of markupOnly(source).matchAll(/\b(?:href|src)\s*=\s*(["'])(.*?)\1/gi)) check(file, match[2]);
}

function inspectTokens(file, tokens) {
  for (const token of tokens) {
    if (token.type === 'link_open') check(file, token.attrGet('href'));
    if (token.type === 'image') check(file, token.attrGet('src'));
    if (['html_inline', 'html_block'].includes(token.type)) inspectHtml(file, token.content);
    if (token.children) inspectTokens(file, token.children);
  }
}

for (const file of files) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  if (file.endsWith('.md')) inspectTokens(file, md.parse(source, {}));
  else inspectHtml(file, source);
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`PASS: ${references} local links/assets/fragments in ${files.length} documentation files; historical inventories and invalid fixtures remain separate`);
}
