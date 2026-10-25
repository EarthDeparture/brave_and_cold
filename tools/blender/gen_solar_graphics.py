"""Original, seeded painterly PV cell and equipment printwork; no downloaded art."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/blender/generated/lookout_solar';OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(7106)
w,h=768,1024
y,x=np.mgrid[:h,:w];grain=rng.normal(0,1.7,(h,w))
base=np.empty((h,w,3))
for i,c in enumerate([34,54,66]):base[:,:,i]=c+grain+3*np.sin(x/91+y/166)+2*np.sin(y/44)
im=Image.fromarray(np.clip(base,0,255).astype('uint8'));d=ImageDraw.Draw(im)
for row in range(10):
 for col in range(6):
  x0=col*128+5;y0=row*102+5;x1=x0+118;y1=y0+92
  c=tuple(int(v) for v in np.array([43,63,75])+rng.integers(-4,5))
  d.rounded_rectangle((x0,y0,x1,y1),radius=9,fill=c,outline=(82,101,109),width=2)
  for stripe in range(1,12):
   yy=y0+stripe*7;d.line((x0+5,yy,x1-5,yy),fill=(87,103,109),width=1)
  for stripe in [33,79]:d.line((x0+stripe,y0+2,x0+stripe,y1-2),fill=(133,148,149),width=2)
for k in range(100):
 xx=int(rng.integers(0,w));yy=int(rng.integers(0,h));d.line((xx,yy,xx+int(rng.integers(2,11)),yy+1),fill=(83,99,104),width=1)
im.save(OUT/'pv_cells.png')
font_path=Path('C:/Windows/Fonts/arialbd.ttf')
def font(s):return ImageFont.truetype(str(font_path),s)
im=Image.new('RGB',(512,512),(191,188,160));d=ImageDraw.Draw(im)
d.rounded_rectangle((14,14,497,497),radius=12,outline=(57,76,67),width=10)
d.rectangle((25,25,485,142),fill=(38,66,57))
d.text((42,44),'KESTREL 07',font=font(49),fill=(223,218,182))
d.text((43,101),'LOCAL DC CHARGER',font=font(24),fill=(214,211,180))
d.text((44,173),'120 W ARRAY / 24 V',font=font(29),fill=(36,54,47))
d.line((44,232,468,232),fill=(74,91,77),width=3)
d.text((44,263),'SOLAR INPUT',font=font(28),fill=(36,54,47))
d.text((44,303),'BATTERY RESERVE',font=font(28),fill=(36,54,47))
d.rectangle((36,371,476,470),fill=(174,130,61))
d.text((49,384),'ISOLATE BEFORE SERVICE',font=font(23),fill=(35,43,36))
d.text((49,425),'TOWN GRID IS SEPARATE',font=font(23),fill=(35,43,36))
im.save(OUT/'charger_plate.png')
print('SOLAR_GRAPHICS seed=7106 pv=768x1024 plate=512x512')
