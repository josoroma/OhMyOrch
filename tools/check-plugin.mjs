import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { parseDocument } from 'yaml';
const root = path.resolve(import.meta.dirname, '..');
const plugin = path.join(root, 'plugins/ohmyorch');
const errors=[];
const check=(ok,message)=>{if(!ok) errors.push(message);};
const read=p=>fs.readFileSync(p,'utf8');
const manifest=JSON.parse(read(path.join(plugin,'.claude-plugin/plugin.json')));
const catalog=JSON.parse(read(path.join(root,'.claude-plugin/marketplace.json')));
check(manifest.name==='ohmyorch','Plugin ID must remain ohmyorch');
check(/^\d+\.\d+\.\d+(?:-[\w.]+)?$/.test(manifest.version),'Invalid SemVer');
check(catalog.plugins.length===1 && catalog.plugins[0].source==='./plugins/ohmyorch','Catalog source boundary');
check(JSON.parse(read(path.join(root,'package.json'))).version===manifest.version,'Maintainer/plugin version drift');
const groups=[['skills',24],['agents',8]];
const seen=new Set();
for(const [group,count] of groups){
 const files=fs.readdirSync(path.join(plugin,group)).map(n=>path.join(plugin,group,n,group==='skills'?'SKILL.md':'')).filter(p=>fs.statSync(p).isFile());
 check(files.length===count,`Expected ${count} ${group}, found ${files.length}`);
 for(const file of files){
  const source=read(file);const match=source.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  if(!match){errors.push(`Missing frontmatter: ${file}`);continue;}
  const doc=parseDocument(match[1],{uniqueKeys:true});
  errors.push(...doc.errors.map(e=>`${file}: ${e.message}`));
  const meta=doc.toJS();
  check(meta.name===(group==='skills'?path.basename(path.dirname(file)):path.basename(file,'.md')),`Component name/path mismatch: ${file}`);
  check(typeof meta.name==='string' && typeof meta.description==='string',`Name/description required: ${file}`);
  check(!meta.name.startsWith('ohmyorch-')&&!meta.name.includes(':'),`Unscoped component name required: ${file}`);
  check(!seen.has(group+meta.name),`Duplicate component: ${meta.name}`);seen.add(group+meta.name);
  check(source.includes('${CLAUDE_PLUGIN_ROOT}/references/contract.md')||meta.name==='contract',`Contract missing: ${file}`);
  check(!/\.claude\/(agents|skills|commands)\/|scripts\/templates\/|\/Users\/|\.nvm\//.test(source),`Legacy path coupling: ${file}`);
  check(!/\/ohmyorch-|ohmyorch-openspec-sync-specs/.test(source),`Legacy invocation in active prompt: ${file}`);
  if(group==='agents'){
   for(const forbidden of ['hooks','permissionMode','mcpServers','initialPrompt'])check(!(forbidden in meta),`Ignored plugin-agent field ${forbidden}: ${file}`);
   check(meta.model==='inherit',`Unexpected model pin: ${file}`);
   check(meta.skills?.includes('ohmyorch:contract'),`Missing contract preload: ${file}`);
   if(['planner','codebase-analyst','product-specifier','spec-ingestor'].includes(meta.name))check(!/\b(Write|Edit)\b/.test(meta.tools),`Read-only role tool budget: ${file}`);
  }
 }
}
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]);}
for(const file of walk(plugin)){
 const relative=path.relative(plugin,file);
 check(!fs.lstatSync(file).isSymbolicLink(),`Symlink in payload: ${relative}`);
 check(!/settings\.local|\.credentials|node_modules|__pycache__|\.pyc$|^tests\//.test(relative),`Private/dev asset in payload: ${relative}`);
 if(file.endsWith('.sh')||relative==='bin/ohmyorch'){
  const result=spawnSync('/bin/bash',['-n',file],{encoding:'utf8'});check(result.status===0,`${relative}: ${result.stderr}`);
  check((fs.statSync(file).mode&0o111)!==0,`Missing executable mode: ${relative}`);
 }
}
const hooks=JSON.parse(read(path.join(plugin,'hooks/hooks.json'))).hooks;
for(const [event,groups] of Object.entries(hooks))for(const group of groups)for(const hook of group.hooks){
 check(hook.type==='command'&&hook.command==='bash'&&Array.isArray(hook.args),`Exec form required: ${event}`);
 check(hook.args.includes('${CLAUDE_PROJECT_DIR}'),`Explicit project root: ${event}`);
 check(hook.args[0]==='${CLAUDE_PLUGIN_ROOT}/hooks/dispatch.sh',`Bundled dispatcher: ${event}`);
 check(hook.timeout>0&&hook.timeout<=30,`Bounded synchronous hook: ${event}`);
}
check(!fs.existsSync(path.join(plugin,'settings.json')),'No global agent/default permissions');
check(!fs.existsSync(path.join(plugin,'.mcp.json')),'No runtime MCP dependency is declared');
if(errors.length){console.error(errors.join('\n'));process.exit(1);}
console.log(`PASS: ${manifest.name} ${manifest.version}; 24 skills, 8 agents; paths, hook registration, Bash syntax and payload boundaries`);
