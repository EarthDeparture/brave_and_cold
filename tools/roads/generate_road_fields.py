"""Original seamless winter-road fields and Canadian-inspired sign artwork.
All markings and silhouettes are project authored, with no downloaded images.
"""
from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates, gaussian_filter
from PIL import Image, ImageDraw, ImageFont
import json, hashlib, math
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'brave-and-cold/assets/road_detail/textures';OUT.mkdir(parents=True,exist_ok=True)
N=1024;rng=np.random.default_rng(100326)
def field(cells):
    values=rng.random((cells,cells)).astype(np.float32)
    coords=np.arange(N,dtype=np.float32)*cells/N
    return np.clip(map_coordinates(values,np.array(np.meshgrid(coords,coords,indexing='ij')),order=3,mode='grid-wrap'),0,1)
large=field(8);med=field(48);small=field(256);grain=rng.random((N,N)).astype(np.float32)
def save(name,rgb,height,rough,strength):
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*strength
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*strength
    normals=np.stack([-dx,-dy,np.ones_like(height)],axis=-1)
    normals/=np.linalg.norm(normals,axis=-1)[...,None]
    for suffix,data in [('alb',np.dstack([rgb,height])),('nrm',np.dstack([normals*.5+.5,rough]))]:
        Image.fromarray(np.uint8(np.clip(data,0,1)*255),'RGBA').save(OUT/f'{name}_{suffix}.png')
aggregate=np.clip((small-.40)*2,0,1)
height=.5+(small-.5)*.042+(grain-.5)*.006
rgb=np.array([.24,.255,.265])*(.85+large*.18+(aggregate-.5)*.16)[...,None]
save('aggregate',rgb,height,.80+med*.12,16)
# Packed spatial controls: broad breakup, deposits, fine crust, slush flecks.
packed=np.stack([large,med,small,gaussian_filter(grain,1,mode='wrap')],axis=-1)
Image.fromarray(np.uint8(packed*255),'RGBA').save(OUT/'road_fields.png')
# Supersampled bespoke sign symbols, clean borders, restrained edge grime.
S=2048;black=(22,25,23);yellow=(227,180,43);white=(221,222,208)
font_path=Path('C:/Windows/Fonts/bahnschrift.ttf')
if not font_path.exists():font_path=Path('C:/Windows/Fonts/arialbd.ttf')
def pts(points):return [(int(x*S),int(y*S)) for x,y in points]
def ellipse(draw,bounds,fill=black):draw.ellipse(tuple(int(v*S) for v in bounds),fill=fill)
def line(draw,points,width,fill=black):draw.line(pts(points),fill=fill,width=int(width*S),joint='curve')
def poly(draw,points,fill=black):draw.polygon(pts(points),fill=fill)
def text(draw,value,center,size,fill=black):
    font=ImageFont.truetype(str(font_path),int(size*S));draw.text((center[0]*S,center[1]*S),value,font=font,fill=fill,anchor='mm',stroke_width=0)
for kind in ['speed','deer','bear','icy','curve_left','curve_right']:
    im=Image.new('RGB',(S,S),white if kind=='speed' else yellow);d=ImageDraw.Draw(im)
    if kind=='speed':
        d.rounded_rectangle((.035*S,.028*S,.965*S,.972*S),radius=.040*S,outline=black,width=int(.019*S))
        text(d,'MAXIMUM',(.5,.23),.105)
        text(d,'50',(.5,.58),.49)
        text(d,'km/h',(.5,.85),.075)
    else:
        poly(d,[(.5,.024),(.976,.5),(.5,.976),(.024,.5)])
        poly(d,[(.5,.052),(.948,.5),(.5,.948),(.052,.5)],yellow)
        symbol=Image.new("RGBA",(S,S),(0,0,0,0));d=ImageDraw.Draw(symbol)
        if kind=='deer':
            # Leaping ungulate: slim torso, tapered neck, split hooves and antlers.
            ellipse(d,(.30,.38,.66,.56));poly(d,[(.55,.48),(.64,.28),(.69,.29),(.65,.51)])
            ellipse(d,(.63,.26,.76,.34));poly(d,[(.72,.28),(.82,.31),(.74,.345)])
            poly(d,[(.315,.43),(.235,.34),(.25,.40),(.32,.49)])
            line(d,[(.35,.52),(.31,.64),(.22,.68)],.030)
            line(d,[(.43,.53),(.43,.63),(.39,.73)],.026)
            line(d,[(.61,.48),(.71,.55),(.78,.53)],.026)
            line(d,[(.58,.53),(.65,.65),(.72,.67)],.026)
            for points in [[(.66,.28),(.64,.20),(.60,.17)],[(.64,.22),(.69,.16)],[(.68,.28),(.72,.20),(.78,.19)],[(.73,.22),(.73,.16)]]:line(d,points,.012)
            poly(d,[(.66,.29),(.64,.24),(.685,.27)])
        elif kind=='bear':
            ellipse(d,(.24,.37,.65,.61));ellipse(d,(.55,.40,.75,.59))
            poly(d,[(.69,.43),(.81,.50),(.78,.56),(.67,.55)])
            ellipse(d,(.61,.37,.67,.44));ellipse(d,(.28,.32,.46,.50))
            for a,b in [(.31,.39),(.49,.55),(.63,.69)]:poly(d,[(a,.52),(b,.52),(b+.01,.70),(a-.04,.70)])
            poly(d,[(.26,.43),(.20,.46),(.25,.49)])
        elif kind=='icy':
            # Vehicle and skid tracks: avoid ambiguous text-only warning.
            poly(d,[(.31,.33),(.38,.26),(.62,.26),(.69,.33),(.72,.47),(.28,.47)])
            poly(d,[(.39,.29),(.61,.29),(.65,.35),(.35,.35)],yellow)
            line(d,[(.31,.46),(.31,.52)],.050);line(d,[(.69,.46),(.69,.52)],.050)
            for x in [.36,.64]:line(d,[(x,.55),(x-.07,.59),(x+.035,.64),(x-.035,.70)],.020)
        else:
            left=kind=='curve_left'
            points=[(.55,.72),(.55,.52),(.53,.46),(.42,.42),(.30,.42)]
            if not left:points=[(1-x,y) for x,y in points]
            line(d,points,.085)
            arrow=[(.24,.42),(.38,.31),(.38,.53)]
            poly(d,arrow if left else [(1-x,y) for x,y in arrow])
    if kind!="speed":
        scale=.74 if kind=="deer" else 1.0
        side=int(S*scale);symbol=symbol.resize((side,side),Image.Resampling.LANCZOS)
        im.paste(symbol,((S-side)//2,(S-side)//2),symbol)
    a=np.asarray(im).astype(np.float32)/255
    yy,xx=np.mgrid[:S,:S]/S
    edge=np.minimum.reduce([xx,yy,1-xx,1-yy])
    wear_rng=np.random.default_rng(55+len(kind))
    wear=wear_rng.random((S,S)).astype(np.float32)
    # Slightly weathered, readable graphic; no heavy noise across type/icons.
    tint=(.985+.015*wear)[...,None]
    a*=tint
    grime=np.exp(-edge*85)*.13
    a*=1-grime[...,None]
    a=np.uint8(np.clip(a,0,1)*255)
    Image.fromarray(a,'RGB').resize((1024,1024),Image.Resampling.LANCZOS).save(OUT/f'sign_{kind}.png')
files=sorted(OUT.glob('*.png'))
receipt={'generator':'tools/roads/generate_road_fields.py','seed':100326,'dimensions':1024,'origin':'Original project-authored procedural road fields and bespoke sign graphics','license':'Project authored; no third-party image assets','font':'System Bahnschrift rasterized into artwork; no font redistribution','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
(OUT/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('ROAD_FIELDS',len(files))
