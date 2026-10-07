import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parent.parent
class Packaging(unittest.TestCase):
    def test_reproducible_allowlist_and_excluded_project_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            command=['python3',str(ROOT/'tools/package-plugin.py'),'--development','--out',tmp]
            subprocess.run(command,check=True,capture_output=True)
            archive=next(Path(tmp).glob('*.zip'));first=hashlib.sha256(archive.read_bytes()).hexdigest()
            subprocess.run(command,check=True,capture_output=True)
            self.assertEqual(first,hashlib.sha256(archive.read_bytes()).hexdigest())
            with zipfile.ZipFile(archive) as zip:
                names=zip.namelist()
                self.assertIn('ohmyorch/.claude-plugin/plugin.json',names)
                self.assertIn('ohmyorch/third-party/openspec-LICENSE',names)
                self.assertEqual(24,sum(n.endswith('/SKILL.md') for n in names))
                self.assertEqual(8,sum(n.startswith('ohmyorch/agents/') for n in names))
                for name in names:
                    self.assertFalse(any(word in name for word in ['settings.local','fixtures/','tests/','node_modules','canonical/','backups/','runtime/','docs/resets']))
                self.assertEqual(0o755,(zip.getinfo('ohmyorch/bin/ohmyorch').external_attr>>16)&0o777)

    def test_unknown_and_symlink_payloads_are_rejected(self):
        spec=importlib.util.spec_from_file_location('package_plugin',ROOT/'tools/package-plugin.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            plugin=Path(tmp)/'plugin';shutil.copytree(ROOT/'plugins/ohmyorch',plugin);module.PLUGIN=plugin
            bad=plugin/'settings.local.json';bad.write_text('{"secret":"fixture-only"}')
            with self.assertRaises(ValueError):module.payload_files()
            bad.unlink();(plugin/'references/external.md').symlink_to(ROOT/'README.md')
            with self.assertRaises(ValueError):module.payload_files()

    def test_public_release_is_blocked_without_real_evidence(self):
        evidence=json.loads((ROOT/'docs/plan/plugin-release-readiness.json').read_text())
        result=subprocess.run(['python3',str(ROOT/'tools/check-release.py')],text=True,capture_output=True)
        if all(evidence.get(k) for k in ['licenseApproved','liveAgentIdentityAndDenials','liveDeliveryLifecycle','latestStableValidated','rollbackRehearsed']):
            self.assertEqual(0,result.returncode,result.stderr)
        else:
            self.assertEqual(1,result.returncode)
            self.assertIn('Public release blocked',result.stderr)

    def test_release_tag_matches_manifest_without_prefix_and_checks_previous_versions(self):
        # Synthetic release evidence stays inside this disposable fixture.
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'tools').mkdir();(root/'docs/plan').mkdir(parents=True)
            plugin=root/'plugins/ohmyorch';(plugin/'.claude-plugin').mkdir(parents=True)
            shutil.copy(ROOT/'tools/check-release.py',root/'tools/check-release.py')
            manifest=plugin/'.claude-plugin/plugin.json'
            manifest.write_text(json.dumps({'version':'0.0.0','license':'MIT'}))
            (plugin/'LICENSE').write_text('Disposable test license fixture only.\n')
            evidence={'pluginVersion':'0.0.1',**{key:True for key in [
                'licenseApproved','liveAgentIdentityAndDenials','liveDeliveryLifecycle',
                'latestStableValidated','rollbackRehearsed']}}
            (root/'docs/plan/plugin-release-readiness.json').write_text(json.dumps(evidence))
            def git(*args):
                subprocess.run(['git',*args],cwd=root,check=True,capture_output=True)
            git('init','-q');git('config','user.name','Release fixture')
            git('config','user.email','fixture@example.invalid');git('add','.')
            git('commit','-qm','Fixture previous version');git('tag','0.0.0')
            manifest.write_text(json.dumps({'version':'0.0.1','license':'MIT'}))
            git('add','.');git('commit','-qm','Fixture current version')
            def check(tag):
                return subprocess.run(['python3',str(root/'tools/check-release.py'),'--tag',tag],
                                      text=True,capture_output=True)
            accepted=check('0.0.1');self.assertEqual(0,accepted.returncode,accepted.stderr)
            prefixed=check('v0.0.1');self.assertEqual(1,prefixed.returncode)
            self.assertIn('without a v prefix',prefixed.stderr)
            git('tag','0.0.2')
            duplicate=check('0.0.1');self.assertEqual(1,duplicate.returncode)
            self.assertIn('Changed payload must increment plugin version',duplicate.stderr)

if __name__=='__main__':unittest.main(verbosity=2)
