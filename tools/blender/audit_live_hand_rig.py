"""Check every native skin/glove pose, plus export weights and bind matrices."""
from pathlib import Path
import bpy,json,sys,hashlib,numpy as np
from mathutils.bvhtree import BVHTree
TOOLS=Path(__file__).parent;sys.path.insert(0,str(TOOLS))
builder=(TOOLS/'gen_anatomical_hands_v2.py').read_text();exec(builder[:builder.index('\nbpy.ops.wm.read_factory_settings(use_empty=True)')])
OUT=TOOLS/'generated/live_hand_rig_v2'
fit=json.loads((TOOLS/'anatomical_tool_fit.json').read_text())
for grip,values in fit.items():POSES[grip]={'fingers':[15,75,50],'thumb':[17,40,28],'opp':-20,**values}
bpy.ops.wm.open_mainfile(filepath=str(OUT/'anatomical_hand_rig.blend'))
report={}
for name,rig_name,side in [('BareHand','HandRig',1),('BareHandLeft','LeftHandRig',-1),('LeatherGlove','HandRig',1),('LeatherGloveLeft','LeftHandRig',-1)]:
    skin=bpy.data.objects[name];rig=bpy.data.objects[rig_name];report[name]={}
    for pose in POSES:
        choose_pose(rig,pose,side)
        for key in skin.data.shape_keys.key_blocks:key.value=float(key.name=='corrective_'+pose)
        bpy.context.view_layer.update();eval=skin.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=eval.to_mesh();mesh.calc_loop_triangles()
        points=np.array([tuple(v.co) for v in mesh.vertices]);tri=np.array([tuple(t.vertices) for t in mesh.loop_triangles])
        tree=BVHTree.FromPolygons(points.tolist(),tri.tolist(),all_triangles=True)
        pairs=[(i,j) for i,j in tree.overlap(tree) if i<j and not set(tri[i])&set(tri[j])]
        regions={}
        for i,j in pairs:
            group=[]
            for vertex in set(tri[i])|set(tri[j]):
                weights=skin.data.vertices[vertex].groups;big=max(weights,key=lambda g:g.weight);group.append(skin.vertex_groups[big.group].name.split('_')[0])
            label='/'.join(sorted(set(group)));regions[label]=regions.get(label,0)+1
        report[name][pose]={'non_neighbour_intersections':len(pairs),'regions':regions}
        print('LIVE_POSE_AUDIT',name,pose,len(pairs),regions,flush=True);eval.to_mesh_clear()
report['source_sha256']=hashlib.sha256((OUT/'anatomical_hand_rig.blend').read_bytes()).hexdigest()
(OUT/'pose_audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
assert all(data['non_neighbour_intersections']==0 for name,poses in report.items() if isinstance(poses,dict) for data in poses.values())
print('LIVE_HAND_POSE_AUDIT_PASS')
