// Usage (same dir, after extract-classes.cjs): node dead-light-classes.cjs <RPR root>  -> live.json
// For each non-dark colour class: in how many literals is it overridden by a dark: sibling of the same family+state?
const fs=require('fs'),path=require('path');const R=process.argv[2];
const files=fs.readFileSync('files.txt','utf8').split('\n');
const fam=t=>{const m=t.match(/^((?:[a-z-]+:)*)(bg|text|border(?:-[trblxy])?|ring-offset|ring|stroke|fill|placeholder|from|to|via|divide|outline|decoration|shadow)-(.+)$/);if(!m)return null;
 if(m[2]==='text'&&/^(xs|sm|base|lg|[0-9]?xl|left|right|center|balance|\[[0-9.]+(px|rem)\]|wrap|nowrap|ellipsis|clip|pretty)/.test(m[3]))return null;
 if(m[2].startsWith('border')&&/^([0-9]|$)/.test(m[3]))return null;
 if(m[2].startsWith('ring')&&/^([0-9]|inset)/.test(m[3]))return null;
 if(m[2]==='outline'&&/^([0-9]|none|offset|dashed|dotted)/.test(m[3]))return null;
 if(m[2]==='shadow'&&/^(sm|md|lg|xl|2xl|inner|none)$/.test(m[3]))return null;
 const pre=m[1];const dark=pre.includes('dark:');return{state:pre.replace('dark:',''),f:m[2],dark};};
const stat={};
for(const f of files){const src=fs.readFileSync(path.join(R,f),'utf8');
 for(let l of (src.match(/"[^"\n]*"|'[^'\n]*'|`[^`]*`/g)||[])){const toks=l.slice(1,-1).split(/\s+/);
  const fams=toks.map(t=>({t,x:fam(t)})).filter(o=>o.x);
  for(const o of fams){if(o.x.dark)continue;const ov=fams.some(p=>p.x.dark&&p.x.state===o.x.state&&p.x.f===o.x.f);
   const s=stat[o.t]=stat[o.t]||{over:0,live:0};ov?s.over++:s.live++;}}}
fs.writeFileSync('live.json',JSON.stringify(stat,null,1));
const live=Object.entries(stat).filter(([k,v])=>v.live>0).map(([k,v])=>k+' live='+v.live+' over='+v.over);
console.log(live.join('\n'));
