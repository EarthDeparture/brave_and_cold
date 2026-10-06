"""Reopen native hands and measure pose geometry and non-neighbour intersections."""
from pathlib import Path
import bpy,bmesh,json,sys,hashlib,numpy as np
from mathutils.bvhtree import BVHTree
builder=Path(__file__).with_name('gen_anatomical_hands_v2.py').read_text()
exec(builder[:builder.index('\nbpy.ops.wm.read_factory_settings(use_empty=True)')])
bpy.ops.wm.open_mainfile(filepath=str(OUT/'anatomical_hands.blend'))
results={}
for skin_name,rig_name,side in [('BareHand','HandRig',1),('BareHandLeft','LeftHandRig',-1)]:
    skin=bpy.data.objects[skin_name];rig=bpy.data.objects[rig_name];rig.location=(0,0,0)
    results[skin_name]={}
    for pose in POSES:
        choose_pose(rig,pose,side)
        for key in skin.data.shape_keys.key_blocks:key.value=float(key.name=='corrective_'+pose)
        bpy.context.view_layer.update();evaluated=skin.evaluated_get(bpy.context.evaluated_depsgraph_get());me=evaluated.to_mesh();me.calc_loop_triangles()
        p=np.array([tuple(v.co) for v in me.vertices]);tri=np.array([tuple(t.vertices) for t in me.loop_triangles]);a,b,c=p[tri[:,0]],p[tri[:,1]],p[tri[:,2]]
        area=np.linalg.norm(np.cross(b-a,c-a),axis=1)*.5;volume=float(np.sum(np.einsum('ij,ij->i',a,np.cross(b,c)))/6)
        tree=BVHTree.FromPolygons([tuple(v) for v in p],[tuple(t) for t in tri],all_triangles=True,epsilon=0)
        intersections=[(i,j) for i,j in tree.overlap(tree) if i<j and not set(tri[i])&set(tri[j])]
        groups={}
        for i,j in intersections:
            ids=set(tri[i])|set(tri[j]);bones=set()
            for k in ids:
                v=skin.data.vertices[k];g=max(v.groups,key=lambda g:g.weight);bones.add(skin.vertex_groups[g.group].name.split('_')[0])
            key='/'.join(sorted(bones));groups[key]=groups.get(key,0)+1
        results[skin_name][pose]={'non_neighbour_triangle_intersections':len(intersections),'intersection_regions':groups,'volume_m3':volume,'minimum_area_m2':float(area.min()),'dimensions_blender_m':(p.max(0)-p.min(0)).tolist()}
        assert np.isfinite(p).all() and volume>0 and area.min()>1e-12,(skin_name,pose,'bad deformed surface')
        evaluated.to_mesh_clear();print('ANATOMY_POSE_AUDIT',skin_name,pose,len(intersections),groups,flush=True)
        assert len(intersections)==0,(skin_name,pose,'non-neighbour surface intersection')
    animation=next(t.strips[0] for t in rig.animation_data.nla_tracks if t.name=='FlexCycle')
    rig.animation_data.use_nla=False;rig.animation_data.action=animation.action;rig.animation_data.action_slot=animation.action_slot
    keys=skin.data.shape_keys;strip=next(t.strips[0] for t in keys.animation_data.nla_tracks if t.name=='FlexCycle')
    keys.animation_data.use_nla=False;keys.animation_data.action=strip.action;keys.animation_data.action_slot=strip.action_slot
    flex=[]
    for frame in range(0,79,2):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();evaluated=skin.evaluated_get(bpy.context.evaluated_depsgraph_get());me=evaluated.to_mesh();me.calc_loop_triangles()
        p=[tuple(v.co) for v in me.vertices];tri=[tuple(t.vertices) for t in me.loop_triangles];tree=BVHTree.FromPolygons(p,tri,all_triangles=True)
        pairs=[(i,j) for i,j in tree.overlap(tree) if i<j and not set(tri[i])&set(tri[j])]
        flex.append({'frame':frame,'non_neighbour_triangle_intersections':len(pairs)})
        evaluated.to_mesh_clear()
    assert max(v['non_neighbour_triangle_intersections'] for v in flex)==0,(skin_name,'FlexCycle',flex)
    results[skin_name]['FlexCycle']={'sampled_frames':flex,'passed':True}
print('ANATOMY_NATIVE_POSE_PASS',flush=True)
results['source_sha256']=hashlib.sha256((OUT/'anatomical_hands.blend').read_bytes()).hexdigest()
(OUT/'pose_audit.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8',newline='\n')
