"""Independent actual-byte checks for the original civilian exports."""
from pathlib import Path
import json, struct, hashlib, numpy as np
R=Path(__file__).resolve().parents[1];D=R/'brave-and-cold/assets/town_residents';S=R/'tools/blender/generated/town_residents'
m=json.loads((D/'manifest.json').read_text());checks=0
def check(ok,label):
 global checks
 assert ok,label;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p,key in [(R/'tools/blender/generated/worker_detail/winter_worker_detail.blend','source_sha256'),(S/'north_ridge_residents.blend','native_sha256'),(S/'issue_ledger.blend','ledger_native_sha256'),(R/'tools/blender/gen_town_residents.py','generator_sha256'),(D/'issue_ledger.glb','ledger_sha256')]:check(sha(p)==m[key],'source/hash '+p.name)
reports=[];coat_images=[]
for model in m['models']:
 p=D/(model['id']+'.glb');check(sha(p)==model['sha256'],'export hash '+model['id'])
 raw=p.read_bytes();magic,version,length=struct.unpack_from('<III',raw);check(magic==0x46546c67 and version==2 and length==len(raw),'GLB envelope')
 jl,jt=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+jl]);bl,bt=struct.unpack_from('<II',raw,20+jl);binary=raw[28+jl:28+jl+bl];check(jt==0x4e4f534a and bt==0x004e4942,'GLB chunks')
 def acc(i):
  a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
  return np.ndarray((a['count'],n),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(dtype).itemsize*n),np.dtype(dtype).itemsize))
 tris=0;surfaces=0;positions=[]
 for mesh in doc['meshes']:
  for pr in mesh['primitives']:
   pos=acc(pr['attributes']['POSITION']);idx=acc(pr['indices']).ravel();positions.append(pos);tris+=len(idx)//3;surfaces+=1
   check(np.isfinite(pos).all() and len(idx)%3==0 and idx.max()<len(pos),'finite indexed geometry '+mesh.get('name',''))
   tri=pos[idx.reshape(-1,3)];check((np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)>1e-10).all(),'nondegenerate geometry')
   w=acc(pr['attributes']['WEIGHTS_0']);j=acc(pr['attributes']['JOINTS_0']);check(np.max(abs(w.sum(axis=1)-1))<.001 and j.max()<13,'normalized thirteen-bone skin')
 check(tris==model['triangles'] and tris<=22000 and surfaces==model['surfaces'] and surfaces<=10,'measured mesh budget')
 bounds=np.ptp(np.concatenate(positions),axis=0);check(1.70<bounds[1]<1.85 and bounds[0]<.8 and bounds[2]<.6,'metre dimensions')
 check(len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==13,'rig contract')
 for image in doc['images']:check('bufferView' in image and 'uri' not in image,'embedded image')
 cloth=next(x for x in doc['materials'] if 'winter_canvas' in x['name']);check('normalTexture' in cloth and 'baseColorTexture' in cloth['pbrMetallicRoughness'],'cloth PBR retained')
 tx=cloth['pbrMetallicRoughness']['baseColorTexture']['index'];iv=doc['bufferViews'][doc['images'][doc['textures'][tx]['source']]['bufferView']]
 coat_images.append(hashlib.sha256(binary[iv.get('byteOffset',0):iv.get('byteOffset',0)+iv['byteLength']]).hexdigest())
 reports.append({'id':model['id'],'triangles':tris,'surfaces':surfaces,'bounds_m':bounds.tolist()})
check(len(set(coat_images))==3,'three actually distinct baked civilian albedos')
(D/'validation.json').write_text(json.dumps({'checks':checks,'failures':0,'models':reports},indent=2)+'\n')
print('TOWN_ASSET_TEST',checks,'checks; 0 failures')
