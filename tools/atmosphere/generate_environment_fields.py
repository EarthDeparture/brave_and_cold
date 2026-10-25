"""Original periodic winter materials and botanical bough atlas. No external images."""
from pathlib import Path
import json, hashlib, math
import numpy as np
from scipy.ndimage import map_coordinates, gaussian_filter
from scipy.spatial import cKDTree
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"brave-and-cold/assets/environment_detail/textures"
OUT.mkdir(parents=True,exist_ok=True)
N=1024
rng=np.random.default_rng(3103)
y,x=np.mgrid[:N,:N].astype(np.float32)
def noise(scales,weights):
    out=np.zeros((N,N),np.float32)
    for size,weight in zip(scales,weights):
        g=rng.random((size,size),dtype=np.float32)
        q=np.arange(N,dtype=np.float32)*size/N
        out+=weight*map_coordinates(g,np.array(np.meshgrid(q,q,indexing="ij")),order=3,mode="grid-wrap")
    return np.clip(out,0,1)
coarse=noise([4,8,16],[.55,.30,.15])
medium=noise([16,32,64],[.50,.30,.20])
fine=noise([64,128,256],[.45,.35,.20])
grain=noise([256,512],[.6,.4])
wave=.5+.5*np.sin(math.tau*(y/N*9+x/N*2)+(coarse-.5)*2.0)
ridge=wave**2
def normal(h,strength):
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*strength
    dy=(np.roll(h,-1,0)-np.roll(h,1,0))*strength
    d=np.stack([-dx,-dy,np.ones_like(h)],axis=-1)
    d/=np.linalg.norm(d,axis=-1)[...,None]
    return d*.5+.5
def save(name,rgb,height,rough,strength):
    Image.fromarray(np.uint8(np.clip(np.dstack([rgb,height]),0,1)*255),"RGBA").save(OUT/(name+"_alb.png"))
    Image.fromarray(np.uint8(np.clip(np.dstack([normal(height,strength),rough]),0,1)*255),"RGBA").save(OUT/(name+"_nrm.png"))
h=.46+ridge*.075+(medium-.5)*.10+(grain-.5)*.004
rgb=np.tile(np.array([.895,.919,.950]),(N,N,1))
rgb*= (.975+coarse*.025+ridge*.018)[...,None]
save("powder",rgb,h,.88+coarse*.05-ridge*.08,22)
rock_h=.45+(coarse-.5)*.16+(medium-.5)*.06
fault=np.exp(-((np.sin(math.tau*(x/N*5+y/N*2)+(coarse-.5)*3))/.10)**2)
rock_h-=fault*.025
rgb=np.array([.22,.245,.275])+(coarse[...,None]-.3)*np.array([.22,.20,.19])
rgb*= (1-fault*.12)[...,None]
save("bedrock",rgb,rock_h,np.full((N,N),.91),8)
forest_h=.46+(medium-.5)*.10+(fine-.5)*.015
rgb=np.array([.27,.265,.25])+(medium[...,None]-.5)*.12
cover=np.clip((coarse-.43)*1.8,0,.55)
rgb=rgb*(1-cover[...,None])+np.array([.80,.84,.89])*cover[...,None]
save("forest_snow",rgb,forest_h,np.full((N,N),.94),5)
# Toroidal, warped cellular fractures at two scales; avoid straight repeated seams.
coords=np.stack([x.ravel()/N,y.ravel()/N],axis=-1)
coords[:,0]+=((medium-.5)*.035).ravel()
coords[:,1]+=((coarse-.5)*.045).ravel()
coords%=1
def fractures(count):
    seeds=rng.random((count,2))
    tree=cKDTree(seeds,boxsize=1)
    d,_=tree.query(coords,k=2)
    edge=(d[:,1]-d[:,0]).reshape(N,N)
    return np.exp(-(edge/.0014)**2).astype(np.float32)
cracks=fractures(46)
secondary=fractures(290)*np.clip((medium-.51)*7,0,.50)
cracks=np.maximum(cracks,secondary)
cloud=np.clip((coarse-.40)*1.5,0,.8)
drift=np.clip((medium+ridge*.08-.64)*3.0,0,.65)
bubbles=(grain>.69).astype(np.float32)*np.clip((fine-.52)*4,0,.5)
detail=np.stack([cracks,cloud,drift,bubbles],axis=-1)
Image.fromarray(np.uint8(detail*255),"RGBA").save(OUT/"ice_fields.png")
# Timber: scale-separated grain, pores and understated ring changes.
wood=(.5+.5*np.sin(math.tau*x/N*38+(coarse-.5)*4+(medium-.5)*.7))**6
wood_h=.5-wood*.06+(fine-.5)*.018
rgb=np.array([.59,.49,.37])*(.85+coarse*.20-wood*.10)[...,None]
save("timber",rgb,wood_h,.78+medium*.12,9)
# Botanical atlas drawn from a seeded branching structure, supersampled.
S=2048; botanical=np.random.default_rng(42419)
im=Image.new("RGBA",(S,S),(0,0,0,0)); draw=ImageDraw.Draw(im)
stem=[]
for j in range(25):
    t=j/24
    stem.append((int(S*(.07+.86*t)),int(S*(.52+.035*math.sin(t*math.pi)))))
draw.line(stem,fill=(73,60,43,255),width=12,joint="curve")
snow=[]
for side in [-1,1]:
    for j in range(45):
        t=.065+j*.019
        base=np.array([S*(.07+.86*t),S*(.52+.035*math.sin(t*math.pi))])
        length=S*(.105*(1-t*.55))*botanical.uniform(.82,1.20)
        angle=side*botanical.uniform(.72,1.12)
        axis=np.array([math.cos(angle),math.sin(angle)])
        tip=base+axis*length
        draw.line([tuple(base),tuple(tip)],fill=(40,62,44,255),width=17)
        for k in range(16):
            u=(k+.5)/17
            p=base+axis*length*u
            for outward in [-1,1]:
                a=angle+outward*botanical.uniform(.8,1.4)
                nl=S*botanical.uniform(.005,.013)*(1-u*.25)
                end=p+np.array([math.cos(a),math.sin(a)])*nl
                colour=(int(botanical.integers(32,62)),int(botanical.integers(65,93)),int(botanical.integers(47,73)),255)
                draw.line([tuple(p),tuple(end)],fill=colour,width=int(botanical.integers(3,6)))
        # Packed snow follows the woody twig; needle ends stay exposed.
        if botanical.random()<.86:
            for k in range(7):
                u=.10+k*.115
                p=base+axis*length*u
                rx=S*botanical.uniform(.006,.012);ry=rx*botanical.uniform(.40,.75)
                tone=int(botanical.integers(204,224))
                draw.ellipse((p[0]-rx,p[1]-ry,p[0]+rx,p[1]+ry),fill=(tone,min(235,tone+8),min(245,tone+18),255))
for j in range(20):
    px,py=stem[j]
    draw.ellipse((px-19,py-9,px+24,py+7),fill=(215,223,235,255))
im=im.resize((N,N),Image.Resampling.LANCZOS)
im.save(OUT/"bough_albedo.png")
alpha=np.asarray(im)[...,3]
assert .07<(alpha>128).mean()<.65,float((alpha>128).mean())
receipt={"schema":1,"origin":"Original project-authored procedural textures and botanical atlas","generator":"tools/atmosphere/generate_environment_fields.py","seed":3103,"botanical_seed":42419,"dimensions":[N,N],"terrain_packing":"albedo RGB + height A; normal RGB + roughness A","ice_packing":"R fractures, G cloudiness, B drift, A trapped bubbles","botanical_alpha_coverage":float((alpha>128).mean()),"files":[]}
for path in sorted(OUT.glob("*.png")):
    receipt["files"].append({"file":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT/"provenance.json").write_text(json.dumps(receipt,indent=2)+"\n")
print("ENVIRONMENT_FIELDS",len(receipt["files"]),"bough coverage",receipt["botanical_alpha_coverage"])
