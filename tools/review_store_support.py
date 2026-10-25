"""Retain actual local placement evidence and the matching source hashes."""
from pathlib import Path
import hashlib,json,re,shutil
from PIL import Image
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots';O=R/'docs/reviews/store-supported-2026-10-13';O.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
suites=[]
for filename in ['store-support-test','store-electrical-regression','store-opening-regression']:
 p=S/(filename+'.log');s=p.read_text(encoding='utf-8-sig');assert 'failures=0' in s and 'SCRIPT ERROR' not in s and not re.search(r'^FAIL\b',s,re.M)
 suites.append({'suite':filename,'checks':len(re.findall(r'^PASS ',s,re.M)),'failures':0,'log_sha256':sha(p)})
capture=S/'store-supported-capture.log';text=capture.read_text(encoding='utf-8-sig');assert 'STORE_CAPTURE_COMPLETE' in text and 'SCRIPT ERROR' not in text
images={}
for p in (S/'store-supported').glob('*.png'):
 im=Image.open(p);size=im.size;im.thumbnail((1600,900));im.save(O/p.name);images[p.name]={'original_size':size,'source_sha256':sha(p),'review_sha256':sha(O/p.name)}
check=R/'brave-and-cold/assets/store_supported/validation.json';v=json.loads(check.read_text());assert v['failures']==0;shutil.copyfile(check,O/'asset-validation.json')
(O/'receipt.json').write_text(json.dumps({'scope':'Local Blender/Godot placement checks, not human play acceptance or a sealed package','suites':suites,'asset_checks':v['checks'],'captures':images,'source_hashes':{str(p.relative_to(R)):sha(p) for p in [R/'tools/blender/fix_store_support.py',R/'brave-and-cold/world/store.gd',R/'brave-and-cold/world/game_world.gd',R/'brave-and-cold/world/electrical_fieldwork.gd',R/'brave-and-cold/world/lookout_opening.gd',R/'brave-and-cold/world/town_life.gd']}},indent=2)+'\n')
print('STORE_SUPPORT_REVIEW_COMPLETE',sum(x['checks'] for x in suites),'gameplay checks,',v['checks'],'asset checks')
