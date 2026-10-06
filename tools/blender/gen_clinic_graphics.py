from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
out=Path(__file__).resolve().parent/'generated/clinic';out.mkdir(parents=True,exist_ok=True)
for k,base in [('plaster',[180,183,166]),('cloth',[78,103,98])]:
 rng=np.random.default_rng(410);a=np.clip(np.array(base).reshape(1,1,3)+rng.normal(0,2,(512,512,1)),0,255).astype('uint8');Image.fromarray(a).save(out/(k+'.png'))
for name,lines in {'sign':['NORTH RIDGE CLINIC','COMMUNITY HEALTH / FIRST AID'],'notice':['WALK-IN HOURS','MON / FRI  08:00–17:00','URGENT CARE / RING BELL','SUPPLIES ARE COUNTED','KEEP REAR EXIT CLEAR'],'hours':['CHECK IN HERE','PLEASE WAIT FOR NURSE']}.items():
 im=Image.new('RGB',(1024,512),(207,201,172));d=ImageDraw.Draw(im);d.rectangle((16,16,1008,496),outline=(63,86,72),width=7)
 for i,line in enumerate(lines):d.text((512,50+i*(400/len(lines))),line,fill=(49,67,53),font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',43 if name=='sign' else 34),anchor='mt')
 im.save(out/(name+'.png'))
