"""Derive the live bare/glove rig without modifying the approved bare source."""
from pathlib import Path
import bpy,json,hashlib,sys
from types import SimpleNamespace
from mathutils import Vector
ROOT=Path(__file__).parent;sys.path.insert(0,str(ROOT))
builder=(ROOT/'gen_anatomical_hands_v2.py').read_text()
exec(builder[:builder.index('\nbpy.ops.wm.read_factory_settings(use_empty=True)')])
ROOT=Path(__file__).parent
SOURCE=ROOT/'generated/anatomical_hands_v2'
OUT=ROOT/'generated/live_hand_rig_v2';OUT.mkdir(exist_ok=True)
fit=json.loads((ROOT/'anatomical_tool_fit.json').read_text())
for grip,values in fit.items():POSES[grip]={'fingers':[15,75,50],'thumb':[17,40,28],'opp':-20,**values}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'anatomical_hands.blend'))
# New tool grip is distinct from the generic round-container shaft grip.
for rig_name,side in [('HandRig',1),('LeftHandRig',-1)]:
    rig=bpy.data.objects[rig_name];rig.animation_data_clear();add_actions(rig,side)
for skin_name,rig_name,side in [('BareHand','HandRig',1),('BareHandLeft','LeftHandRig',-1)]:
    skin=bpy.data.objects[skin_name];skin.shape_key_clear();correctives(skin,bpy.data.objects[rig_name],side);morph_actions(skin)
gloves=[]
for skin_name,rig_name,name,side in [('BareHand','HandRig','LeatherGlove',1),('BareHandLeft','LeftHandRig','LeatherGloveLeft',-1)]:
    rig=bpy.data.objects[rig_name];rig.location=(0,0,0);choose_pose(rig,'Open',side)
    bare=bpy.data.objects[skin_name]
    for key in bare.data.shape_keys.key_blocks:key.value=0
    glove=bare.copy();glove.data=bare.data.copy();glove.name=name;bpy.context.collection.objects.link(glove);glove.shape_key_clear()
    # A thin fitted work glove. A uniform allowance preserves the original
    # connected crease topology; normal extrusion folds its narrow webs inward.
    for vertex in glove.data.vertices:vertex.co*=1.006
    glove.data.update();glove.data.materials.clear()
    glove.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER')
    # Both native rigs carry outward normals and explicit mirrored vertices.
    paths=[]
    for digit in ['index','middle','ring','little','thumb']:
        bones=[rig.data.bones[digit+'_'+str(i).zfill(2)] for i in [1,2,3]]
        points=[bones[0].head_local,bones[1].head_local,bones[2].head_local,bones[2].tail_local]
        paths.append(([Vector((p.x,p.z,-p.y)) for p in points],.009))
    import hand_materials as leather
    leather.PALM['rig_hand']=(0,-1,0)
    if side==1:
        leather.paint_atlas([glove],[SimpleNamespace(name='rig_hand',wrist=(0,0,0),digits=paths)],OUT,'leather')
    else:
        # Mirror the right atlas by copying UVs in vertex/loop order from the mirrored native topology.
        # Both skin sides already share anatomical UV correspondence; use the same regional map.
        right=gloves[0]
        for uv in glove.data.uv_layers:glove.data.uv_layers.remove(uv)
        uv=glove.data.uv_layers.new(name='UVMap')
        # Match corners by vertex index because left faces have reversed winding.
        for face,other in zip(glove.data.polygons,right.data.polygons):
            corners={right.data.loops[i].vertex_index:right.data.uv_layers.active.data[i].uv.copy() for i in other.loop_indices}
            for i in face.loop_indices:uv.data[i].uv=corners[glove.data.loops[i].vertex_index]
        glove.data.materials.append(right.data.materials[0])
    correctives(glove,rig,side);morph_actions(glove);gloves.append(glove)
for rig_name,side in [('HandRig',1),('LeftHandRig',-1)]:
    rig=bpy.data.objects[rig_name];choose_pose(rig,'Open',side);rig.animation_data.use_nla=True
bpy.ops.object.select_all(action='DESELECT')
visible=[bpy.data.objects[n] for n in ['HandRig','LeftHandRig','BareHand','BareHandLeft','NailsRight','NailsLeft']]+gloves
for obj in visible:obj.select_set(True)
rest={obj:obj.matrix_basis.copy() for obj in visible}
glb=OUT/'anatomical_hand_rig.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_skins=True,export_def_bones=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_morph=True)
from export_hand_morph_tracks_v2 import bake_morph_tracks
bake_morph_tracks(glb)
for obj,matrix in rest.items():obj.matrix_basis=matrix
for rig_name,side in [('HandRig',1),('LeftHandRig',-1)]:choose_pose(bpy.data.objects[rig_name],'Open',side)
for obj in [bpy.data.objects['BareHand'],bpy.data.objects['BareHandLeft']]+gloves:
    obj.data.shape_keys.animation_data.action=None;obj.data.shape_keys.animation_data.use_nla=False
    for track in obj.data.shape_keys.animation_data.nla_tracks:track.mute=True
    for key in obj.data.shape_keys.key_blocks:key.value=0
notes=bpy.data.texts.get('LIVE_RIG_README') or bpy.data.texts.new('LIVE_RIG_README')
notes.clear();notes.write('Live North Ridge hands / metres / wrist origin zero / fingers -Z in Godot.\n17 joints per side; editable quad cages retained.\nBare skin, rigid nails, thin leather gloves with original baked seam atlas.\nGrip clips: '+', '.join(POSES)+'\nFlexCycle is an anatomy preview. Native helper poses must also apply matching volume correctives.\nRuntime wrist offsets live in assets/weapons/north_ridge/contact_profiles.json.\nOriginal approved bare source remains separate and unmodified.\n')
for image in bpy.data.images:
    if image.source=='FILE' and image.packed_file is None:image.pack()
for obj in [*gloves,bpy.data.objects['BareHandLeft'],bpy.data.objects['NailsLeft'],bpy.data.objects['LeftHandRig']]:obj.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'anatomical_hand_rig.blend'),compress=True)
meta={'source_sha256':hashlib.sha256((SOURCE/'anatomical_hands.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256((OUT/'anatomical_hand_rig.blend').read_bytes()).hexdigest(),'original':True,'bones_per_hand':17,'glove_fit_scale':1.006,'grips':list(POSES),'notes':'Original approved anatomy with thin fitted leather surfaces and baked seam materials; nails hide when gloves are worn.'}
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
print('LIVE_ANATOMICAL_RIG_PASS')
