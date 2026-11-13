"""Integration tests for installed-code/project-data separation and recovery.
Python is a maintainer test dependency, never a plugin runtime dependency.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent
PLUGIN = Path(os.environ.get('OHMYORCH_TEST_PLUGIN_ROOT', REPO / 'plugins/ohmyorch'))
CLI = PLUGIN / 'bin/ohmyorch'
CONFIG = {'schemaVersion': 1, 'enabled': True,
          'documents': {'prd': 'PRD.md', 'specs': 'SPECS.md', 'codebase': 'CODEBASE.md'},
          'openspec': {'root': 'openspec', 'schema': 'spec-driven'},
          'output': {'pages': 'docs/pages', 'epicLogs': 'SPEC-LOGS'},
          'delivery': {'maxStalls': 3},
          'fastValidation': {'enabled': False, 'script': 'scripts/fast-validate.sh'}}
# The whole CLI surface: one script per operation, nothing else.
OPERATIONS = ['doctor', 'bootstrap', 'adapt-project', 'upgrade-project', 'migrate-legacy', 'harness-reset',
              'delivery', 'validate-product-artifacts', 'validate-html-page', 'guard-context-preflight',
              'guard-story-done', 'guard-archive', 'guard-delivery-loop', 'run-project-validation']
RETIRED = ['workflow-status', 'status', 'completion-gate', 'validate-implementation-plan', 'validate-review',
           'validate-test-report', 'validate-status', 'validate-verification', 'check-write-scope',
           'check-scope', 'guard-planning-handoff']
# Scripts every hook needs; doctor reports exactly these as bundled-*.
HOOK_SCRIPTS = ['validate-product-artifacts', 'delivery', 'guard-archive', 'guard-story-done',
                'guard-context-preflight', 'guard-delivery-loop']
# Files an earlier plugin version wrote into a change. They are project history now.
LEFTOVERS = {'review.md': '# Review\n\nVerdict: fail\n\nBlocking:\n- F-1: unresolved finding\n\nOpenSpec verify: MISMATCH\n',
             'test-report.md': '# Test Report\n\nVerdict: fail\n\n| 1 | criterion | FAIL |\n',
             'status.md': '# Status\n\n| State | REVIEWING |\n\nFirst incomplete gate: review\n',
             'completion.md': '# Completion\n\n| Verdict | not-eligible |\n',
             'implementation-plan.md': '# Implementation Plan\n\n## Predicted files\n\n- src/app.ts\n',
             'history/review-r1.md': '# Review round 1\n\nVerdict: fail\n'}
SESSION_CONTEXT = ('OhMyOrch activated. Each SPECS story is delivered as one OpenSpec change: propose, apply, verify, '
                   'archive. Document mapping: PRD={prd}, SPECS={specs}, CODEBASE={codebase}. Derive the next action '
                   'from artifacts; archive before DONE. Never write installed plugin code or silently initialize a project.')
# Managed guidance text: what 0.0.1 wrote into consumer projects, and what replaces it.
PREVIOUS_GUIDANCE = ('Delegate implementation, review and testing independently. Specialists persist\n'
                     'their own verdicts; the main session derives resumption from project artifacts.\n')
CURRENT_GUIDANCE = ('Each READY story is one OpenSpec change: propose, apply, verify, archive.\n'
                    'The next action is derived from project artifacts, never from chat memory.\n')
PREVIOUS_RULE = ('One story/change at a time. Derive the next action from gates. Planner returns the handoff; '
                 'implementer edits product code; reviewer/tester write only their selected verdict. Archive before DONE.')
CURRENT_RULE = ("One story/change at a time. Each change follows OpenSpec: propose, apply, verify, archive. "
                "Derive the next action from the change's artifacts and tasks. Archive before DONE.")
READ_ONLY = 'BLOCKED [{role}] {file} — read-only role returns authored content to the coordinator\n'
SUBAGENT_DENIED = 'OhMyOrch: unknown subagent cannot write PM state\n'
LEASE_DENIED = 'OhMyOrch: another session owns PM state\n'
ARCHIVE_BLOCK = ('BLOCKED  archive {id}\n'
                 '  {progress} tasks complete in openspec/changes/{id}/tasks.md.\n'
                 '  Finish the remaining tasks (/ohmyorch:opsx-apply {id}) or remove tasks that no longer apply, then archive.\n')
DONE_BLOCK = ('BLOCKED  {specs} — {story} to DONE\n'
              '  Change {id} is still active (openspec/changes/{id}).\n'
              '  Archive it first (openspec archive {id} -y), then set the story to DONE.\n')
ARCHIVE_FORM = 'OhMyOrch: unsupported archive shell form; run it alone as: openspec archive <change-id> -y\n'
MISSING_SCRIPT = 'OhMyOrch: missing bundled validator: {name}\n'
# The context line 0.0.1 scaffolded into openspec/config.yaml, and its replacement.
PREVIOUS_CONTEXT = 'OhMyOrch handles independent planning, implementation, review and testing.'
CURRENT_CONTEXT = 'Each READY story is delivered as one OpenSpec change: propose, apply, verify, archive.'
STOP_BLOCK = ('Delivery goal {target} is ACTIVE — do not stop yet.\n'
              'Next action: {action}  (story: {story}, change: {change})\n'
              'Command: {command}\n'
              'Reason: {reason}\n'
              'Do it in this session, then run ohmyorch delivery next again. Unchanged stop attempts: {n} of {max} allowed.\n')

class Integration(unittest.TestCase):
    maxDiff = None

    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix='ohmyorch-tests-')
        self.root = Path(self.work.name) / 'host with $literal and "quote"'
        self.root.mkdir()
        self.config = json.loads(json.dumps(CONFIG))

    def tearDown(self):
        self.work.cleanup()

    def run_cli(self, *args, code=0, env=None, plugin=PLUGIN):
        result = subprocess.run([str(plugin / 'bin/ohmyorch'), '--project-root', str(self.root), *args],
                                text=True, capture_output=True, env={**os.environ, **(env or {})})
        self.assertEqual(code, result.returncode, result.stdout + result.stderr)
        return result

    def activate(self, docs='root'):
        d = self.root / '.claude/ohmyorch'
        d.mkdir(parents=True, exist_ok=True)
        documents = dict(CONFIG['documents'])
        if docs == 'mixed':
            documents['specs'] = 'docs/SPECS.md'
        elif docs == 'docs':
            documents = {k: 'docs/' + v for k,v in documents.items()}
        self.config['documents'] = documents
        (d / 'project.json').write_text(json.dumps(self.config))
        for key, path in self.config['documents'].items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(REPO / 'tests/fixtures/valid' / Path(path).name, target)
        return d

    def change(self, passing=False):
        """One active change for US-1.1, holding only OpenSpec's own artifacts."""
        d = self.root / 'openspec/changes/selected'
        d.mkdir(parents=True)
        (d / 'specs').mkdir()
        (d / 'proposal.md').write_text('# Proposal\n\nStory: US-1.1\n')
        (d / 'specs/spec.md').write_text('# Spec\n')
        specs=self.specs_file()
        specs.write_text(specs.read_text().replace('Status: READY','Status: READY\n\nChange: `openspec/changes/selected/`',1))
        (d / 'tasks.md').write_text('- [x] completed\n' if passing else '- [ ] pending\n')
        return d

    def specs_file(self):
        return self.root/self.config['documents']['specs']

    def archive(self, name='selected', date='2026-11-12'):
        """What `openspec archive` does to the directory, without needing the CLI."""
        target=self.root/'openspec/changes/archive'/f'{date}-{name}'
        target.parent.mkdir(parents=True, exist_ok=True)
        (self.root/'openspec/changes'/name).rename(target)
        return target

    def clone_plugin(self, name, without=(), tripwire=()):
        """A copy of the payload with scripts removed, or replaced by a script that
        records its own name outside the project and fails."""
        clone=Path(self.work.name)/name
        shutil.copytree(PLUGIN,clone)
        for script in without: (clone/'scripts'/f'{script}.sh').unlink()
        log=Path(self.work.name)/f'{name}.spawned'
        for script in tripwire:
            target=clone/'scripts'/f'{script}.sh'
            target.write_text(f'#!/bin/bash\nprintf \'%s\\n\' {script} >> {shlex.quote(str(log))}\nexit 2\n')
            target.chmod(0o755)
        return clone,log

    def spawned(self, log):
        names=log.read_text().split() if log.exists() else []
        if log.exists(): log.unlink()
        return names

    def git(self, *args):
        return subprocess.run(['git','-c','user.email=fixture@example.invalid','-c','user.name=Fixture',
                               '-c','commit.gpgsign=false',*args],cwd=self.root,check=True,text=True,capture_output=True)

    def make_codebase_stale(self):
        """CODEBASE.md records a real revision and HEAD has moved past it."""
        self.git('init','-q')
        (self.root/'src').mkdir(exist_ok=True)
        (self.root/'src/app.ts').write_text('export const a=1\n')
        self.git('add','-A');self.git('commit','-qm','Fixture first revision')
        revision=self.git('rev-parse','HEAD').stdout.strip()
        codebase=self.root/self.config['documents']['codebase']
        codebase.write_text(codebase.read_text().replace('0f1e2d3',revision))
        (self.root/'src/other.ts').write_text('export const b=2\n')
        self.git('add','-A');self.git('commit','-qm','Fixture second revision')
        return codebase

    def hook(self, mode, tool_input=None, agent=None, session='owner', code=0, plugin=PLUGIN, env=None, **extra):
        event = {'pre-write':'PreToolUse', 'pre-bash':'PreToolUse', 'post-write':'PostToolUse',
                 'stop':'Stop', 'session-context':'SessionStart'}[mode]
        payload = {'hook_event_name':event, 'session_id':session, 'cwd':str(self.root), **extra}
        if tool_input is not None: payload['tool_input'] = tool_input
        if agent is not None: payload.update(agent_type=agent, agent_id='specialist')
        result = subprocess.run(['bash', str(plugin / 'hooks/dispatch.sh'), '--project-root', str(self.root),
                                 '--mode',mode], input=json.dumps(payload), text=True, capture_output=True,
                                env={**os.environ, **(env or {})})
        self.assertEqual(code, result.returncode, result.stdout + result.stderr)
        if result.stdout.strip():
            try: json.loads(result.stdout)
            except ValueError: self.fail('Hook stdout must contain one JSON object: '+result.stdout)
        return result

    def next_action(self, target, *args, **kwargs):
        return json.loads(self.run_cli(*args,'delivery','next',target,'--json',**kwargs).stdout)

    def snapshot(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file()}

    def test_inactive_hooks_never_initialize(self):
        self.hook('session-context')
        self.hook('pre-write', {'file_path':'src/example.ts', 'content':'example'})
        self.assertEqual({}, self.snapshot())

    def test_bootstrap_preview_apply_and_repeat(self):
        preview=json.loads(self.run_cli('bootstrap','--dry-run').stdout)
        self.assertGreater(len(preview['files']), 5)
        self.assertEqual({}, self.snapshot())
        self.run_cli('bootstrap','--apply','--plan-id',preview['planId'])
        first=self.snapshot()
        self.run_cli('bootstrap','--apply')
        self.assertEqual(first,self.snapshot())
        self.assertNotIn('CODEBASE.md', first)
        self.assertFalse((self.root / 'scripts').exists())
        self.assertFalse((self.root / '.claude/skills').exists())
        self.assertFalse((self.root / '.claude/agents').exists())

    def test_existing_intent_and_credentials_preserved(self):
        (self.root/'PRD.md').write_text('Human intent\n')
        (self.root/'CLAUDE.md').write_text('Human guidance\n')
        (self.root/'.claude').mkdir()
        secret=self.root/'.claude/settings.local.json'
        secret.write_text('{"env":{"TOKEN":"test-sentinel-only"}}')
        self.run_cli('bootstrap','--apply')
        self.assertEqual('Human intent\n',(self.root/'PRD.md').read_text())
        self.assertEqual('Human guidance\n',(self.root/'CLAUDE.md').read_text())
        self.assertEqual('{"env":{"TOKEN":"test-sentinel-only"}}',secret.read_text())
        backups=list((self.root/'.claude/ohmyorch/backups').rglob('settings.local.json'))
        self.assertEqual([],backups)

    def test_managed_guidance_describes_the_openspec_flow(self):
        self.run_cli('bootstrap','--apply')
        guidance=(self.root/'CLAUDE.md').read_text()
        self.assertIn('Current-state evidence: CODEBASE.md (generate it only through analysis).\n'+CURRENT_GUIDANCE+
                      'Generic rules are bundled in the plugin; updates never copy executable code here.\n',guidance)
        self.run_cli('adapt-project','--apply')
        rules={subject:(self.root/f'.claude/rules/ohmyorch-{subject}-standards.md').read_text()
               for subject in ['codebase','product','delivery','testing']}
        self.assertTrue(rules['delivery'].endswith('\n'+CURRENT_RULE+'\n'))
        # The other three rule bodies are unchanged by the simplified flow.
        self.assertTrue(rules['codebase'].endswith(
            '\nRead configured CODEBASE before planning. Its observations constrain feasibility and never invent '
            'product intent. Architecture, entry points and tooling remain unknown unless evidenced there.\n'))
        self.assertTrue(rules['product'].endswith(
            '\nHuman decisions and approved source material govern intent. Ingest testable scenarios and explicit '
            'unknowns; do not invent READY stories.\n'))
        self.assertTrue(rules['testing'].endswith(
            '\nObserve evidence for every evaluated criterion. FAIL and UNVERIFIED remain distinct; never label an '
            'unrun command PASS. Use documented project checks. Fast validation needs current local hash approval.\n'))
        for text in [guidance,rules['delivery']]:
            for retired in ['Delegate implementation','Specialists persist','verdict','gates','Planner','implementer','reviewer','tester']:
                self.assertNotIn(retired,text)

    def test_adapt_project_replaces_guidance_written_by_the_previous_version(self):
        # A project as 0.0.1 left it, staged by a payload that differs only in that text.
        previous,_=self.clone_plugin('previous-guidance')
        lifecycle=previous/'lib/lifecycle.sh';source=lifecycle.read_text()
        self.assertEqual((1,1),(source.count(CURRENT_GUIDANCE),source.count(CURRENT_RULE)))
        lifecycle.write_text(source.replace(CURRENT_GUIDANCE,PREVIOUS_GUIDANCE).replace(CURRENT_RULE,PREVIOUS_RULE))
        self.run_cli('bootstrap','--apply',plugin=previous)
        self.run_cli('adapt-project','--apply',plugin=previous)
        guidance=self.root/'CLAUDE.md';rule=self.root/'.claude/rules/ohmyorch-delivery-standards.md'
        self.assertIn(PREVIOUS_GUIDANCE,guidance.read_text())
        self.assertIn(PREVIOUS_RULE,rule.read_text())
        guidance.write_text('# Human heading\n\n'+guidance.read_text()+'\nHuman footer\n')
        # A hand-edited managed file is a conflict: nothing is rewritten.
        untouched=rule.read_text()
        rule.write_text(untouched+'\nHuman edit\n')
        before=self.snapshot()
        self.run_cli('adapt-project','--apply',code=2)
        self.assertEqual({path:digest for path,digest in before.items() if not path.startswith('.claude/ohmyorch/backups/')},
                         {path:digest for path,digest in self.snapshot().items() if not path.startswith('.claude/ohmyorch/backups/')})
        rule.write_text(untouched)
        # Unedited, the previous text is replaced in place by an explicit, previewable operation.
        before=self.snapshot()
        preview=json.loads(self.run_cli('adapt-project','--dry-run').stdout)
        self.assertLessEqual({'CLAUDE.md','.claude/rules/ohmyorch-delivery-standards.md'},{entry['path'] for entry in preview['files']})
        self.assertEqual(before,self.snapshot())
        self.run_cli('adapt-project','--apply','--plan-id',preview['planId'])
        text=guidance.read_text()
        self.assertIn(CURRENT_GUIDANCE,text)
        self.assertNotIn('Specialists persist',text)
        self.assertTrue(text.startswith('# Human heading\n\n'))
        self.assertTrue(text.endswith('\nHuman footer\n'))
        self.assertIn(CURRENT_RULE,rule.read_text())
        self.assertNotIn(PREVIOUS_RULE,rule.read_text())
        for document in ['PRD.md','SPECS.md','.claude/ohmyorch/project.json']:
            self.assertEqual(before[document],self.snapshot()[document])
        applied=self.snapshot()
        self.run_cli('adapt-project','--apply')
        self.assertEqual(applied,self.snapshot())

    def test_root_docs_mixed_mapping_and_json(self):
        for docs in ['root','docs','mixed']:
            self.activate(docs)
            documents=self.config['documents']
            report=json.loads(self.run_cli('doctor','--json').stdout)
            self.assertEqual(documents,report['documents'])
            self.run_cli('validate-product-artifacts','--quiet')
            payload={'tool_input':{'file_path':str(self.specs_file())}}
            hook=subprocess.run([str(CLI),'--project-root',str(self.root),'validate-product-artifacts','--hook','--quiet'],
                                input=json.dumps(payload),text=True,capture_output=True)
            self.assertEqual(0,hook.returncode,hook.stderr)
            self.assertEqual('',hook.stdout)
            context=json.loads(self.hook('session-context').stdout)
            self.assertEqual({'hookSpecificOutput':{'hookEventName':'SessionStart',
                                                    'additionalContext':SESSION_CONTEXT.format(**documents)}},context)
            # Derived text names the mapped SPECS, wherever it lives.
            action=self.next_action('US-1.2')
            self.assertEqual({'target':'US-1.2','action':'escalate','story':'US-1.2','change':'us-1-2-story-awaiting-clarification',
                              'command':f"resolve US-1.2 in {documents['specs']} (a product decision is required)",
                              'reason':'US-1.2 is NEEDS CLARIFICATION, not READY'},action)
            self.assertIn(f"with a Change: line in {documents['specs']}",self.next_action('US-1.1')['command'])
        # Mixed mapping: only docs/SPECS.md is the backlog. The root SPECS.md left by
        # the first activation is an ordinary file to every guard.
        self.assertEqual('docs/SPECS.md',self.config['documents']['specs'])
        self.change()
        mapped=self.specs_file().read_text()
        done=mapped.replace('Status: READY','Status: DONE',1)
        blocked=self.hook('pre-write',{'file_path':'docs/SPECS.md','content':done},code=2)
        self.assertEqual(DONE_BLOCK.format(specs='docs/SPECS.md',story='US-1.1',id='selected'),blocked.stderr)
        self.hook('pre-write',{'file_path':'SPECS.md','content':done})
        self.hook('pre-write',{'file_path':'docs/SPECS.md','content':'text'},agent='general-purpose',code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','content':'text'},agent='general-purpose')

    def test_ambiguity_traversal_invalid_schema_and_symlinks(self):
        (self.root/'docs').mkdir()
        (self.root/'PRD.md').write_text('root')
        (self.root/'docs/PRD.md').write_text('docs')
        self.run_cli('bootstrap','--dry-run',code=2)
        self.run_cli('bootstrap','--dry-run','--prd','docs/PRD.md')
        self.run_cli('bootstrap','--dry-run','--prd','../escape.md',code=2)
        (self.root/'alias').symlink_to(Path(self.work.name),target_is_directory=True)
        self.run_cli('bootstrap','--dry-run','--prd','alias/escape.md',code=2)
        self.activate()
        self.config['schemaVersion']=99
        (self.root/'.claude/ohmyorch/project.json').write_text(json.dumps(self.config))
        refused=self.run_cli('delivery','next','US-1.1',code=2)
        self.assertIn('invalid/unsupported project config',refused.stderr)
        self.run_cli('guard-archive','--change','selected',code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','content':'bad'},code=2)
        self.hook('pre-write',{'file_path':'.claude/ohmyorch/project.json','content':json.dumps(CONFIG)})

    def test_config_loader_refuses_unsafe_paths_and_values(self):
        spelling='OhMyOrch: config paths must use canonical relative spelling\n'
        distinct='OhMyOrch: document paths must be distinct\n'
        schema='OhMyOrch: invalid/unsupported project config (schema 1, local spec-driven only)\n'
        cases=[('documents','prd','./PRD.md',spelling),('documents','specs','../SPECS.md',spelling),
               ('documents','codebase','/abs/CODEBASE.md',spelling),('output','pages','../pages',spelling),
               ('output','epicLogs','../LOGS',spelling),('fastValidation','script','../x.sh',spelling),
               ('documents','specs','PRD.md',distinct),('delivery','maxStalls',7,schema)]
        target=self.activate()/'project.json'
        texts=[]
        for section,key,value,message in cases:
            config=json.loads(json.dumps(CONFIG)); config[section][key]=value
            texts.append((f'{section}.{key}={value!r}',json.dumps(config),message))
        texts.append(('two documents',json.dumps(CONFIG)+'\n'+json.dumps(CONFIG),schema))
        for label,text,message in texts:
            with self.subTest(label):
                target.write_text(text)
                refused=self.run_cli('delivery','next','US-1.1',code=2)
                # A `..` or absolute path prints one more line first, from the path check.
                self.assertTrue(refused.stderr.endswith(message),refused.stderr)
                self.assertEqual('',refused.stdout)
                self.hook('pre-write',{'file_path':'SPECS.md','content':'x'},code=2)
        # The same file, valid again, is accepted: the refusals above were the loader's.
        target.write_text(json.dumps(CONFIG))
        self.assertEqual('propose',self.next_action('US-1.1')['action'])

    def test_disabled_project_hooks_are_a_no_op(self):
        directory=self.activate()
        self.change()
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        specs=(self.root/'SPECS.md').read_text()
        done=specs.replace('Status: READY','Status: DONE',1)
        # Everything an activated project refuses, each with its exit code there.
        refusals=[('pre-write',{'file_path':'SPECS.md','content':done},{}),
                  ('pre-write',{'file_path':'SPECS.md','content':specs},{'agent':'general-purpose'}),
                  ('pre-write',{'file_path':'src/app.ts','content':'text'},{'agent':'ohmyorch:spec-ingestor'}),
                  ('pre-write',{'file_path':'SPECS.md','content':specs},{'session':'spectator'}),
                  ('pre-write',{'content':'no target path'},{}),
                  ('pre-bash',{'command':'openspec archive selected -y'},{}),
                  ('pre-bash',{'command':'cd x && openspec archive selected -y'},{}),
                  ('stop',None,{})]
        for mode,tool_input,who in refusals:
            self.hook(mode,tool_input,code=2,**who)
        # Disabled, the project is left alone: no guard runs, not even to be found missing.
        broken,_=self.clone_plugin('disabled-without-guards',without=['guard-archive','guard-story-done','guard-delivery-loop'])
        self.config['enabled']=False
        (directory/'project.json').write_text(json.dumps(self.config))
        before=self.snapshot()
        for plugin in [PLUGIN,broken]:
            for mode,tool_input,who in refusals+[('post-write',{'file_path':'SPECS.md','content':'unused'},{}),
                                                 ('session-context',None,{})]:
                silent=self.hook(mode,tool_input,plugin=plugin,**who)
                self.assertEqual('',silent.stdout+silent.stderr,(mode,tool_input))
        self.assertEqual(before,self.snapshot())
        # Enabled again, the same events are enforced again.
        self.config['enabled']=True
        (directory/'project.json').write_text(json.dumps(self.config))
        for mode,tool_input,who in refusals:
            self.hook(mode,tool_input,code=2,**who)

    def test_cli_surface_is_the_fourteen_operations(self):
        self.assertEqual(14,len(OPERATIONS))
        self.assertEqual(sorted(op+'.sh' for op in OPERATIONS),sorted(p.name for p in (PLUGIN/'scripts').iterdir()))
        self.activate()
        self.change()
        before=self.snapshot()
        for operation in RETIRED:
            for arguments in [[],['--change','selected'],['--help']]:
                refused=self.run_cli(operation,*arguments,code=2)
                self.assertEqual(f'OhMyOrch: unknown operation: {operation}\n',refused.stderr)
                self.assertEqual('',refused.stdout)
        for operation in OPERATIONS:
            self.run_cli(operation,'--help')
        reopen=self.run_cli('--session-id','owner','delivery','reopen',code=2)
        self.assertIn("unknown command 'reopen'",reopen.stderr)
        option=self.run_cli('delivery','next','--change','selected',code=2)
        self.assertIn("unknown option '--change'",option.stderr)
        self.assertEqual(before,self.snapshot())
        checks=json.loads(self.run_cli('doctor','--json').stdout)['checks']
        self.assertEqual([('bundled-'+name,'PASS') for name in HOOK_SCRIPTS],
                         [(c['name'],c['status']) for c in checks if c['name'].startswith('bundled-')])

    def test_plugin_agents_are_read_only_and_subagents_cannot_write_delivery_state(self):
        self.activate()
        self.change()
        (self.root/'openspec/delivery').mkdir()
        targets=['src/app.ts','SPECS.md','PRD.md','CODEBASE.md','openspec/changes/selected/tasks.md',
                 'openspec/changes/selected/proposal.md','openspec/delivery/goal.md']
        # Every plugin agent is a read-only authoring role, whatever its name.
        for role in ['codebase-analyst','product-specifier','spec-ingestor']:
            for target in targets:
                denied=self.hook('pre-write',{'file_path':target,'content':'text'},agent='ohmyorch:'+role,code=2)
                self.assertEqual(READ_ONLY.format(role=role,file=target),denied.stderr)
                self.assertEqual('',denied.stdout)
        for role in ['implementer','reviewer','tester','planner','product-manager','not-a-shipped-agent']:
            for target in ['src/app.ts','openspec/changes/selected/tasks.md','openspec/changes/selected/review.md']:
                denied=self.hook('pre-write',{'file_path':target,'content':'text'},agent='ohmyorch:'+role,code=2)
                self.assertEqual(READ_ONLY.format(role=role,file=target),denied.stderr)
        absolute=self.hook('pre-write',{'file_path':str(self.root/'src/app.ts'),'content':'text'},agent='ohmyorch:spec-ingestor',code=2)
        self.assertEqual(READ_ONLY.format(role='spec-ingestor',file='src/app.ts'),absolute.stderr)
        self.hook('pre-write',{'file_path':'src/app.ts','edits':[{'old_string':'a','new_string':'b'}]},agent='ohmyorch:codebase-analyst',code=2)
        # Any other subagent may write product code and a change's artifacts...
        for target in ['src/app.ts','README.md','openspec/changes/selected/tasks.md','openspec/changes/selected/proposal.md',
                       'openspec/changes/selected/specs/spec.md','openspec/changes/selected/design.md',
                       'openspec/changes/selected/review.md','openspec/changes/other/tasks.md','CODEBASE.md','PRD.md']:
            allowed=self.hook('pre-write',{'file_path':target,'content':'text'},agent='general-purpose')
            self.assertEqual('',allowed.stdout+allowed.stderr,target)
        # ...but never the backlog or the delivery goal.
        for target in ['SPECS.md',str(self.root/'SPECS.md'),'openspec/delivery/goal.md','openspec/delivery/notes.md']:
            for writer in [{'agent':'general-purpose'},{'agent':'unrelated-agent'},{'agent_id':'anonymous-subagent'}]:
                denied=self.hook('pre-write',{'file_path':target,'content':'text'},code=2,**writer)
                self.assertEqual(SUBAGENT_DENIED,denied.stderr)
        mixed=self.hook('pre-write',{'files':[{'file_path':'src/app.ts'},{'file_path':'openspec/delivery/goal.md'}]},agent='general-purpose',code=2)
        self.assertEqual(SUBAGENT_DENIED,mixed.stderr)
        # The main session performs every delivery step itself. Identity is protocol
        # data: text that merely mentions an agent changes nothing.
        specs=(self.root/'SPECS.md').read_text()
        for target,content in [('src/app.ts','agent_type: ohmyorch:spec-ingestor'),
                               ('openspec/changes/selected/tasks.md','- [x] pending\n'),
                               ('openspec/changes/selected/review.md','agent_type: ohmyorch:reviewer'),
                               ('openspec/changes/selected/test-report.md','"agent_id": "specialist"'),
                               ('openspec/delivery/goal.md','# Delivery Goal\n'),('SPECS.md',specs)]:
            allowed=self.hook('pre-write',{'file_path':target,'content':content})
            self.assertEqual('',allowed.stdout+allowed.stderr,target)
        self.hook('pre-write',{'file_path':'a\nb.md','content':'text'},code=2)
        self.hook('pre-write',{'file_path':str(Path(self.work.name)/'outside.md'),'content':'text'},code=2)
        self.hook('pre-write',{'content':'text'},code=2)

    def test_ordinary_writes_spawn_no_guard(self):
        self.activate()
        self.change()
        self.make_codebase_stale()
        # Every script is a tripwire that records its name and fails.
        clone,log=self.clone_plugin('tripwired',tripwire=HOOK_SCRIPTS+['run-project-validation'])
        specs=(self.root/'SPECS.md').read_text()
        ordinary=['src/app.ts',str(self.root/'src/app.ts'),'README.md','docs/notes.md','CODEBASE.md',
                  'openspec/changes/selected/tasks.md','openspec/changes/selected/proposal.md',
                  'openspec/changes/selected/specs/spec.md','openspec/specs/widget/spec.md','.claude/rules/local.md']
        for target in ordinary:
            for agent in [None,'general-purpose']:
                result=self.hook('pre-write',{'file_path':target,'content':'text'},agent=agent,plugin=clone)
                self.assertEqual('',result.stdout+result.stderr,target)
        self.hook('pre-write',{'file_path':'src/app.ts','old_string':'a','new_string':'b'},plugin=clone)
        self.hook('pre-write',{'files':[{'file_path':'src/a.ts'},{'file_path':'src/b.ts'}]},plugin=clone)
        self.hook('post-write',{'file_path':'src/app.ts','content':'unused'},plugin=clone)
        self.hook('post-write',{'file_path':'openspec/changes/selected/tasks.md','content':'unused'},plugin=clone)
        self.hook('pre-bash',{'command':'git status --short'},plugin=clone)
        self.hook('pre-bash',{'command':'openspec status --change selected'},plugin=clone)
        self.hook('pre-bash',{'command':'openspec archive --help'},plugin=clone)
        self.hook('session-context',plugin=clone)
        self.hook('stop',plugin=clone)
        self.assertEqual([],self.spawned(log))
        # The same tripwires prove which guard each protected path reaches.
        self.hook('pre-write',{'file_path':'PRD.md','content':'text'},plugin=clone,code=2)
        self.assertEqual(['guard-context-preflight'],self.spawned(log))
        self.hook('pre-write',{'file_path':'SPECS.md','content':specs+'\nA new paragraph.\n'},plugin=clone,code=2)
        self.assertEqual(['guard-context-preflight'],self.spawned(log))
        # Bookkeeping skips the preflight process entirely and goes to the DONE guard.
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: READY','new_string':'Status: IN PROGRESS'},plugin=clone,code=2)
        self.assertEqual(['guard-story-done'],self.spawned(log))
        self.hook('pre-write',{'files':[{'file_path':'src/a.ts'},{'file_path':'PRD.md'}]},plugin=clone,code=2)
        self.assertEqual(['guard-context-preflight'],self.spawned(log))
        for document in ['PRD.md','SPECS.md','CODEBASE.md']:
            self.hook('post-write',{'file_path':document,'content':'unused'},plugin=clone,code=2)
            self.assertEqual(['validate-product-artifacts'],self.spawned(log))
        self.hook('pre-bash',{'command':'openspec archive selected -y'},plugin=clone,code=2)
        self.assertEqual(['guard-archive'],self.spawned(log))

    def test_specs_bookkeeping_skips_the_stale_codebase_preflight(self):
        self.activate()
        self.change()
        codebase=self.make_codebase_stale()
        specs=self.root/'SPECS.md'
        # The ingest format mirrors every work item in a generated table; the fixture has none.
        marker='CODEBASE Context: consumed (0f1e2d3)\n'
        story_row='| US-1.1 | A well-formed ready story | READY | EPIC-1 |'
        task_row='| US-1.1#1 | t | TODO | US-1.1 |'
        epic_row='| EPIC-1 | Fixture Epic | READY | - |'
        table_head='| ID | Title | Status | Parent |'
        self.assertEqual(1,specs.read_text().count(marker))
        specs.write_text(specs.read_text().replace(marker,marker+f'\n## Work Item Status\n\n{table_head}\n|---|---|---|---|\n'
                                                   f'{epic_row}\n{story_row}\n{task_row}\n'))
        original=specs.read_text()
        stale=self.run_cli('guard-context-preflight','--file','SPECS.md',code=2)
        self.assertIn('HEAD has moved on',stale.stderr)
        def write(tool_input,code=0):
            result=self.hook('pre-write',{'file_path':'SPECS.md',**tool_input},code=code)
            self.assertEqual(original,specs.read_text())
            return result
        # The one task line of US-1.1, located by the lines that follow it.
        task='- [ ] t\n\nOpen Questions:\n- None.'
        tick={'old_string':task,'new_string':task.replace('- [ ] t','- [x] t')}
        moved_row={'old_string':story_row,'new_string':story_row.replace('READY','IN PROGRESS')}
        # Status:, Change:, ticking a task, and the story/task rows of the Work Item
        # Status table are what the delivery loop records.
        bookkeeping=[
            {'old_string':'Status: READY','new_string':'Status: IN PROGRESS'},
            {'old_string':'Change: `openspec/changes/selected/`','new_string':'Change: `openspec/changes/archive/2026-11-12-selected/`'},
            {'old_string':'- [ ] t','new_string':'- [x] t','replace_all':True},
            {'old_string':'Tasks:\n- [x] t','new_string':'Tasks:\n  - [ ] t'},
            {'edits':[{'old_string':'Status: READY','new_string':'Status: IN PROGRESS'},
                      {'old_string':'Change: `openspec/changes/selected/`','new_string':'Change: `openspec/changes/renamed/`'},
                      {'old_string':'- [ ] t','new_string':'- [X] t','replace_all':True}]},
            {'content':original.replace('Status: READY','Status: IN PROGRESS').replace('- [ ] t','- [x] t')},
            {'content':original},
            tick,
            moved_row,
            {'old_string':task_row,'new_string':task_row.replace('TODO','DONE')},
            {'old_string':story_row+'\n'+task_row,'new_string':'|US-1.1|A well-formed ready story|IN PROGRESS|EPIC-1|\n| US-1.1#1 |t|DONE|US-1.1|'},
            # The whole of a propose or mark-done record, as one edit.
            {'edits':[{'old_string':'Status: READY','new_string':'Status: IN PROGRESS'},
                      {'old_string':'Change: `openspec/changes/selected/`','new_string':'Change: `openspec/changes/archive/2026-11-12-selected/`'},
                      tick,moved_row,{'old_string':task_row,'new_string':task_row.replace('TODO','DONE')}]},
            {'content':original.replace('Status: READY','Status: IN PROGRESS').replace('- [ ] t','- [x] t')
                               .replace(story_row,story_row.replace('READY','IN PROGRESS')).replace('TODO','DONE')},
            # A rewrite that ticks and drops the file's final newline changes no content.
            {'content':original.replace('- [ ] t','- [x] t').rstrip('\n')},
        ]
        self.assertTrue(original.endswith('\n'))
        for tool_input in bookkeeping:
            allowed=write(tool_input)
            self.assertEqual('',allowed.stdout+allowed.stderr,tool_input)
        # A Change: line arrives with, and leaves with, the blank line that separates
        # it. Blank lines carry no content, so they do not make bookkeeping material.
        write({'old_string':'Status: NEEDS CLARIFICATION','new_string':'Status: NEEDS CLARIFICATION\n\nChange: `openspec/changes/other/`'})
        write({'content':original.replace('Change: `openspec/changes/selected/`\n\n','')})
        # Anything else is a material SPECS update and still needs current context.
        material=[
            {'old_string':'# EPIC-1: Fixture Epic','new_string':'# EPIC-1: Renamed Epic'},
            {'old_string':'### US-1.1: A well-formed ready story','new_string':'### US-1.1: A renamed story'},
            {'old_string':"Exercise the validator's passing path.",'new_string':'Exercise something else.'},
            {'old_string':'- PRD.md section 1','new_string':'- PRD.md section 9'},
            {'old_string':'Scenario: Well-formed behavior','new_string':'Scenario: Different behavior'},
            {'old_string':'- Which behavior is correct?','new_string':'- Which Status: is correct?'},
            {'old_string':'Status: READY','new_string':' Status: READY'},
            {'old_string':'Status: READY','new_string':'Status: IN PROGRESS\n\nA sentence of new scope.'},
            {'edits':[{'old_string':'Status: READY','new_string':'Status: IN PROGRESS'},
                      {'old_string':'- PRD.md section 2','new_string':'- PRD.md section 7'}]},
            {'content':original.replace('Status: READY','Status: IN PROGRESS')+'\n### US-1.4: A new story\n\nStatus: READY\n'},
            {'content':'Status: READY\n'},
        ]
        # Only the story and task rows of the table are bookkeeping.
        table=[
            {'old_string':epic_row,'new_string':epic_row.replace('READY','DONE')},
            {'old_string':table_head,'new_string':table_head.replace('Title','Name')},
            {'old_string':story_row,'new_string':story_row+'\n| US-1.4 | A story nobody specified | READY | EPIC-1 |\n\nA sentence of new scope.'},
            {'old_string':story_row,'new_string':'Story US-1.1 | A well-formed ready story | READY | EPIC-1 |'},
            # The work item id is the row's first cell, not any later one.
            {'old_string':story_row,'new_string':'| EPIC-1 | US-1.1 | A well-formed ready story | READY |'},
            {'edits':[moved_row,{'old_string':epic_row,'new_string':epic_row.replace('Fixture','Renamed')}]},
        ]
        # A task line is bookkeeping only when the tick is all that changes.
        tasks=[
            {'old_string':task,'new_string':'- [ ] t\n- [ ] a task nobody approved\n\nOpen Questions:\n- None.'},
            {'old_string':task,'new_string':task.replace('- [ ] t','- [ ] a different task')},
            {'old_string':task,'new_string':task.replace('- [ ] t','- [x] t, done differently')},
            {'old_string':'Tasks:\n'+task,'new_string':'Tasks:\n\nOpen Questions:\n- None.'},
            {'old_string':'- [x] t','new_string':'- [x] t\n- [x] t'},
            {'edits':[{'old_string':'Status: READY','new_string':'Status: IN PROGRESS'},
                      {'old_string':task,'new_string':task.replace('- [ ] t','- [x] t\n- [ ] one more')}]},
            # A tick that brings a second copy of the task line with it.
            {'old_string':task,'new_string':task.replace('- [ ] t','- [x] t\n- [x] t')},
            # A task line that leaves one story and turns up, ticked, in another:
            # the same text removed and added, but not in the same place.
            {'edits':[{'old_string':task,'new_string':'Open Questions:\n- None.'},
                      {'old_string':'Tasks:\n- [x] t','new_string':'Tasks:\n- [x] t\n- [x] t'}]},
        ]
        # A NUL byte must not hide the changed lines from the comparison, in the
        # middle of a line or at its start.
        binary=[{'old_string':'# EPIC-1: Fixture Epic','new_string':'# EPIC-1: Renamed\x00 Epic'},
                {'old_string':'# EPIC-1: Fixture Epic','new_string':'# EPIC-1: Fixture Epic\n\x00A sentence of new scope.'}]
        for tool_input in material+table+tasks+binary:
            blocked=write(tool_input,code=2)
            self.assertIn('BLOCKED  SPECS.md\n',blocked.stderr,tool_input)
            self.assertIn('HEAD has moved on',blocked.stderr,tool_input)
        # PRD writes always run the preflight, bookkeeping-shaped or not.
        prd=(self.root/'PRD.md').read_text()
        for tool_input in [{'content':prd},{'content':prd+'\nStatus: READY\n'},
                           {'old_string':'Product intent for the fixture.','new_string':'Status: DONE'}]:
            blocked=self.hook('pre-write',{'file_path':'PRD.md',**tool_input},code=2)
            self.assertIn('BLOCKED  PRD.md\n',blocked.stderr)
        # A SPECS file that does not exist yet is new content, never bookkeeping.
        specs.unlink()
        created=self.hook('pre-write',{'file_path':'SPECS.md','content':'Status: READY\n'},code=2)
        self.assertIn('HEAD has moved on',created.stderr)
        specs.write_text(original)
        # Skipping the preflight never skips the DONE guard.
        done=write({'old_string':'Status: READY','new_string':'Status: DONE'},code=2)
        self.assertEqual(DONE_BLOCK.format(specs='SPECS.md',story='US-1.1',id='selected'),done.stderr)
        # An edit that cannot be reconstructed is refused before anything is judged.
        absent=write({'old_string':'does not exist','new_string':'Status: DONE'},code=2)
        self.assertIn('cannot reconstruct prospective SPECS write',absent.stderr)
        ambiguous=write({'old_string':'- [ ] t','new_string':'- [x] t'},code=2)
        self.assertIn('cannot reconstruct prospective SPECS write',ambiguous.stderr)
        # The comparison reads bytes: a byte that is invalid in the session's
        # encoding, on a line that is bookkeeping anyway, does not stop it.
        specs.write_bytes(original.encode().replace(b'Status: NEEDS CLARIFICATION',b'Status: NEEDS CLARIFICATION \xff'))
        # Read as bytes: awk may warn about that byte on stderr, which is not text.
        event={'hook_event_name':'PreToolUse','session_id':'owner','cwd':str(self.root),
               'tool_input':{'file_path':'SPECS.md',**tick}}
        ticked=subprocess.run(['bash',str(PLUGIN/'hooks/dispatch.sh'),'--project-root',str(self.root),'--mode','pre-write'],
                              input=json.dumps(event).encode(),capture_output=True,env={**os.environ,'LC_ALL':'en_US.UTF-8'})
        self.assertEqual(0,ticked.returncode,ticked.stderr)
        self.assertNotIn(b'BLOCKED',ticked.stderr)
        # A final newline missing on disk and present in the write is no content either.
        specs.write_text(original.rstrip('\n'))
        closed=self.hook('pre-write',{'file_path':'SPECS.md','content':original.replace('- [ ] t','- [x] t')})
        self.assertEqual('',closed.stdout+closed.stderr)
        specs.write_text(original)
        # A comparison step that prints nothing has failed: the preflight still runs.
        shim=Path(self.work.name)/'silent-tr';shim.mkdir()
        (shim/'tr').write_text('#!/bin/sh\ncat >/dev/null\n');(shim/'tr').chmod(0o755)
        silent=self.hook('pre-write',{'file_path':'SPECS.md',**material[0]},code=2,
                         env={'PATH':f"{shim}{os.pathsep}{os.environ['PATH']}"})
        self.assertIn('BLOCKED  SPECS.md\n',silent.stderr)
        self.assertEqual(original,specs.read_text())
        # Allowed, blocked or refused, a SPECS write leaves no scratch file behind.
        scratch=Path(self.work.name)/'hook-scratch';scratch.mkdir()
        for tool_input,code in [(bookkeeping[0],0),(material[0],2),({'old_string':'Status: READY','new_string':'Status: DONE'},2),
                                ({'old_string':'does not exist','new_string':'x'},2),(tick,0),(moved_row,0),(tasks[0],2)]:
            self.hook('pre-write',{'file_path':'SPECS.md',**tool_input},code=code,env={'TMPDIR':str(scratch)})
            self.assertEqual([],list(scratch.iterdir()),tool_input)
        # Once CODEBASE.md describes HEAD again, the material edits pass too.
        head=self.git('rev-parse','HEAD').stdout.strip()
        recorded=codebase.read_text().split('Analyzed revision: ')[1].split('\n')[0]
        codebase.write_text(codebase.read_text().replace(recorded,head))
        for tool_input in material[:6]+table+tasks:
            write(tool_input)
        self.hook('pre-write',{'file_path':'PRD.md','content':prd})

    def test_codebase_preflight_reads_the_recorded_decision_from_the_write(self):
        self.activate()
        codebase=self.make_codebase_stale()
        recorded=codebase.read_text().split('Analyzed revision: ')[1].split('\n')[0]
        head=self.git('rev-parse','HEAD').stdout.strip()
        consumed='CODEBASE Context: consumed (0f1e2d3)'
        accepted=f'CODEBASE Context: consumed ({recorded}, staleness accepted)'
        material={'SPECS.md':{'old_string':'Scenario: Well-formed behavior','new_string':'Scenario: Different behavior'},
                  'PRD.md':{'old_string':'Product intent for the fixture.','new_string':'Different intent.'}}
        originals={document:(self.root/document).read_text() for document in material}
        def write(document,tool_input,code=0):
            result=self.hook('pre-write',{'file_path':document,**tool_input},code=code)
            if code==0: self.assertEqual('',result.stdout+result.stderr,(document,tool_input))
            return result
        for document,edit in material.items():
            # The stale block prints the line that accepts the analysis as it is...
            blocked=write(document,edit,code=2)
            self.assertIn(f'  To proceed deliberately, put this line in {document}:\n    {accepted}\n',blocked.stderr)
            # ...and the write that records it passes, alone or with the material change.
            write(document,{'old_string':consumed,'new_string':accepted})
            write(document,{'content':originals[document].replace(consumed,accepted)+'\nA new paragraph.\n'})
            write(document,{'edits':[{'old_string':consumed,'new_string':accepted},edit]})
            # The acceptance is tied to the revision CODEBASE.md records.
            for other in [head,'0f1e2d3',recorded[:12]]:
                refused=write(document,{'old_string':consumed,'new_string':f'CODEBASE Context: consumed ({other}, staleness accepted)'},code=2)
                self.assertIn('HEAD has moved on',refused.stderr)
        # A PRD write that cannot be reconstructed is judged on the file on disk,
        # never refused for that: here the file on disk records no decision.
        fallback=write('PRD.md',{'old_string':'no such text','new_string':accepted},code=2)
        self.assertIn('HEAD has moved on',fallback.stderr)
        self.assertNotIn('reconstruct',fallback.stderr)
        # No write leaves a scratch file behind, allowed, blocked or judged on disk.
        scratch=Path(self.work.name)/'hook-scratch';scratch.mkdir()
        for tool_input,code in [({'old_string':consumed,'new_string':accepted},0),(material['PRD.md'],2),
                                ({'old_string':'no such text','new_string':'x'},2)]:
            self.hook('pre-write',{'file_path':'PRD.md',**tool_input},code=code,env={'TMPDIR':str(scratch)})
            self.assertEqual([],list(scratch.iterdir()),tool_input)
        # Recorded on disk, the decision covers the following writes to that document...
        for document in material:
            (self.root/document).write_text(originals[document].replace(consumed,accepted))
        for document,edit in material.items():
            write(document,edit)
        write('PRD.md',{'old_string':'no such text','new_string':'x'})
        direct=self.run_cli('guard-context-preflight','--file','SPECS.md')
        self.assertEqual(f'ALLOW  stale CODEBASE.md ({recorded}) accepted by the decision recorded in SPECS.md\n',direct.stderr)
        # ...until a write removes it.
        for document in material:
            removed=write(document,{'old_string':accepted,'new_string':consumed},code=2)
            self.assertIn('HEAD has moved on',removed.stderr)
            (self.root/document).write_text(originals[document])
        # Stale means a commit touched something other than the three mapped documents.
        codebase.write_text(codebase.read_text().replace(recorded,head))
        for document,edit in material.items(): write(document,edit)
        self.git('add','CODEBASE.md');self.git('commit','-qm','Fixture: refreshed analysis')
        for document,edit in material.items(): write(document,edit)
        for document in material:
            (self.root/document).write_text(originals[document]+'\nA committed paragraph.\n')
        self.git('add','SPECS.md','PRD.md');self.git('commit','-qm','Fixture: product documents')
        for document,edit in material.items(): write(document,edit)
        (self.root/'src/app.ts').write_text('export const a=2\n')
        self.git('add','src/app.ts');self.git('commit','-qm','Fixture: source change')
        for document,edit in material.items():
            blocked=write(document,edit,code=2)
            self.assertIn(f'CODEBASE.md describes {head}, but HEAD has moved on (1 file(s) changed).',blocked.stderr)
        # A brownfield project without CODEBASE.md: the skip decision is read from the write too.
        codebase.unlink()
        skip='CODEBASE Context: skipped (analysis deliberately not run)'
        for document,edit in material.items():
            (self.root/document).write_text(originals[document])
            blocked=write(document,edit,code=2)
            self.assertIn('A meaningful codebase is present but CODEBASE.md does not exist.',blocked.stderr)
            self.assertIn(f'    b) record a deliberate skip by adding this line to {document}:\n'
                          '       CODEBASE Context: skipped (<reason>)\n',blocked.stderr)
            write(document,{'old_string':consumed,'new_string':skip})
            write(document,{'content':f'# Rewritten\n\n{skip}\n\nIntent.\n'})
            # A document that does not exist yet is judged the same way.
            (self.root/document).unlink()
            write(document,{'content':f'# New\n\n{skip}\n\nIntent.\n'})
            created=write(document,{'content':'# New\n\nIntent.\n'},code=2)
            self.assertIn('CODEBASE.md does not exist',created.stderr)
            (self.root/document).write_text(originals[document])
        # Once the decision is recorded, the validator reports it. It never advises
        # removing the line the preflight asked for.
        for document in material:
            (self.root/document).write_text(originals[document].replace(consumed,skip))
        report=self.run_cli('validate-product-artifacts')
        text=report.stdout+report.stderr
        self.assertEqual(2,text.count(f'records an explicit skip decision: {skip}'),text)
        self.assertNotIn('remove the marker',text)
        # A consumed marker that only mentions the word is not that decision.
        for document in material:
            (self.root/document).write_text(originals[document].replace(consumed,'CODEBASE Context: consumed (0f1e2d3, nothing skipped)'))
        report=self.run_cli('validate-product-artifacts')
        text=report.stdout+report.stderr
        self.assertNotIn('records an explicit skip decision',text)
        self.assertEqual(2,text.count('remove the marker'),text)

    def test_batched_edit_does_not_bypass_done(self):
        self.activate()
        change=self.change()
        content=(self.root/'SPECS.md').read_text()
        first=content.split('### US-1.2:')[0]
        blocked=DONE_BLOCK.format(specs='SPECS.md',story='US-1.1',id='selected')
        attempts=[{'edits':[{'old_string':first,'new_string':first.replace('Status: READY','Status: DONE')}]},
                  {'old_string':'Status: READY','new_string':'Status: DONE'},
                  {'edits':[{'old_string':'Status: READY','new_string':'Status: IN PROGRESS'},
                            {'old_string':'Status: IN PROGRESS','new_string':'Status: DONE'}]},
                  {'content':content.replace('Status: READY','Status: DONE')},
                  # Pointing the Change: line at the archive does not archive the change.
                  {'content':content.replace('Status: READY','Status: DONE').replace('changes/selected/','changes/archive/2026-11-12-selected/')},
                  # Nor does rewording or dropping the line detach the story from it:
                  # the change the file on disk names is judged as well.
                  {'content':content.replace('Status: READY','Status: DONE').replace('`openspec/changes/selected/`','`openspec/changes/selected/` (archived)')},
                  {'edits':[{'old_string':'Status: READY','new_string':'Status: DONE'},
                            {'old_string':'Change: `openspec/changes/selected/`','new_string':'Change: [selected](openspec/changes/archive/selected/)'}]},
                  {'old_string':'Status: READY\n\nChange: `openspec/changes/selected/`','new_string':'Status: DONE\n\nChange: done'},
                  {'old_string':'Status: READY\n\nChange: `openspec/changes/selected/`\n','new_string':'Status: DONE\n'}]
        for attempt in attempts:
            result=self.hook('pre-write',{'file_path':'SPECS.md',**attempt},code=2)
            self.assertEqual(blocked,result.stderr)
            self.assertEqual('',result.stdout)
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'does not exist','new_string':'Status: DONE'},code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','content':content})
        # Archive before DONE is structural: finished tasks do not stand in for the archive.
        (change/'tasks.md').write_text('- [x] completed\n')
        self.hook('pre-bash',{'command':'openspec archive selected -y'})
        for attempt in attempts:
            self.hook('pre-write',{'file_path':'SPECS.md',**attempt},code=2)
        # A story that never had a change is not this guard's concern.
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: NEEDS CLARIFICATION','new_string':'Status: DONE'})
        self.archive()
        for attempt in attempts:
            allowed=self.hook('pre-write',{'file_path':'SPECS.md',**attempt})
            self.assertEqual('',allowed.stdout+allowed.stderr)
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'does not exist','new_string':'Status: DONE'},code=2)

    def test_specs_larger_than_one_linux_argument_is_still_guarded(self):
        """Linux refuses a single argument of 128 KiB or more, so the dispatcher hands the
        prospective SPECS to the DONE guard as a file, never as an argument."""
        self.activate()
        self.change()
        specs=self.specs_file()
        specs.write_text(specs.read_text()+'Filler prose that only makes the document larger than one argument.\n'*3000)
        self.assertGreater(specs.stat().st_size,131072)
        content=specs.read_text()
        blocked=DONE_BLOCK.format(specs='SPECS.md',story='US-1.1',id='selected')
        attempts=[{'old_string':'Status: READY','new_string':'Status: DONE'},
                  {'content':content.replace('Status: READY','Status: DONE',1)}]
        for attempt in attempts:
            result=self.hook('pre-write',{'file_path':'SPECS.md',**attempt},code=2)
            self.assertEqual(blocked,result.stderr)
            self.assertEqual('',result.stdout)
        # The same large file accepts bookkeeping, so the block above is the guard's verdict.
        allowed=self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: READY','new_string':'Status: IN PROGRESS'})
        self.assertEqual('',allowed.stdout+allowed.stderr)
        self.archive()
        for attempt in attempts:
            allowed=self.hook('pre-write',{'file_path':'SPECS.md',**attempt})
            self.assertEqual('',allowed.stdout+allowed.stderr)

    def test_archive_guard_through_the_bash_hook(self):
        self.activate()
        change=self.change()
        # The literal command, run alone. The id may be bare or in one pair of quotes.
        literal=['openspec archive selected -y','openspec archive selected --yes','openspec archive selected',
                 'openspec  archive  selected  --skip-specs  -y ','openspec archive "selected" -y',
                 "openspec archive 'selected' -y",'openspec archive "selected" --skip-specs --yes']
        for command in literal:
            blocked=self.hook('pre-bash',{'command':command,'description':'Archive the change'},code=2)
            self.assertEqual(ARCHIVE_BLOCK.format(id='selected',progress='0/1'),blocked.stderr,command)
            self.assertEqual('',blocked.stdout)
        (change/'tasks.md').write_text('- [x] 1.1 build\n- [ ] 1.2 test\n  - [X] 1.2.1 nested\n')
        blocked=self.hook('pre-bash',{'command':'openspec archive selected -y'},code=2)
        self.assertEqual(ARCHIVE_BLOCK.format(id='selected',progress='2/3'),blocked.stderr)
        # Unfinished is what OpenSpec counts as unfinished, whatever the marker.
        (change/'tasks.md').write_text('- [x] 1.1 build\n- [~] 1.2 test\n* [ ] 1.3 document\n1. [x] 1.4 release\n')
        blocked=self.hook('pre-bash',{'command':'openspec archive selected -y'},code=2)
        self.assertEqual(ARCHIVE_BLOCK.format(id='selected',progress='2/4'),blocked.stderr)
        # Only that standalone literal invocation is judged; any other command that
        # invokes the archive is refused outright, whatever the state of the tasks.
        unsupported=['openspec archive selected -y; openspec archive other -y','openspec archive "$CHANGE" -y',
                     'cd x && openspec archive selected -y','openspec archive ../selected -y',
                     'openspec archive selected -y --no-validate',
                     # a global option or another launcher in front of the subcommand
                     'openspec --no-color archive selected -y','openspec -h archive',
                     'npx openspec@1.13.2 archive selected -y','npx @fission-ai/openspec@latest archive selected -y',
                     # more than one line: one allowed line must not carry the others
                     'openspec archive --help\nopenspec archive selected -y','openspec archive selected -y\ngit status',
                     # an option or nothing where the id belongs
                     'openspec archive -y','openspec archive --yes selected','openspec archive -selected -y',
                     'openspec archive _selected -y',
                     # quotes that do not wrap exactly one id
                     'openspec archive "selected -y',"openspec archive \"selected' -y",'openspec archive "" -y',
                     'openspec archive "selected""other" -y']
        def refuse_unsupported():
            for command in unsupported:
                refused=self.hook('pre-bash',{'command':command},code=2)
                self.assertEqual(ARCHIVE_FORM,refused.stderr,command)
                self.assertEqual('',refused.stdout)
        refuse_unsupported()
        # Asking for help, or merely naming the directory, is not an archive.
        untouched=[{'command':'openspec archive --help'},{'command':'openspec archive -h'},
                   {'command':'openspec list --json','description':'then openspec archive selected'},
                   {'command':'openspec --no-color validate selected --strict'},
                   {'command':'ls openspec/changes/archive'},{'command':'git diff openspec -- docs'}]
        for tool_input in untouched:
            passed=self.hook('pre-bash',tool_input)
            self.assertEqual('',passed.stdout+passed.stderr,tool_input)
        # Leftover verdict files of an earlier version are never consulted.
        for name,text in LEFTOVERS.items():
            (change/name).parent.mkdir(exist_ok=True);(change/name).write_text(text)
        (change/'tasks.md').write_text('- [x] 1.1 build\n- [x] 1.2 test\n')
        for command in literal+['openspec archive selected --skip-specs --yes']:
            allowed=self.hook('pre-bash',{'command':command})
            self.assertEqual('',allowed.stdout+allowed.stderr,command)
        refuse_unsupported()
        # A quoted id is the same id: it reaches the guard, which counts the tasks.
        (change/'tasks.md').write_text('* [x] 1.1 build\n+ [X] 1.2 test\n')
        self.hook('pre-bash',{'command':'openspec archive "selected" -y'})
        (change/'tasks.md').write_text('* [x] 1.1 build\n+ [-] 1.2 test\n')
        blocked=self.hook('pre-bash',{'command':"openspec archive 'selected' --yes"},code=2)
        self.assertEqual(ARCHIVE_BLOCK.format(id='selected',progress='1/2'),blocked.stderr)
        (change/'tasks.md').write_text('# Tasks\n\nNo checklist.\n')
        self.hook('pre-bash',{'command':'openspec archive selected -y'})
        (change/'tasks.md').unlink()
        self.hook('pre-bash',{'command':'openspec archive selected -y'})
        self.hook('pre-bash',{'command':'openspec archive never-existed -y'})
        self.archive()
        self.hook('pre-bash',{'command':'openspec archive selected -y'})

    def test_leftover_legacy_change_files_are_ignored_and_survive(self):
        self.activate()
        change=self.change(True)
        for name,text in LEFTOVERS.items():
            (change/name).parent.mkdir(exist_ok=True);(change/name).write_text(text)
        def leftovers(directory):
            return {str(p.relative_to(directory)):p.read_text() for p in directory.rglob('*') if p.is_file()}
        expected={**LEFTOVERS,'proposal.md':'# Proposal\n\nStory: US-1.1\n','specs/spec.md':'# Spec\n','tasks.md':'- [x] completed\n'}
        self.assertEqual(expected,leftovers(change))
        verify={'target':'US-1.1','action':'verify','story':'US-1.1','change':'selected',
                'command':'/ohmyorch:opsx-verify selected; with no CRITICAL issue, run a separate Bash call: openspec archive selected -y',
                'reason':'1/1 tasks complete; verify, then archive'}
        self.assertEqual(verify,self.next_action('US-1.1'))
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        self.run_cli('--session-id','owner','delivery','refresh')
        self.assertEqual(verify,json.loads(self.run_cli('--session-id','owner','delivery','refresh','--json').stdout))
        stop=self.hook('stop',code=2)
        self.assertEqual(STOP_BLOCK.format(target='US-1.1',action='verify',story='US-1.1',change='selected',
                                           command=verify['command'],reason=verify['reason'],n=1,max=3),stop.stderr)
        self.hook('pre-bash',{'command':'openspec archive selected -y'})
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: READY','new_string':'Status: DONE'},code=2)
        self.hook('post-write',{'file_path':'openspec/changes/selected/tasks.md','content':'unused'})
        self.assertEqual(json.loads(self.run_cli('guard-archive','--change','selected','--json').stdout),
                         {'change':'selected','archiveEligible':True,'blocked':False})
        self.run_cli('--session-id','owner','delivery','stop')
        self.assertEqual(expected,leftovers(change))
        archived=self.archive()
        self.assertEqual('mark-done',self.next_action('US-1.1')['action'])
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: READY','new_string':'Status: DONE'})
        self.assertEqual(expected,leftovers(archived))
        goal=(self.root/'openspec/delivery/goal.md').read_text()
        self.assertNotIn('Owner',goal)

    def test_session_lease_stalls_and_takeover(self):
        self.activate()
        self.change()
        (self.root/'openspec/changes/selected/status.md').write_text(LEFTOVERS['status.md'])
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        # A command that fails for the session already holding the lease keeps the lease.
        self.run_cli('--session-id','owner','delivery','start','US-1.3',code=1)
        before=self.snapshot()
        self.hook('stop',session='spectator')
        self.hook('stop',agent='general-purpose')
        self.assertEqual(before,self.snapshot())
        # Every goal writer is refused to another session, and nothing is written.
        for command in [['refresh'],['stop'],['block','--reason','x'],['start','US-1.1']]:
            refused=self.run_cli('--session-id','spectator','delivery',*command,code=2)
            self.assertEqual('OhMyOrch: delivery is owned by session owner; explicit --takeover required\n',refused.stderr,command)
        self.assertEqual(before,self.snapshot())
        # Delivery state belongs to the session that owns the goal; nothing else does.
        specs=(self.root/'SPECS.md').read_text()
        for target in ['SPECS.md','openspec/delivery/goal.md','openspec/delivery/notes.md']:
            denied=self.hook('pre-write',{'file_path':target,'content':specs},session='spectator',code=2)
            self.assertEqual(LEASE_DENIED,denied.stderr)
        leased=self.hook('pre-write',{'file_path':'SPECS.md','content':specs},session='spectator',agent='ohmyorch:spec-ingestor',code=2)
        self.assertEqual(LEASE_DENIED,leased.stderr)
        for target in ['src/app.ts','openspec/changes/selected/tasks.md','openspec/changes/selected/status.md',
                       'openspec/changes/selected/completion.md']:
            self.hook('pre-write',{'file_path':target,'content':'text'},session='spectator')
        self.hook('pre-write',{'file_path':'SPECS.md','content':specs})
        self.assertEqual(before,self.snapshot())
        blocked=dict(target='US-1.1',action='apply',story='US-1.1',change='selected',
                     command='/ohmyorch:opsx-apply selected',reason='0/1 tasks complete',max=3)
        for attempt in range(1,4):
            # Identity is the protocol field: a message that mentions one is still the main session.
            stop=self.hook('stop',code=2,last_assistant_message='Subagent payloads carry "agent_id": "specialist".')
            self.assertEqual(STOP_BLOCK.format(n=attempt,**blocked),stop.stderr)
            self.assertEqual('',stop.stdout)
            self.assertIn(f'count={attempt}\n',(self.root/'.claude/ohmyorch/runtime/owner/loop.state').read_text())
        halted=json.loads(self.hook('stop').stdout)
        self.assertEqual({'systemMessage':"Delivery goal US-1.1 recorded BLOCKED — no progress: next action 'apply' for US-1.1 "
                          'unchanged across 4 stop attempts. Inspect ohmyorch delivery next, then run /ohmyorch:deliver US-1.1 to resume.'},halted)
        goal=(self.root/'openspec/delivery/goal.md').read_text()
        self.assertIn('| Status | BLOCKED |',goal)
        self.assertIn("| Reason | no progress: next action 'apply' for US-1.1 unchanged across 4 stop attempts |",goal)
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/delivery.owner').exists())
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/owner/loop.state').exists())
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        # Progress resets the count: a ticked task changes the derived action.
        self.hook('stop',code=2);self.hook('stop',code=2)
        (self.root/'openspec/changes/selected/tasks.md').write_text('- [x] pending\n')
        progressed=self.hook('stop',code=2)
        self.assertIn('Next action: verify  (story: US-1.1, change: selected)\n',progressed.stderr)
        self.assertIn('Unchanged stop attempts: 1 of 3 allowed.\n',progressed.stderr)
        self.run_cli('--session-id','replacement','--takeover','delivery','refresh')
        owner=json.loads((self.root/'.claude/ohmyorch/runtime/delivery.owner/owner.json').read_text())
        self.assertEqual('replacement',owner['sessionId'])
        self.hook('stop',session='owner')
        former=self.hook('pre-write',{'file_path':'SPECS.md','content':'text'},session='owner',code=2)
        self.assertEqual(LEASE_DENIED,former.stderr)

    def test_stop_hook_records_escalation_and_completion(self):
        self.activate()
        goal=self.root/'openspec/delivery/goal.md'
        owner=self.root/'.claude/ohmyorch/runtime/delivery.owner'
        self.run_cli('--session-id','owner','delivery','start','US-1.2')
        self.assertTrue(owner.exists())
        escalated=json.loads(self.hook('stop').stdout)
        self.assertEqual({'systemMessage':'Delivery goal US-1.2 recorded BLOCKED — a human decision is required: '
                          'US-1.2 is NEEDS CLARIFICATION, not READY. Resolve it, then run /ohmyorch:deliver US-1.2 to resume.'},escalated)
        self.assertIn('| Status | BLOCKED |',goal.read_text())
        self.assertIn('| Reason | escalate: US-1.2 is NEEDS CLARIFICATION, not READY |',goal.read_text())
        self.assertFalse(owner.exists())
        silent=self.hook('stop')
        self.assertEqual('',silent.stdout+silent.stderr)
        # A different goal may start once the previous one is no longer ACTIVE or BLOCKED.
        # A start that fails without a lease held beforehand leaves none behind.
        self.run_cli('--session-id','owner','delivery','start','US-1.3',code=1)
        self.assertFalse(owner.exists())
        self.run_cli('--session-id','owner','delivery','start','US-1.2')
        self.assertTrue(owner.exists())
        # The owner's own block and stop record the halt and release the lease.
        self.run_cli('--session-id','owner','delivery','block','--reason','owner decision')
        self.assertIn('| Status | BLOCKED |',goal.read_text())
        self.assertIn('| Reason | owner decision |',goal.read_text())
        self.assertFalse(owner.exists())
        self.run_cli('--session-id','owner','delivery','start','US-1.2')
        self.assertTrue(owner.exists())
        self.run_cli('--session-id','owner','delivery','stop','--reason','switching goals')
        self.assertIn('| Status | STOPPED |',goal.read_text())
        self.assertFalse(owner.exists())
        # An ACTIVE goal whose last story becomes DONE is recorded COMPLETE by the stop.
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        self.assertIn('| Status | ACTIVE |',goal.read_text())
        self.hook('stop',code=2)
        specs=self.root/'SPECS.md'
        specs.write_text(specs.read_text().replace('Status: READY','Status: DONE'))
        completed=json.loads(self.hook('stop').stdout)
        self.assertEqual({'systemMessage':'Delivery goal US-1.1 is COMPLETE — every story is DONE.'},completed)
        self.assertIn('| Status | COMPLETE |',goal.read_text())
        self.assertIn('Action: complete\n',goal.read_text())
        self.assertFalse(owner.exists())
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/owner/loop.state').exists())
        # A goal that is already complete when it starts never holds a session.
        self.run_cli('--session-id','owner','delivery','start','US-1.3')
        self.assertIn('| Target | US-1.3 |',goal.read_text())
        self.assertIn('| Status | COMPLETE |',goal.read_text())
        silent=self.hook('stop')
        self.assertEqual('',silent.stdout+silent.stderr)
        self.assertFalse(owner.exists())
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/operation.lock').exists())

    def test_owner_block_for_a_human_decision_lets_the_stop_through(self):
        self.activate()
        self.change()
        goal=self.root/'openspec/delivery/goal.md'
        owner=self.root/'.claude/ohmyorch/runtime/delivery.owner'
        state=self.root/'.claude/ohmyorch/runtime/owner/loop.state'
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        # Work remains, so the Stop hook refuses the stop: it cannot see a question.
        self.hook('stop',code=2)
        self.assertTrue(state.exists())
        reason='US-1.1: does the greeting keep its punctuation?'
        blocked=self.run_cli('--session-id','owner','delivery','block','--reason',reason)
        self.assertEqual(f'Goal US-1.1 recorded as BLOCKED — {reason}\n',blocked.stdout)
        self.assertIn('| Status | BLOCKED |',goal.read_text())
        self.assertIn(f'| Reason | {reason} |',goal.read_text())
        self.assertFalse(owner.exists())
        self.assertFalse(state.exists())
        # The recorded decision lets the same session stop, silently and unchanged.
        before=self.snapshot()
        silent=self.hook('stop')
        self.assertEqual('',silent.stdout+silent.stderr)
        self.assertEqual(before,self.snapshot())
        # The same target resumes the goal, and stalls are counted from zero.
        resumed=self.run_cli('--session-id','owner','delivery','start','US-1.1')
        self.assertIn('GOAL  US-1.1 (story) — ACTIVE\n',resumed.stdout)
        self.assertIn('| Status | ACTIVE |',goal.read_text())
        self.assertIn('| Reason | - |',goal.read_text())
        self.assertTrue(owner.exists())
        again=self.hook('stop',code=2)
        self.assertIn('Next action: apply  (story: US-1.1, change: selected)\n',again.stderr)
        self.assertIn('Unchanged stop attempts: 1 of 3 allowed.\n',again.stderr)

    def test_derivation_needs_no_openspec_cli_and_no_plugin_cli(self):
        self.activate()
        self.change(True)
        env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin'}
        if shutil.which('openspec',path=env['PATH']): self.skipTest('openspec is installed in a system directory')
        action=self.next_action('US-1.1','--session-id','actual-session',env=env)
        self.assertEqual(['target','action','story','change','command','reason'],list(action))
        self.assertEqual('verify',action['action'])
        self.assertEqual('/ohmyorch:opsx-verify selected; with no CRITICAL issue, run a separate Bash call: openspec archive selected -y',action['command'])
        self.assertIn('separate Bash call',action['command'])
        for fragment in ['&&','bin/ohmyorch','--project-root','--session-id',str(self.root),'completion-gate']:
            self.assertNotIn(fragment,action['command'])
        self.assertEqual(json.loads(self.run_cli('guard-archive','--change','selected','--json',env=env).stdout)['archiveEligible'],True)
        text=self.run_cli('delivery','next','US-1.1',env=env).stdout
        self.assertEqual(['Action:  verify','Story:   US-1.1','Change:  selected','Command: '+action['command'],
                          'Reason:  1/1 tasks complete; verify, then archive'],text.splitlines())
        # Starting a goal is the one step that checks the supported OpenSpec version.
        goal=self.root/'openspec/delivery/goal.md'
        missing=self.run_cli('--session-id','owner','delivery','start','US-1.1',code=2,env=env)
        self.assertIn('OpenSpec 1.13.2 is required',missing.stderr)
        stubs=Path(self.work.name)/'stub-bin';stubs.mkdir()
        stub=stubs/'openspec';stub.write_text('#!/bin/sh\necho 1.12.0\n');stub.chmod(0o755)
        stubbed={'PATH':f"{stubs}:{env['PATH']}"}
        other=self.run_cli('--session-id','owner','delivery','start','US-1.1',code=2,env=stubbed)
        self.assertIn('OpenSpec 1.13.2',other.stderr)
        self.assertFalse(goal.exists())
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/delivery.owner').exists())
        # Nothing else ever runs the CLI: with a stub that records every call, the
        # derivation, both guards and the Stop loop decide exactly as before.
        stub.write_text('#!/bin/sh\ncase "$1" in --version) echo 1.13.2; exit 0 ;; esac\n'
                        'echo "$@" >> "$(dirname "$0")/calls"\nexit 1\n')
        self.assertEqual(action,self.next_action('US-1.1',env=stubbed))
        self.hook('pre-bash',{'command':'openspec archive selected -y'},env=stubbed)
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: READY','new_string':'Status: DONE'},code=2,env=stubbed)
        self.run_cli('--session-id','owner','delivery','start','US-1.1',env=stubbed)
        self.run_cli('--session-id','owner','delivery','refresh','--json',env=stubbed)
        self.hook('stop',code=2,env=stubbed)
        self.hook('post-write',{'file_path':'SPECS.md','content':'unused'},env=stubbed)
        self.run_cli('--session-id','owner','delivery','stop',env=stubbed)
        self.assertFalse((stubs/'calls').exists())

    def test_missing_bundled_dependency_is_blocked(self):
        self.activate()
        self.change()
        # Every hook event, with a payload a complete install lets through untouched.
        events=[('pre-write',{'file_path':'src/app.ts','content':'text'}),
                ('post-write',{'file_path':'src/app.ts','content':'text'}),
                ('pre-bash',{'command':'git status'}),('session-context',None),('stop',None)]
        for mode,tool_input in events:
            self.hook(mode,tool_input)
        project='.claude/ohmyorch/project.json'
        # A script the runtime itself requires: every hook event and every operation
        # fails closed and names it. It is a broken install, not a configuration
        # fault, so the project.json repair route does not open either.
        for missing in ['validate-product-artifacts','delivery']:
            clone,_=self.clone_plugin('without-'+missing,without=[missing])
            unusable,_=self.clone_plugin('unusable-'+missing)
            (unusable/'scripts'/f'{missing}.sh').chmod(0o644)
            for plugin in [clone,unusable]:
                for mode,tool_input in events+[('pre-write',{'file_path':'SPECS.md','content':'text'}),
                                               ('pre-write',{'file_path':project,'content':json.dumps(CONFIG)}),
                                               ('pre-bash',{'command':'openspec archive selected -y'})]:
                    refused=self.hook(mode,tool_input,plugin=plugin,code=2)
                    self.assertEqual(MISSING_SCRIPT.format(name=missing),refused.stderr,(missing,mode))
                    self.assertEqual('',refused.stdout)
            # Each operation would otherwise succeed here: the refusal is the rule's own.
            for arguments in [['delivery','next','US-1.1'],['guard-archive','--change','never-existed'],
                              ['guard-story-done','--file','SPECS.md','--content','Status: READY'],
                              ['guard-context-preflight','--file','README.md'],
                              ['validate-product-artifacts','--quiet'],['run-project-validation']]:
                self.run_cli(*arguments)
                refused=self.run_cli(*arguments,code=2,plugin=clone)
                self.assertEqual(MISSING_SCRIPT.format(name=missing),refused.stderr,arguments)
                self.assertEqual('',refused.stdout)
            report=json.loads(self.run_cli('doctor','--json',code=1,plugin=clone).stdout)
            self.assertEqual(['bundled-'+missing],[c['name'] for c in report['checks'] if c['status']=='FAIL'])
        # With both gone, hooks and operations name the same one first.
        clone,_=self.clone_plugin('without-both',without=['delivery','validate-product-artifacts'])
        self.assertEqual(MISSING_SCRIPT.format(name='delivery'),self.hook('stop',plugin=clone,code=2).stderr)
        self.assertEqual(MISSING_SCRIPT.format(name='delivery'),
                         self.run_cli('guard-archive','--change','never-existed',code=2,plugin=clone).stderr)
        # A script only the hooks need: every hook event fails closed and names it.
        for missing in ['guard-archive','guard-story-done','guard-context-preflight','guard-delivery-loop']:
            clone,_=self.clone_plugin('without-'+missing,without=[missing])
            for mode,tool_input in events:
                refused=self.hook(mode,tool_input,plugin=clone,code=2)
                self.assertEqual(MISSING_SCRIPT.format(name=missing),refused.stderr)
                self.assertEqual('',refused.stdout)
            self.assertEqual('apply',self.next_action('US-1.1',plugin=clone)['action'])
            gone=self.run_cli(missing,'--help',code=2,plugin=clone)
            self.assertEqual(f'OhMyOrch: missing bundled operation: {missing}\n',gone.stderr)
            report=json.loads(self.run_cli('doctor','--json',code=1,plugin=clone).stdout)
            self.assertEqual(['bundled-'+missing],[c['name'] for c in report['checks'] if c['status']=='FAIL'])
        # An unusable project.json is a configuration fault whatever the install lacks:
        # the repair route stays open, and only that write passes.
        clone,_=self.clone_plugin('without-delivery-invalid-config',without=['delivery'])
        self.config['schemaVersion']=99
        (self.root/project).write_text(json.dumps(self.config))
        repaired=self.hook('pre-write',{'file_path':project,'content':json.dumps(CONFIG)},plugin=clone)
        self.assertEqual('',repaired.stdout+repaired.stderr)
        for mode,tool_input in [('pre-write',{'file_path':'src/app.ts','content':'text'}),('pre-bash',{'command':'git status'})]:
            refused=self.hook(mode,tool_input,plugin=clone,code=2)
            self.assertEqual('OhMyOrch: invalid project configuration; repair project.json explicitly\n',refused.stderr)

    def test_every_refusal_names_its_reason(self):
        self.activate()
        # A malformed payload is refused with one line on stderr, never silently.
        malformed_write=('OhMyOrch: malformed write payload: tool_input must be an object whose target paths '
                         'are strings without control characters\n')
        for mode in ['pre-write','post-write']:
            for tool_input in ['text',['SPECS.md'],{'file_path':7},{'file_path':'a\nb.md','content':'text'},
                               {'file_path':'ok.md','edits':[{'file_path':'bad\tname.md'}]},{'files':[{'file_path':{}}]}]:
                refused=self.hook(mode,tool_input,code=2)
                self.assertEqual(malformed_write,refused.stderr,(mode,tool_input))
                self.assertEqual('',refused.stdout)
        no_target=self.hook('pre-write',{'content':'text'},code=2)
        self.assertEqual('OhMyOrch: write payload has no supported target paths\n',no_target.stderr)
        for tool_input in [None,'text',{},{'command':7},{'command':None},{'command':['openspec','archive','selected']}]:
            refused=self.hook('pre-bash',tool_input,code=2)
            self.assertEqual('OhMyOrch: malformed Bash payload: tool_input.command must be a string\n',refused.stderr,tool_input)
            self.assertEqual('',refused.stdout)
        def dispatch(mode,payload):
            return subprocess.run(['bash',str(PLUGIN/'hooks/dispatch.sh'),'--project-root',str(self.root),'--mode',mode],
                                  input=json.dumps(payload),text=True,capture_output=True)
        event={'hook_event_name':'PreToolUse','session_id':'owner','cwd':str(self.root)}
        for mode,payload,reason in [('bogus',event,'unknown dispatcher mode: bogus'),
                                    ('stop',event,'hook event/mode mismatch'),
                                    ('pre-bash',{**event,'session_id':''},'malformed hook input in activated project'),
                                    ('pre-bash',[event],'malformed hook input in activated project')]:
            refused=dispatch(mode,payload)
            self.assertEqual((2,'',f'OhMyOrch: {reason}\n'),(refused.returncode,refused.stdout,refused.stderr),(mode,reason))
        # The refusal for a missing backlog names the document the project maps.
        for docs,mapped in [('root','SPECS.md'),('docs','docs/SPECS.md')]:
            self.activate(docs)
            self.specs_file().unlink()
            refused=self.run_cli('delivery','next','US-1.1',code=1)
            self.assertEqual(f'error: {mapped} not found (the mapped SPECS document)\n',refused.stderr)
            self.assertEqual('',refused.stdout)

    def test_configured_stall_limit_is_honoured(self):
        blocked=dict(target='US-1.1',action='apply',story='US-1.1',change='selected',
                     command='/ohmyorch:opsx-apply selected',reason='0/1 tasks complete')
        goal=self.root/'openspec/delivery/goal.md'
        # delivery.maxStalls is the number of unchanged stop attempts that are blocked.
        self.config['delivery']['maxStalls']=1
        directory=self.activate()
        self.change()
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        stop=self.hook('stop',code=2)
        self.assertEqual(STOP_BLOCK.format(n=1,max=1,**blocked),stop.stderr)
        halted=json.loads(self.hook('stop').stdout)
        self.assertEqual({'systemMessage':"Delivery goal US-1.1 recorded BLOCKED — no progress: next action 'apply' for US-1.1 "
                          'unchanged across 2 stop attempts. Inspect ohmyorch delivery next, then run /ohmyorch:deliver US-1.1 to resume.'},halted)
        self.assertIn("| Reason | no progress: next action 'apply' for US-1.1 unchanged across 2 stop attempts |",goal.read_text())
        # Raised, the same project blocks that many attempts before it gives up.
        self.config['delivery']['maxStalls']=5
        (directory/'project.json').write_text(json.dumps(self.config))
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        for attempt in range(1,6):
            stop=self.hook('stop',code=2)
            self.assertEqual(STOP_BLOCK.format(n=attempt,max=5,**blocked),stop.stderr)
        self.assertIn('unchanged across 6 stop attempts',json.loads(self.hook('stop').stdout)['systemMessage'])
        # Zero blocks nothing: the first unchanged attempt is recorded and allowed.
        self.config['delivery']['maxStalls']=0
        (directory/'project.json').write_text(json.dumps(self.config))
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        self.assertIn('unchanged across 1 stop attempt.',json.loads(self.hook('stop').stdout)['systemMessage'])
        self.assertIn('| Status | BLOCKED |',goal.read_text())

    def test_adapt_project_refreshes_an_unedited_scaffolded_openspec_config(self):
        if not shutil.which('openspec'): self.skipTest('OpenSpec initialization prerequisite missing')
        # A project as 0.0.1 scaffolded it, staged by a payload that differs only in that line.
        previous,_=self.clone_plugin('previous-config')
        template=PLUGIN/'templates/project/openspec/config.yaml'
        current=template.read_text()
        self.assertEqual(1,current.count(CURRENT_CONTEXT))
        scaffolded=current.replace(CURRENT_CONTEXT,PREVIOUS_CONTEXT)
        (previous/'templates/project/openspec/config.yaml').write_text(scaffolded)
        self.run_cli('bootstrap','--apply','--with-openspec',plugin=previous)
        self.run_cli('adapt-project','--apply',plugin=previous)
        config=self.root/'openspec/config.yaml'
        ledger=self.root/'.claude/ohmyorch/managed-files.json'
        self.assertEqual(scaffolded,config.read_text())
        def entry(): return json.loads(ledger.read_text())['files']['openspec/config.yaml']
        def planned(operation,*arguments):
            return [item['path'] for item in json.loads(self.run_cli(operation,*arguments,'--dry-run').stdout)['files']]
        self.assertEqual('scaffold',entry()['kind'])
        # Edited by hand it is the project's own: not planned, not touched, not a conflict.
        edited=scaffolded+'rules:\n  proposal:\n    - Keep it short.\n'
        config.write_text(edited)
        self.assertNotIn('openspec/config.yaml',planned('adapt-project'))
        untouched=self.run_cli('adapt-project','--apply')
        self.assertNotIn('config.yaml',untouched.stdout+untouched.stderr)
        self.assertEqual(edited,config.read_text())
        # Unedited, the preview lists it and writes nothing...
        config.write_text(scaffolded)
        before=self.snapshot()
        preview=json.loads(self.run_cli('adapt-project','--dry-run').stdout)
        self.assertIn('openspec/config.yaml',[item['path'] for item in preview['files']])
        self.assertEqual(before,self.snapshot())
        # ...and the reviewed plan replaces it with the current template, keeping a backup.
        self.run_cli('adapt-project','--apply','--plan-id',preview['planId'])
        self.assertEqual(current,config.read_text())
        self.assertIn(CURRENT_CONTEXT,config.read_text())
        self.assertNotIn(PREVIOUS_CONTEXT,config.read_text())
        self.assertEqual('scaffold',entry()['kind'])
        self.assertEqual(hashlib.sha256(current.encode()).hexdigest(),entry()['sha256'])
        backups=[path.read_text() for path in (self.root/'.claude/ohmyorch/backups').glob('*/files/openspec/config.yaml')]
        self.assertIn(scaffolded,backups)
        applied=self.snapshot()
        self.assertNotIn('openspec/config.yaml',planned('adapt-project'))
        self.run_cli('adapt-project','--apply')
        self.assertEqual(applied,self.snapshot())
        # It stays a scaffold: a harness reset neither plans nor deletes it.
        self.assertNotIn('openspec/config.yaml',planned('harness-reset'))
        self.run_cli('harness-reset','--apply')
        self.assertEqual(current,config.read_text())
        # A config the plugin never recorded is left alone even when it is the old text.
        self.root=Path(self.work.name)/'host with a config of its own'
        self.root.mkdir()
        self.run_cli('bootstrap','--apply')
        config=self.root/'openspec/config.yaml'
        config.parent.mkdir()
        config.write_text(scaffolded)
        self.assertNotIn('openspec/config.yaml',planned('adapt-project'))
        self.run_cli('adapt-project','--apply')
        self.assertEqual(scaffolded,config.read_text())

    def test_interrupted_apply_rolls_back_and_private_backups(self):
        self.run_cli('bootstrap','--apply',code=2,env={'OHMYORCH_FAIL_AFTER':'2'})
        self.assertFalse((self.root/'PRD.md').exists())
        self.assertFalse((self.root/'SPECS.md').exists())
        self.assertFalse((self.root/'.claude/ohmyorch/project.json').exists())
        journals=list((self.root/'.claude/ohmyorch/backups').rglob('journal.json'))
        self.assertEqual(1,len(journals))
        self.assertEqual('rolled-back',json.loads(journals[0].read_text())['status'])
        self.assertEqual(0o700,journals[0].parent.stat().st_mode&0o777)
        self.run_cli('bootstrap','--apply')
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/operation.lock').exists())

    def test_managed_merge_conflicts_and_hash_guarded_recovery(self):
        self.run_cli('bootstrap','--apply')
        before=self.snapshot()
        self.run_cli('adapt-project','--apply')
        self.assertEqual(4,len(list((self.root/'.claude/rules').glob('*.md'))))
        applied=self.snapshot()
        self.run_cli('adapt-project','--apply')
        self.assertEqual(applied,self.snapshot())
        rule=self.root/'.claude/rules/ohmyorch-testing-standards.md'
        rule.write_text(rule.read_text()+'\nHuman edit\n')
        self.run_cli('adapt-project','--apply',code=2)
        self.assertTrue(rule.read_text().endswith('Human edit\n'))
        journal=max((self.root/'.claude/ohmyorch/backups').glob('*/journal.json'),key=lambda p:p.stat().st_mtime_ns)
        self.run_cli('upgrade-project','--apply','--rollback',journal.parent.name,code=2)
        self.assertTrue(rule.read_text().endswith('Human edit\n'))
        self.assertEqual(before['PRD.md'],self.snapshot()['PRD.md'])

    def test_reset_is_bounded_and_requires_reviewed_hash(self):
        self.run_cli('bootstrap','--apply')
        (self.root/'scripts').mkdir()
        host=self.root/'scripts/host.sh';host.write_text('echo human-owned\n')
        (self.root/'src').mkdir();(self.root/'src/CLAUDE.md').write_text('nested human-owned')
        self.change()
        self.run_cli('harness-reset','--scope','workflow','--apply',code=2)
        preview=json.loads(self.run_cli('harness-reset','--scope','workflow','--dry-run').stdout)
        self.run_cli('harness-reset','--scope','workflow','--apply','--plan-id',preview['planId'])
        self.assertEqual('echo human-owned\n',host.read_text())
        self.assertEqual('nested human-owned',(self.root/'src/CLAUDE.md').read_text())
        self.assertFalse((self.root/'openspec/changes/selected/tasks.md').exists())

    def test_host_script_requires_current_ignored_approval(self):
        self.run_cli('bootstrap','--apply')
        subprocess.run(['git','init','-q',str(self.root)],check=True)
        d=self.root/'scripts';d.mkdir()
        script=d/'fast-validate.sh';script.write_text('#!/bin/bash\nprintf executed > marker\n');script.chmod(0o755)
        config=json.loads((self.root/'.claude/ohmyorch/project.json').read_text())
        config['fastValidation']['enabled']=True
        (self.root/'.claude/ohmyorch/project.json').write_text(json.dumps(config))
        self.run_cli('run-project-validation')
        self.assertFalse((self.root/'marker').exists())
        self.run_cli('run-project-validation','--approve-current')
        self.assertFalse((self.root/'marker').exists())
        self.run_cli('run-project-validation')
        self.assertTrue((self.root/'marker').exists())
        (self.root/'marker').unlink()
        script.write_text(script.read_text()+'# changed\n')
        self.run_cli('run-project-validation')
        self.assertFalse((self.root/'marker').exists())

    def test_post_write_runs_fast_validation_only_when_enabled(self):
        self.run_cli('bootstrap','--apply')
        subprocess.run(['git','init','-q',str(self.root)],check=True)
        d=self.root/'scripts';d.mkdir()
        script=d/'fast-validate.sh';script.write_text('#!/bin/bash\nprintf executed > marker\n');script.chmod(0o755)
        marker=self.root/'marker'
        project=self.root/'.claude/ohmyorch/project.json'
        def configure(enabled):
            config=json.loads(project.read_text());config['fastValidation']['enabled']=enabled
            project.write_text(json.dumps(config))
        write={'file_path':'src/app.ts','content':'unused'}
        tripwired,log=self.clone_plugin('tripwired-validation',tripwire=['run-project-validation'])
        absent,_=self.clone_plugin('without-validation',without=['run-project-validation'])
        def exported():
            # What a script spawned after initialization inherits from the runtime.
            probe='source "$1/lib/runtime.sh"; ohmyorch_init --project-root "$2"; /bin/bash -c \'printf %s "$OHMYORCH_FAST_VALIDATION"\''
            return subprocess.run(['/bin/bash','-c',probe,'probe',str(PLUGIN),str(self.root)],text=True,capture_output=True,check=True).stdout
        # Disabled (the bootstrap default): the validation script is not even spawned.
        self.assertFalse(json.loads(project.read_text())['fastValidation']['enabled'])
        self.assertEqual('false',exported())
        self.run_cli('run-project-validation','--approve-current')
        for plugin in [PLUGIN,tripwired,absent]:
            silent=self.hook('post-write',write,plugin=plugin)
            self.assertEqual('',silent.stdout+silent.stderr)
        self.assertEqual([],self.spawned(log))
        self.assertFalse(marker.exists())
        # Enabled: spawned for every written file, and it runs only an approved script.
        configure(True)
        self.assertEqual('true',exported())
        self.hook('post-write',write,plugin=tripwired,code=2)
        self.assertEqual(['run-project-validation'],self.spawned(log))
        self.hook('post-write',write,plugin=absent,code=2)
        ran=self.hook('post-write',write)
        self.assertEqual('',ran.stdout)
        self.assertEqual('executed',marker.read_text())
        marker.unlink()
        script.write_text('#!/bin/bash\nprintf executed > marker\nexit 1\n')
        skipped=self.hook('post-write',write)
        self.assertIn('SKIP: script has no current hash-bound local approval',skipped.stderr)
        self.assertEqual('',skipped.stdout)
        self.assertFalse(marker.exists())
        self.run_cli('run-project-validation','--approve-current')
        failed=self.hook('post-write',write,code=2)
        self.assertEqual('',failed.stdout)
        self.assertTrue(marker.exists())
        marker.unlink()
        # Disabled again: an approved failing script is neither run nor mentioned.
        configure(False)
        silent=self.hook('post-write',write)
        self.assertEqual('',silent.stdout+silent.stderr)
        self.assertFalse(marker.exists())
        # An unconfigured project has no fast validation to enable.
        project.unlink()
        self.assertEqual('false',exported())

    def test_legacy_cutover_preserves_custom_settings_and_can_roll_back(self):
        legacy=self.root/'.claude/agents/ohmyorch-reviewer.md'
        legacy.parent.mkdir(parents=True)
        legacy.write_bytes((REPO/'tests/fixtures/legacy/reviewer.md').read_bytes())
        custom=legacy.parent/'custom.md';custom.write_text('Human customization')
        handlers=json.loads((PLUGIN/'references/legacy-hooks.json').read_text())
        handler=next(h for h in handlers if h['event']=='PreToolUse' and h['matcher']=='Write|Edit|MultiEdit')
        settings={'env':{'PREFERENCE':'fixture'}, 'hooks':{'PreToolUse':[{'matcher':handler['matcher'], 'hooks':[{'type':'command','command':handler['command']},{'type':'command','command':'echo user-owned'}]}]}}
        settings_file=self.root/'.claude/settings.json';settings_file.write_text(json.dumps(settings))
        before=self.snapshot()
        plan=json.loads(self.run_cli('migrate-legacy','--dry-run').stdout)
        self.assertEqual(before,self.snapshot())
        self.run_cli('migrate-legacy','--apply',code=2)
        self.run_cli('migrate-legacy','--apply','--plan-id',plan['planId'])
        self.assertFalse(legacy.exists())
        self.assertEqual('Human customization',custom.read_text())
        after=json.loads(settings_file.read_text())
        self.assertEqual(settings['env'],after['env'])
        self.assertEqual(['echo user-owned'],[h['command'] for h in after['hooks']['PreToolUse'][0]['hooks']])
        journal=next((self.root/'.claude/ohmyorch/backups').glob('*/journal.json'))
        op=journal.parent.name
        state_before=self.snapshot()
        self.run_cli('upgrade-project','--dry-run','--rollback',op)
        self.assertEqual(state_before,self.snapshot())
        self.run_cli('upgrade-project','--apply','--rollback',op)
        for path,value in before.items(): self.assertEqual(value,self.snapshot()[path])
        self.assertFalse((self.root/'.claude/ohmyorch/project.json').exists())

    def test_edited_legacy_components_and_stale_plan(self):
        legacy=self.root/'.claude/agents/ohmyorch-reviewer.md'
        legacy.parent.mkdir(parents=True)
        legacy.write_text('Locally edited specialist')
        self.run_cli('migrate-legacy','--dry-run',code=2)
        plan=json.loads(self.run_cli('migrate-legacy','--include-edited','--dry-run').stdout)
        legacy.write_text('Another edit after preview')
        self.run_cli('migrate-legacy','--include-edited','--apply','--plan-id',plan['planId'],code=2)
        self.assertEqual('Another edit after preview',legacy.read_text())

    def test_post_hook_has_protocol_clean_stdout(self):
        self.activate()
        for target in ['SPECS.md','PRD.md','CODEBASE.md']:
            validated=self.hook('post-write',{'file_path':target,'content':'unused'})
            self.assertEqual('',validated.stdout)
        # With fast validation disabled an ordinary file is not worth a single line.
        for agent in [None,'general-purpose','ohmyorch:spec-ingestor']:
            silent=self.hook('post-write',{'file_path':'src/app.ts','content':'unused'},agent=agent)
            self.assertEqual('',silent.stdout+silent.stderr)
        # A written document that breaks the artifact contract blocks, on stderr only.
        (self.root/'SPECS.md').write_text((self.root/'SPECS.md').read_text().replace('Status: READY','Status: ALMOST'))
        broken=self.hook('post-write',{'file_path':'SPECS.md','content':'unused'},code=2)
        self.assertEqual('',broken.stdout)
        self.assertNotEqual('',broken.stderr)

    def test_openspec_initialization_and_old_counter_upgrade(self):
        if not shutil.which('openspec'): self.skipTest('OpenSpec initialization prerequisite missing')
        self.run_cli('bootstrap','--apply','--with-openspec')
        config=(self.root/'openspec/config.yaml').read_text()
        self.assertIn('schema: spec-driven',config)
        self.assertIn('Each READY story is delivered as one OpenSpec change: propose, apply, verify, archive.',config)
        self.assertFalse((self.root/'.claude/skills').exists())
        first=self.snapshot()
        self.run_cli('bootstrap','--apply','--with-openspec')
        self.assertEqual(first,self.snapshot())
        old=self.root/'openspec/delivery/loop.state';old.write_text('count=2\n')
        goal=self.root/'openspec/delivery/goal.md';goal.write_text('Durable goal unchanged')
        self.run_cli('upgrade-project','--apply')
        self.assertFalse(old.exists())
        self.assertEqual('count=2\n',(self.root/'.claude/ohmyorch/runtime/legacy-loop.state').read_text())
        self.assertEqual('Durable goal unchanged',goal.read_text())

    def test_real_openspec_change_from_verify_through_archive_to_done(self):
        if not shutil.which('openspec'): self.skipTest('OpenSpec prerequisite missing')
        quiet={**os.environ,'OPENSPEC_TELEMETRY':'0','DO_NOT_TRACK':'1'}
        self.run_cli('bootstrap','--apply','--with-openspec')
        self.activate()
        change=self.change()
        (change/'specs/spec.md').unlink()
        capability=change/'specs/widget';capability.mkdir()
        (capability/'spec.md').write_text('## ADDED Requirements\n\n### Requirement: Widget response\nThe system SHALL return a successful widget response.\n\n#### Scenario: Successful widget request\n- **WHEN** the user requests a widget\n- **THEN** the system returns the widget\n')
        result=subprocess.run(['openspec','validate','selected','--json'],cwd=self.root,text=True,capture_output=True,env=quiet)
        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
        self.assertTrue(json.loads(result.stdout)['items'][0]['valid'])
        # apply: an unticked task keeps the archive shut.
        self.assertEqual('apply',self.next_action('US-1.1')['action'])
        self.hook('pre-bash',{'command':'openspec archive selected -y'},code=2)
        (change/'tasks.md').write_text('- [x] completed\n')
        # verify: every task ticked, the archive command is handed over and allowed.
        action=self.next_action('US-1.1')
        self.assertEqual('verify',action['action'])
        self.assertTrue(action['command'].endswith('run a separate Bash call: openspec archive selected -y'))
        self.hook('pre-bash',{'command':'openspec archive selected -y'})
        done=(self.root/'SPECS.md').read_text().replace('Status: READY','Status: DONE',1)
        self.hook('pre-write',{'file_path':'SPECS.md','content':done},code=2)
        # archive: the real CLI validates and merges the delta spec and moves the change.
        archive=subprocess.run(['openspec','archive','selected','-y'],cwd=self.root,text=True,capture_output=True,env=quiet)
        self.assertEqual(0,archive.returncode,archive.stdout+archive.stderr)
        self.assertFalse(change.exists())
        archived=[p for p in (self.root/'openspec/changes/archive').iterdir() if p.is_dir()]
        self.assertEqual(1,len(archived))
        self.assertTrue(archived[0].name.endswith('-selected'))
        self.assertEqual(['proposal.md','specs','tasks.md'],sorted(p.name for p in archived[0].iterdir() if not p.name.startswith('.')))
        self.assertIn('Widget response',(self.root/'openspec/specs/widget/spec.md').read_text())
        # mark-done: the DONE edit is now the only step left, and it is allowed.
        action=self.next_action('US-1.1')
        self.assertEqual('mark-done',action['action'])
        self.assertEqual('change selected is archived but US-1.1 is READY',action['reason'])
        done=done.replace('openspec/changes/selected/',f'openspec/changes/archive/{archived[0].name}/').replace('- [ ] t','- [x] t',1)
        self.hook('pre-write',{'file_path':'SPECS.md','content':done})
        (self.root/'SPECS.md').write_text(done)
        self.hook('post-write',{'file_path':'SPECS.md','content':'unused'})
        self.assertEqual({'target':'US-1.1','action':'complete','story':'-','change':'-',
                          'command':'none — every story in the goal is DONE','reason':'all 1 story/stories are DONE'},
                         self.next_action('US-1.1'))

if __name__=='__main__': unittest.main(verbosity=2)
