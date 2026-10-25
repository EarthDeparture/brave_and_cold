"""Original wood, blued steel and receiver markings for fictional game weapons."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy.ndimage import gaussian_filter
OUT=Path(__file__).parent/'generated/north_ridge_weapon_kit_v1/textures';OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(20261008);n=1024;y,x=np.mgrid[:n,:n];fine=rng.normal(0,1,(n,n))
for name,base in [('beech',[177,103,53]),('walnut',[136,73,40]),('redwood',[176,76,42]),('blued',[69,74,72]),('steel',[152,155,146]),('brass',[173,137,66]),('rubber',[37,39,36])]:
    if name in ['beech','walnut','redwood']:
        bend=11*np.sin(y*.009)+5*np.sin(y*.033)
        grain=np.sin((x+bend)*.078)+.4*np.sin((x+bend)*.34)
        cloud=gaussian_filter(fine,18,mode='wrap')*55
        h=grain*.09+fine*.007;variation=grain*8+cloud*12+fine*1.2;rough=.73
    elif name=='rubber':
        h=fine*.025;variation=fine*1.5;rough=.91
    else:
        cloud=gaussian_filter(fine,8,mode='wrap')*18;h=fine*.004;variation=fine*1.3+cloud*7;rough=.50 if name=='steel' else .66
        for k in range(190):
            xx,yy=rng.integers(4,1000,2);width=int(rng.integers(3,30));variation[yy,xx:xx+width]+=rng.uniform(4,21)
    a=np.clip(np.array(base)[None,None,:]+variation[:,:,None],0,255).astype('uint8');Image.fromarray(a).save(OUT/(name+'_base.png'))
    Image.fromarray(np.clip(rough*255+variation*.5,0,255).astype('uint8')).save(OUT/(name+'_rough.png'))
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*.16;dy=(np.roll(h,-1,0)-np.roll(h,1,0))*.16
    normal=np.stack([-dx,-dy,np.ones_like(dx)],axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    Image.fromarray(np.clip((normal*.5+.5)*255,0,255).astype('uint8')).save(OUT/(name+'_normal.png'))
for k in range(1,9):
    im=Image.new('RGB',(512,128),(72,77,74));d=ImageDraw.Draw(im);font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',33)
    d.text((256,43),'NORTH RIDGE',font=font,fill=(154,158,145),anchor='mm');d.text((256,91),f'FIELD / {k:02d}',font=font,fill=(154,158,145),anchor='mm');im.save(OUT/f'marking_{k}.png')
(OUT/'manifest.json').write_text(json.dumps({'original':True,'seed':20261008,'normal_convention':'OpenGL +Y','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.png'))}},indent=2)+'\n',encoding='utf-8',newline='\n')
print('WEAPON_TEXTURES_READY',len(list(OUT.glob('*.png'))))
