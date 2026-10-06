from pathlib import Path
import bpy,json,sys,numpy as np
from mathutils.bvhtree import BVHTree
TOOLS=Path(__file__).parent;sys.path.insert(0,str(TOOLS))
builder=(TOOLS/'gen_anatomical_hands_v2.py').read_text();exec(builder[:builder.index('\nbpy.ops.wm.read_factory_settings(use_empty=True)')])
fit=json.loads((TOOLS/'anatomical_tool_fit.json').read_text());POSES['ToolGrip']={'fingers':[15,75,50],'thumb':[17,40,28],'opp':-20,**fit['ToolGrip']}
bpy.ops.wm.open_mainfile(filepath=str(TOOLS/'generated/live_hand_rig_v2/anatomical_hand_rig.blend'))
skin=bpy.data.objects['BareHand'];rig=bpy.data.objects['HandRig'];skin.data.shape_keys.animation_data_clear()
for key in skin.data.shape_keys.key_blocks:key.value=0
skin.modifiers[0].use_deform_preserve_volume=True
distal=[]
for v in skin.data.vertices:
    group=max(v.groups,key=lambda g:g.weight);distal.append(skin.vertex_groups[group.group].name=='thumb_03')
for angles in [[17,40,28],[9,23,29],[17,23,15],[0,20,10],[30,30,20],[17,50,35]]:
 for opp in [-20,-24,-28,-32]:
    POSES['ToolGrip'].update(thumb=angles,opp=opp);choose_pose(rig,'ToolGrip',1)
    ev=skin.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
    pts=np.array([(v.co.x,v.co.z,-v.co.y) for v in mesh.vertices]);tri=np.array([tuple(t.vertices) for t in mesh.loop_triangles])
    bvh=BVHTree.FromPolygons(pts.tolist(),tri.tolist(),all_triangles=True)
    pairs=[(i,j) for i,j in bvh.overlap(bvh) if i<j and not set(tri[i])&set(tri[j])]
    p=(np.array([.106,.006,-.032])+np.stack([pts[:,2],-pts[:,0],-pts[:,1]],axis=1))/1.2
    d=((abs(p[:,0]/.0122)**2.4+abs((p[:,2]-.002)/.0168)**2.4)**(1/2.4)-1)*.0122*1.2
    print('THUMB_CANDIDATE',angles,opp,'self',len(pairs),'tip_gap',float(np.min(abs(d[np.array(distal)]))),'depth',float(max(0,-d.min())),flush=True);ev.to_mesh_clear()
