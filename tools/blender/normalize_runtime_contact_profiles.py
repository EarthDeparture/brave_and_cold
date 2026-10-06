"""Convert the initial measured weapon-space calibration into moving socket space."""
from pathlib import Path
import json,numpy as np
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'brave-and-cold/assets/weapons/north_ridge/contact_profiles.json'
profiles=json.loads(path.read_text());assert '_space' not in profiles,'Already converted'
rows=json.loads((ROOT/'brave-and-cold/shots/anatomical-weapons/contact_geometry.json').read_text())
z=np.array([.55,0,.835]);z/=np.linalg.norm(z);x=np.array([0,1,0]);bolt_basis=np.stack([x,np.cross(z,x),z],axis=1)
mag_basis=np.array([[0,-1,0],[0,0,1],[-1,0,0]])
for weapon,profile in profiles.items():
 if weapon=='tool':continue
 for key,grip in [('magazine_left',mag_basis),('bolt_right',bolt_basis)]:
    if key not in profile:continue
    state,side=key.split('_');hand_basis=np.array(rows[weapon+'/'+state][side]['basis']).T
    socket_basis=hand_basis@grip.T;profile[key]=np.linalg.solve(socket_basis,np.array(profile[key])).tolist()
profiles['_space']='moving socket local metres; calibrated against real skinned vertices and closed prop components'
path.write_text(json.dumps(profiles,indent=2)+'\n',encoding='utf-8',newline='\n');print('CONTACT_SOCKET_SPACE_PASS')
