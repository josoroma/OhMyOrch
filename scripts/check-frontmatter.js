#!/usr/bin/env node
// check-frontmatter.js — validate every harness agent and skill definition.
//
// A file whose frontmatter is missing, unparseable, or lacks `name` is silently
// skipped by Claude Code, so this is a real check rather than a formality.
//
// Exit codes: 0 all valid, 1 at least one invalid.

const fs = require('fs');
const path = require('path');
const YAML = require(
  '/Users/josoroma/.nvm/versions/node/v22.23.2/lib/node_modules/@fission-ai/openspec/node_modules/yaml'
);

function fm(file) {
  const text = fs.readFileSync(file, 'utf8');
  if (!text.startsWith('---\n')) return null;
  const end = text.indexOf('\n---', 3);
  if (end === -1) return null;
  return YAML.parse(text.slice(3, end));
}

let bad = 0;

const agentsDir = '.claude/agents';
for (const f of fs.readdirSync(agentsDir).sort()) {
  if (!f.endsWith('.md') || f === 'README.md') continue;
  const file = path.join(agentsDir, f);
  try {
    const d = fm(file);
    const ok = d && d.name && d.description;
    console.log(`${ok ? 'OK  ' : 'FAIL'}  agent  ${f.padEnd(24)} ${d?.name ?? ''}${d?.hooks ? '  [hook]' : ''}`);
    if (!ok) bad++;
  } catch (e) {
    console.log(`FAIL  agent  ${f} -> ${e.message}`);
    bad++;
  }
}

const skillsDir = '.claude/skills';
for (const d2 of fs.readdirSync(skillsDir).sort()) {
  const file = path.join(skillsDir, d2, 'SKILL.md');
  if (!fs.existsSync(file)) continue;
  try {
    const d = fm(file);
    const ok = d && d.name;
    console.log(`${ok ? 'OK  ' : 'FAIL'}  skill  ${d2.padEnd(24)} ${d?.name ?? ''}`);
    if (!ok) bad++;
  } catch (e) {
    console.log(`FAIL  skill  ${d2} -> ${e.message}`);
    bad++;
  }
}

console.log('');
console.log(bad ? `RESULT: FAIL — ${bad} invalid definition(s).` : 'RESULT: PASS — all definitions valid.');
process.exit(bad ? 1 : 0);
