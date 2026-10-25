from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
out=Path(__file__).resolve().parent/'generated/city_letter';out.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(768,1024),(214,205,178));d=ImageDraw.Draw(im)
d.rectangle((38,45,730,385),fill=(157,173,163),outline=(80,94,82),width=4)
# Original line drawing of home, rather than borrowed photography.
for i,(x,h) in enumerate([(80,160),(170,215),(260,125),(360,260),(470,160),(580,190)]):
 d.rectangle((x,370-h,x+68,370),fill=(84,104,96),outline=(47,69,64),width=3)
 for y in range(395-h,350,35):
  for xx in [x+14,x+43]:d.rectangle((xx,y,xx+10,y+16),fill=(197,184,129))
d.line((45,350,720,350),fill=(63,89,78),width=6)
for i,line in enumerate(['SUNDAY / FROM ELISE','One week is not forever.','Write when you get there.','Your watch is in the bag.','Come home with a story.']):d.text((67,450+i*86),line,font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',32 if i else 34),fill=(52,64,53))
d.line((66,913,689,913),fill=(98,111,87),width=2);im.save(out/'letter.png')
