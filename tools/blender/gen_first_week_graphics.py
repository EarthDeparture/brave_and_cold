"""Original field-equipment printwork; run before gen_first_week.py."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np
out=Path(__file__).resolve().parent/'generated/first_week';out.mkdir(parents=True,exist_ok=True)
copy={"water":["NORTH RIDGE","BOILED WATER","0.5 L / REFILL"],"cache":["CREW RESERVE / 07","COUNTED SUPPLIES","TAKE WHAT YOU NEED"],"note":["MARA / MONDAY","DELIVERY TOMORROW?","CITY LETTER AT TOWER"],"timber":["DRY TIMBER","SPLIT / RESTOCK","KESTREL RELAY 07"],"meter":["CREW LOAD","6 W","STANDBY"],"feeder":["CREW SPUR / DISCONNECT","LOCAL SUPPLY ONLY"]}
for k,lines in copy.items():
 rng=np.random.default_rng(100+list(copy).index(k));grain=rng.normal(0,2,(384,768,1));base=np.array([185,177,135]).reshape(1,1,3);im=Image.fromarray(np.clip(base+grain,0,255).astype('uint8'));d=ImageDraw.Draw(im);d.rectangle((18,18,750,366),outline=(70,77,60),width=5)
 for i,line in enumerate(lines):
  font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',32 if k=='note' else 36);y=65+i*(250/max(len(lines),2));d.text((384,y),line,font=font,fill=(40,51,40),anchor='mt')
 for x in [28,740]:
  for y in [28,356]:d.ellipse((x-6,y-6,x+6,y+6),fill=(119,127,119))
 im.save(out/(k+'.png'))
