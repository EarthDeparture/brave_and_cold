from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"brave-and-cold/assets/route_detail";OUT.mkdir(parents=True,exist_ok=True)
fontpath='C:/Windows/Fonts/bahnschrift.ttf'
image=Image.new('RGB',(1024,1024),(171,166,143));d=ImageDraw.Draw(image)
font=lambda n:ImageFont.truetype(fontpath,n)
d.rectangle((30,25,994,150),fill=(35,47,46));d.text((74,46),'LOOKOUT / RELAY POWER',font=font(58),fill=(225,219,189))
d.text((75,172),'FIELD DISTRIBUTION   •   UNIT 04',font=font(30),fill=(42,48,43))
d.rectangle((82,247,480,491),fill=(225,220,190),outline=(51,56,50),width=12)
for angle in range(20,161,10):
 a=math.radians(angle);x=281+148*math.cos(a);y=431-145*math.sin(a)
 d.line((x,y,281+125*math.cos(a),431-122*math.sin(a)),fill=(35,38,32),width=5)
d.line((281,438,365,330),fill=(149,52,30),width=6);d.ellipse((264,421,298,455),fill=(36,39,34));d.text((220,453),'V AC',font=font(25),fill=(40,42,35))
labels=['RELAY','LOOKOUT','HEAT','SPARE']
for i,label in enumerate(labels):
 y=565+i*88;d.text((75,y),label,font=font(43),fill=(36,43,37));d.text((405,y+3),'10 A' if i!=2 else '15 A',font=font(28),fill=(68,65,53))
d.rectangle((553,275,960,442),fill=(214,177,63));d.polygon([(595,404),(750,297),(903,404)],outline=(33,35,31),fill=(232,199,81));d.line((762,328,735,367,767,362,746,394),fill=(36,36,29),width=12)
d.text((565,462),'ISOLATE BEFORE SERVICE',font=font(22),fill=(38,41,32))
d.text((565,914),'MAINTENANCE LOG: 07 / 12',font=font(22),fill=(54,57,46))
# Independent, subtle paint abrasion keeps the labels readable.
import random
rng=random.Random(20261004)
for i in range(500):
 x=rng.randrange(1024);y=rng.randrange(1024)
 if x<45 or x>984:d.line((x,y,x+rng.randrange(1,8),y+1),fill=(108,111,98),width=1)
texture=OUT/'panel_face.png';image.save(texture)
