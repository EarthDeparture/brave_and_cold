"""Actual-byte validation of eyelid morphs and the unchanged human contract."""
from pathlib import Path
import hashlib,json,numpy as np
from glb_geometry import GLB
R=Path(__file__).resolve().parents[1];D=R/'brave-and-cold/assets/resident_presence';S=R/'tools/blender/generated/resident_presence';m=json.loads((D/'manifest.json').read_text());old=json.loads((R/'brave-and-cold/assets/modular_human/manifest.json').read_text());checks=0;models=[]
def check(ok,label):
 global checks
 assert ok,label;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p,key in [(R/'tools/blender/generated/modular_human/human_foundation.blend','source_native_sha256'),(R/'tools/blender/gen_modular_human.py','source_generator_sha256'),(S/'resident_presence.blend','native_sha256'),(R/'tools/blender/gen_resident_presence.py','generator_sha256')]:check(sha(p)==m[key],'hash '+p.name)
for record in m['exports']:
 path=D/(record['id']+'.glb');check(sha(path)==record['sha256'],'export hash');g=GLB(path);doc=g.doc
 joints=doc['skins'][0]['joints'];names={doc['nodes'][i]['name'] for i in joints};check(len(joints)==45 and names==set(old['bones']),'original 45-bone contract')
 tris=0;surfaces=0;changed=0;maximum=0;points=[];blink_meshes=0
 for mesh in doc['meshes']:
  for pr in mesh['primitives']:
   pos=g.acc(pr['attributes']['POSITION']);idx=g.acc(pr['indices']).ravel();points.append(pos);tris+=len(idx)//3;surfaces+=1
   check(np.isfinite(pos).all() and len(idx)%3==0 and idx.max()<len(pos),'finite indexed mesh')
   normals=g.acc(pr['attributes']['NORMAL']);check(np.isfinite(normals).all() and np.max(abs(np.linalg.norm(normals,axis=1)-1))<.001,'unit base normals')
   w=g.acc(pr['attributes']['WEIGHTS_0']);j=g.acc(pr['attributes']['JOINTS_0']);check(np.max(abs(w.sum(axis=1)-1))<.001 and j.max()<45,'normalized weights')
   if 'targets' in pr:
    check(mesh['extras']['targetNames']==['Blink'] and len(pr['targets'])==1,'single named Blink target');blink_meshes+=1
    delta=g.acc(pr['targets'][0]['POSITION']);mask=np.linalg.norm(delta,axis=1)>.00001;changed+=int(mask.sum());maximum=max(maximum,float(np.linalg.norm(delta,axis=1).max()))
    check(np.isfinite(delta).all() and ((pos[mask,1]>1.685)&(pos[mask,1]<1.703)&(abs(pos[mask,0])>.01)&(abs(pos[mask,0])<.055)).all(),'only eyelid regions move')
    check(((pos[mask]+delta[mask])[:,1]>1.686).all() and ((pos[mask]+delta[mask])[:,1]<1.702).all(),'closed lids remain local to eyes')
 check(blink_meshes==1 and changed>=380 and maximum<.015,'bounded imported eyelid closure')
 base=next(r for r in old['exports'] if r['id']==record['id']);check(tris==record['triangles']==base['triangles'] and surfaces==record['surfaces']==base['surfaces'] and tris<=40000,'unchanged geometry/draw budget')
 allp=np.concatenate(points);check(abs(allp[:,1].min()-.0115)<.00001 and 1.70<np.ptp(allp,axis=0)[1]<1.85,'metre scale and sole contact retained')
 for image in doc['images']:check('bufferView' in image and 'uri' not in image,'embedded textures')
 models.append({'id':record['id'],'triangles':tris,'surfaces':surfaces,'changed_export_vertices':changed,'maximum_blink_delta_m':maximum})
(D/'validation.json').write_text(json.dumps({'checks':checks,'failures':0,'models':models},indent=2)+'\n')
print('RESIDENT_PRESENCE_ASSET_TEST',checks,'checks; 0 failures')
