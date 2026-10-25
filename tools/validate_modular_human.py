"""Independent contracts on exported bytes, not generator self-reported counts."""
from pathlib import Path
import json,hashlib,numpy as np
from glb_geometry import GLB
R=Path(__file__).resolve().parents[1];D=R/'brave-and-cold/assets/modular_human';S=R/'tools/blender/generated/modular_human'
m=json.loads((D/'manifest.json').read_text());checks=0;reports=[];coat=[];skins=[]
def check(ok,label):
 global checks
 assert ok,label;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
check(sha(S/'human_foundation.blend')==m['native_sha256'],'native source hash')
check(sha(R/'tools/blender/gen_modular_human.py')==m['generator_sha256'],'generator hash')
for name,h in m['textures'].items():check(sha(S/name)==h,'authored texture hash '+name)
for model in m['exports']:
 path=D/(model['id']+'.glb');check(sha(path)==model['sha256'],'export hash');g=GLB(path);d=g.doc
 check(len(d['skins'])==1 and len(d['skins'][0]['joints'])==45,'single 45-bone contract')
 names={d['nodes'][j]['name'] for j in d['skins'][0]['joints']};check(names==set(m['bones']),'actual joint names match contract')
 check(all('zombie_'+limb+'_'+side in {n['name'] for n in d['nodes']} for limb in ['arm','elbow','leg','knee'] for side in ['l','r']),'existing logical drivers retained')
 tris=0;surfaces=0;points=[]
 for mesh in d['meshes']:
  for pr in mesh['primitives']:
   p=g.acc(pr['attributes']['POSITION']);idx=g.acc(pr['indices']).ravel();points.append(p);tris+=len(idx)//3;surfaces+=1
   check(np.isfinite(p).all() and idx.max()<len(p) and len(idx)%3==0,'finite indexed '+mesh['name'])
   tri=p[idx.reshape(-1,3)];check((np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)>1e-10).all(),'nondegenerate '+mesh['name'])
   w=g.acc(pr['attributes']['WEIGHTS_0']);j=g.acc(pr['attributes']['JOINTS_0']);check(np.max(abs(w.sum(axis=1)-1))<.001 and j.max()<45 and (w>=0).all(),'normalized skin '+mesh['name'])
   normal=g.acc(pr['attributes']['NORMAL']);check(np.isfinite(normal).all() and np.max(abs(np.linalg.norm(normal,axis=1)-1))<.001,'unit normals '+mesh['name'])
 check(tris==model['triangles'] and tris<=40000 and surfaces==model['surfaces'] and surfaces<=10,'measured near mesh budget')
 p=np.concatenate(points);lo=p.min(axis=0);hi=p.max(axis=0)
 check(1.70<hi[1]-lo[1]<1.85 and hi[0]-lo[0]<.8 and hi[2]-lo[2]<.55,'adult metre proportions')
 check(abs(lo[1]-.0115)<.00001,'sole contact datum')
 for im in d['images']:check('bufferView' in im and 'uri' not in im,'self contained image')
 for name,target in [('HumanJacket',coat),('HumanSkin',skins)]:
  material=next(mat for mat in d['materials'] if mat['name']==name)
  tx=material['pbrMetallicRoughness']['baseColorTexture']['index'];target.append(hashlib.sha256(g.image(d['textures'][tx]['source'])).hexdigest())
  if name=='HumanJacket':check('normalTexture' in material,'woven cloth normal map')
 reports.append({'id':model['id'],'triangles':tris,'surfaces':surfaces,'bounds_m':[lo.tolist(),hi.tolist()]})
check(len(set(coat[:3]))==3,'distinct civilian cloth maps')
check(skins[0]==skins[1]==skins[2] and skins[3]!=skins[0],'infected skin differs without changing anatomy')
(D/'validation.json').write_text(json.dumps({'checks':checks,'failures':0,'models':reports},indent=2)+'\n')
print('MODULAR_HUMAN_ASSET_TEST',checks,'checks; 0 failures')
