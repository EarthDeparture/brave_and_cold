"""Validate the actual GLB and its original-source receipt; no editor needed."""
import json,struct,math,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[2];A=R/'brave-and-cold/assets/field_walkie'
m=json.loads((A/'manifest.json').read_text(encoding='utf8'));raw=(A/'field_walkie.glb').read_bytes()
assert len(raw)==m['bytes'] and len(raw)<600000
assert hashlib.sha256(raw).hexdigest()==m['sha256']
assert hashlib.sha256((R/m['source']).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()==m['generator_sha256']
magic,version,size=struct.unpack_from('<III',raw);assert magic==0x46546c67 and version==2 and size==len(raw)
jl=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+jl]);binary=raw[28+jl:]
formats={5126:'f',5125:'I',5123:'H',5121:'B'};components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def values(index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']];fmt='<'+formats[a['componentType']]*components[a['type']]
 off=v.get('byteOffset',0)+a.get('byteOffset',0);step=v.get('byteStride',struct.calcsize(fmt))
 assert off+(a['count']-1)*step+struct.calcsize(fmt)<=len(binary)
 return [struct.unpack_from(fmt,binary,off+i*step) for i in range(a['count'])]
count=0;degenerate=0
for mesh in g['meshes']:
 for part in mesh['primitives']:
  assert part.get('mode',4)==4
  a=part['attributes'];pos=values(a['POSITION']);norm=values(a['NORMAL']);idx=[v[0] for v in values(part['indices'])]
  assert all(math.isfinite(c) for p in pos for c in p)
  assert len(norm)==len(pos) and all(.99<sum(c*c for c in n)<1.01 for n in norm)
  assert len(idx)%3==0 and min(idx)>=0 and max(idx)<len(pos)
  count+=len(idx)//3
  for i in range(0,len(idx),3):
   p,q,r=[pos[idx[i+j]] for j in range(3)];u=[q[k]-p[k] for k in range(3)];v=[r[k]-p[k] for k in range(3)]
   cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
   degenerate+=sum(c*c for c in cross)<1e-22
assert count==m['triangles'] and count<6500 and degenerate==0,(count,degenerate)
nodes={n['name']:i for i,n in enumerate(g['nodes'])};assert set(nodes)==set(m['semantic_nodes'])
assert nodes['Display'] in g['nodes'][nodes['Handset']]['children'],'LCD must disappear with handset'
assert len(g['meshes'])==3 and len(g['materials'])<=8
assert not g.get('animations') and not g.get('skins') and not g.get('images'),'Self-contained static original prop'
for material in g['materials']:
 pbr=material['pbrMetallicRoughness'];assert 0<=pbr.get('roughnessFactor',1)<=1 and 0<=pbr.get('metallicFactor',1)<=1
result={'ok':True,'triangles':count,'degenerate_triangles':degenerate,'bytes':len(raw),'semantic_nodes':list(nodes),'materials':len(g['materials']),'sha256':m['sha256'],'source_sha256':m['generator_sha256']}
print(json.dumps(result,indent=2))
