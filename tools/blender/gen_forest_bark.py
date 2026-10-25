"""Original fissured conifer bark; retain the existing pale birch atlas half."""
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates
from PIL import Image
import json, hashlib
R=Path(__file__).resolve().parents[2]; O=R/'tools/blender/generated/forest_quality'
rng=np.random.default_rng(71740); h=1024; w=512
y,x=np.mgrid[:h,:w]; warp=gaussian_filter(rng.normal(size=(h,w)),(24,16))*85
# Independently placed irregular fissures avoid sinusoidal zigzag repetition.
height=np.full((h,w),.58)
for center in np.cumsum(rng.uniform(12,29,45)):
 c=np.mod(center+warp+gaussian_filter(rng.normal(size=h),18)[:,None]*10,w)
 distance=np.abs(np.mod(x-c+w/2,w)-w/2)
 height-=np.exp(-(distance/rng.uniform(1.0,2.1))**2)*rng.uniform(.12,.25)
height+=gaussian_filter(rng.normal(size=(h,w)),(2,1))*.035
height+=gaussian_filter(rng.normal(size=(h,w)),(18,10))*.55
height=np.clip(height,.18,.8)
tone=height*.38+.69
color=np.clip(tone[:,:,None]*np.array([91,86,75]),0,255).astype('uint8')
old=Image.open(R/'brave-and-cold/assets/environment_detail/tree_diversity/winter_bark.png').convert('RGB').resize((1024,1024))
old.paste(Image.fromarray(color),(0,0));old.save(O/'winter_bark.png')
dy,dx=np.gradient(height); n=np.dstack([-dx*3,-dy*3,np.ones((h,w))]);n/=np.linalg.norm(n,axis=2)[:,:,None]
normal=Image.open(R/'brave-and-cold/assets/environment_detail/tree_diversity/winter_bark_normal.png').convert('RGB').resize((1024,1024))
normal.paste(Image.fromarray(((n*.5+.5)*255).astype('uint8')),(0,0));normal.save(O/'winter_bark_normal.png')
provenance=json.loads((O/'texture_provenance.json').read_text())
provenance['bark']={'seed':71740,'origin':'Original non-periodic conifer fissures; existing project-authored pale birch half retained','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [O/'winter_bark.png',O/'winter_bark_normal.png']}}
(O/'texture_provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
print('FOREST_BARK_READY')
