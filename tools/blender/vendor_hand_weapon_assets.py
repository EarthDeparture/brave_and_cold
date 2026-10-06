"""Verify original local source rosters and copy only approved runtime GLBs."""
from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'tools/blender/generated';GAME=ROOT/'brave-and-cold'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for folder in ['anatomical_hands_v2','north_ridge_weapon_kit_v1']:
    source=BASE/folder;record=json.loads((source/'package_hashes.json').read_text());record=record.get('files',record)
    for path,digest in record.items():assert sha(source/path)==digest,(folder,path,'source roster mismatch')
receipt={'workflow':'Local offline original Blender assets; exact source-byte verification, not a game-dev CLI admission','files':{}}
previous_path=GAME/'assets/weapons/north_ridge/admission.json'
previous=json.loads(previous_path.read_text()) if previous_path.exists() else {'files':{}}
hand=BASE/'live_hand_rig_v2';meta=json.loads((hand/'manifest.json').read_text());assert sha(hand/'anatomical_hand_rig.glb')==meta['glb_sha256']
items=[(hand/'anatomical_hand_rig.glb',GAME/'assets/models/viewmodel/anatomical_hand_rig.glb')]
weapons=BASE/'north_ridge_weapon_kit_v1';catalog=json.loads((weapons/'manifest.json').read_text())
for name,asset in catalog['assets'].items():
    if asset['kind']!='weapon':continue
    src=weapons/asset['glb'];assert sha(src)==asset['glb_sha256'];items.append((src,GAME/'assets/weapons/north_ridge'/src.name))
for src,dest in items:
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists() and sha(dest)!=sha(src):
        prior=previous['files'].get(dest.relative_to(GAME).as_posix(),{})
        assert sha(dest)==prior.get('sha256'),'Refuse unrecorded/externally changed asset: '+str(dest)
    shutil.copy2(src,dest);assert sha(dest)==sha(src)
    receipt['files'][dest.relative_to(GAME).as_posix()]={'sha256':sha(dest),'source':src.relative_to(ROOT).as_posix(),'provenance':'Original project Blender geometry/textures'}
out=GAME/'assets/weapons/north_ridge/admission.json';out.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
print('HAND_WEAPON_VENDOR_PASS',len(items))
