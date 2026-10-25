from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
out=Path(__file__).resolve().parent/'generated/maintenance';out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(710);n=rng.normal(0,7,(512,512,1));base=np.array([90,98,92]);arr=np.clip(base+n,0,255).astype('uint8');Image.fromarray(arr).save(out/'stone.png')
im=Image.new('RGB',(768,192),(38,62,49));d=ImageDraw.Draw(im);d.rectangle((8,8,759,183),outline=(159,171,126),width=5);d.text((384,67),'FIELD REPAIR',font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',48),fill=(210,212,181),anchor='mm');d.text((384,129),'NEEDLE / THREAD / PATCHES',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',26),fill=(190,200,173),anchor='mm');im.save(out/'sewing.png')

y,x=np.indices((512,512));weave=((x%4==0)+(y%4==0))*3;rng=np.random.default_rng(815);cotton=np.clip(np.array([220,216,195])+rng.normal(0,1.5,(512,512,1))-weave[...,None],0,255).astype("uint8");Image.fromarray(cotton).save(out/"cotton.png")
