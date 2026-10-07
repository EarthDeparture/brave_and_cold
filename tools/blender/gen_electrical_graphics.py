"""Original counted-stock printwork. No downloaded imagery or distributed fonts."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
R=Path(__file__).resolve().parents[2]
OUT=R/'tools/blender/generated/electrical_fieldwork';OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(7107)
def font(size):return ImageFont.truetype('C:/Windows/Fonts/arial.ttf',size)
for name,base,lines in [
 ('packet',(168,143,92),['NORTH RIDGE','KESTREL 07 / DC','MATCHED FUSE','SEALED CONNECTOR PAIR','ONE ISSUE ONLY']),
 ('controller',(144,150,120),['KESTREL 07','WINTER REGULATOR','120 W DC / MATCHED KIT','CABLE + SEALED PLUGS','SERVICE STOCK']),
 ('slate',(192,182,154),['NORTH RIDGE SUPPLY','KESTREL 07 / SERVICE ISSUE','','','MARA / JUNE'])]:
 a=np.zeros((512,768,3),dtype=np.uint8)
 for i,c in enumerate(base):a[:,:,i]=np.clip(c+rng.normal(0,1.6,(512,768)),0,255)
 im=Image.fromarray(a);d=ImageDraw.Draw(im)
 d.rectangle((15,15,752,496),outline=(65,70,55),width=6)
 for i,line in enumerate(lines):d.text((38,47+i*86),line,font=font(39 if i==0 else 30),fill=(43,52,42))
 # Subtle weathering restricted to border; printed contents remain legible.
 for _ in range(120):
  x=int(rng.integers(22,740));y=int(rng.choice([23,489]));d.line((x,y,x+int(rng.integers(2,15)),y),fill=(141,132,105),width=2)
 im.save(OUT/(name+'.png'))
print('ELECTRICAL_GRAPHICS 3 original sheets, seed 7107')
