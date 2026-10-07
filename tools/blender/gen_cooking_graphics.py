"""Original marbled game-meat texture. Deterministic local raster, no downloaded art."""
from pathlib import Path
import numpy as np
from PIL import Image
out=Path(__file__).resolve().parents[2]/'tools/blender/generated/cooking';out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(7109);y,x=np.mgrid[:512,:512]
noise=rng.normal(0,3,(512,512))+4*np.sin(x*.18+y*.02)
vein=np.exp(-np.square(np.sin(x*.020+np.sin(y*.018)*1.5)*13))*64
col=np.stack((125+noise+vein,48+noise*.5+vein*.95,41+noise*.5+vein*.8),axis=-1)
Image.fromarray(np.uint8(np.clip(col,0,255))).save(out/'meat_marbling.png');print('COOKING_GRAPHIC 512 seed=7109')

# Distinct roasted surface, with the same cut and fat-vein structure.
cooked=np.stack((100+noise*.8+vein*.5,69+noise*.6+vein*.45,43+noise*.5+vein*.3),axis=-1)
Image.fromarray(np.uint8(np.clip(cooked,0,255))).save(out/"meat_seared.png")
