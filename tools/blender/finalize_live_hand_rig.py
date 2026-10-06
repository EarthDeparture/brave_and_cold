"""Pack the editor source; exported GLB and gameplay bytes remain unchanged."""
from pathlib import Path
import bpy,json,hashlib
OUT=Path(__file__).parent/'generated/live_hand_rig_v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'anatomical_hand_rig.blend'))
for image in bpy.data.images:
    if image.source=='FILE' and image.packed_file is None:image.pack()
for name in ['LeatherGlove','LeatherGloveLeft','BareHandLeft','NailsLeft','LeftHandRig']:bpy.data.objects[name].hide_set(True)
text=bpy.data.texts['LIVE_RIG_README'];text.write('\nEditor opens on bare right anatomy. Left hand and glove shells are hidden for editing; toggle object visibility to select a variant. Packed textures make this file self-contained.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'anatomical_hand_rig.blend'),compress=True)
meta=json.loads((OUT/'manifest.json').read_text());meta['native_sha256']=hashlib.sha256((OUT/'anatomical_hand_rig.blend').read_bytes()).hexdigest();meta['packed_textures']=True
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n');print('LIVE_NATIVE_PACK_PASS')
