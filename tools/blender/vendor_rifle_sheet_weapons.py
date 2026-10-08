"""Copy the rifle-sheet v2 weapon GLBs into the game and record their hashes.
Run after: blender --background --python tools/blender/gen_rifle_sheet_weapons.py"""
from pathlib import Path
import json, hashlib, shutil
ROOT = Path(__file__).resolve().parents[2]; GAME = ROOT / 'brave-and-cold'
SRC = ROOT / 'tools/blender/generated/rifle_sheet_kit_v2'
DEST = GAME / 'assets/weapons/north_ridge'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
catalog = json.loads((SRC / 'manifest.json').read_text())
receipt = {'workflow': 'Local Blender 5.2 rifle sheet kit v2 (Troy reference sheet 2026-10-08); exact byte copy', 'files': {}}
for name, asset in catalog['assets'].items():
    src = SRC / asset['glb']; assert sha(src) == asset['glb_sha256'], name
    dest = DEST / src.name; shutil.copy2(src, dest); assert sha(dest) == sha(src)
    receipt['files'][dest.relative_to(GAME).as_posix()] = {'sha256': sha(dest), 'source': src.relative_to(ROOT).as_posix(), 'provenance': 'Original project Blender geometry/painted textures'}
old = json.loads((DEST / 'admission.json').read_text()) if (DEST / 'admission.json').exists() else {'files': {}}
for k, v in old.get('files', {}).items():
    if 'north_ridge' not in k: receipt['files'].setdefault(k, v)   # keep the hand rig record
(DEST / 'admission.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8', newline='\n')
print('RIFLE_SHEET_VENDOR_PASS', len(catalog['assets']))
