"""Original gravel/PBR fields and maintenance marker graphics; local deterministic art."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy.ndimage import gaussian_filter
R=Path(__file__).resolve().parents[2];out=R/'tools/blender/generated/route_detail';runtime=R/'brave-and-cold/assets/route_detail/textures'
out.mkdir(parents=True,exist_ok=True);runtime.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(71007);n=1024;y,x=np.mgrid[:n,:n]
fine=rng.random((n,n));stone=gaussian_filter(fine,1.4,mode='wrap');stone=(stone-stone.min())/(stone.max()-stone.min())
macro=gaussian_filter(rng.random((n,n)),28,mode='wrap');macro=(macro-macro.min())/(macro.max()-macro.min())
gravel=.45+.25*stone+.10*macro
colour=gravel[...,None]*np.array([.43,.38,.31])+((fine-.5)*.05)[...,None]
colour+=np.maximum(0,stone-.70)[...,None]*.22
height=gaussian_filter(stone,1,mode='wrap')*.09
dy,dx=np.gradient(height*14);normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
concrete=np.repeat((.65+.09*stone+.05*macro)[...,None],3,axis=-1)*np.array([.98,1,1.02])
for name,a in [('gravel_alb',colour),('gravel_nrm',normal*.5+.5),('concrete_alb',concrete)]:
 p=runtime/(name+'.png');Image.fromarray(np.uint8(np.clip(a,0,1)*255)).save(p)
font=Path('C:/Windows/Fonts/bahnschrift.ttf')
def graphic(name,lines):
 im=Image.new('RGB',(512,512),(38,57,49));d=ImageDraw.Draw(im)
 d.rounded_rectangle((15,15,496,496),radius=8,outline=(185,175,136),width=9)
 for text,yy,size in lines:
  f=ImageFont.truetype(str(font),size);d.text((256,yy),text,font=f,anchor='mm',fill=(215,203,162))
 im.save(out/(name+'.png'))
graphic('field_gate',[('KEEP GATE',175,60),('SHUT',305,94),('KESTREL RELAY 07',437,29)])
graphic('field_marker',[('KESTREL',105,61),('RELAY 07',190,61),('^',325,140),('SERVICE PATH',449,30)])
files=list(runtime.glob('*.png'))+[out/'field_gate.png',out/'field_marker.png']
(runtime.parent/'graphics.json').write_text(json.dumps({'source':'Original project-authored local raster/PBR art','seed':71007,'font':'System Bahnschrift rasterized; font not redistributed','files':{str(p.relative_to(R)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2)+'\n',encoding='utf8',newline='\n')
print('ROUTE_GRAPHICS',len(files))
