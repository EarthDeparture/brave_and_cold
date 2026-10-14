"""Check actual stock components against furniture tops after GLB transforms."""
from pathlib import Path
import json,hashlib,numpy as np
from glb_geometry import GLB
R=Path(__file__).resolve().parents[1];D=R/'brave-and-cold/assets/store_supported';m=json.loads((D/'manifest.json').read_text());checks=0
def check(ok,label):
 global checks
 assert ok,label;checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p,key in [(R/'tools/blender/generated/route_identity/store_dressing.blend','source_sha256'),(R/'tools/blender/generated/store_supported/store_dressing_supported.blend','native_sha256'),(D/'store_dressing.glb','glb_sha256'),(R/'tools/blender/fix_store_support.py','generator_sha256')]:check(sha(p)==m[key],'hash '+p.name)
g=GLB(D/'store_dressing.glb');trans=g.transforms();reports=[];tins=0;medical=0;boxes=0;wool=0
for i,node in enumerate(g.doc['nodes']):
 if node.get('name') not in ['ShelfStock','CounterStock','CrateStock']:continue
 ps=[];edges=[];at=0
 for pr in g.doc['meshes'][node['mesh']]['primitives']:
  p=g.acc(pr['attributes']['POSITION']);p=(np.c_[p,np.ones(len(p))]@trans[i].T)[:,:3];ps.extend(p.tolist())
  for t in g.acc(pr['indices']).reshape(-1,3):
   for k in range(3):edges.append((at+int(t[k]),at+int(t[(k+1)%3])))
  at+=len(p)
 parent=list(range(len(ps)))
 def find(x):
  while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
  return x
 def union(a,b):parent[find(a)]=find(b)
 for a,b in edges:union(a,b)
 seen={}
 for j,p in enumerate(ps):
  key=tuple(round(v,5) for v in p)
  if key in seen:union(j,seen[key])
  else:seen[key]=j
 parts={}
 for j,p in enumerate(ps):parts.setdefault(find(j),[]).append(p)
 for points in parts.values():
  p=np.array(points);lo=p.min(axis=0);hi=p.max(axis=0);delta=hi-lo;kind=''
  if node['name']=='ShelfStock' and .17<delta[1]<.195 and .12<delta[0]<.15:
   kind='food_tin';top=min([.825,1.425,2.025],key=lambda h:abs(h-lo[1]));check(abs(lo[1]-top-.002)<.0001,'tin supports');tins+=1
  elif node['name']=='ShelfStock' and .195<delta[0]<.205 and .195<delta[1]<.205:
   kind='medical';check(abs(lo[1]-.827)<.0001,'medical supports');medical+=1
  elif node['name']=='CrateStock' and delta[0]>.50:
   kind='hardware';check(abs(lo[1]-1.102)<.0001,'hardware crate supports');boxes+=1
  elif node['name']=='CrateStock' and .42<delta[0]<.45:
   kind='wool';check(min(abs(lo[1]-1.315),abs(lo[1]-1.385))<.0001,'folded wool supports');wool+=1
  if kind:reports.append({'group':node['name'],'kind':kind,'min_m':lo.tolist(),'max_m':hi.tolist()})
check(tins==18 and medical==3 and boxes==1 and wool==2,'all supported bodies are tested, not just labels')
(D/'validation.json').write_text(json.dumps({'checks':checks,'failures':0,'components':reports},indent=2)+'\n')
print('STORE_SUPPORT_ASSET_TEST',checks,'checks; 0 failures')
