"""Local render/pose receipts for the next resident presentation pass."""
from pathlib import Path
import json,re,hashlib,statistics,shutil
from PIL import Image,ImageDraw
import numpy as np
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots';O=R/'docs/reviews/resident-presence-2026-10-14';O.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
logs=['resident-presence-final-'+n for n in ['resident_presence','town_life','store_support','first_week_collapse']]+['resident-presence-skin-'+n for n in ['rowan','sam','lin','infected_preview']]+['resident-presence-gait'];suites=[]
for name in logs:
 p=S/(name+'.log');text=p.read_text(encoding='utf-8-sig');match=re.search(r'\w+_TEST checks=(\d+) failures=0',text)
 assert match and 'SCRIPT ERROR:' not in text and not re.search(r'^FAIL\b',text,re.M),name
 suites.append({'suite':name,'checks':int(match[1]),'failures':0,'log_sha256':sha(p)})
asset=R/'brave-and-cold/assets/resident_presence/validation.json';validation=json.loads(asset.read_text());assert validation['failures']==0;shutil.copyfile(asset,O/'asset-validation.json')
images={}
for folder,prefix,log,marker in [('resident-presence','diagnostic-','resident-presence-capture.log','RESIDENT_PRESENCE_CAPTURE_COMPLETE'),('resident-presence-world','world-','resident-presence-world-capture.log','RESIDENT_PRESENCE_WORLD_CAPTURE_COMPLETE')]:
 text=(S/log).read_text(encoding='utf-8-sig');assert marker in text and 'SCRIPT ERROR' not in text
 for p in sorted((S/folder).glob('*.png')):
  im=Image.open(p);size=im.size;im.thumbnail((1280,900));dest=O/(prefix+p.name);im.save(dest)
  images[dest.name]={'source_dimensions':size,'source_sha256':sha(p),'review_sha256':sha(dest)}
# Check rendered coverage in the visible aperture, not merely shape-key values.
counts={}
for name in ['open','half','closed']:
 a=np.array(Image.open(S/'resident-presence'/(name+'.png')).convert('RGB')).astype(float);h,w=a.shape[:2];count=0
 for cx in [.382,.618]:
  ys,xs=np.mgrid[0:h,0:w];mask=((xs/w-cx)/.063)**2+((ys/h-.500)/.024)**2<1
  neutral=(abs(a[:,:,0]-a[:,:,1])<18)&(abs(a[:,:,1]-a[:,:,2])<18)&(a.min(axis=2)>95)
  count+=int((mask&neutral).sum())
 counts[name]=count
assert counts['open']>100 and counts['closed']<counts['open']*.10,counts
sheet=Image.new('RGB',(1260,445),'#101b20');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(['open','half','closed']):
 im=Image.open(O/('diagnostic-'+name+'.png')).convert('RGB').resize((420,420));sheet.paste(im,(i*420,25));draw.text((i*420+10,8),name,fill='white')
sheet.save(O/'blink-comparison.png')
timing=json.loads((S/'resident-presence-world/timing.json').read_text());text=(S/'resident-presence-timing.log').read_text(encoding='utf-8-sig');assert 'PRESENCE_BUDGET_COMPLETE' in text and 'buffer_create' not in text and 'SCRIPT ERROR' not in text
assert timing['resolution']==[1920,1080] and len(timing['rows'])==6 and all(r['frames']>200 and (r['variant']=='off' or r['visible_centres_max']>0) for r in timing['rows'])
shutil.copyfile(S/'resident-presence-world/timing.json',O/'timing.json');summary={k:statistics.median(r['median_ms'] for r in timing['rows'] if r['variant']==k) for k in ['off','on']}
files=[R/'brave-and-cold/entities/town_resident.gd',R/'brave-and-cold/systems/resident_presence.gd',R/'brave-and-cold/ui/town_conversation.gd',R/'brave-and-cold/tests/test_resident_presence.gd',R/'tools/blender/gen_resident_presence.py',R/'tools/validate_resident_presence.py']
(O/'receipt.json').write_text(json.dumps({'scope':'Local original Blender derivative, actual-byte/engine-pose validation and direct renders; no canonical package, sealed run or human play acceptance','start_commit':'15f0b46','gameplay_checks':sum(s['checks'] for s in suites),'asset_checks':validation['checks'],'suites':suites,'captures':images,'rendered_aperture_neutral_pixels':counts,'timing_medians_ms':summary,'timing_log_sha256':sha(S/'resident-presence-timing.log'),'sources':{str(p.relative_to(R)):sha(p) for p in files},'assets':json.loads((R/'brave-and-cold/assets/resident_presence/manifest.json').read_text())},indent=2)+'\n')
print('RESIDENT_PRESENCE_REVIEW_COMPLETE',sum(s['checks'] for s in suites),'gameplay checks;',validation['checks'],'asset checks;',counts,summary)
