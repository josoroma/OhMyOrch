#!/usr/bin/env python3
"""Reproducible allowlisted supplement to marketplace distribution."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parent.parent
PLUGIN=ROOT/'plugins/ohmyorch'
EXACT={'.claude-plugin/plugin.json','bin/ohmyorch','hooks/hooks.json','hooks/dispatch.sh',
       'README.md','CHANGELOG.md','THIRD-PARTY-NOTICES.md','LICENSE',
       'third-party/openspec-LICENSE'}
PATTERNS=[r'skills/[a-z-]+/SKILL\.md',r'agents/[a-z-]+\.md',
          r'references/[a-z-]+\.(md|json)',r'references/rules/[a-z-]+\.md',
          r'lib/[a-z-]+\.(sh|jq)',r'scripts/[a-z-]+\.sh',
          r'templates/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_.-]+\.(md|html|yaml|json)']

def payload_files():
    files=[]
    for file in sorted(PLUGIN.rglob('*')):
        if file.is_symlink(): raise ValueError(f'Symlink refused: {file}')
        if not file.is_file(): continue
        relative=file.relative_to(PLUGIN).as_posix()
        if relative not in EXACT and not any(re.fullmatch(p,relative) for p in PATTERNS):
            raise ValueError(f'Payload file not allowlisted: {relative}')
        files.append((file,relative))
    return files

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=ROOT/'dist')
    parser.add_argument('--development',action='store_true',help='Unreleased local test artifact; bypasses public-release gates')
    args=parser.parse_args()
    if not args.development: subprocess.run(['python3',str(ROOT/'tools/check-release.py')],check=True)
    manifest=json.loads((PLUGIN/'.claude-plugin/plugin.json').read_text())
    version=manifest['version'];name=f'ohmyorch-{version}'+('-development' if args.development else '')
    files=payload_files();args.out.mkdir(parents=True,exist_ok=True)
    archive=args.out/(name+'.zip')
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as zip:
        for file,relative in files:
            info=zipfile.ZipInfo('ohmyorch/'+relative,date_time=(1980,1,1,0,0,0))
            info.create_system=3;info.external_attr=(file.stat().st_mode&0o777)<<16
            info.compress_type=zipfile.ZIP_DEFLATED;zip.writestr(info,file.read_bytes())
    checksum=hashlib.sha256(archive.read_bytes()).hexdigest()
    (args.out/(name+'.sha256')).write_text(f'{checksum}  {archive.name}\n')
    print(f'{archive}: {len(files)} allowlisted files, SHA-256 {checksum}')

if __name__=='__main__':main()
