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

# Original floor tile, worn exterior paint and readable medical packaging.
rng=np.random.default_rng(740);n=rng.normal(0,3,(512,512,1));a=np.clip(np.array([127,136,125])+n,0,255).astype('uint8')
for k in range(0,512,128):a[k:k+2,:,:]=[77,87,79];a[:,k:k+2,:]=[77,87,79]
im=Image.fromarray(a);d=ImageDraw.Draw(im)
for k in range(80):
 x,y=rng.integers(4,498,2);d.line((int(x),int(y),int(x+8),int(y+3)),fill=(101,112,103),width=1)
im.save(out/'linoleum.png')
a=np.clip(np.array([66,84,72])+rng.normal(0,3,(512,512,1)),0,255).astype('uint8');a[:,::96,:]=[40,53,44];Image.fromarray(a).save(out/'siding.png')
for name,lines,bg in [('dressing',['STERILE','DRESSING','5 cm / SINGLE USE'],(208,203,178)),('antiseptic',['WOUND','ANTISEPTIC','EXTERNAL USE'],(205,200,170)),('chart',['WASH / CLEAN / COVER','CLEAN HANDS FIRST','KEEP DRESSINGS DRY','CHECK WOUND DAILY','RETURN TO SHELTER'],(203,200,179)),('city_letter',['SUNDAY / FROM ELISE','ONE WEEK IS NOT FOREVER.','WRITE WHEN YOU GET THERE.','YOUR WATCH IS IN THE BAG.'],(215,203,167))]:
 im=Image.new('RGB',(768,768),(bg));d=ImageDraw.Draw(im);d.rectangle((16,16,751,751),outline=(65,90,76),width=6)
 for i,line in enumerate(lines):d.text((384,130+i*(500/len(lines))),line,font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',52 if name in ['dressing','antiseptic'] else 29),fill=(50,66,56),anchor='mm')
 im.save(out/(name+'.png'))
