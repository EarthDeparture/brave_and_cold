"""Validate local evidence and assemble movement/art review artifacts."""
import hashlib,json,re
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];PROJECT=ROOT/'brave-and-cold';E=PROJECT/'shots/walk-surfaces';R=E/'review';R.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def summary(path):
    records=json.loads(path.read_text());assert len(records)==1005
    result={}
    for name,predicate in [('terrain',lambda r:r['index']==-1),('road',lambda r:r['index']>=0 and r['side']==0),('shoulder',lambda r:r['index']>=0 and r['side']!=0)]:
        rows=[r for r in records if predicate(r)];jerk=[r['jerk'] for r in rows]
        result[name]={'cases':len(rows),'blocked_frames':sum(r['blocks'] for r in rows),'deflections':sum(r['deflections'] for r in rows),'camera_step_change_p95_m':float(np.percentile(jerk,95)),'camera_step_change_max_m':max(jerk),'support_error_max_m':max(r['support_error'] for r in rows if 'support_error' in r) if any('support_error' in r for r in rows) else None}
    return result
manifest=json.loads((E/'final/manifest.json').read_text());assert manifest['resolution']==[1600,900]
asset=PROJECT/'assets/models/viewmodel/survivor_hand_rig.glb';hand=json.loads(asset.with_suffix('.json').read_text());assert hand['version']==6 and sha(asset)==manifest['hand_sha256']==hand['sha256']
assert hand['generator_sha256']==sha(ROOT/'tools/blender/gen_hand_rig.py')
assert hand['material_source_sha256']==sha(ROOT/'tools/blender/hand_materials.py')
assert len(manifest['captures'])==15 and len(manifest['film'])==84 and manifest['walk_metres']>31
captures={}
for item in manifest['captures']:
    p=PROJECT/item['file'].removeprefix('res://');assert sha(p)==item['sha256'];assert Image.open(p).size==(1600,900);captures[item['id']]=item['sha256']
frames=[];film=[]
for item in manifest['film']:
    p=PROJECT/item['file'].removeprefix('res://');assert Image.open(p).size==(1600,900)
    frames.append(Image.open(p).convert('RGB').resize((960,540),Image.Resampling.LANCZOS));film.append({'frame':item['frame'],'sha256':sha(p),'eye':item['eye']})
frames[0].save(R/'walking.gif',save_all=True,append_images=frames[1:],duration=167,loop=0,optimize=False)
ids=['fists-bare','fists-gloves','axe-rest-bare','axe-rest-gloves','rifle-bolt-bare','rifle-bolt-gloves']
sheet=Image.new('RGB',(1440,864),'#171d23');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(ids):
    im=Image.open(E/'final'/f'{name}.png');im=im.crop((0,450,1600,900)).resize((720,240),Image.Resampling.LANCZOS)
    x=(i%2)*720;y=(i//2)*288;sheet.paste(im,(x,y+28));draw.text((x+12,y+8),name,fill='white')
sheet.save(R/'hand-grips.png')
tests={}
for name in ['walk_surfaces','jump','shore_walking','road_detail','viewmodel','fire_lookout','environment_detail','atmosphere','frozen_water','audio','survival']:
    p=E/'logs'/f'test_{name}.log';s=p.read_text(errors='replace')
    assert not re.search(r'(^FAIL\b|SCRIPT ERROR|Parse Error|failures=[1-9])',s,re.M),(name,s[-1200:])
    if name=='shore_walking':
        rows=re.findall(r'SHORE_WALK fps=(\d+) crossings=28 blocked_frames=(\d+) minimum_metres=([\d.]+) max_vertical_bump_m=([\d.]+)',s)
        assert len(rows)==3 and all(int(b)==0 and float(d)>24 and float(j)<.02 for _,b,d,j in rows)
        assert 'STAIR_CONTROLLER ascent=true' in s and 'STAIR_CONTROLLER descent=true' in s
    elif name=='frozen_water':
        assert all(k+'=true' in s for k in ['finite','clockwise','authored_heights','thickness','footprint'])
    else:assert re.search(r'(failures=0|failed=0|PASS)',s),(name,'missing test results')
    tests[name]={'sha256':sha(p),'results':[line for line in s.splitlines() if 'COMPLETE' in line or 'failures=' in line or 'HAND_RIG_TEST' in line or 'SHORE_WALK' in line or 'STAIR_CONTROLLER' in line or 'ICE_MESH_TEST' in line]}
panel=PROJECT/'assets/route_detail/field_power_panel.glb';provenance=json.loads(panel.with_name('provenance.json').read_text());assert sha(panel)==provenance['sha256']
source_paths=['entities/player/player.gd','entities/player/survivor_hand_rig.gd','entities/player/viewmodel.gd','world/walk_surface.gd','world/walk_ribbon.gd','world/road_net.gd','world/trail_net.gd','world/fire_lookout.gd','world/game_world.gd','world/storage_chest.gd','world/store.gd','systems/population.gd','entities/animals/deer.gd','entities/animals/wolf.gd','entities/zombies/zombie.gd','tests/survey_walking.gd','tests/test_walk_surfaces.gd','tests/visual/capture_surface_review.gd']
receipt={'baseline_commit':'39d91cb','checkpoint':'checkpoint/pre-walk-surface-2026-10-04','branch':'codex/walk-surface-polish','engine':'Godot 4.7.2','gpu':manifest['gpu'],'resolution':manifest['resolution'],'seed':manifest['seed'],'baseline_survey':summary(E/'baseline.json'),'candidate_survey':summary(E/'candidate.json'),'tests':tests,'surface_render':{k:manifest[k] for k in ['walk_metres','camera_step_change_max_m','controller_median_ms','controller_p99_ms']},'captures':captures,'film':film,'assets':{'hand':hand,'power_panel':provenance},'source_sha256':{p:sha(PROJECT/p) for p in source_paths},'evidence_sha256':{p:sha(E/p) for p in ['baseline.json','candidate.json','final/manifest.json','review/walking.gif','review/hand-grips.png']},'limitations':['Survey samples walkable grades; cliffs and solid objects remain blockers.','Controller timing excludes renderer, AI and screenshot readback; no horde or GPU benchmark claim.','The road remains a steep remote service route; grading preserves existing geography.','The technician panel is an original visual asset, without a new maintenance mechanic.','Existing Terrain3D deprecation and shutdown resource warnings persist.']}
(ROOT/'docs/validation/WALK_SURFACE_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n')
print(json.dumps({k:receipt[k] for k in ['baseline_survey','candidate_survey','surface_render']},indent=2))
