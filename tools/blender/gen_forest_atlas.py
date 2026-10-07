"""Original mip-safe evergreen sprays, with separate loaded/green paint."""
from pathlib import Path
import random,math,json,hashlib
from PIL import Image,ImageDraw,ImageFilter
R=Path(__file__).resolve().parents[2];OUT=R/'tools/blender/generated/forest_quality';OUT.mkdir(parents=True,exist_ok=True)
S=2048;rng=random.Random(71739);im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im)
stem=[(S*(.035+.91*t/32),S*(.50+.03*math.sin(t/32*math.pi))) for t in range(33)]
d.line(stem,fill=(86,74,55,255),width=16,joint='curve')
for j in range(24):
 t=.08+j*.036;base=(S*(.035+.91*t),S*(.50+.03*math.sin(t*math.pi)))
 for side in [-1,1]:
  angle=side*rng.uniform(.82,1.20);length=S*(.18*(1-t*.63))*rng.uniform(.88,1.12)
  tip=(base[0]+math.cos(angle)*length,base[1]+math.sin(angle)*length)
  d.line([base,tip],fill=(63,82,59,255),width=42)
  for k in range(16):
   u=k/17;p=(base[0]+(tip[0]-base[0])*u,base[1]+(tip[1]-base[1])*u)
   for sign in [-1,1]:
    a=angle+sign*rng.uniform(.65,1.15);nl=S*rng.uniform(.015,.025)*(1-u*.35)
    end=(p[0]+math.cos(a)*nl,p[1]+math.sin(a)*nl)
    tone=rng.randint(-5,9);d.line([p,end],fill=(63+tone,88+tone,65+tone,255),width=rng.randint(7,11))
    # Dense near-axis needle clusters retain coverage when mipmapped, while
    # outer needles provide the irregular botanical outline.
    rr=S*.009;d.ellipse((p[0]-rr,p[1]-rr,p[0]+rr,p[1]+rr),fill=(61+tone,83+tone,61+tone,255))
im=im.resize((1024,1024),Image.Resampling.LANCZOS)
# Fine supported snow follows the existing spray rather than enlarging alpha.
# The coarse geometry supplies depth; this paint breaks up the long white cap.
snow=Image.new('RGBA',(1024,1024));sd=ImageDraw.Draw(snow);snow_rng=random.Random(71741)
for j in range(23):
 t=.08+j*.036;base=(1024*(.035+.91*t),1024*(.50+.03*math.sin(t*math.pi)))
 for side in [-1,1]:
  angle=side*snow_rng.uniform(.85,1.16);length=1024*(.18*(1-t*.63))*snow_rng.uniform(.70,.98)
  for k in range(5):
   u=.08+k*.18;x=base[0]+math.cos(angle)*length*u;y=base[1]+math.sin(angle)*length*u
   rr=snow_rng.uniform(11,19)*(1-u*.32);tone=snow_rng.randint(-8,7)
   sd.ellipse((x-rr*1.1,y-rr*.58,x+rr*1.1,y+rr*.58),fill=(185+tone,199+tone,209+tone,245))
snow=snow.filter(ImageFilter.GaussianBlur(1.0));loaded=Image.alpha_composite(im,snow);loaded.putalpha(im.getchannel('A'))
# Dilation of RGB only prevents black fringes in alpha mipmaps.
rgb=im.convert('RGB');alpha=im.getchannel('A');rgb=rgb.filter(ImageFilter.MaxFilter(5));rgb.putalpha(alpha)
p=OUT/'needle_spray.png';rgb.save(p)
loaded_rgb=loaded.convert('RGB').filter(ImageFilter.MaxFilter(5));loaded_rgb.putalpha(alpha);loaded_path=OUT/'needle_spray_snow.png';loaded_rgb.save(loaded_path)
atlas=Image.new('RGBA',(2048,1024));atlas.paste(rgb,(0,0));atlas.paste(loaded_rgb,(1024,0));atlas_path=OUT/'crown_sprays.png';atlas.save(atlas_path)
(OUT/'texture_provenance.json').write_text(json.dumps({'origin':'Original Pillow botanical paint','seed':71739,'snow_seed':71741,'dimensions':[1024,1024],'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'snow_sha256':hashlib.sha256(loaded_path.read_bytes()).hexdigest(),'atlas_sha256':hashlib.sha256(atlas_path.read_bytes()).hexdigest(),'atlas_dimensions':[2048,1024]},indent=2)+'\n')
print('FOREST_ATLAS_READY')
