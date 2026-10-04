"""Original fictional North Ridge route graphics; Pillow only."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import random
OUT=Path(__file__).resolve().parents[1]/'blender/generated/route_identity/textures';OUT.mkdir(parents=True,exist_ok=True)
def card(name,lines,bg=(34,50,49),fg=(219,220,191)):
 im=Image.new('RGB',(768,384),bg);d=ImageDraw.Draw(im);rng=random.Random(43)
 for _ in range(2000):
  x=rng.randrange(768);y=rng.randrange(384);c=tuple(max(0,min(255,v+rng.randrange(-12,13))) for v in bg);d.point((x,y),c)
 d.rectangle((15,15,752,368),outline=fg,width=3);y=(384-55*len(lines))//2
 for text in lines:
  size=50
  while True:
   font=ImageFont.truetype('C:/Windows/Fonts/bahnschrift.ttf',size);box=d.textbbox((0,0),text,font=font)
   if box[2]-box[0]<715:break
   size-=1
  d.text(((768-(box[2]-box[0]))/2,y),text,font=font,fill=fg);y+=55
 im.save(OUT/(name+'.png'))
LABELS={'store_sign':['NORTH RIDGE SUPPLY','GROCERIES - HARDWARE - FIELD EQUIPMENT'],'hours':['WINTER HOURS','MON - SAT   08:00 - 18:00','Deliveries: service entrance'],'beans':['NORTH RIDGE','BAKED BEANS','454 g'],'medical':['FIELD FIRST AID','STERILE DRESSINGS'],'matches':['STORM MATCHES','KEEP DRY'],'nails':['GALVANISED NAILS','HARDWARE   500 g'],'relay':['KESTREL RELAY 07','MAINTENANCE ACCESS','AUTHORIZED FIELD CREW'],'workorder':['SERVICE ORDER   KR-07','Standby supply: inspect connections','Town depot: North Ridge Supply','Log readings before departure'],'radio':['KR-07 SERVICE','CH 03'],'meter':['FIELD METER','DC     12.48 V','V     OHM     A'],'ledger':['NORTH RIDGE SUPPLY','DELIVERY LEDGER','Winter stock - depot collection']}
for i,title in enumerate(['UTILITY LODGE','FORESTRY CREW','VALLEY RESIDENCE','VALLEY RESIDENCE','VALLEY RESIDENCE']):LABELS['home_'+str(i)]=[title,'NORTH RIDGE / '+str(i+1).zfill(2)]
for name,lines in LABELS.items():
 card(name,lines,*(((212,202,170),(48,52,42)) if name in ['hours','workorder','ledger','medical'] else ((34,50,49),(219,220,191))))
print('ROUTE_GRAPHICS',len(LABELS))
