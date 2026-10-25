"""Inspect actual original GLB bytes before admitting the new visual bank."""
from pathlib import Path
import json,hashlib,shutil
import numpy as np
from blender.validate_field_survival_kit import read_glb,transform
R=Path(__file__).resolve().parents[1];SRC=R/'tools/blender/generated/forest_quality';DST=R/'brave-and-cold/assets/environment_detail/forest_quality'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((SRC/'manifest.json').read_text());assert sha(SRC/'winter_crowns.blend')==manifest['native_sha256']
assert sha(R/'tools/blender/gen_forest_quality.py')==manifest['generator_sha256']
assert len(manifest['models'])==12
report={}
for e in manifest['models']:
 p=SRC/(e['name']+'.glb');assert sha(p)==e['sha256'];raw,g,v=read_glb(p)
 assert len(g['meshes'])==1 and len(g['meshes'][0]['primitives'])==1
 assert all(np.max(abs(transform(n)-np.eye(4)))<1e-6 for n in g['nodes'])
 prim=g['meshes'][0]['primitives'][0];attrs=prim['attributes']
 pts=v(attrs['POSITION']);norm=v(attrs['NORMAL']);col=v(attrs['COLOR_0']);uv=v(attrs['TEXCOORD_0'])
 ca=g['accessors'][attrs['COLOR_0']]
 if ca.get('normalized'):col=col.astype(float)/{5121:255,5123:65535}[ca['componentType']]
 assert all(np.isfinite(x).all() for x in [pts,norm,col,uv])
 assert np.max(abs(np.linalg.norm(norm,axis=1)-1))<.006
 assert pts[:,1].min()>=-.001 and .99<=pts[:,1].max()<=1.03
 assert np.max(np.min(abs(col[:,3,None]-np.array([.10,.50,.52,1])),axis=1))<.002
 idx=v(prim['indices']).astype(int).ravel();tri=pts[idx].reshape(-1,3,3)
 area=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)
 assert area.min()>1e-12 and len(tri)==e['triangles']
 assert len(tri)<=(1100 if e['name'].endswith('_far') else 4200)
 report[e['name']]={'triangles':len(tri),'bounds':[pts.min(axis=0).tolist(),pts.max(axis=0).tolist()],'sha256':sha(p),'bytes':len(raw)}
for e in manifest['models']:
 if e['name'].endswith('_far'):continue
 a=np.array(report[e['name']]['bounds']);b=np.array(report[e['name']+'_far']['bounds'])
 assert np.max(abs(a-b))<.04,(e['name'],a,b)
DST.mkdir(parents=True,exist_ok=True)
assert sha(SRC/'needle_spray.png')==manifest['texture_sha256']
provenance=json.loads((SRC/'texture_provenance.json').read_text())
assert sha(SRC/'needle_spray_snow.png')==provenance['snow_sha256']
assert sha(SRC/'crown_sprays.png')==provenance['atlas_sha256']
for name,digest in provenance['bark']['files'].items():assert sha(SRC/name)==digest
for name in ['manifest.json','needle_spray.png','needle_spray_snow.png','crown_sprays.png','texture_provenance.json','winter_bark.png','winter_bark_normal.png']+[e['name']+'.glb' for e in manifest['models']]:
 shutil.copy2(SRC/name,DST/name);assert sha(SRC/name)==sha(DST/name)
(DST/'validation.json').write_text(json.dumps({'actual_glb_bytes':'passed','native_digest':manifest['native_sha256'],'assets':report},indent=2)+'\n')
print('FOREST_QUALITY_ASSETS_PASS',len(report))
