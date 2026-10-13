"""Retain local town-life QA evidence; no sealed/canonical package claim."""
from pathlib import Path
import json, re, hashlib, statistics, shutil
from PIL import Image, ImageDraw
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots';OUT=R/'docs/reviews/town-life-2026-10-13'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
OUT.mkdir(parents=True,exist_ok=True)
suites=[]
for name in ['town_life','infected_skin','infected_gait','first_week_collapse','shift_work','lookout_opening','electrical_fieldwork']:
 p=S/('town-life-test_'+name+'.log');text=p.read_text(encoding='utf-8-sig')
 match=re.search(r'\w+_TEST\s+(?:checks=(\d+)\s+)?failures=(\d+)',text)
 assert match and int(match[2])==0 and 'SCRIPT ERROR:' not in text and not re.search(r'^FAIL\b',text,re.M),name
 suites.append({'suite':name,'checks':int(match[1]) if match[1] else len(re.findall(r'^PASS\b',text,re.M)),'failures':0,'log_sha256':sha(p)})
asset=json.loads((R/'brave-and-cold/assets/town_residents/validation.json').read_text());assert asset['failures']==0
tests={'gameplay_and_pose_checks':sum(x['checks'] for x in suites),'asset_checks':asset['checks'],'failures':0,'suites':suites}
(OUT/'tests.json').write_text(json.dumps(tests,indent=2)+'\n');shutil.copyfile(R/'brave-and-cold/assets/town_residents/validation.json',OUT/'asset-validation.json')
capture=(S/'town-life-capture.log').read_text(encoding='utf-8-sig');assert 'TOWN_CAPTURE_COMPLETE' in capture and 'SCRIPT ERROR' not in capture
captures={}
for p in sorted((S/'town-life').glob('*.png')):
 im=Image.open(p);original=im.size;im.thumbnail((1600,900));im.save(OUT/p.name)
 captures[p.name]={'source_size':original,'source_sha256':sha(p),'review_sha256':sha(OUT/p.name)}
assert len(captures)==11
sheet=Image.new('RGB',(1400,820),'#101b20');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(['ordinary-counter','ill-counter','unresponsive','infected-counter']):
 im=Image.open(OUT/(name+'.png')).convert('RGB').resize((700,394));x=(i%2)*700;y=(i//2)*410
 sheet.paste(im,(x,y+16));draw.text((x+10,y+2),name.replace('-',' '),fill='white')
sheet.save(OUT/'shop-progression.png')
log=(S/'town-life-timing-final.log').read_text(encoding='utf-8-sig')
assert 'TOWN_BUDGET_COMPLETE' in log and 'SCRIPT ERROR' not in log and 'buffer_create' not in log
timing=json.loads((S/'town-life/timing.json').read_text());assert timing['resolution']==[1920,1080] and timing['seed']==20261004 and len(timing['rows'])==6
assert all(x['frames']>200 and x['resident_nodes']==3 and (x['variant']=='off' or x['visible_centres_max']>0) for x in timing['rows'])
shutil.copyfile(S/'town-life/timing.json',OUT/'timing.json')
rejects=[]
for name,reason in [('town-life-timing.log','D3D12 buffer creation failed, 0x887a0005; no timing acceptance'),('town-life-timing-vulkan.log','Completed with no resident centres visible and incorrect 3200x1800 viewport; not an NPC-cost measurement')]:
 p=S/name;lines=p.read_text(encoding='utf-8-sig').splitlines()
 rejects.append({'log':name,'reason':reason,'sha256':sha(p),'first_60_lines':lines[:60]})
(OUT/'rejected-diagnostics.json').write_text(json.dumps(rejects,indent=2)+'\n')
raw=(S/'town-life-budget-before.log').read_text(encoding='utf-8-sig');assert 'BUDGET_COMPLETE' in raw and 'SCRIPT ERROR:' not in raw
(OUT/'clinic-budget-before.txt').write_text('\n'.join(x for x in raw.splitlines() if x.startswith('BUDGET'))+'\n')
manifest=json.loads((R/'brave-and-cold/assets/town_residents/manifest.json').read_text())
sources={str(p.relative_to(R)):sha(p) for p in [R/'brave-and-cold/entities/town_resident.gd',R/'brave-and-cold/systems/town_resident_state.gd',R/'brave-and-cold/world/town_life.gd',R/'brave-and-cold/ui/town_conversation.gd',R/'brave-and-cold/data/town_dialogue.json',R/'brave-and-cold/entities/zombies/zombie.gd',R/'brave-and-cold/world/game_world.gd']}
(OUT/'receipt.json').write_text(json.dumps({'scope':'Original local Blender assets, actual-byte validation, Godot captures and bounded local timing. No canonical package, sealed run or human play acceptance.','assets':manifest,'sources':sources,'captures':captures,'tests':tests,'timing_log_sha256':sha(S/'town-life-timing-final.log')},indent=2)+'\n')
summary={k:statistics.median(x['median_ms'] for x in timing['rows'] if x['variant']==k) for k in ['on','off']}
print('TOWN_REVIEW_COMPLETE',json.dumps(tests));print('TIMING_MEDIANS',summary)
