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
def food_label(name,flavour,ink):
 # Original cylindrical packaging: a narrow front panel, rear information,
 # painted food illustration and worn paper. All variants are the beans item.
 im=Image.new('RGB',(768,384),(211,199,162));d=ImageDraw.Draw(im);rng=random.Random(79)
 d.rectangle((0,0,767,27),fill=ink);d.rectangle((0,342,767,383),fill=ink)
 d.rectangle((203,29,565,340),fill=ink)
 def centered(text,y,size,color):
  font=ImageFont.truetype('C:/Windows/Fonts/bahnschrift.ttf',size)
  bounds=d.textbbox((0,0),text,font=font);d.text((384-(bounds[2]-bounds[0])/2,y),text,font=font,fill=color)
 cream=(235,223,186)
 d.polygon([(345,74),(367,45),(393,74)],fill=cream)
 d.polygon([(375,74),(398,40),(423,74)],fill=cream)
 d.polygon([(388,54),(398,40),(408,54),(399,51)],fill=ink)
 centered('NORTH RIDGE',84,32,cream);centered('BAKED BEANS',125,35,cream)
 centered(flavour,167,21,cream)
 d.ellipse((304,216,464,296),fill=(42,38,29),outline=cream,width=3)
 d.ellipse((314,222,454,289),fill=(125,60,28))
 for i in range(22):
  x=rng.randrange(323,440);y=rng.randrange(235,275)
  shade=rng.choice([(197,132,67),(218,157,86),(179,106,52)])
  d.ellipse((x-9,y-6,x+10,y+6),fill=shade,outline=(100,58,28),width=1)
  d.arc((x-3,y-4,x+5,y+4),80,260,fill=(137,76,36),width=2)
 centered('454 g  /  READY TO EAT',307,19,cream)
 font=ImageFont.truetype('C:/Windows/Fonts/bahnschrift.ttf',15)
 d.text((24,57),'PANTRY SUPPLY',font=font,fill=ink)
 for i,text in enumerate(['Heat or eat cold.','Store cool and dry.','Pack out empty tins.']):d.text((24,94+i*24),text,font=font,fill=ink)
 d.text((587,55),'INGREDIENTS',font=font,fill=ink)
 for i,text in enumerate(['Beans, water,','tomato, sugar,','salt and spices.']):d.text((587,88+i*24),text,font=font,fill=ink)
 for y in range(208,302,15):d.line((590,y,741,y),fill=ink,width=1)
 # Printed paper variation and fine abrasions retain the readable front.
 pix=im.load()
 for y in range(384):
  for x in range(768):
   delta=rng.randrange(-4,5);pix[x,y]=tuple(max(0,min(255,v+delta)) for v in pix[x,y])
 d=ImageDraw.Draw(im)
 for i in range(80):
  x=rng.randrange(768);y=rng.choice([rng.randrange(0,15),rng.randrange(330,384)])
  d.line((x,y,x+rng.randrange(1,9),y),fill=(193,183,150),width=1)
 im.save(OUT/(name+'.png'))
food_label('beans','CLASSIC RECIPE',(40,66,49))
food_label('tomato_beans','RICH TOMATO SAUCE',(126,48,33))
food_label('maple_beans','MAPLE AND MOLASSES',(109,77,36))
print('ROUTE_GRAPHICS',len(LABELS)+2)
