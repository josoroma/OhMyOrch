"""Real Claude marketplace/cache install-update-uninstall in an isolated profile."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO=Path(__file__).resolve().parent.parent
CLAUDE=os.environ.get('OHMYORCH_CLAUDE_BIN',shutil.which('claude'))

def digest(root):
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file() and '.git' not in p.parts
            and p.name!='settings.local.json'}

with tempfile.TemporaryDirectory(prefix='ohmyorch-marketplace-') as tmp:
    work=Path(tmp).resolve(); catalog=work/'catalog';host=work/'host';profile=work/'profile'
    (catalog/'.claude-plugin').mkdir(parents=True);(catalog/'plugins').mkdir();host.mkdir();profile.mkdir()
    shutil.copy(REPO/'.claude-plugin/marketplace.json',catalog/'.claude-plugin')
    shutil.copytree(REPO/'plugins/ohmyorch',catalog/'plugins/ohmyorch')
    env={**os.environ,'CLAUDE_CONFIG_DIR':str(profile),'DISABLE_TELEMETRY':'1','DISABLE_ERROR_REPORTING':'1'}
    def git(*args):
        subprocess.run(['git',*args],cwd=catalog,env=env,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    git('init','-q');git('config','user.name','Plugin fixture');git('config','user.email','fixture@example.invalid')
    git('add','.');git('commit','-qm','Fixture initial plugin version')
    def run(*args):
        result=subprocess.run([CLAUDE,*args],cwd=host,env=env,text=True,capture_output=True,timeout=60)
        if result.returncode: raise AssertionError(' '.join(args)+'\n'+result.stdout+result.stderr)
        return result.stdout
    initial=digest(host)
    run('plugin','marketplace','add',str(catalog),'--scope','local')
    run('plugin','install','ohmyorch@ohmyorch-marketplace','--scope','local')
    assert initial==digest(host),'Install initialized a project'
    listings=json.loads(run('plugin','list','--json'))
    entries=listings if isinstance(listings,list) else listings.get('plugins',[])
    entry=next(p for p in entries if p.get('id',p.get('name','')).startswith('ohmyorch'))
    installed=Path(entry['installPath'])
    assert installed.is_relative_to(profile/'plugins/cache'),f'Expected a cached installation: {installed}'
    assert not (installed/'tests').exists()
    run('plugin','validate','--strict','--json',str(installed))
    version=subprocess.run([str(installed/'bin/ohmyorch'),'--project-root',str(host),'doctor','--json'],
                           env=env,text=True,capture_output=True,check=True)
    assert json.loads(version.stdout)['enabled'] is False
    subprocess.run([str(installed/'bin/ohmyorch'),'--project-root',str(host),'bootstrap','--apply'],env=env,
                   text=True,capture_output=True,check=True)
    (host/'PRD.md').write_text('Human intent survives code update and uninstall\n')
    before=digest(host)
    manifest=catalog/'plugins/ohmyorch/.claude-plugin/plugin.json'
    changed=json.loads(manifest.read_text())
    major,minor,patch=map(int,changed['version'].split('-')[0].split('.'))
    updated_version=f'{major}.{minor}.{patch+1}'
    changed['version']=updated_version;manifest.write_text(json.dumps(changed,indent=2)+'\n')
    git('add','.');git('commit','-qm','Fixture next patch version')
    run('plugin','marketplace','update','ohmyorch-marketplace')
    run('plugin','update','ohmyorch@ohmyorch-marketplace','--scope','local')
    assert before==digest(host),'Plugin update rewrote project state'
    listings=json.loads(run('plugin','list','--json'));entries=listings if isinstance(listings,list) else listings.get('plugins',[])
    entry=next(p for p in entries if p.get('id',p.get('name','')).startswith('ohmyorch'))
    assert entry['version']==updated_version,entry
    run('plugin','uninstall','ohmyorch@ohmyorch-marketplace','--scope','local')
    assert before==digest(host),'Uninstall removed durable project data'
    print('PASS: '+run('--version').strip()+'; isolated marketplace, cached plugin, next-patch update, uninstall, project preservation')
