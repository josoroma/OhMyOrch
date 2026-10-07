import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { test } from 'node:test';

const page = fs.readFileSync(new URL('../SPECS-APP.hml', import.meta.url), 'utf8');
const sample = fs.readFileSync(new URL('../docs/SPECS-EXAMPLE/SPECS.md', import.meta.url), 'utf8');
const scripts = [...page.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
assert.equal(scripts.length, 4, 'embedded Markdown library, parser, source loader and application');
const context = vm.createContext({ atob, URL, TextEncoder });
scripts.forEach((script, index) => {
  new vm.Script(script[1], { filename: 'SPECS-APP-script-' + index });
  if (index < 3) vm.runInContext(script[1], context);
});
const parse = context.SpecsBacklog.parse;
const readSource = context.SpecsSources.read;
const sourceBase = 'https://workspace.test/repo/SPECS-APP.hml';
function sourceFetch(responses, calls) {
  return async (url, options) => {
    const pathname = new URL(url).pathname;
    calls.push({ pathname, options });
    assert.ok(responses[pathname], 'unexpected source request: ' + pathname);
    const [status, body = '', headers = {}] = responses[pathname];
    return new Response(body, { status, headers });
  };
}
const fence = String.fromCharCode(96).repeat(3);
const document = lines => lines.join('\n');

test('example hierarchy, status, tasks and scenarios remain coherent', () => {
  const model = parse(sample);
  assert.equal(model.title, 'PocketTasks');
  assert.equal(model.epics.length, 2);
  assert.equal(model.stories.length, 2);
  assert.equal(model.tasks.length, 4);
  assert.equal(model.warnings.length, 0);
  assert.deepEqual(Array.from(model.stories, story => story.status), ['READY', 'BLOCKED']);
  assert.deepEqual(Array.from(model.stories, story => story.scenarios), [10, 5]);
  assert.deepEqual(Array.from(model.stories[1].dependencies), ['US-1.1']);
  assert.equal(model.tasks[3].id, 'US-2.1#2');
  assert.equal(model.tasks[3].story.epic.id, 'EPIC-2');
  assert.equal(model.raw, sample);
  assert.ok(model.headings.some(heading => heading.title === 'Global Business Rules'));
});

test('headings, status and task text inside fences never become work items', () => {
  const model = parse(document([
    '# SPECS — Fences', '# EPIC-1: Real epic', '### US-1.1: Real story',
    'Status: READY', 'Tasks:', '- [ ] Actual work', fence + 'gherkin',
    '# EPIC-99: Fake epic', '### US-99.1: Fake story', 'Status: DONE',
    '- [x] Fake work', 'Scenario: Real acceptance text', 'Given a case', fence,
    'Open Questions:', '- None.',
  ]));
  assert.equal(model.epics.length, 1);
  assert.equal(model.stories.length, 1);
  assert.equal(model.tasks.length, 1);
  assert.equal(model.stories[0].status, 'READY');
  assert.equal(model.stories[0].scenarios, 1);
  assert.equal(model.tasks[0].title, 'Actual work');
  assert.match(model.raw, /Fake epic/);
});

test('source fields and checkboxes win over a conflicting index with visible notes', () => {
  const model = parse(document([
    '# SPECS — Conflict', '| ID | Status |', '|---|---|',
    '| US-1.1 | DONE |', '| US-1.1#1 | TODO |',
    '# EPIC-1: Epic', '### US-1.1: Story', 'Status: BLOCKED', 'Tasks:', '- [x] Finished task',
  ]));
  assert.equal(model.stories[0].status, 'BLOCKED');
  assert.equal(model.tasks[0].done, true);
  assert.equal(model.tasks[0].status, 'DONE');
  assert.ok(model.warnings.some(warning => warning.includes('Its body is used')));
  assert.ok(model.warnings.some(warning => warning.includes('Its checkbox is used')));
});

test('missing status, nonstandard status and undefined dependencies remain explicit', () => {
  const model = parse(document([
    '# SPECS — Incomplete', '| ID | Status |', '|---|---|',
    '| US-1.1 | IN PROGRESS |', '| US-9.1 | READY |',
    '# EPIC-1: Epic', '### US-1.1: Indexed story', 'Tasks:', '- [ ] First task',
    '### US-1.2: Unspecified story', 'Dependencies:', '- US-9.1 must finish.',
    '### US-1.3: Paused story', 'Status: paused',
  ]));
  assert.deepEqual(Array.from(model.stories, story => story.status), ['IN PROGRESS', 'UNSPECIFIED', 'PAUSED']);
  assert.ok(model.warnings.some(warning => warning.includes('status table value is used')));
  assert.ok(model.warnings.some(warning => warning.includes('US-9.1 is indexed')));
  assert.ok(model.warnings.some(warning => warning.includes('not defined')));
  assert.ok(model.warnings.some(warning => warning.includes('PAUSED')));
});

test('duplicate IDs and task titles stay visible with unique internal keys', () => {
  const model = parse(document([
    '# SPECS — Duplicates', '# EPIC-1: First', '### US-1.1: One', 'Status: READY',
    'Tasks:', '- [ ] **Same**', '- [X] **Same**', 'Open Questions:', '- None.',
    '# EPIC-1: Second', '### US-1.1: Two', 'Status: DONE', 'Tasks:', '- [x] Same',
  ]));
  assert.equal(model.epics.length, 2);
  assert.equal(model.stories.length, 2);
  assert.equal(model.tasks.length, 3);
  assert.equal(new Set(Array.from(model.tasks, task => task.key)).size, 3);
  assert.deepEqual(Array.from(model.tasks, task => task.title), ['Same', 'Same', 'Same']);
  assert.equal(model.warnings.filter(warning => warning.startsWith('Duplicate')).length, 2);
});

test('standalone stories use an explicit unassigned epic and Markdown headings work for fields', () => {
  const model = parse(document([
    '# SPECS — Standalone', '## us-5.1: One story', 'Status: READY',
    '#### Dependencies', '- us-5.2', '#### Tasks', '- [ ] Work with ' + String.fromCharCode(96) + 'code' + String.fromCharCode(96),
    '#### Open Questions', '- No invented next action.',
  ]));
  assert.equal(model.epics[0].id, 'UNASSIGNED');
  assert.equal(model.stories[0].id, 'US-5.1');
  assert.equal(model.tasks[0].title, 'Work with code');
  assert.deepEqual(Array.from(model.stories[0].dependencies), ['US-5.2']);
  assert.ok(model.warnings.some(warning => warning.includes('Unassigned')));
});

test('full source survives BOM, CRLF, diagrams, extra sections and HTML verbatim', () => {
  const source = '\uFEFF' + document([
    '# SPECS — Preserved', '## Context', '<img onerror="alert(1)" src="remote">',
    '## Repeated', 'Some context.', '## Repeated', 'More context.',
    fence + 'mermaid', 'flowchart TD', '  A --> B', fence,
  ]).replace(/\n/g, '\r\n');
  const model = parse(source);
  assert.equal(model.raw, source);
  assert.equal(model.text.startsWith('# SPECS'), true);
  assert.equal(model.text.includes('\r'), false);
  assert.deepEqual(Array.from(model.headings, heading => heading.slug), ['specs--preserved', 'context', 'repeated', 'repeated-1']);
  assert.equal(model.stories.length, 0);
});

test('default opens the root specification and forwards reload and cancellation options', async () => {
  const calls = [], controller = new AbortController();
  const source = await readSource(undefined, sourceBase, {
    fetch: sourceFetch({ '/repo/SPECS.md': [200, '# Project'] }, calls),
    signal: controller.signal,
  });
  assert.equal(source.path, 'SPECS.md');
  assert.equal(source.url, 'https://workspace.test/repo/SPECS.md');
  assert.equal(source.text, '# Project');
  assert.equal(source.fallback, false);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].options.cache, 'no-store');
  assert.equal(calls[0].options.signal, controller.signal);
});

test('missing root specification falls back to the example and records its own folder', async () => {
  for (const missing of [404, 410]) {
    const calls = [];
    const source = await readSource('SPECS.md', sourceBase, {
      fetch: sourceFetch({
        '/repo/SPECS.md': [missing],
        '/repo/docs/SPECS-EXAMPLE/SPECS.md': [200, sample],
      }, calls),
    });
    assert.deepEqual(calls.map(call => call.pathname), ['/repo/SPECS.md', '/repo/docs/SPECS-EXAMPLE/SPECS.md']);
    assert.equal(source.path, 'docs/SPECS-EXAMPLE/SPECS.md');
    assert.equal(source.url, 'https://workspace.test/repo/docs/SPECS-EXAMPLE/SPECS.md');
    assert.equal(source.fallback, true);
    assert.equal(source.text, sample);
  }
});

test('explicit example selection never probes the root specification', async () => {
  const calls = [];
  const source = await readSource('docs/SPECS-EXAMPLE/SPECS.md', sourceBase, {
    fetch: sourceFetch({ '/repo/docs/SPECS-EXAMPLE/SPECS.md': [200, sample] }, calls),
  });
  assert.equal(calls.length, 1);
  assert.equal(source.fallback, false);
  assert.equal(source.text, sample);
});

test('an existing empty root document stays selected', async () => {
  const calls = [];
  const source = await readSource('SPECS.md', sourceBase, {
    fetch: sourceFetch({ '/repo/SPECS.md': [200] }, calls),
  });
  assert.equal(calls.length, 1);
  assert.equal(source.path, 'SPECS.md');
  assert.equal(source.text, '');
  assert.equal(source.fallback, false);
});

test('permission and server failures never silently substitute the example', async () => {
  for (const status of [403, 500]) {
    const calls = [];
    await assert.rejects(readSource('SPECS.md', sourceBase, {
      fetch: sourceFetch({ '/repo/SPECS.md': [status] }, calls),
    }), new RegExp('SPECS.md.*HTTP ' + status));
    assert.equal(calls.length, 1);
  }
});

test('missing example reports a recoverable failure without further requests', async () => {
  const calls = [];
  await assert.rejects(readSource('SPECS.md', sourceBase, {
    fetch: sourceFetch({
      '/repo/SPECS.md': [404],
      '/repo/docs/SPECS-EXAMPLE/SPECS.md': [404],
    }, calls),
  }), /docs\/SPECS-EXAMPLE\/SPECS.md.*HTTP 404/);
  assert.equal(calls.length, 2);
});

test('size limits and invalid source choices fail without triggering fallback', async () => {
  for (const response of [
    [200, 'Small body', { 'content-length': String(context.SpecsSources.maxBytes + 1) }],
    [200, 'x'.repeat(context.SpecsSources.maxBytes + 1)],
  ]) {
    const calls = [];
    await assert.rejects(readSource('SPECS.md', sourceBase, {
      fetch: sourceFetch({ '/repo/SPECS.md': response }, calls),
    }), /larger than 5 MB/);
    assert.equal(calls.length, 1);
  }
  const calls = [];
  await assert.rejects(readSource('../private.md', sourceBase, { fetch: sourceFetch({}, calls) }), /Choose the project or example/);
  assert.equal(calls.length, 0);
});

test('an interrupted request propagates cancellation instead of fetching the example', async () => {
  let requests = 0;
  await assert.rejects(readSource('SPECS.md', sourceBase, {
    fetch: async () => { requests++; throw new DOMException('Cancelled', 'AbortError'); },
  }), { name: 'AbortError' });
  assert.equal(requests, 1);
});
