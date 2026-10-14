"""Retain current local character evidence; never certify human play acceptance."""
from pathlib import Path
import json,re,hashlib,shutil,statistics
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots';O=R/'docs/reviews/modular-human-2026-10-14';O.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
suites=[]
logs=['modular-human-skin-'+name for name in ['rowan','sam','lin','infected_preview']]+['modular-human-final-'+name for name in ['modular_human_gait','town_life','infected_skin','infected_gait']]+['modular-human-first-week','modular-human-final-electrical']
for filename in logs:
 p=S/(filename+'.log');s=p.read_text(encoding='utf-8-sig');match=re.search(r'\w+_TEST checks=(\d+) failures=0',s)
 assert match and 'SCRIPT ERROR:' not in s and not re.search(r'^FAIL\b',s,re.M),filename
 assert int(match[1])==len(re.findall(r'^PASS ',s,re.M)),filename
 suites.append({'suite':filename,'checks':int(match[1]),'failures':0,'log_sha256':sha(p)})
asset=R/'brave-and-cold/assets/modular_human/validation.json';v=json.loads(asset.read_text());assert v['failures']==0;shutil.copyfile(asset,O/'asset-validation.json')
for folder,marker in [('modular-human','MODULAR_HUMAN_PREVIEW_COMPLETE'),('modular-human-engine','HUMAN_CAPTURE_COMPLETE')]:
 log=S/('modular-human-preview.log' if folder=='modular-human' else 'modular-human-capture.log');text=log.read_text(encoding='utf-8-sig');assert marker in text and 'SCRIPT ERROR' not in text and 'Traceback' not in text
images={}
for folder in ['modular-human','modular-human-engine']:
 for p in sorted((S/folder).glob('*.png')):
  im=Image.open(p);size=im.size;im.thumbnail((1600,1000));dest=O/(('blender-' if folder=='modular-human' else 'engine-')+p.name);im.save(dest)
  images[dest.name]={'source_size':size,'source_sha256':sha(p),'review_sha256':sha(dest)}
sheet=Image.new('RGB',(1400,700),'#111b20');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(['body-front','body-three-quarter','face-front','hand']):
 im=Image.open(O/('blender-'+name+'.png')).convert('RGB');im.thumbnail((350,670));x=i*350+(350-im.width)//2;sheet.paste(im,(x,25));draw.text((i*350+10,7),name.replace('-',' '),fill='white')
sheet.save(O/'foundation-sheet.png')
timing_log=S/'modular-human-timing.log';text=timing_log.read_text(encoding='utf-8-sig');assert 'HUMAN_BUDGET_COMPLETE' in text and 'SCRIPT ERROR' not in text and 'buffer_create' not in text
timing=json.loads((S/'modular-human-engine/timing.json').read_text());assert timing['resolution']==[1920,1080] and len(timing['rows'])==6
assert all(r['frames']>200 and r['resident_nodes']==3 and (r['variant']=='off' or r['visible_centres_max']>0) for r in timing['rows'])
shutil.copyfile(S/'modular-human-engine/timing.json',O/'timing.json')
summary={key:statistics.median(r['median_ms'] for r in timing['rows'] if r['variant']==key) for key in ['on','off']}
files=[R/'tools/blender/gen_modular_human.py',R/'tools/blender/render_modular_human.py',R/'tools/validate_modular_human.py',R/'brave-and-cold/entities/town_resident.gd',R/'brave-and-cold/tests/test_town_life.gd',R/'brave-and-cold/tests/test_modular_human_skin.gd',R/'brave-and-cold/tests/test_modular_human_gait.gd']
(O/'receipt.json').write_text(json.dumps({'scope':'Original local Blender assets, actual-byte and engine-pose checks, real captures and bounded local timing. No canonical/sealed package or user play acceptance. Anonymous population rollout and facial animation remain separate work.','started_from':'7822ca4','store_fix_commit':'d4f2497','asset_manifest':json.loads((R/'brave-and-cold/assets/modular_human/manifest.json').read_text()),'source_hashes':{str(p.relative_to(R)):sha(p) for p in files},'captures':images,'gameplay_checks':sum(r['checks'] for r in suites),'asset_checks':v['checks'],'suites':suites,'timing_medians_ms':summary,'timing_log_sha256':sha(timing_log)},indent=2)+'\n')
print('MODULAR_HUMAN_REVIEW_COMPLETE',sum(r['checks'] for r in suites),'gameplay checks;',v['checks'],'asset checks;',json.dumps(summary))
