"""Independently inspect original cooking GLB, metric bounds and native provenance."""
from pathlib import Path
import json,struct,hashlib
import numpy as np
from validate_food_assets import geometry_bounds
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def validate():
 folder=R/'brave-and-cold/assets/cooking';m=json.loads((folder/'manifest.json').read_text());e=m['skillet_portion']
 p=folder/'skillet_portion.glb';data=p.read_bytes();magic,version,size=struct.unpack_from('<4sII',data)
 assert magic==b'glTF' and version==2 and size==len(data)
 n,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
 doc=json.loads(data[20:20+n].decode().rstrip());lo,hi=geometry_bounds(doc,data,n)
 assert np.allclose(lo,e['bounds_min_xyz'],atol=1e-5) and np.allclose(hi,e['bounds_max_xyz'],atol=1e-5)
 assert np.allclose(hi-lo,e['dimensions_m'],atol=1e-5)
 tris=sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
 assert tris==e['triangles'] and tris<3000 and len(doc['materials'])==3
 assert {'PanFood','SearMarks'} <= {node.get('name') for node in doc['nodes']}
 assert len(doc['textures'])==1 and all('bufferView' in im for im in doc['images'])
 assert sha(p)==e['sha256'] and sha(R/e['source'])==e['source_sha256']
 for file,digest in m['generators'].items():assert hashlib.sha256((R/'tools/blender'/file).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()==digest
 for file,digest in m['graphics'].items():
  assert sha(R/'tools/blender/generated/cooking'/file)==digest
  assert sha(folder/(('skillet_portion_'+file) if file=='meat_marbling.png' else file))==digest
 return {'triangles':tris,'materials':len(doc['materials']),'textures':len(doc['textures']),'dimensions_m':e['dimensions_m'],'source_export_graphics_verified':True}
if __name__=='__main__':print(json.dumps(validate(),indent=2))
