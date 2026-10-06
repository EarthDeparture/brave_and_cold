"""Make each editable weapon collection an opening-ready packed Blender scene."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector,Euler
OUT=Path(__file__).parent/'generated/north_ridge_weapon_kit_v1'
meta=json.loads((OUT/'manifest.json').read_text())
def add_preview_script(objects):
    for o in objects:o['authoring_rest_matrix']=[v for row in o.matrix_basis for v in row]
    text=bpy.data.texts.get('Preview_Clips.py') or bpy.data.texts.new('Preview_Clips.py')
    text.clear();text.write(Path(__file__).with_name('preview_weapon_kit_clip.py').read_text())
for name,r in meta['assets'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=OUT/r['native']
    with bpy.data.libraries.load(str(path),link=False) as (available,loaded):loaded.collections=[name+'_Editable']
    coll=loaded.collections[0];bpy.context.scene.collection.children.link(coll)
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1;scene.render.fps=30
    scene.frame_set(0)
    root=bpy.data.objects[name];root.select_set(True);bpy.context.view_layer.objects.active=root
    add_preview_script([root]+list(root.children_recursive))
    scene.frame_end=90
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                view=area.spaces.active.region_3d
                lo,hi=r['bounds_min'],r['bounds_max'];view.view_location=Vector(((lo[0]+hi[0])/2,-(lo[2]+hi[2])/2,(lo[1]+hi[1])/2))
                view.view_distance=max(r['dimensions_m'])*1.8;view.view_rotation=Euler((1.2,0,1.5)).to_quaternion();area.spaces.active.shading.type='MATERIAL'
    ready=path.with_name(name+'_ready.blend');bpy.ops.wm.save_as_mainfile(filepath=str(ready),compress=True);ready.replace(path)
    r['native_sha256']=hashlib.sha256(path.read_bytes()).hexdigest();print('WEAPON_SOURCE_READY',name,flush=True)
master=OUT/'north_ridge_weapon_library.blend';bpy.ops.wm.open_mainfile(filepath=str(master));add_preview_script(list(bpy.context.scene.objects))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            view=area.spaces.active.region_3d;view.view_location=Vector((.9,-2.7,0));view.view_distance=6.5;view.view_rotation=Euler((.25,0,0)).to_quaternion();area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(master),compress=True)
meta['source_finalizer_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
