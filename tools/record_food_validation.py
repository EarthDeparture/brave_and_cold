"""Seal diagnostics/assets/render review evidence without reading user saves."""
from pathlib import Path
import json,re,hashlib
from validate_food_assets import validate
R=Path(__file__).resolve().parents[1];SHOTS=R/'brave-and-cold/shots/food-preservation-2026-10-07'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_sha(p):return hashlib.sha256(p.read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()
expected={'food_preservation':69,'electrical_fieldwork':49,'solar_recovery':29,'lookout_assignment':27,'lookout_opening':53,'watch_walkie_door':46,'radio_bulletins':141,'first_week_core':33,'first_week_story':38,'opening_pacing':50,'lookout_stair_turns':91}
tests={}
for name,n in expected.items():
 path=SHOTS/('test_'+name+'.log');text=path.read_text(encoding='utf-8-sig')
 assert len(re.findall(r'^PASS ',text,re.M))==n,(name,n)
 assert not re.search(r'^FAIL |SCRIPT ERROR|Parse Error',text,re.M),name
 assert 'failures=0' in text,name
 tests[name]={'pass_assertions':n,'log':str(path.relative_to(R)).replace('\\','/'),'sha256':sha(path),'native_exit_code':0}
rollback=SHOTS/'rollback.log';assert re.search(r'Ran 3 tests',rollback.read_text()) and 'OK' in rollback.read_text()
capture=SHOTS/'capture.log';capture_text=capture.read_text(encoding='utf-8-sig');assert 'FOOD_CAPTURE_DONE gpu=NVIDIA GeForce GTX 1080 Ti' in capture_text
assert 'SCRIPT ERROR' not in capture_text
images={}
for name in ['rack-empty','rack-loaded','rack-door-open','rack-night-fire','rack-blizzard-light','food-notes','rack-collected','dried-food-pickup']:
 path=SHOTS/(name+'.png');assert path.exists() and path.read_bytes()[:8]==b'\x89PNG\r\n\x1a\n'
 images[name]={'path':str(path.relative_to(R)).replace('\\','/'),'sha256':sha(path),'agent_visual_review':'accepted'}
sources=['brave-and-cold/systems/food_portion.gd','brave-and-cold/systems/food_preservation.gd','brave-and-cold/systems/inventory.gd','brave-and-cold/world/campfire.gd','brave-and-cold/world/game_world.gd','brave-and-cold/world/item_pickup.gd','brave-and-cold/world/lookout_opening.gd','brave-and-cold/world/storage_chest.gd','brave-and-cold/tests/test_food_preservation.gd','brave-and-cold/tests/visual/capture_food_preservation.gd','tools/blender/gen_food_preservation.py','tools/blender/gen_food_graphics.py','tools/validate_food_assets.py','tools/export_food_rollback.py','tools/test_export_food_rollback.py']
out={'date':'2026-10-07','baseline':'9f3dff6','branch':'codex/food-preservation','rollback_tag':'checkpoint/pre-food-preservation-2026-10-07','gameplay_assertions':sum(expected.values()),'diagnostics':tests,'rollback_copy_tests':{'passed':3,'log_sha256':sha(rollback)},'assets':validate(),'manifest_sha256':sha(R/'brave-and-cold/assets/food_preservation/manifest.json'),'source_sha256_lf':{path:source_sha(R/path) for path in sources},'render':{'renderer':'Vulkan Forward+','gpu':'NVIDIA GeForce GTX 1080 Ti','viewport':[1600,900],'capture_log_sha256':sha(capture),'images':images,'scope':'Frozen player-camera views; sky/light storm response, not moving snowfall; no human playtest or performance claim'},'initial_candidate_rejected':'rack brackets overlapped window; final rack mounted below sill','preexisting_diagnostics':'Restricted user log/editor paths, certificate store output, Terrain3D editor DoubleSlider nil/int error and shutdown RID/ObjectDB warnings remain; no runtime script/parse errors in selected tests','save_safety':'Synthetic in-memory snapshots and temporary rollback fixtures only; user saves untouched'}
(R/'docs/validation/FOOD_PRESERVATION_RECEIPT.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8')
print('FOOD_VALIDATION_RECEIPT gameplay_assertions=',out['gameplay_assertions'],'rollback_tests=3 assets=2 images=',len(images))
