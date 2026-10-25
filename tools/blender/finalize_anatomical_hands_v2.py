"""Make the native source easy to inspect, preserving the exported rest pose."""
from pathlib import Path
import bpy,json,hashlib,math
from mathutils import Quaternion,Vector
ROOT=Path(__file__).parent
OUT=ROOT/'generated/anatomical_hands_v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'anatomical_hands.blend'))
text=bpy.data.texts.get('Preview_Hand_Poses.py') or bpy.data.texts.new('Preview_Hand_Poses.py')
text.clear();text.write((ROOT/'preview_anatomical_hands_v2.py').read_text())
notes=bpy.data.texts.get('START_HERE.txt') or bpy.data.texts.new('START_HERE.txt')
notes.clear();notes.write('ANATOMICAL HANDS v2\nMetres. Both wrist-local rigs export at origin; source rigs are separated for inspection.\nSkin, curved nails, original editable quad cages, UVs and packed PBR maps.\nSelect a rig and enter Pose Mode to inspect finger bones.\nTo play bone and corrective animation together, open Preview_Hand_Poses.py, set CLIP, Run Script, then play the timeline.\nThe nine static clips and FlexCycle use matching bone + shape-key actions.\nControl cages are hidden, separately editable base topology, not live drivers of the baked skin.\nThis candidate has not replaced live gameplay hands or been fitted to weapons.\n')
for name in ['EditableQuadCage_Right','EditableQuadCage_Left']:
    cage=bpy.data.objects.get(name)
    if cage:cage.hide_set(True);cage.hide_render=True
bpy.ops.object.select_all(action='DESELECT')
skin=bpy.data.objects['BareHand'];skin.select_set(True);bpy.context.view_layer.objects.active=skin
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_location=Vector((0,.045,0))
            area.spaces.active.region_3d.view_distance=.53
            area.spaces.active.region_3d.view_rotation=Quaternion((1,0,0,0))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'anatomical_hands.blend'))
meta=json.loads((OUT/'manifest.json').read_text());meta['native_sha256']=hashlib.sha256((OUT/'anatomical_hands.blend').read_bytes()).hexdigest()
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
print('ANATOMICAL_SOURCE_READY')
