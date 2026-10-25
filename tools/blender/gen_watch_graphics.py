from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math
out=Path(__file__).resolve().parent/'generated/wristwatch';out.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(512,512),(23,31,30));d=ImageDraw.Draw(im);d.ellipse((8,8,504,504),fill=(33,40,37),outline=(172,177,148),width=8)
for k in range(60):
 a=k*math.tau/60;ra=217 if k%5 else 203;d.line((256+math.sin(a)*ra,256-math.cos(a)*ra,256+math.sin(a)*232,256-math.cos(a)*232),fill=(209,214,177),width=5 if k%5==0 else 2)
for num in [12,3,6,9]:
 a=num*math.tau/12;d.text((256+math.sin(a)*165,256-math.cos(a)*165),str(num),font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',47),fill=(215,218,189),anchor='mm')
d.text((256,185),'NORTH RIDGE',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17),fill=(159,179,163),anchor='mm');d.text((256,330),'FIELD / 24H',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16),fill=(159,179,163),anchor='mm');im.save(out/'dial.png')
