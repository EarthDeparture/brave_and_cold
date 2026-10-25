"""Reopen the release source and exercise the exact embedded preview helper."""
from pathlib import Path
import bpy,json,hashlib,numpy as np
OUT=Path(__file__).parent/'generated/anatomical_hands_v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'anatomical_hands.blend'))
meta=json.loads((OUT/'manifest.json').read_text())
assert hashlib.sha256((OUT/'anatomical_hands.blend').read_bytes()).hexdigest()==meta['native_sha256']
helpers={'__name__':'preview_validation'}
exec(bpy.data.texts['Preview_Hand_Poses.py'].as_string(),helpers)
assert all(image.packed_file for image in bpy.data.images if image.name.startswith('skin_'))
for name in ['EditableQuadCage_Right','EditableQuadCage_Left']:
    cage=bpy.data.objects[name];assert len(cage.data.vertices)==943 and cage.hide_render
clips={}
for clip in meta['clips']:
    helpers['play_clip'](clip)
    frames=[0,18,40,56,78] if clip=='FlexCycle' else [0,30]
    frames_report=[]
    for frame in frames:
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        values={}
        for skin_name in ['BareHand','BareHandLeft']:
            skin=bpy.data.objects[skin_name]
            weights=[key.value for key in skin.data.shape_keys.key_blocks if key.name!='Basis']
            expected=0 if clip=='Open' or (clip=='FlexCycle' and frame in [0,78]) else 1
            assert abs(max(weights)-expected)<1e-5,(clip,frame,skin_name,weights)
            values[skin_name]=[float(v) for v in weights]
        frames_report.append({'frame':frame,'corrective_weights':values})
    clips[clip]={'preview_helper_passed':True,'frames':frames_report}
result={'native_sha256':meta['native_sha256'],'blender':bpy.app.version_string,'packed_maps':3,'editable_cages':2,'clips':clips,'source_reopened':True}
(OUT/'native_validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print('ANATOMICAL_NATIVE_HELPER_PASS',len(clips))
