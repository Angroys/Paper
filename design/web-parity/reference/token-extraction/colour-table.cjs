// Usage (same dir, after the two scripts above): node colour-table.cjs  -> colors.md (tokens.md section 3)
const fs=require('fs');const c=JSON.parse(fs.readFileSync('classes.json','utf8'));
const VARS={'--accent':'#818cf8','--accent-hover':'#a5b4fc','--accent-soft':'#1e1b4b','--accent-ink':'#c7d2fe','--background':'#0a0a0a','--foreground':'#f5f5f5','--popover-accent':'#818cf8','--popover-bg':'#111827','--popover-border':'#374151','--popover-text':'#d1d5db','--term-underline':'#2563eb','--mark-focus-ring':'#4f46e5'};
const hex=(r,g,b)=>'#'+[r,g,b].map(v=>Math.round(v).toString(16).padStart(2,'0')).join('');
function parse(v){v=v.trim();let m;
 if(m=v.match(/^var\((--[a-z-]+)\)$/))return VARS[m[1]]?{hex:VARS[m[1]],a:1,via:m[1]}:{raw:v};
 if(m=v.match(/^#([0-9a-f]{6})$/i))return{hex:v.toLowerCase(),a:1};
 if(m=v.match(/^#([0-9a-f]{3})$/i))return{hex:'#'+m[1].split('').map(x=>x+x).join('').toLowerCase(),a:1};
 if(m=v.match(/^rgb\((\d+) (\d+) (\d+) \/ (var\([^,]+, ?1\)|1|[0-9.]+)\)$/))return{hex:hex(+m[1],+m[2],+m[3]),a:m[4].startsWith('var')?1:+m[4]};
 if(m=v.match(/^rgba?\((\d+), ?(\d+), ?(\d+)(?:, ?([0-9.]+))?\)$/))return{hex:hex(+m[1],+m[2],+m[3]),a:m[4]===undefined?1:+m[4]};
 if(v==='transparent')return{hex:'#000000',a:0};
 if(v==='currentColor'||v==='inherit')return{raw:v};
 return{raw:v};}
const over=(fg,a,bg)=>{const f=[1,3,5].map(i=>parseInt(fg.slice(i,i+2),16)),b=[1,3,5].map(i=>parseInt(bg.slice(i,i+2),16));return hex(...f.map((x,i)=>x*a+b[i]*(1-a)));};
const props=/^(color|background-color|border-color|border-[a-z]+-color|--tw-ring-color|--tw-ring-offset-color|stroke|fill|--tw-gradient-from|--tw-gradient-to|--tw-gradient-stops|outline-color|accent-color|caret-color|text-decoration-color|--tw-shadow-color|--tw-divide-color)$/;
const rows=[];
for(const x of c){for(const r of x.rules){for(const d of r.decls){const i=d.indexOf(': ');const p=d.slice(0,i),v=d.slice(i+2);
  if(!props.test(p))continue; if(p==='--tw-gradient-to'&&v.includes('position')&&!/rgb|#|var\(--[a-z]/.test(v.replace('var(--tw-gradient-to-position)','')))continue;
  let vv=v.replace(/ var\(--tw-gradient-(from|to)-position\)/,'');
  const q=parse(vv); rows.push({cls:x.cls,count:x.count,prop:p,val:v,...q});}}}
// dedupe by cls+prop
const seen=new Set();const out=[];
for(const r of rows){const k=r.cls+'|'+r.prop;if(seen.has(k))continue;seen.add(k);out.push(r);}
out.sort((a,b)=>a.cls.replace(/^([a-z-]+:)+/,'').localeCompare(b.cls.replace(/^([a-z-]+:)+/,''))||a.cls.localeCompare(b.cls));
const live=JSON.parse(fs.readFileSync('live.json','utf8'));
let md='| Class | Uses | Property | Resolved value | Over #0a0a0a | Over #171717 | Dark-only status |\n|---|---|---|---|---|---|---|\n';
for(const r of out){let res=r.hex?(r.a===1?r.hex:`${r.hex} @ ${r.a}`)+(r.via?` (${r.via})`:''):'`'+r.raw+'`';
 const o1=r.hex&&r.a<1&&r.a>0?over(r.hex,r.a,'#0a0a0a'):'';const o2=r.hex&&r.a<1&&r.a>0?over(r.hex,r.a,'#171717'):'';
 const isDark=/(^|:)dark:/.test(r.cls);const L=live[r.cls];let st=isDark?'**live**':(L?(L.live===0?'dead (always paired with a dark: override)':(L.over===0?'**live** (no dark: override)':`**live** in ${L.live}, dead in ${L.over}`)):'**live**');
 md+=`| \`${r.cls}\` | ${r.count} | ${r.prop.replace('--tw-','')} | ${res} | ${o1} | ${o2} | ${st} |\n`;}
fs.writeFileSync('colors.md',md);console.log(out.length);
