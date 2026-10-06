"""Fit the opposing thumb to the authored hatchet shaft, without changing sources."""
from pathlib import Path
import bpy,json,sys,numpy as np
TOOLS=Path(__file__).parent;sys.path.insert(0,str(TOOLS))
builder=(TOOLS/'gen_anatomical_hands_v2.py').read_text();exec(builder[:builder.index('\nbpy.ops.wm.read_factory_settings(use_empty=True)')])
fit=json.loads((TOOLS/'anatomical_tool_fit.json').read_text())
POSES['ToolGrip']={'fingers':[15,75,50],'thumb':[17,40,28],'opp':-20,**fit['ToolGrip']}
bpy.ops.wm.open_mainfile(filepath=str(TOOLS/'generated/live_hand_rig_v2/anatomical_hand_rig.blend'))
rig=bpy.data.objects['HandRig']
def residual(values):
    POSES['ToolGrip'].update(thumb=values[:3],opp=values[3]);choose_pose(rig,'ToolGrip',1)
    samples=[];radii=[]
    for j in range(3):
        bone=rig.pose.bones['thumb_'+str(j+1).zfill(2)]
        for t in np.linspace(.15,.90,8):
            p=bone.head.lerp(bone.tail,float(t));hand=np.array([p.x,p.z,-p.y])
            samples.append((np.array([.106,.006,-.032])+np.array([hand[2],-hand[0],-hand[1]]))/1.2)
            radii.append((.0105-.0015*(j+t))/1.2)
    p=np.array(samples);gap=((abs(p[:,0]/.0122)**2.4+abs((p[:,2]-.002)/.0168)**2.4)**(1/2.4)-1)*.0122-np.array(radii)
    return np.r_[np.minimum(gap,0)*30,gap[-8:]*4,(values-[17,40,28,-20])*.00001]
best=(float('inf'),None)
for start in [[17,40,28,-20],[40,40,20,-50],[0,30,10,10]]:
    value=np.array(start,dtype=float);cost=float(np.linalg.norm(residual(value)))
    for step in [8,4,2,1,.5]:
        for iteration in range(35):
            candidate_best=(cost,value)
            for axis in range(4):
                for sign in [-1,1]:
                    candidate=value.copy();candidate[axis]+=sign*step
                    if any(candidate<[-10,0,0,-80]) or any(candidate>[75,80,50,60]):continue
                    candidate_cost=float(np.linalg.norm(residual(candidate)))
                    if candidate_cost<candidate_best[0]:candidate_best=(candidate_cost,candidate)
            if candidate_best[0]>=cost-1e-10:break
            cost,value=candidate_best
    if cost<best[0]:best=(cost,value)
out={'thumb':best[1][:3].tolist(),'opp':float(best[1][3]),'residual':best[0]}
(TOOLS/'generated/live_hand_rig_v2/thumb_fit_candidate.json').write_text(json.dumps(out,indent=2)+'\n');print('THUMB_FIT',out)
