"""Read exact GLB bytes and retained native-source hashes, no provider claims."""
from pathlib import Path
import json,hashlib
import numpy as np
from blender.validate_field_survival_kit import read_glb,transform
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
skin=R/'brave-and-cold/assets/infected/skin';m=json.loads((skin/'manifest.json').read_text())
assert sha(skin/'winter_worker_skin.glb')==m['glb_sha256']
assert sha(R/'tools/blender/generated/infected_skin/winter_worker_skin.blend')==m['native_sha256']
assert sha(R/'tools/blender/gen_infected_skin.py')==m['generator_sha256']
raw,g,v=read_glb(skin/'winter_worker_skin.glb');assert len(g['skins'])==1
assert len(g['skins'][0]['joints'])==11 and {g['nodes'][i]['name'] for i in g['skins'][0]['joints']}==set(m['bones'])
assert set(m['clips']).issubset({a['name'] for a in g['animations']})
tri=0;vertices=0
for mesh in g['meshes']:
 for p in mesh['primitives']:
  a=p['attributes'];positions=v(a['POSITION']);weights=v(a['WEIGHTS_0']);joints=v(a['JOINTS_0'])
  assert np.isfinite(positions).all() and np.isfinite(weights).all() and np.min(weights)>=0
  assert np.max(np.abs(weights.sum(axis=1)-1))<.0001 and np.max(joints)<11
  tri+=g['accessors'][p['indices']]['count']//3;vertices+=len(positions)
assert tri<20000
(skin/'validation.json').write_text(json.dumps({'actual_bytes':'passed','triangles':tri,'vertices':vertices,'bones':11,'preview_clips':len(g['animations']),'native_sha256':m['native_sha256'],'runtime_deformation_check':'res://tests/test_infected_skin.gd'},indent=2)+'\n')
props=R/'brave-and-cold/assets/opening_props';m=json.loads((props/'manifest.json').read_text());entry=m['field_flask']
assert sha(props/'field_flask.glb')==entry['sha256'] and sha(R/entry['source'])==entry['source_sha256']
assert sha(R/'tools/blender/gen_opening_flask.py')==m['provenance']['generator_sha256']
assert sha(R/'tools/blender/generated/opening_props/flask_enamel.png')==m['provenance']['enamel_sha256']
raw,g,v=read_glb(props/'field_flask.glb');assert any(n.get('name')=='FlaskCap' for n in g['nodes'])
parents={c:i for i,n in enumerate(g['nodes']) for c in n.get('children',[])}
def xf(i):return (xf(parents[i]) if i in parents else np.eye(4))@transform(g['nodes'][i])
points=[];tri=0
for i,node in enumerate(g['nodes']):
 if 'mesh' not in node:continue
 for p in g['meshes'][node['mesh']]['primitives']:
  pts=v(p['attributes']['POSITION']);assert np.isfinite(pts).all()
  points.append((xf(i)@np.c_[pts,np.ones(len(pts))].T).T[:,:3]);tri+=g['accessors'][p['indices']]['count']//3
points=np.concatenate(points);size=np.ptp(points,axis=0)
assert np.max(np.abs(size-np.array([.0846,.264,.0843])))<.002 and tri<5000,(size,tri)
# No collision/physics extensions; actual hollow mouth remains inspectable in Blender.
assert 'KHR_physics_rigid_bodies' not in g.get('extensionsUsed',[])
(props/'validation.json').write_text(json.dumps({'actual_bytes':'passed','triangles':tri,'bounds_m':[points.min(axis=0).tolist(),points.max(axis=0).tolist()],'native_sha256':entry['source_sha256']},indent=2)+'\n')
audio=R/'brave-and-cold/assets/environment_detail/audio/surface_foley';m=json.loads((audio/'provenance.json').read_text())
for e in m['files']:assert sha(audio/e['file'])==e['sha256'] and .01<e['rms']<.5 and e['peak']<1
print('OPENING_ASSETS_PASS skin_vertices=',vertices,'flask_triangles=',tri,'foley=',len(m['files']))
