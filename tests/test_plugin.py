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

class Integration(unittest.TestCase):
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
        if docs == 'mixed':
            self.config['documents']['specs'] = 'docs/SPECS.md'
        elif docs == 'docs':
            self.config['documents'] = {k: 'docs/' + v for k,v in CONFIG['documents'].items()}
        (d / 'project.json').write_text(json.dumps(self.config))
        for key, path in self.config['documents'].items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(REPO / 'tests/fixtures/valid' / Path(path).name, target)
        return d

    def change(self, passing=False):
        d = self.root / 'openspec/changes/selected'
        d.mkdir(parents=True)
        (d / 'specs').mkdir()
        (d / 'proposal.md').write_text('# Proposal\n\nStory: US-1.1\n')
        (d / 'specs/spec.md').write_text('# Spec\n')
        (d/'implementation-plan.md').write_text((REPO/'tests/fixtures/plans/valid/implementation-plan.md').read_text().replace('US-2.1','US-1.1'))
        specs=self.root/self.config['documents']['specs']
        specs.write_text(specs.read_text().replace('Status: READY','Status: READY\n\nChange: `openspec/changes/selected/`',1))
        (d / 'tasks.md').write_text('- [x] completed\n' if passing else '- [ ] pending\n')
        if passing:
            shutil.copy(REPO / 'tests/fixtures/reviews/valid/review.md', d)
            shutil.copy(REPO / 'tests/fixtures/test-reports/valid/test-report.md', d)
        return d

    def hook(self, mode, tool_input=None, agent=None, session='owner', code=0, plugin=PLUGIN, **extra):
        event = {'pre-write':'PreToolUse', 'pre-bash':'PreToolUse', 'post-write':'PostToolUse',
                 'stop':'Stop', 'session-context':'SessionStart'}[mode]
        payload = {'hook_event_name':event, 'session_id':session, 'cwd':str(self.root), **extra}
        if tool_input is not None: payload['tool_input'] = tool_input
        if agent is not None: payload.update(agent_type=agent, agent_id='specialist')
        result = subprocess.run(['bash', str(plugin / 'hooks/dispatch.sh'), '--project-root', str(self.root),
                                 '--mode',mode], input=json.dumps(payload), text=True, capture_output=True)
        self.assertEqual(code, result.returncode, result.stdout + result.stderr)
        if result.stdout.strip():
            try: json.loads(result.stdout)
            except ValueError: self.fail('Hook stdout must contain one JSON object: '+result.stdout)
        return result

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

    def test_root_docs_mixed_mapping_and_json(self):
        for docs in ['root','docs','mixed']:
            self.activate(docs)
            report=json.loads(self.run_cli('doctor','--json').stdout)
            self.assertEqual(self.config['documents'],report['documents'])
            self.run_cli('validate-product-artifacts','--quiet')
            payload={'tool_input':{'file_path':str(self.root/self.config['documents']['specs'])}}
            hook=subprocess.run([str(CLI),'--project-root',str(self.root),'validate-product-artifacts','--hook','--quiet'],
                                input=json.dumps(payload),text=True,capture_output=True)
            self.assertEqual(0,hook.returncode,hook.stderr)
            self.assertEqual('',hook.stdout)
        self.change(True)
        live=json.loads(self.run_cli('workflow-status','--change','selected','--json').stdout)
        self.assertEqual(7,len(live['gates']))
        self.run_cli('status','--change','selected','--quiet')
        self.run_cli('validate-status','--change','selected','--quiet')
        self.assertIn('ohmyorch:',(self.root/'openspec/changes/selected/status.md').read_text())

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
        self.run_cli('status','--change','selected',code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','content':'bad'},code=2)
        self.hook('pre-write',{'file_path':'.claude/ohmyorch/project.json','content':json.dumps(CONFIG)})

    def test_role_matrix_exact_change_and_spoofed_text(self):
        self.activate()
        self.change()
        for role,allowed in [('reviewer','review.md'),('tester','test-report.md')]:
            self.hook('pre-write',{'file_path':f'openspec/changes/selected/{allowed}','content':'verdict'},agent='ohmyorch:'+role)
            for denied in ['src/app.ts','SPECS.md','openspec/changes/other/'+allowed]:
                self.hook('pre-write',{'file_path':denied,'content':'text'},agent='ohmyorch:'+role,code=2)
        self.hook('pre-write',{'file_path':'openspec/changes/selected/review.md','content':'agent_type: ohmyorch:reviewer'},code=2)
        self.hook('pre-write',{'file_path':'openspec/changes/selected/tasks.md','content':'task'},agent='ohmyorch:implementer')
        self.hook('pre-write',{'file_path':'openspec/changes/selected/test-report.md','content':'text'},agent='ohmyorch:implementer',code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','content':'text'},agent='unrelated-agent',code=2)
        self.hook('pre-write',{'file_path':'a\nb.md','content':'text'},code=2)
        self.hook('pre-write',{'file_path':str(Path(self.work.name)/'outside.md'),'content':'text'},code=2)

    def test_batched_edit_does_not_bypass_done(self):
        self.activate()
        self.change()
        content=(self.root/'SPECS.md').read_text()
        first=content.split('### US-1.2:')[0]
        self.hook('pre-write',{'file_path':'SPECS.md','edits':[{'old_string':first,'new_string':first.replace('Status: READY','Status: DONE')}]},code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'Status: READY','new_string':'Status: DONE'},code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','old_string':'does not exist','new_string':'Status: DONE'},code=2)
        self.hook('pre-write',{'file_path':'SPECS.md','content':content})

    def test_archive_guard_and_json_context(self):
        self.activate()
        self.change()
        self.hook('pre-bash',{'command':'openspec archive selected -y'},code=2)
        self.hook('pre-bash',{'command':'openspec archive selected -y; openspec archive other -y'},code=2)
        self.hook('pre-bash',{'command':'openspec archive "$CHANGE" -y'},code=2)
        self.hook('pre-bash',{'command':'openspec archive --help'})
        context=json.loads(self.hook('session-context').stdout)['hookSpecificOutput']
        self.assertEqual('SessionStart',context['hookEventName'])
        self.assertIn('reviewer/tester',context['additionalContext'])

    def test_session_lease_stalls_and_takeover(self):
        self.activate()
        self.change()
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        before=self.snapshot()
        self.hook('stop',session='spectator')
        self.assertEqual(before,self.snapshot())
        self.run_cli('--session-id','spectator','delivery','refresh',code=2)
        for i in range(3): self.hook('stop',code=2)
        self.hook('stop')
        self.assertIn('| Status | BLOCKED |',(self.root/'openspec/delivery/goal.md').read_text())
        self.assertFalse((self.root/'.claude/ohmyorch/runtime/delivery.owner').exists())
        self.run_cli('--session-id','owner','delivery','start','US-1.1')
        self.run_cli('--session-id','replacement','--takeover','delivery','refresh')
        owner=json.loads((self.root/'.claude/ohmyorch/runtime/delivery.owner/owner.json').read_text())
        self.assertEqual('replacement',owner['sessionId'])
        self.hook('stop',session='owner')
        self.hook('pre-write',{'file_path':'SPECS.md','content':'text'},session='owner',code=2)

    def test_missing_bundled_dependency_is_blocked(self):
        self.activate()
        clone=Path(self.work.name)/'incomplete-plugin'
        shutil.copytree(PLUGIN,clone)
        (clone/'scripts/validate-review.sh').unlink()
        self.hook('pre-write',{'file_path':'openspec/changes/selected/review.md','content':'verdict'},agent='ohmyorch:reviewer',plugin=clone,code=2)
        self.run_cli('workflow-status','--change','selected',code=2,plugin=clone)
        self.run_cli('completion-gate','--change','doctor','--json',code=2,plugin=clone)

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
        self.hook('post-write',{'file_path':'SPECS.md','content':'unused'})
        self.hook('post-write',{'file_path':'src/app.ts','content':'unused'},agent='ohmyorch:implementer')

    def test_openspec_initialization_and_old_counter_upgrade(self):
        if not shutil.which('openspec'): self.skipTest('OpenSpec initialization prerequisite missing')
        self.run_cli('bootstrap','--apply','--with-openspec')
        self.assertIn('schema: spec-driven',(self.root/'openspec/config.yaml').read_text())
        first=self.snapshot()
        self.run_cli('bootstrap','--apply','--with-openspec')
        self.assertEqual(first,self.snapshot())
        old=self.root/'openspec/delivery/loop.state';old.write_text('count=2\n')
        goal=self.root/'openspec/delivery/goal.md';goal.write_text('Durable goal unchanged')
        self.run_cli('upgrade-project','--apply')
        self.assertFalse(old.exists())
        self.assertEqual('count=2\n',(self.root/'.claude/ohmyorch/runtime/legacy-loop.state').read_text())
        self.assertEqual('Durable goal unchanged',goal.read_text())

    def test_native_openspec_validation(self):
        if not shutil.which('openspec'): self.skipTest('OpenSpec prerequisite missing')
        self.run_cli('bootstrap','--apply','--with-openspec')
        self.activate()
        change=self.change(True)
        (change/'specs/spec.md').unlink()
        capability=change/'specs/widget';capability.mkdir()
        (capability/'spec.md').write_text('## ADDED Requirements\n\n### Requirement: Widget response\nThe system SHALL return a successful widget response.\n\n#### Scenario: Successful widget request\n- **WHEN** the user requests a widget\n- **THEN** the system returns the widget\n')
        result=subprocess.run(['openspec','validate','selected','--json'],cwd=self.root,text=True,capture_output=True)
        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
        self.assertTrue(json.loads(result.stdout)['items'][0]['valid'])
        completion=json.loads(self.run_cli('completion-gate','--change','selected','--json').stdout)
        self.assertTrue(completion['eligible'])
        self.assertEqual('pass',completion['openspecValidateState'])

    def test_preserved_acceptance_and_verification_ambiguities(self):
        self.activate()
        change=self.change(True)
        env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin'}
        report=change/'test-report.md'
        original=report.read_text()
        # Partial coverage and mixed UNVERIFIED remain warnings/legacy allowances.
        report.write_text(original.replace('Coverage: 3/3','Coverage: 3/4'))
        self.run_cli('validate-test-report','--report',str(report),'--quiet')
        mixed=original.replace('| 2 | Keep codebase claims evidence-backed | PASS |','| 2 | Keep codebase claims evidence-backed | UNVERIFIED |')
        report.write_text(mixed)
        self.run_cli('validate-test-report','--report',str(report),'--quiet')
        result=json.loads(self.run_cli('completion-gate','--change','selected','--json',env=env).stdout)
        self.assertTrue(result['eligible'])
        action=json.loads(self.run_cli('--session-id','actual-session','delivery','next','US-1.1','--json',env=env).stdout)
        command=shlex.split(action['command'])
        self.assertEqual(str(self.root.resolve()),command[command.index('--project-root')+1])
        self.assertEqual('actual-session',command[command.index('--session-id')+1])
        self.assertEqual(str(PLUGIN.resolve()/'bin/ohmyorch'),command[0])
        self.assertNotIn('&&',action['command'])
        self.assertIn('separate Bash call',action['command'])
        # Existing classifier exempts the substring VERIFIED, including UNVERIFIED.
        review=change/'review.md'
        review.write_text(review.read_text().replace('VERIFIED — no blocking mismatch','UNVERIFIED'))
        result=json.loads(self.run_cli('completion-gate','--change','selected','--json',env=env).stdout)
        self.assertTrue(result['eligible'])
        report.write_text(original.replace('| PASS |','| UNVERIFIED |'))
        self.run_cli('validate-test-report','--report',str(report),'--quiet',code=1)

if __name__=='__main__': unittest.main(verbosity=2)
