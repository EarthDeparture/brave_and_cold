"""Turn collection libraries into normal opening-ready Blender scenes."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector, Euler
OUT=Path(__file__).parent/'generated/field_survival_kit_v1'
data=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
for name,record in data['assets'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=OUT/record['native']
    with bpy.data.libraries.load(str(path),link=False) as (available,loaded):
        loaded.collections=[name+'_Editable']
    coll=loaded.collections[0];bpy.context.scene.collection.children.link(coll)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    root=next(o for o in coll.objects if o.name==name)
    bpy.context.view_layer.objects.active=root
    for o in coll.objects:o.select_set(False)
    root.select_set(True)
    dims=record['measured_size_m']
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                view=area.spaces.active.region_3d
                view.view_location=Vector((0,0,dims[1]*.5));view.view_distance=max(dims)*2.4
                view.view_rotation=Euler((1.08,0,.57)).to_quaternion()
                area.spaces.active.shading.type='MATERIAL'
    ready=path.with_name(name+'_ready.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(ready),compress=True)
    ready.replace(path)
    record['native_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    print('SOURCE_READY',name,flush=True)
data['source_finalizer_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
(OUT/'manifest.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
