"""Reopen every delivered .blend: scenes, packed textures, sockets and dimensions."""
from pathlib import Path
import bpy,json
from mathutils import Vector
OUT=Path(__file__).parent/'generated/field_survival_kit_v1'
meta=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
results={}
for name,r in meta['assets'].items():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/r['native']))
    root=bpy.context.scene.objects.get(name);assert root is not None,name
    assert bpy.context.scene.unit_settings.scale_length==1 and bpy.context.scene.unit_settings.system=='METRIC'
    meshes=[o for o in root.children_recursive if o.type=='MESH'];assert len(meshes)==r['mesh_nodes']
    names={o.name for o in root.children_recursive};assert all(s in names for s in r['pivots'])
    bpy.context.view_layer.update();p=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    size=[max(v[i] for v in p)-min(v[i] for v in p) for i in [0,2,1]]
    assert max(abs(a-b) for a,b in zip(size,r['measured_size_m']))<.0005,(name,size)
    count=0
    for o in meshes:
        for m in o.data.materials:
            for n in m.node_tree.nodes:
                if n.type=='TEX_IMAGE':assert n.image.packed_file is not None,(name,n.image.name);count+=1
    results[name]={'opening_ready_scene':True,'metres':True,'packed_texture_nodes':count,'pivots':len(r['pivots'])}
    print('NATIVE_VERIFIED',name,flush=True)
(OUT/'native_validation.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print('FIELD_KIT_NATIVE_PASS',len(results),flush=True)
