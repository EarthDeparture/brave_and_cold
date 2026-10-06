"""Original deterministic printwork and PBR surfaces for the field equipment kit."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter

OUT = Path(__file__).parent / 'generated/field_survival_kit_v1/textures'
OUT.mkdir(parents=True, exist_ok=True)
N = 512
rng = np.random.default_rng(20261006)
y, x = np.mgrid[:N, :N]
fine = rng.normal(0, 1, (N, N))
coarse = gaussian_filter(fine, 9, mode='wrap') * 18
for name, color in [('steel', [176,181,178]), ('enamel', [235,232,222]),
                    ('canvas', [102,115,81]), ('leather', [105,70,49]),
                    ('wood', [164,113,59]), ('rubber', [45,49,46]),
                    ('cotton', [219,215,196]), ('stone', [149,147,134])]:
    if name in ('canvas', 'cotton'):
        h = .35*np.sin(x*np.pi/2) + .35*np.sin(y*np.pi/2) + fine*.08
        variation = h*6 + coarse*3
        rough = .91
    elif name == 'wood':
        h = np.sin(x*.19 + np.sin(y*.013)*2) * .35 + fine*.03
        variation = h*15 + coarse*3
        rough = .78
    elif name == 'stone':
        h=gaussian_filter(fine,1.2,mode='wrap')*2+coarse*.4
        variation=h*13+fine*7
        rough=.94
    elif name == 'leather':
        h = gaussian_filter(fine, .9, mode='wrap') + coarse*.1
        variation = h*7 + coarse*4
        rough = .85
    elif name == 'rubber':
        h = fine*.06
        variation = fine*1.5
        rough = .86
    else:
        h = fine*.02
        variation = fine*1.8 + coarse*3
        rough = .53 if name == 'steel' else .65
        for _ in range(80):
            xx, yy = rng.integers(0,N,2)
            width = int(rng.integers(4,35))
            variation[yy,xx:min(N,xx+width)] -= rng.uniform(8,22)
    a = np.clip(np.array(color)[None,None,:]+variation[:,:,None],0,255).astype('uint8')
    Image.fromarray(a).save(OUT/(name+'_base.png'))
    rr = np.clip(rough*255 + variation*.3, 0, 255).astype('uint8')
    Image.fromarray(rr).save(OUT/(name+'_rough.png'))
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*.16
    dy=(np.roll(h,-1,0)-np.roll(h,1,0))*.16
    normal=np.stack([-dx,-dy,np.ones_like(dx)],axis=2)
    normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    Image.fromarray(np.clip((normal*.5+.5)*255,0,255).astype('uint8')).save(OUT/(name+'_normal.png'))

# Explicit tinted colour maps render identically in Blender and glTF/Godot.
for key,family,tint in [('dark_steel','steel',(.30,.34,.32)),('red','enamel',(.64,.12,.075)),
                        ('ochre','enamel',(.8,.53,.08)),('green','enamel',(.13,.24,.19)),
                        ('blue','enamel',(.23,.48,.65)),('gold','steel',(.85,.62,.12)),
                        ('rust','enamel',(.41,.19,.09)),('glass','steel',(.28,.34,.30)),
                        ('white','enamel',(1,1,1))]:
    a=np.asarray(Image.open(OUT/(family+'_base.png')),dtype=float)*np.array(tint)
    Image.fromarray(np.clip(a,0,255).astype('uint8')).save(OUT/(key+'_base.png'))

def font(n): return ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', n)
def panel(name, bg, lines, stripe=(50,68,56)):
    im=Image.new('RGB',(1024,512),bg);d=ImageDraw.Draw(im)
    d.rectangle((12,12,1011,499),outline=stripe,width=6)
    d.rectangle((22,22,1001,95),fill=stripe)
    for i,line in enumerate(lines):
        d.text((512,56 if i==0 else 132+(i-1)*79),line,
               font=font(40 if i==0 else 32),fill=bg if i==0 else stripe,anchor='mm')
    # Physical print scuffs, restrained enough to preserve instructions.
    for _ in range(45):
        px,py=rng.integers(25,980),rng.integers(110,480)
        d.line((int(px),int(py),int(px+7),int(py)),fill=bg,width=1)
    im.save(OUT/(name+'.png'))
panel('propane_label',(218,203,168),['NORTH RIDGE / FUEL','PROPANE / KEEP UPRIGHT','OUTDOOR EQUIPMENT ONLY','VALVE CLOSED FOR STORAGE'])
panel('fuel_label',(222,203,167),['FIELD SUPPLY','FUEL / 10 L','VENT BEFORE POURING','KEEP AWAY FROM FLAME'],(116,43,32))
panel('radio_dial',(216,211,184),['NORTH RIDGE / PORTABLE','AM  530  700  1000  1600','FM  88  94  100  108','PUBLIC / WEATHER / FIELD'])
# Tuning strips require a wide layout rather than a squashed package label.
im=Image.new('RGB',(1536,256),(218,215,187));d=ImageDraw.Draw(im)
d.rectangle((9,9,1526,246),outline=(50,62,51),width=5)
d.text((32,52),'AM',font=font(45),fill=(50,62,51),anchor='lm')
d.text((32,193),'FM',font=font(45),fill=(50,62,51),anchor='lm')
for k in range(25):
    xx=160+k*53;d.line((xx,112,xx,150 if k%6==0 else 133),fill=(50,62,51),width=3)
for xx,am,fm in [(160,'530','88'),(478,'700','94'),(1114,'1000','100'),(1432,'1600','108')]:
    d.text((xx,52),am,font=font(46),fill=(50,62,51),anchor='mm')
    d.text((xx,193),fm,font=font(46),fill=(50,62,51),anchor='mm')
im.save(OUT/'radio_dial.png')
panel('matches_label',(225,214,178),['NORTH RIDGE','SAFETY MATCHES','KEEP DRY / 40 MATCHES'])
panel('battery_label',(225,215,171),['FIELD CELL','1.5 V / ALKALINE','DO NOT RECHARGE'])
panel('bandage_label',(229,224,202),['FIELD DRESSING','STERILE / KEEP DRY','5 cm x 3 m / SINGLE USE'],(97,69,55))
for name,title,color in [('beans','BAKED BEANS',(91,116,69)),('soup','VEGETABLE SOUP',(150,83,48)),('fish','PACKED FISH',(69,105,125)),('fruit','PEACH HALVES',(174,132,49))]:
    panel('can_'+name,(220,211,181),['NORTH RIDGE / PANTRY',title,'NET 400 g / SHELF STABLE','OPEN / HEAT / EAT'],color)
im=Image.new('RGB',(512,512),(224,217,183));d=ImageDraw.Draw(im)
for k in range(72):
    a=k*np.pi/36;r=210;r2=193 if k%6 else 175
    d.line((256+np.sin(a)*r,256-np.cos(a)*r,256+np.sin(a)*r2,256-np.cos(a)*r2),fill=(52,60,51),width=2)
for s,px,py in [('N',256,104),('E',410,256),('S',256,410),('W',104,256)]:
    d.text((px,py),s,font=font(42),fill=(136,50,39) if s=='N' else (52,60,51),anchor='mm')
d.ellipse((185,185,327,327),outline=(81,92,69),width=3)
im.save(OUT/'compass_dial.png')
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.png'))}
(OUT/'manifest.json').write_text(json.dumps({'original':True,'seed':20261006,'normal_convention':'OpenGL +Y','files':files},indent=2)+'\n',encoding='utf-8')
print('FIELD_KIT_TEXTURES',len(files))
