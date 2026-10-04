from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,statistics,re
ROOT=Path.cwd();game=ROOT/'brave-and-cold';base=game/'shots/roads-jump';review=base/'review';review.mkdir(exist_ok=True)
a=json.loads((base/'bench-before/manifest.json').read_text());b=json.loads((base/'final/manifest.json').read_text())
if len(a['captures'])!=33 or len(b['captures'])!=33:raise RuntimeError('Incomplete repeated capture')
metrics=[]
for ident in dict.fromkeys(x['id'] for x in a['captures']):
 before=[x for x in a['captures'] if x['id']==ident];after=[x for x in b['captures'] if x['id']==ident]
 for x,y in zip(before,after):
  if any(x[k]!=y[k] for k in ['eye','target','hour','weather']):raise RuntimeError('Unmatched capture '+ident)
  for record in [x,y]:
   file=game/record['file'].removeprefix('res://')
   if hashlib.sha256(file.read_bytes()).hexdigest()!=record['sha256']:raise RuntimeError('Capture hash mismatch')
 av=statistics.median(x['median_ms'] for x in before);bv=statistics.median(x['median_ms'] for x in after)
 metrics.append({'id':ident,'before_ms':av,'after_ms':bv,'delta_ms':bv-av,'change_pct':(bv/av-1)*100})
for name,ids in [('before-after.png',['road-overcast','road-dusk','sign-1','sign-2']),('signs-before-after.png',['sign-0','sign-1','sign-2','sign-3','sign-4'])]:
 canvas=Image.new('RGB',(1600,len(ids)*482),(19,24,30));draw=ImageDraw.Draw(canvas)
 for i,ident in enumerate(ids):
  for col,bank in enumerate(['bench-before','final']):
   im=Image.open(base/bank/(ident+'-r0.png')).convert('RGB').resize((800,450),Image.Resampling.LANCZOS)
   canvas.paste(im,(col*800,i*482));draw.text((col*800+10,i*482+458),('Before' if col==0 else 'After')+' - '+ident,fill='white')
 canvas.save(review/name)
assets={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((game/'assets/road_detail').rglob('*')) if p.suffix in ['.png','.glb']}
for provenance in [(game/'assets/road_detail/textures/provenance.json'),(game/'assets/road_detail/models/provenance.json')]:
 data=json.loads(provenance.read_text())
 if 'files' in data:
  for name,digest in data['files'].items():assert hashlib.sha256((provenance.parent/name).read_bytes()).hexdigest()==digest
 else:
  for model in data['models']:assert hashlib.sha256((provenance.parent/(model['name']+'.glb')).read_bytes()).hexdigest()==model['sha256']
suites=['jump','road_detail','shore_walking','fire_lookout','viewmodel','survival','frozen_water','atmosphere','audio','environment_detail'];tests={}
for suite in suites:
 p=base/('test_'+suite+'.log');text=p.read_text(errors='replace')
 if re.search(r'(^FAIL\b|SCRIPT ERROR|Parse Error|failures=[1-9])',text,re.M):raise RuntimeError('Failed suite '+suite)
 if suite=='frozen_water' and 'ICE_MESH_TEST finite=true' not in text:raise RuntimeError('Incomplete ice suite')
 if suite=='shore_walking' and 'descent=true' not in text:raise RuntimeError('Incomplete walking suite')
 if suite not in ['frozen_water','shore_walking'] and 'failures=0' not in text:raise RuntimeError('Incomplete suite '+suite)
 tests[suite]={'passed':True,'log_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
jump=json.loads((base/'jump-film/manifest.json').read_text())
assert jump['space_event_started_jump'] and jump['save_protected_while_airborne'] and jump['landed']
for name in ['final.log','jump-world.log','final-sign-correction.log']:
 text=(base/name).read_text(errors='replace')
 if 'SCRIPT ERROR' in text or 'SHADER ERROR' in text:raise RuntimeError('Renderer failure '+name)
source_paths=['brave-and-cold/entities/player/player.gd','brave-and-cold/project.godot','brave-and-cold/world/game_world.gd','brave-and-cold/world/road_net.gd','brave-and-cold/world/shaders/winter_road.gdshader','brave-and-cold/world/cabin.gd','brave-and-cold/world/hut.gd','brave-and-cold/world/store.gd','brave-and-cold/world/fire_lookout.gd','tools/roads/generate_road_fields.py','tools/blender/gen_road_signs.py','brave-and-cold/tests/test_jump.gd','brave-and-cold/tests/test_road_detail.gd','brave-and-cold/tests/visual/capture_roads.gd','brave-and-cold/tests/visual/capture_jump.gd']
receipt={'schema':1,'baseline_commit':'9886e7df4c427e2f93b72e31e0f0c8ba83ab610f','checkpoint':'checkpoint/pre-roads-jump-2026-10-03','resolution':[1600,900],'gpu':b['gpu'],'benchmark':'Three static full-world render repetitions, 120 measured frames after 30 warmup frames per view; no active creatures. Screenshot readback excluded from timing. Wall-clock frame durations, not GPU timestamp queries.','metrics':metrics,'asset_hashes':assets,'source_hashes':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in source_paths},'tests':tests,'jump_world':{k:v for k,v in jump.items() if k!='captures'},'capture_manifests':{'before':a,'after':b},'road_contract':{'points':1024,'length_m':2558.138,'road_triangles':16368,'signs':18,'poles':57,'bridge_spans':[[293,302]],'raw_terrain_grade_max_pct':87.010,'raw_terrain_grade_p95_pct':42.739,'grade_note':'Raw lidar/carved-bed sample gradients, not an engineered road grade or a gameplay collision audit.'}}
(ROOT/'docs/validation/ROADS_JUMP_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
(review/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('VERIFIED',len(assets),'assets,',len(tests),'suites, 33 matched repeated captures and actual Spacebar input')
print('ROAD_COST',[(m['id'],round(m['delta_ms'],3)) for m in metrics[:6]])
