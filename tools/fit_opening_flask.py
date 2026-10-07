"""Bounded actual-hand contact search. Diagnose only; no runtime edits."""
from pathlib import Path
import numpy as np,json
R=Path(__file__).resolve().parents[1];O=R/'brave-and-cold/shots/opening-quality'
data=json.loads((O/'flask_vertices.json').read_text());best=None
for release,row in data.items():
 points=[np.array(row[name]) for name in ['bare','gloved']]
 for dx in np.arange(-.020,.0201,.002):
  for dz in np.arange(-.020,.0201,.002):
   overlap=0;contacts=[]
   for p in points:
    q=p[(p[:,1]>.03)&(p[:,1]<.175)]
    d=np.linalg.norm(q[:,[0,2]]-np.array([dx,dz]),axis=1)-.042
    overlap=max(overlap,float(max(0,-d.min())));contacts.append(int(np.sum(np.abs(d)<.004)))
   if overlap>.0035 or min(contacts)<100:continue
   score=np.linalg.norm([dx,dz])+float(release)*.025
   if best is None or score<best['score']:best={'release':float(release),'bottle_local_translation_m':[float(dx),0,float(dz)],'overlap_m':overlap,'contact_vertices':contacts,'score':float(score)}
assert best is not None,'No valid fit in the declared 20mm / 36% release bounds'
(O/'flask_fit.json').write_text(json.dumps(best,indent=2)+'\n');print(json.dumps(best))
