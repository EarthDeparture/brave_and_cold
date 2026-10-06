"""Reopen each normal .blend scene and exercise its original rigid NLA rig."""
from pathlib import Path
import bpy,json,sys
sys.path.insert(0,str(Path(__file__).parent))
from preview_weapon_kit_clip import preview_clip
OUT=Path(__file__).parent/'generated/north_ridge_weapon_kit_v1'
meta=json.loads((OUT/'manifest.json').read_text());results={}
for name,r in meta['assets'].items():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/r['native']));scene=bpy.context.scene
    root=scene.objects.get(name);assert root is not None and root.parent is None
    assert scene.unit_settings.system=='METRIC' and scene.unit_settings.scale_length==1 and scene.render.fps==30
    meshes=[o for o in root.children_recursive if o.type=='MESH'];assert len(meshes)==r['mesh_nodes']
    names={o.name for o in root.children_recursive};assert set(r['nodes'])<=names
    scene.frame_set(0);bpy.context.view_layer.update();p=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    size=[max(v[i] for v in p)-min(v[i] for v in p) for i in (0,2,1)]
    assert max(abs(a-b) for a,b in zip(size,r['dimensions_m']))<.0005,(name,size,r['dimensions_m'])
    texture_count=0
    for o in meshes:
        for mat in o.data.materials:
            for n in mat.node_tree.nodes:
                if n.type=='TEX_IMAGE':assert n.image.packed_file is not None;(texture_count:=texture_count+1)
    objects=[root]+list(root.children_recursive);rest={o:o.matrix_basis.copy() for o in objects};verified={}
    for clip,contract in r['animations'].items():
        preview_clip(name,clip)
        tracks=[]
        for o in objects:
            if o.animation_data:
                for t in o.animation_data.nla_tracks:tracks.extend([t.name] if t.name==clip else [])
        assert len(tracks)==len(contract['animated_nodes']),(name,clip,tracks)
        scene.frame_set(0);before={o:o.matrix_world.copy() for o in objects};changed=False
        for fraction in (.2,.45,.7,1):
            scene.frame_set(round(contract['duration_s']*30*fraction));bpy.context.view_layer.update()
            changed|=any(sum(abs(a-b) for rowa,rowb in zip(before[o],o.matrix_world) for a,b in zip(rowa,rowb))>.00001 for o in objects)
        assert changed,(name,clip,'no actual native movement')
        verified[clip]={'rig_moves':True,'matched_tracks':len(tracks)}
        for o in objects:
            if o.animation_data:
                o.animation_data.action=None;o.animation_data.use_nla=True
                for t in o.animation_data.nla_tracks:t.mute=True
            o.matrix_basis=rest[o]
    results[name]={'opening_ready':True,'metres':True,'packed_textures':texture_count,'nodes':len(r['nodes']),'animations':verified}
    print('WEAPON_NATIVE_VERIFIED',name,flush=True)
(OUT/'native_validation.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8',newline='\n')
print('WEAPON_NATIVE_PASS',len(results),flush=True)
