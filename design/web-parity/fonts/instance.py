# Usage: python instance.py <GeistVF.woff> "Geist" <outdir> 400,500,600,700   (needs fonttools)
import sys, os
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
src, fam, out = sys.argv[1], sys.argv[2], sys.argv[3]
names={300:'Light',400:'Regular',500:'Medium',600:'SemiBold',700:'Bold'}
for w in map(int, sys.argv[4].split(',')):
    f=TTFont(src); f.flavor=None
    inst=instantiateVariableFont(f,{'wght':w},updateFontNames=False)
    n=inst['name']; style=names[w]; ps=fam.replace(' ','')+'-'+style
    for rec in list(n.names):
        if rec.nameID in (1,2,4,6,16,17): n.removeNames(nameID=rec.nameID)
    n.setName(fam if w in (400,700) else f'{fam} {style}',1,3,1,0x409)
    n.setName('Regular' if w in (400,) else ('Bold' if w==700 else 'Regular'),2,3,1,0x409)
    n.setName(f'{fam} {style}',4,3,1,0x409); n.setName(ps,6,3,1,0x409)
    n.setName(fam,16,3,1,0x409); n.setName(style,17,3,1,0x409)
    inst['OS/2'].usWeightClass=w
    p=os.path.join(out,ps+'.ttf'); inst.save(p); print(p, os.path.getsize(p))
