// Usage (from an empty output dir): node extract-classes.cjs <RPR root> .
// Tokenises every string literal in the in-scope RPR .tsx files and runs the tokens
// through RPR's own Tailwind + config. Writes files.txt, generated.css, classes.json.
const fs=require('fs'),path=require('path');
const R=process.argv[2], OUT=process.argv[3];
const req=(m)=>require(path.join(R,'node_modules',m));
const dirs=['src/components/library','src/components/reader','src/components/glossary','src/components/settings','src/components/auth','src/components/layout','src/components/projects','src/components/landing','src/app'];
const files=[];
const walk=d=>{for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory()){if(e.name==='api')continue;walk(p)}else if(/\.tsx$/.test(e.name))files.push(p)}};
dirs.forEach(d=>walk(path.join(R,d)));
// collect string literal tokens
const counts={}, where={};
const tokRe=/^(?:[a-z0-9-]+:)*-?[a-z][a-z0-9-]*(?:-\[[^\]\s]+\]|\/[0-9.]+|-[0-9.]+(?:\/[0-9]+)?)*(?:\/[0-9.]+)?$|^(?:[a-z0-9-]+:)*\[[^\]]+\]$/;
for(const f of files){
  const src=fs.readFileSync(f,'utf8');
  const lits=src.match(/"[^"\n]*"|'[^'\n]*'|`[^`]*`/g)||[];
  for(let l of lits){l=l.slice(1,-1).replace(/\$\{[^}]*\}/g,' ');
    for(const t of l.split(/\s+/)){ if(!t||!tokRe.test(t))continue;
      counts[t]=(counts[t]||0)+1; (where[t]=where[t]||new Set()).add(path.relative(R,f));}}
}
fs.writeFileSync(path.join(OUT,'files.txt'),files.map(f=>path.relative(R,f)).join('\n'));
// generate tailwind css for those files
const postcss=req('postcss'); const tailwind=req('tailwindcss');
const loadConfig=require(path.join(R,'node_modules','tailwindcss','loadConfig.js'));
const cfg=loadConfig(path.join(R,'tailwind.config.ts'));
const toks=Object.keys(counts);
cfg.content=[{raw:toks.join(' '),extension:'html'}]; cfg.safelist=[];
postcss([tailwind(cfg)]).process('@tailwind components;@tailwind utilities;',{from:undefined}).then(res=>{
  fs.writeFileSync(path.join(OUT,'generated.css'),res.css);
  const unesc=s=>s.replace(/\\(.)/g,'$1');
  const rules={};
  res.root.walkRules(r=>{
    let media=r.parent&&r.parent.type==='atrule'?('@'+r.parent.name+' '+r.parent.params):'';
    for(const sel of r.selectors){
      const m=sel.match(/\.((?:\\.|[^\s.:>,)\[\]\\])+)/g); if(!m)continue;
      // pick the class that is a known token
      for(const c of m){const name=unesc(c.slice(1)); if(counts[name]){
        const decls=[];r.walkDecls(d=>decls.push(d.prop+': '+d.value));
        (rules[name]=rules[name]||[]).push({sel,media,decls});}}
    }
  });
  const out=toks.filter(t=>rules[t]).sort().map(t=>({cls:t,count:counts[t],files:[...where[t]],rules:rules[t]}));
  fs.writeFileSync(path.join(OUT,'classes.json'),JSON.stringify(out,null,1));
  console.log('tokens',toks.length,'tailwind classes',out.length);
});
