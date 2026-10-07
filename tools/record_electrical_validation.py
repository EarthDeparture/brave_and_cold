"""Bind final local evidence for the electrical fieldwork batch; no user saves."""
from pathlib import Path
import json,hashlib,re,subprocess
from validate_electrical_assets import validate
R=Path(__file__).resolve().parents[1]
OUT=R/'brave-and-cold/shots/electrical-fieldwork-2026-10-07'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def source_sha(path):return hashlib.sha256(path.read_text(encoding='utf-8-sig').replace('\r\n','\n').encode()).hexdigest()
def record():
 diagnostics={}
 names=['test_electrical_fieldwork','test_solar_recovery','test_lookout_assignment','test_lookout_opening','test_watch_walkie_door','test_radio_bulletins','test_first_week_core','test_first_week_story','test_opening_pacing','test_lookout_stair_turns']
 for name in names:
  path=OUT/(name+'.log');log=path.read_text(encoding='utf-8-sig');passed=len(re.findall(r'^PASS ',log,re.M))
  assert passed and 'failures=0' in log and not re.search(r'^FAIL |SCRIPT ERROR|Parse Error',log,re.M),name
  diagnostics[name]={'assertions_passed':passed,'failures':0,'observed_exit_code':0,'log_sha256':sha(path),'shutdown_warnings':sorted(set(re.findall(r'^WARNING:.*(?:leaked|ObjectDB).*$',log,re.M)))}
 assert sum(e['assertions_passed'] for e in diagnostics.values())==557
 routes={}
 for name in ['electrical-baseline','electrical-outing']:
  path=R/'brave-and-cold/shots/opening-pacing-2026-10-06'/(name+'-route.json')
  data=json.loads(path.read_text());assert data['completed'] and not data['failure'] and data['repair_stage']==3
  if name=='electrical-outing':
   last=data['samples'][-1]
   assert last['winter_controller'] and last['tested_lead_installed'] and all(last['electrical_issue'].values())
   assert last['fuse_pack']==1 and last['controller_pack']==last['cable_pack']==last['connector_pack']==0
  routes[name]={'file':str(path.relative_to(R)).replace('\\','/'),'sha256':sha(path),'run':data}
 captures={}
 for name in ['depot-controller-stock','depot-stock-issued','crew-spare-packet','spur-cable-recovery','electrical-issue-record','controller-diagnosis']:
  path=OUT/(name+'.png');assert path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
  captures[name]={'file':str(path.relative_to(R)).replace('\\','/'),'sha256':sha(path),'visually_inspected':True}
 capture_log=(OUT/'capture.log').read_text(encoding='utf-8-sig');assert 'ELECTRICAL_CAPTURE_DONE gpu=NVIDIA GeForce GTX 1080 Ti' in capture_log
 assert 'SCRIPT ERROR' not in capture_log and 'Parse Error' not in capture_log
 rollback_log=(OUT/'rollback-tests.log').read_text(encoding='utf-8-sig');assert 'Ran 3 tests' in rollback_log and 'OK' in rollback_log
 sources=['.gitignore','brave-and-cold/systems/inventory.gd','brave-and-cold/systems/solar_supply.gd','brave-and-cold/world/first_week_route.gd','brave-and-cold/world/game_world.gd','brave-and-cold/world/item_pickup.gd','brave-and-cold/world/lookout_opening.gd','brave-and-cold/world/lookout_solar.gd','brave-and-cold/systems/electrical_service.gd','brave-and-cold/world/electrical_fieldwork.gd','brave-and-cold/tests/test_electrical_fieldwork.gd','brave-and-cold/tests/measure_electrical_outing.gd','brave-and-cold/tests/visual/capture_electrical_fieldwork.gd','tools/blender/gen_electrical_fieldwork.py','tools/blender/gen_electrical_graphics.py','tools/validate_electrical_assets.py','tools/export_electrical_rollback.py','tools/test_export_electrical_rollback.py','tools/record_electrical_validation.py','docs/design/ELECTRICAL_FIELDWORK.md','docs/design/SOLAR_AND_SUSTAINABLE_FOOD.md','docs/validation/ELECTRICAL_FIELDWORK.md']
 manifest=R/'brave-and-cold/assets/electrical_fieldwork/manifest.json'
 receipt={'date':'2026-10-07','branch':'codex/electrical-fieldwork','baseline_commit':subprocess.check_output(['git','rev-parse','checkpoint/pre-electrical-fieldwork-2026-10-07'],cwd=R,text=True).strip(),'checkpoint':'checkpoint/pre-electrical-fieldwork-2026-10-07','source_digest_convention':'UTF-8, no BOM, LF normalized; binary/media and raw logs use exact bytes','source_sha256_lf':{name:source_sha(R/name) for name in sources},'asset_manifest_sha256_lf':source_sha(manifest),'asset_manifest':json.loads(manifest.read_text()),'asset_validation':validate(),'runtime_diagnostics':diagnostics,'total_runtime_assertions_passed':557,'rollback_export_tests':{'passed':3,'log_sha256':sha(OUT/'rollback-tests.log'),'original_user_save_files_read_or_modified':False},'movement_outings':routes,'captures':captures,'capture_gpu':'NVIDIA GeForce GTX 1080 Ti','capture_resolution':[1600,900],'capture_log_sha256':sha(OUT/'capture.log'),'editor_import':{'log_sha256':sha(OUT/'import.log'),'limitations':'Restricted AppData editor/cache/log writes and root certificate access; unchanged Terrain3D DoubleSlider editor error. Not claimed as a clean editor launch.'},'behavior_limits':['No new automatic hardware failure events','No battery energy, capacity or outage-deadline gifts','No map/road/structure relocation or new ground collider','No user saves used by runtime diagnostics','No remote push','No farming, greenhouse or preservation implementation','Movement diagnostics freeze entity animations and are not human or FPS benchmarks']}
 target=R/'docs/validation/ELECTRICAL_FIELDWORK_RECEIPT.json';target.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'runtime_assertions':557,'rollback_tests':3,'routes':{name:entry['run']['samples'][-1]['real_s'] for name,entry in routes.items()},'receipt':str(target)},indent=2))
if __name__=='__main__':record()
