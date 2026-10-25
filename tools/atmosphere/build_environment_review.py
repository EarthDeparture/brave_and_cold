"""Verify original asset receipts and matched local captures; generate review evidence."""
from pathlib import Path
import json,hashlib,statistics,re,subprocess
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
PROJECT=ROOT/'brave-and-cold';SHOTS=PROJECT/'shots/environment-detail';OUT=SHOTS/'review';OUT.mkdir(parents=True,exist_ok=True)
before=json.loads((SHOTS/'before/manifest.json').read_text());after=json.loads((SHOTS/'final-03/manifest.json').read_text())
assert before['resolution']==after['resolution']==[1600,900]
old={r['id']:r for r in before['captures']};new={r['id']:r for r in after['captures']}
assert len(old)==20 and len(new)==25
for name,b in old.items():
 a=new[name]
 for key in ['hour','weather','eye','target','inside','fov','overcast','cloud_coverage']:assert a[key]==b[key],(name,key)
 for folder,record in [('before',b),('final-03',a)]:
  assert hashlib.sha256((SHOTS/folder/(name+'.png')).read_bytes()).hexdigest()==record['sha256']
for path,digest in after['source_hashes'].items():
 assert hashlib.sha256((PROJECT/path.removeprefix('res://')).read_bytes()).hexdigest()==digest,path
asset_count=0
for folder in ['textures','trees','viewmodel','audio']:
 directory=PROJECT/'assets/environment_detail'/folder
 receipt=json.loads((directory/'provenance.json').read_text())
 entries=receipt.get('files',receipt.get('models'))
 for item in entries:
  filename=item.get('file',item.get('name','')+'.glb')
  if 'sha256' not in item:continue
  assert hashlib.sha256((directory/filename).read_bytes()).hexdigest()==item['sha256'],filename
  asset_count+=1
 if folder=='viewmodel':
  assert hashlib.sha256((directory/'winter_sleeves.glb').read_bytes()).hexdigest()==receipt['sha256'];asset_count+=1
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',24)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
def cell(folder,name,w=800):
 return Image.open(SHOTS/folder/(name+'.png')).convert('RGB').resize((w,round(w*9/16)),Image.Resampling.LANCZOS)
def pairs(names,target):
 im=Image.new('RGB',(1600,494*len(names)),(16,23,31));draw=ImageDraw.Draw(im)
 for row,name in enumerate(names):
  y=row*494
  for folder,x,label in [('before',0,'BEFORE'),('final-03',800,'AFTER')]:
   draw.text((x+16,y+8),label+' — '+name.replace('-',' '),font=font,fill='white')
   im.paste(cell(folder,name),(x,y+44))
 im.save(OUT/target)
pairs(['clear-forest','clear-lake','blizzard-interior'],'before-after.png')
pairs(['clear-interior','dusk-lookout','night-forest'],'material-lighting-review.png')
sheet=Image.new('RGB',(2500,318*5),(16,23,31));draw=ImageDraw.Draw(sheet)
for i,name in enumerate(new):
 x=i%5*500;y=i//5*318
 draw.text((x+10,y+5),name,font=small,fill='white');sheet.paste(cell('final-03',name,500),(x,y+36))
sheet.save(OUT/'all-25-views.png')
frames=[]
for i in range(40):
 name='forest-overcast-%03d'%i
 im=Image.new('RGB',(1600,494),(16,23,31));draw=ImageDraw.Draw(im)
 draw.text((16,8),'BEFORE — actual game frames',font=font,fill='white')
 draw.text((816,8),'AFTER — actual game frames',font=font,fill='white')
 im.paste(cell('film-before',name),(0,44));im.paste(cell('film-after',name),(800,44));frames.append(im)
frames[0].save(OUT/'moving-before-after.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=False)
metrics=[]
for baseline,candidate in [('motion-baseline-confirm','motion-final'),('live-before','live-after')]:
 b=json.loads((SHOTS/baseline/'manifest.json').read_text());a=json.loads((SHOTS/candidate/'manifest.json').read_text())
 assert b['resolution']==a['resolution']==[1600,900] and b['performance_valid'] and a['performance_valid']
 assert b['repeats']==a['repeats']==3
 for name in dict.fromkeys(r['id'] for r in b['scenarios']):
  rows=[{k:round(statistics.median(r[k] for r in m['scenarios'] if r['id']==name),3) for k in ['median_ms','p99_ms','engine_process_median_ms']} for m in [b,a]]
  metrics.append({'scenario':name,'live':a['live_gameplay'],'before':rows[0],'after':rows[1],'change_percent':round(100*(rows[1]['median_ms']/rows[0]['median_ms']-1),1)})
tests={}
for name in ['test_environment_detail','test_atmosphere','test_survival','test_frozen_water','test_shore_walking','test_fire_lookout','test_viewmodel','test_audio']:
 text=(SHOTS/(name+'.log')).read_text()
 assert 'FAIL ' not in text and 'SCRIPT ERROR' not in text and 'Parse Error' not in text,name
 if 'failures=' in text:assert re.search(r'failures=0(?:\D|$)',text),name
 tests[name]={'passed':True,'sha256':hashlib.sha256((SHOTS/(name+".log")).read_bytes()).hexdigest()}
b=np.asarray(Image.open(SHOTS/'before/clear-forest.png')).astype(int)
a=np.asarray(Image.open(SHOTS/'baseline-confirm/clear-forest.png')).astype(int)
delta=np.abs(a-b)
verification={'schema':1,'renderer_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'baseline_commit':'cdc91978c33ec980b8d0dd5192f1e41b523a59ef','recovery_tag':'checkpoint/pre-environment-detail-2026-10-03','matched_views':20,'extra_tree_views':5,'asset_hashes_verified':asset_count,'resolution':[1600,900],'gpu':after['gpu'],'driver':after['driver'],'engine':after['engine'],'metrics':metrics,'tests':tests,'render_source_hashes':after['source_hashes'],'baseline_comparison':{'mean_absolute_byte_difference':float(delta.mean()),'changed_pixels':int(np.any(delta,axis=2).sum()),'total_pixels':1600*900},'limitations':'Local project capture fallback, not sealed game-dev CLI telemetry. Wall-clock frame observations; live case includes normal population. Film readback overhead excluded. Existing Terrain3D deprecation and exit resource warnings remain.'}
(OUT/'receipt.json').write_text(json.dumps(verification,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
print('VERIFIED',asset_count,'asset hashes, 20 matched views + 5 bough views, 8 suites, 40 actual moving frames per variant.')
