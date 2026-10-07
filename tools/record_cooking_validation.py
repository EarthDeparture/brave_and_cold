"""Seal accepted gameplay, original asset and visual-review evidence."""
from pathlib import Path
import hashlib,json,re
from validate_cooking_assets import validate
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots/hunt-cooking-2026-10-07'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_sha(p):return hashlib.sha256(p.read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()
expected={'hunt_cooking':50,'food_preservation':69,'electrical_fieldwork':49,'solar_recovery':29,'lookout_assignment':27,'lookout_opening':53,'watch_walkie_door':46,'radio_bulletins':141,'first_week_core':33,'first_week_story':38,'opening_pacing':50,'lookout_stair_turns':91}
tests={}
for name,n in expected.items():
 p=S/('test_'+name+'.log');t=p.read_text(encoding='utf-8-sig')
 assert len(re.findall(r'^PASS ',t,re.M))==n,(name,n)
 assert 'failures=0' in t and not re.search(r'^FAIL |SCRIPT ERROR|Parse Error',t,re.M),name
 tests[name]={'pass_assertions':n,'log':str(p.relative_to(R)).replace('\\','/'),'sha256':sha(p),'native_exit_code':0}
p6=S/'p6.log';t=p6.read_text(encoding='utf-8-sig')
assert 'P6TEST failures=0' in t and 'SCRIPT ERROR' not in t
assert len(re.findall(r'^P6TEST .*?(?:=true| true)',t,re.M))==13
rollback=S/'rollback.log';assert 'Ran 3 tests' in rollback.read_text() and 'OK' in rollback.read_text()
route=S/'hunt-route.json';outing=json.loads(route.read_text());assert outing['completed'] and not outing['failure']
assert outing['ammo_spent']==1 and outing['raw_remaining']==5 and abs(outing['knife_condition']-.98)<1e-6
assert outing['food_message'].startswith('Ate Dried Venison') and 'SCRIPT ERROR' not in (S/'hunt-route.log').read_text(encoding='utf-8-sig')
capture=S/'capture.log';t=capture.read_text(encoding='utf-8-sig');assert 'COOK_CAPTURE_DONE gpu=NVIDIA GeForce GTX 1080 Ti' in t and 'SCRIPT ERROR' not in t
images={}
for name in ['cabin-empty','cabin-raw','cabin-cooked','cabin-collected','lookout-raw','lookout-cooked','lookout-night-fire','lookout-spoiled']:
 p=S/(name+'.png');assert p.read_bytes()[:8]==b'\x89PNG\r\n\x1a\n'
 images[name]={'path':str(p.relative_to(R)).replace('\\','/'),'sha256':sha(p),'agent_visual_review':'accepted'}
sources=['brave-and-cold/systems/cook_batch.gd','brave-and-cold/systems/carcass.gd','brave-and-cold/systems/inventory.gd','brave-and-cold/entities/animals/deer.gd','brave-and-cold/entities/animals/wolf.gd','brave-and-cold/world/cook_display.gd','brave-and-cold/world/cabin.gd','brave-and-cold/world/game_world.gd','brave-and-cold/world/lookout_opening.gd','brave-and-cold/ui/dev_menu.gd','brave-and-cold/tests/test_hunt_cooking.gd','brave-and-cold/tests/test_food_preservation.gd','brave-and-cold/tests/measure_hunt_cooking.gd','brave-and-cold/tests/measure_opening_route.gd','brave-and-cold/tests/visual/capture_hunt_cooking.gd','tools/blender/gen_cooking.py','tools/blender/gen_cooking_graphics.py','tools/validate_cooking_assets.py','tools/export_cooking_rollback.py','tools/test_export_cooking_rollback.py']
out={'date':'2026-10-07','baseline':'d3a9f87','branch':'codex/hunt-cooking','rollback_tag':'checkpoint/pre-hunt-cooking-2026-10-07','gameplay_assertions':sum(expected.values()),'diagnostics':tests,'p6_checks':{'passed':13,'log_sha256':sha(p6)},'rollback_copy_tests':{'passed':3,'log_sha256':sha(rollback)},'controlled_outing':outing,'outing_json_sha256':sha(route),'outing_log_sha256':sha(S/'hunt-route.log'),'assets':validate(),'manifest_sha256':sha(R/'brave-and-cold/assets/cooking/manifest.json'),'source_sha256_lf':{p:source_sha(R/p) for p in sources},'render':{'renderer':'Vulkan Forward+','gpu':'NVIDIA GeForce GTX 1080 Ti','viewport':[1600,900],'capture_log_sha256':sha(capture),'images':images,'scope':'Frozen player-camera views; no moving AI, human playtesting or performance claim'},'rejected_candidates':['Cabin pans below authored stove top','Cooked food retained raw-red hue'],'preexisting_diagnostics':'Restricted user/editor log/cache paths, certificate-store output, Terrain3D editor DoubleSlider nil/int error and shutdown resource warnings'}
(R/'docs/validation/HUNT_AND_COOKING_RECEIPT.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8',newline='\n')
print('COOKING_RECEIPT gameplay=',sum(expected.values()),'p6=13 rollback=3 views=',len(images))
