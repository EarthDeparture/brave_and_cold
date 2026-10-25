"""Original deterministic dried fibres and enamel instruction plate; no external images."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
out=Path(__file__).resolve().parents[2]/'tools/blender/generated/food_preservation'
out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(7108);y,x=np.mgrid[:512,:512]
grain=9*np.sin(x*.18+2*np.sin(y*.018))+4*np.sin(x*.79+y*.018)+rng.normal(0,3,(512,512))
fat=np.maximum(0,np.sin(x*.038+np.sin(y*.023)*2.5)-.65)*65
base=np.stack([98+grain+fat,48+grain*.55+fat*.7,30+grain*.30+fat*.43],axis=-1)
Image.fromarray(np.uint8(np.clip(base,0,255))).save(out/'dried_fibres.png')
im=Image.new('RGB',(768,256),(178,183,161));d=ImageDraw.Draw(im)
for i in range(900):
 px=int(rng.integers(0,768));py=int(rng.integers(0,256));d.line((px,py,px+int(rng.integers(1,7)),py),fill=(159,165,146))
font=lambda size:ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',size)
d.rectangle((12,12,755,243),outline=(48,69,59),width=4)
for text,ypos,size in [('NORTH RIDGE / STOVE DRYER',30,40),('COOK FIRST - 4 PORTIONS - 2 HOURS',99,34),('KEEP STOVE LIT / CHECK FRESHNESS',174,31)]:
 d.text((384,ypos),text,font=font(size),anchor='mt',fill=(34,48,41))
im.save(out/'rack_plate.png')
print('FOOD_GRAPHICS seed=7108 fibres=512 plate=768x256')
