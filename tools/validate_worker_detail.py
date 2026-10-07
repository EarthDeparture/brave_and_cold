"""Validate produced GLB bytes, packed textures and source hashes independently."""
from pathlib import Path
import json, struct, hashlib
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[1];RT=R/'brave-and-cold/assets/infected/detail';OUT=R/'tools/blender/generated/worker_detail'
manifest=json.loads((RT/'manifest.json').read_text());checks=0
def check(ok,label):
 global checks
 assert ok,label;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p,key in [(RT/'winter_worker_detail.glb','glb_sha256'),(RT/'winter_worker_proxy.glb','proxy_sha256'),(OUT/'winter_worker_detail.blend','native_sha256'),(R/'tools/blender/gen_worker_detail.py','generator_sha256')]:check(sha(p)==manifest[key],'hash '+p.name)
for name,hash_value in manifest['textures'].items():
 p=OUT/name;check(sha(p)==hash_value,'texture hash '+name)
 a=np.array(Image.open(p).convert('RGB'));check(a.shape==(512,512,3) and np.std(a.astype(float),axis=(0,1)).max()>1,'nonblank original map '+name)
def inspect(p,near):
 raw=p.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
 check(magic==0x46546c67 and version==2 and length==len(raw),'GLB envelope '+p.name)
 jl,jt=struct.unpack_from('<II',raw,12);check(jt==0x4e4f534a,'JSON chunk')
 doc=json.loads(raw[20:20+jl]);bl,bt=struct.unpack_from('<II',raw,20+jl);binary=raw[28+jl:28+jl+bl];check(bt==0x004e4942,'BIN chunk')
 def acc(i):
  a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
  dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
  offset=v.get('byteOffset',0)+a.get('byteOffset',0);step=v.get('byteStride',np.dtype(dtype).itemsize*components)
  return np.ndarray((a['count'],components),dtype=dtype,buffer=binary,offset=offset,strides=(step,np.dtype(dtype).itemsize))
 tris=0;surfaces=0;allpos=[];degenerate=0
 for mesh in doc['meshes']:
  for pr in mesh['primitives']:
   pos=acc(pr['attributes']['POSITION']);ids=acc(pr['indices']).ravel();tris+=len(ids)//3;surfaces+=1;allpos.append(pos)
   check(np.isfinite(pos).all() and ids.max()<len(pos),'finite indexed vertices '+mesh.get('name',''))
   tri=pos[ids.reshape(-1,3)];degenerate+=int((np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)<1e-10).sum())
   if near:
    volume=np.einsum('ij,ij->i',tri[:,0],np.cross(tri[:,1],tri[:,2])).sum()/6
    check(volume>1e-12,'outward closed-surface winding '+mesh.get('name',''))
    weights=acc(pr['attributes']['WEIGHTS_0']);joints=acc(pr['attributes']['JOINTS_0'])
    if weights.dtype.kind!='f':weights=weights.astype(float)/np.iinfo(weights.dtype).max
    check(np.isfinite(weights).all() and np.max(abs(weights.sum(axis=1)-1))<.001 and joints.max()<13,'normalized four-influence skin '+mesh.get('name',''))
   else:
    check('COLOR_0' in pr['attributes'],'proxy vertex palette')
    col=acc(pr['attributes']['COLOR_0'])
    if col.dtype.kind!='f':col=col.astype(float)/np.iinfo(col.dtype).max
    def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
    expected=np.array([linear(c) for c in (.36,.40,.32)])
    check((np.linalg.norm(col[:,:3]-expected,axis=1)<.015).sum()>100,'distant canvas matches linear textured albedo')
    expected=np.array([linear(c) for c in (.38,.35,.30)])
    check((np.linalg.norm(col[:,:3]-expected,axis=1)<.015).sum()>20,'distant skin matches linear textured albedo')
 bbox=np.ptp(np.concatenate(allpos),axis=0)
 check(1.70<bbox[1]<1.85 and .4<bbox[0]<.8 and bbox[2]<.6,'metre dimensions')
 check(tris<= (22000 if near else 2500) and surfaces<= (8 if near else 1),'mesh budgets')
 check(degenerate==0,'no zero-area triangles')
 if near:
  check(len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==13,'13-bone skin contract')
  for img in doc.get('images',[]):check('bufferView' in img and 'uri' not in img,'embedded texture')
  cloth=next(m for m in doc['materials'] if 'winter_canvas' in m['name'])
  check('normalTexture' in cloth and 'metallicRoughnessTexture' in cloth['pbrMetallicRoughness'] and 'baseColorTexture' in cloth['pbrMetallicRoughness'],'cloth PBR maps')
 return {'triangles':tris,'surfaces':surfaces,'bounds_m':bbox.tolist(),'zero_area_triangles':degenerate,'sha256':sha(p)}
result={'near':inspect(RT/'winter_worker_detail.glb',True),'proxy':inspect(RT/'winter_worker_proxy.glb',False)}
result['checks']=checks;result['failures']=0
(RT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('WORKER_ASSET_TEST',json.dumps(result))
