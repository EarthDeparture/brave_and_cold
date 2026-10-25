from pathlib import Path
import numpy as np
from scipy.ndimage import map_coordinates
from PIL import Image
root=Path(__file__).resolve().parents[2]
rng=np.random.default_rng(1337)
n=1024
def field(scales, weights):
    out=np.zeros((n,n),dtype=np.float32)
    for size,weight in zip(scales,weights):
        grid=rng.random((size,size),dtype=np.float32)
        # Grid-wrap interpolation is continuous at both ends of the texture.
        indices=np.arange(n,dtype=np.float32)*size/n
        coords=np.array(np.meshgrid(indices,indices,indexing="ij"))
        layer=map_coordinates(grid,coords,order=3,mode="grid-wrap",prefilter=True)
        out+=weight*layer
    return np.clip(out,0,1)
density=field([8,16,32,64,128],[.48,.25,.15,.08,.04])
detail=field([16,32,64,128,256],[.44,.28,.16,.08,.04])
warp=field([4,8,16,32],[.55,.27,.13,.05])
data=np.stack([density,detail,warp],axis=-1)
target=root/"brave-and-cold/assets/textures/atmosphere/cloud_fields.png"
target.parent.mkdir(parents=True,exist_ok=True)
Image.fromarray(np.uint8(data*255),"RGB").save(target)
print("CLOUD_FIELDS",target,"density",float(density.min()),float(density.max()),float(density.mean()))
