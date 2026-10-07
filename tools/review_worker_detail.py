"""Retain local validation/capture/timing receipts; not sealed game-dev runs."""
from pathlib import Path
import json, re, hashlib, shutil, statistics
from PIL import Image, ImageDraw
R=Path(__file__).resolve().parents[1];S=R/'brave-and-cold/shots';W=S/'worker-detail';OUT=R/'docs/reviews/worker-detail-2026-10-07'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 suites=[]
 for name in ['infected_skin','infected_gait','viewmodel','first_week_collapse','first_week_core','opening_pacing','encounter_presentation','population_reserve']:
  p=S/('worker-detail-test_'+name+'.log');txt=p.read_text(encoding='utf-8-sig')
  found=re.search(r'\w+_TEST\s+(?:checks=(\d+)\s+)?failures=(\d+)',txt)
  assert found and int(found[2])==0 and 'SCRIPT ERROR' not in txt and not re.search(r'^FAIL\b',txt,re.M),name
  count=int(found[1]) if found[1] else len(re.findall(r'^PASS\b',txt,re.M))
  suites.append({'suite':name,'checks':count,'failures':0,'log_sha256':digest(p)})
 validation=json.loads((R/'brave-and-cold/assets/infected/detail/validation.json').read_text());assert validation['failures']==0
 tests={'gameplay_and_pose_checks':sum(s['checks'] for s in suites),'asset_checks':validation['checks'],'failures':0,'suites':suites}
 (OUT/'tests.json').write_text(json.dumps(tests,indent=2)+'\n')
 for filename,marker in [('capture','WORKER_DETAIL_CAPTURE_COMPLETE'),('motion-capture','WORKER_MOTION_CAPTURE_COMPLETE'),('interactions-capture','OPENING_INTERACTIONS_CAPTURE_COMPLETE'),('world-capture','ENCOUNTER_WORLD_CAPTURE_COMPLETE'),('group-timing','WORKER_TIMING_COMPLETE'),('moving-timing','OPENING_MOTION_COMPLETE')]:
  txt=(S/('worker-detail-'+filename+'.log')).read_text(encoding='utf-8-sig');assert marker in txt and 'SCRIPT ERROR' not in txt,filename
 group=json.loads((W/'group-timing.json').read_text());assert len(group['rows'])==6
 assert all(r['actors']==55 and r['visible']==16 and r['samples']==240 for r in group['rows'])
 candidate=json.loads((W/'performance/manifest.json').read_text())
 baseline=json.loads((OUT.parent/'encounter-polish-2026-10-07/performance-candidate.json').read_text())
 assert candidate['opening_seed']==baseline['opening_seed']==20261004
 assert candidate['population_target']==baseline['population_target']==250
 assert candidate['resolution']==baseline['resolution']==[1920,1080] and candidate['gpu']==baseline['gpu']
 assert candidate['implementation']=='86a5a82-worker-detail' and len(candidate['samples'])==12
 rows=[]
 for case in dict.fromkeys(r['case'] for r in candidate['samples']):
  row={'case':case}
  for label,run in [('previous',baseline),('current',candidate)]:
   values=[r for r in run['samples'] if r['case']==case];assert len(values)==3
   row[label]={'median_ms':statistics.median(v['median_ms'] for v in values),'p95_range_ms':[min(v['p95_ms'] for v in values),max(v['p95_ms'] for v in values)],'warm_hitches_over_33ms':sum(v['hitches_over_33ms'] for v in values),'active_peaks':[v['active_infected_max'] for v in values],'entry_max_ms':[v['entry_max_ms'] for v in values]}
  row['active_peaks_equal']=row['previous']['active_peaks']==row['current']['active_peaks'];rows.append(row)
 comparison={'previous_runtime':'0f13238 (same game runtime as d853ea8 documentation HEAD)','current_runtime':'86a5a82','rows':rows,'limitations':'Same verified seed/target/renderer/resolution, three 12-second moving repeats per case. Host load is uncontrolled; active peaks are retained because AI is not fixed-step replay. Local frame intervals do not attribute GPU work or establish minimum-spec performance.'}
 (OUT/'moving-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
 for src,dst in [(W/'group-timing.json','group-timing.json'),(W/'performance/manifest.json','moving-timing.json'),(R/'brave-and-cold/assets/infected/detail/validation.json','asset-validation.json')]:shutil.copyfile(src,OUT/dst)
 for name in ['rest','face']:
  images=[Image.open(W/(variant+'-headlamp-'+name+'.png')).convert('RGB') for variant in ['before','after']]
  sheet=Image.new('RGB',(1400,476),'#15202a');draw=ImageDraw.Draw(sheet)
  for i,im in enumerate(images):
   sheet.paste(im.resize((700,450)),(i*700,26));draw.text((i*700+15,8),'Before' if i==0 else 'Current',fill='white')
  sheet.save(OUT/('comparison-'+name+'.png'))
 for src,dst in [(W/'world/clinic-worker.png','clinic-worker.png'),(W/'world/clinic-settled.png','clinic-settled.png'),(W/'interactions/hammer_gloved_17.png','hammer-impact.png')]:shutil.copyfile(src,OUT/dst)
 frames=[Image.open(p).convert('RGB').resize((800,600)).convert('P',palette=Image.Palette.ADAPTIVE,colors=192) for p in sorted((W/'motion').glob('*.png'))]
 assert len(frames)==48
 frames[0].save(OUT/'walking-comparison.gif',save_all=True,append_images=frames[1:],duration=42,loop=0,optimize=False)
 captures={p.name:digest(p) for p in OUT.glob('*') if p.suffix in ['.png','.gif']}
 manifest=json.loads((R/'brave-and-cold/assets/infected/detail/manifest.json').read_text())
 (OUT/'receipt.json').write_text(json.dumps({'runtime':'86a5a82','native_sha256':manifest['native_sha256'],'near_glb_sha256':manifest['glb_sha256'],'proxy_glb_sha256':manifest['proxy_sha256'],'captures':captures,'tests':tests,'scope':'Original local Blender assets, actual-byte validation and Godot GPU captures. No human play acceptance, canonical package or sealed renderer telemetry claimed.'},indent=2)+'\n')
 print('WORKER_REVIEW_COMPLETE',json.dumps(tests))
 print('MOVING_COMPARISON',json.dumps(rows))
if __name__=='__main__':main()
