"""Copy weapon kit v3 GLBs (rifles, optics, lights) into the game and record hashes.
Run after: blender --background --factory-startup --python tools/blender/gen_weapon_kit_v3.py
  tools/terrain/.venv/Scripts/python.exe tools/blender/vendor_weapon_kit_v3.py"""
from pathlib import Path
import json, hashlib, shutil
ROOT = Path(__file__).resolve().parents[2]; GAME = ROOT / 'brave-and-cold'
SRC = ROOT / 'tools/blender/generated/weapon_kit_v3'
DEST = GAME / 'assets/weapons/v3'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
catalog = json.loads((SRC / 'manifest.json').read_text())
receipt = {'workflow': 'Local Blender 5.2 weapon kit v3 (tools/blender/gen_weapon_kit_v3.py); exact byte copy', 'files': {}}
for name, asset in catalog['assets'].items():
    src = SRC / asset['glb']; assert sha(src) == asset['glb_sha256'], name
    sub = {'rifle': 'rifles', 'optic': 'optics', 'light': 'lights', 'muzzle': 'muzzle'}[asset['kind']]
    (DEST / sub).mkdir(parents=True, exist_ok=True)
    dest = DEST / sub / src.name; shutil.copy2(src, dest); assert sha(dest) == sha(src)
    receipt['files'][dest.relative_to(GAME).as_posix()] = {'sha256': sha(dest), 'kind': asset['kind'], 'triangles': asset['triangles'],
                                                            'provenance': 'Original project Blender geometry and generated textures'}
(DEST / 'admission.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8', newline='\n')
print('W3_VENDOR_PASS', len(catalog['assets']))
