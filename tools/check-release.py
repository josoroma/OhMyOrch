#!/usr/bin/env python3
"""Public release gates; absence of evidence is a failure, not implicit approval."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser();parser.add_argument('--tag');args=parser.parse_args()
manifest=json.loads((ROOT/'plugins/ohmyorch/.claude-plugin/plugin.json').read_text())
evidence=json.loads((ROOT/'docs/plan/plugin-release-readiness.json').read_text())
errors=[]
for key in ['licenseApproved','liveAgentIdentityAndDenials','liveDeliveryLifecycle','latestStableValidated','rollbackRehearsed']:
    if evidence.get(key) is not True: errors.append(f'{key}: release evidence/decision pending')
if evidence.get('pluginVersion')!=manifest['version']:errors.append('Release evidence belongs to a different plugin version')
license=ROOT/'plugins/ohmyorch/LICENSE'
if not license.is_file() or not manifest.get('license'):errors.append('Actual plugin LICENSE and SPDX manifest license required')
if args.tag:
    if args.tag!=manifest['version']:errors.append('Tag must equal <manifest.version> without a v prefix')
    tags=subprocess.run(['git','tag','--sort=-version:refname'],cwd=ROOT,text=True,capture_output=True,check=True).stdout.splitlines()
    previous=next((t for t in tags if t!=args.tag and re.fullmatch(r'v?\d+\.\d+\.\d+(?:-[\w.]+)?',t)),None)
    if previous:
        old=subprocess.run(['git','show',previous+':plugins/ohmyorch/.claude-plugin/plugin.json'],cwd=ROOT,text=True,capture_output=True)
        if old.returncode==0 and json.loads(old.stdout)['version']==manifest['version']:errors.append('Changed payload must increment plugin version')
if errors:
    print('Public release blocked:\n'+ '\n'.join('- '+e for e in errors),file=sys.stderr);sys.exit(1)
print('PASS: public release evidence, license and version gates')
