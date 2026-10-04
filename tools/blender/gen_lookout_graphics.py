"""Original weathered maintenance graphics and woven textile, deterministic seed."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
R=Path(__file__).resolve().parents[2]/'tools/blender/generated/lookout_opening/textures'
R.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(20261004)
def font(n):return ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',n)
def plate(id,title,lines,bg=(48,66,61),fg=(219,211,182)):
 im=Image.new('RGB',(1024,640),bg);d=ImageDraw.Draw(im)
 d.rectangle((24,24,999,615),outline=fg,width=5)
 d.text((56,60),title,font=font(65),fill=fg)
 d.line((55,152,965,152),fill=fg,width=4)
 for i,line in enumerate(lines):d.text((56,195+i*70),line,font=font(40),fill=fg)
 for x in [40,984]:
  for y in [40,600]:d.ellipse((x-8,y-8,x+8,y+8),fill=(92,96,85))
 a=np.asarray(im).astype(float);noise=rng.normal(0,2,a.shape[:2])[...,None];a=np.clip(a+noise,0,255).astype('uint8');im=Image.fromarray(a)
 d=ImageDraw.Draw(im)
 for i in range(100):
  x,y=rng.integers(0,1024),rng.integers(0,640);d.line((int(x),int(y),int(x+rng.integers(2,18)),int(y)),fill=bg,width=1)
 im.save(R/(id+'.png'))
plate('cabinet','NORTH RIDGE / R-07',['TRANSFER CABINET','LOCAL RELAY + LOOKOUT','ISOLATE BEFORE SERVICE','CONTACTS / FUSE / TRANSFER'])
plate('hazard','CAUTION',['ISOLATE BOTH SOURCES','MAINS + BATTERY'],(124,91,25),(25,28,25))
plate('battery','RESERVE POWER',['12 V  /  12 Ah','144 Wh / LOCAL ONLY','LAMP 7W   RX 3W'])
plate('reserved','RESERVED / R-07',['TRANSFER RELAY','NORTH RIDGE LOOKOUT','FIELD TECH COLLECTION'],(196,181,143),(36,48,44))
plate('gate','KEEP GATE CLOSED',['FIELD RELAY COMPOUND','AUTHORIZED PERSONNEL'])
plate('rations','RIDGE PROVISIONS',['BEANS / FIELD RATION','STOCK: 4 TINS'],(126,52,28),(216,191,142))
plate('log','FIELD SERVICE LOG',['01  INSPECT CABINET','02  COLLECT RESERVED RELAY','    NORTH RIDGE SUPPLY','03  INSTALL + VERIFY','CHECK FUEL / WATER / RADIO'],(198,188,159),(36,44,37))
n=1024;y,x=np.mgrid[:n,:n];noise=rng.normal(0,1,(n,n))
base=np.stack([np.full((n,n),43),np.full((n,n),66),np.full((n,n),71)],-1).astype(float)
weave=(np.sin(x*np.pi/2)*2+np.sin(y*np.pi/2)*2+noise)[...,None]
checks=(((x//171+y//171)%2)*9)[...,None]
Image.fromarray(np.clip(base+weave+checks,0,255).astype('uint8')).save(R/'cloth.png')
print('LOOKOUT_GRAPHICS_READY',len(list(R.glob('*.png'))))
