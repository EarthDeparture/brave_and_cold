"""Inspect actual source/GLB bytes and extracted textures, independently of Blender export."""
from pathlib import Path
import json,hashlib,struct
import numpy as np
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def geometry_bounds(doc,data,json_size):
 offset=20+json_size;bin_size,kind=struct.unpack_from('<II',data,offset);assert kind==0x004e4942
 blob=data[offset+8:offset+8+bin_size];positions=[]
 def matrix(node):
  if 'matrix' in node:return np.array(node['matrix']).reshape((4,4),order='F')
  x,y,z,w=node.get('rotation',[0,0,0,1]);m=np.eye(4)
  m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
  m[:3,:3]=m[:3,:3]@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
 def visit(idx,parent):
  node=doc['nodes'][idx];world=parent@matrix(node)
  if 'mesh' in node:
   for primitive in doc['meshes'][node['mesh']]['primitives']:
    a=doc['accessors'][primitive['attributes']['POSITION']];assert a['componentType']==5126 and a['type']=='VEC3'
    v=doc['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)+a.get('byteOffset',0)
    points=np.ndarray((a['count'],3),dtype='<f4',buffer=blob,offset=start,strides=(v.get('byteStride',12),4))
    assert np.isfinite(points).all()
    positions.append((world@np.column_stack((points,np.ones(len(points)))).T).T[:,:3])
  for child in node.get('children',[]):visit(child,world)
 for root in doc['scenes'][doc.get('scene',0)]['nodes']:visit(root,np.eye(4))
 points=np.concatenate(positions);return points.min(axis=0),points.max(axis=0)
def validate():
 folder=R/'brave-and-cold/assets/food_preservation';manifest=json.loads((folder/'manifest.json').read_text());results={}
 for name in ['stove_drying_rack','dried_portion']:
  e=manifest[name];p=folder/(name+'.glb');data=p.read_bytes();magic,version,length=struct.unpack_from('<4sII',data)
  assert magic==b'glTF' and version==2 and length==len(data)
  count,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
  doc=json.loads(data[20:20+count].decode().rstrip())
  assert sha(p)==e['sha256'] and sha(R/e['source'])==e['source_sha256']
  tris=sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
  lo,hi=geometry_bounds(doc,data,count)
  assert np.allclose(lo,e['bounds_min_xyz'],atol=1e-5) and np.allclose(hi,e['bounds_max_xyz'],atol=1e-5)
  assert tris==e['triangles'] and tris<12000 and len(doc.get('materials',[]))<=6
  assert len(doc.get('textures',[]))<=2 and all('bufferView' in im for im in doc.get('images',[]))
  if name=='stove_drying_rack':
   assert {'RackDoor','Portion0','Portion1','Portion2','Portion3'} <= {n.get('name') for n in doc['nodes']}
   assert .55<e['dimensions_m'][0]<.57 and .83<e['dimensions_m'][1]<.87 and .33<e['dimensions_m'][2]<.35
  for im in doc.get('images',[]):
   graphic=im.get('name','')+'.png'
   if graphic in manifest['graphics']:assert sha(folder/(name+'_'+graphic))==manifest['graphics'][graphic]
  results[name]={'triangles':tris,'materials':len(doc.get('materials',[])),'dimensions_m':e['dimensions_m'],'source_export_graphics_verified':True}
 for file,digest in manifest['generators'].items():assert hashlib.sha256((R/'tools/blender'/file).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()==digest
 for file,digest in manifest['graphics'].items():assert sha(R/'tools/blender/generated/food_preservation'/file)==digest
 return results
if __name__=='__main__':print(json.dumps(validate(),indent=2))
