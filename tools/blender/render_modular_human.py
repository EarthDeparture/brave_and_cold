"""Inspect the actual saved original master, not a stand-in mesh."""
from pathlib import Path
import bpy
from mathutils import Vector
R=Path(__file__).resolve().parents[2];D=R/'brave-and-cold/shots/modular-human'
D.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'tools/blender/generated/modular_human/human_foundation.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
s.world=bpy.data.worlds.new('InspectionWorld');s.world.use_nodes=True
s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.12,.12,.12,1)
s.view_settings.view_transform='AgX'
def cv(p):return Vector((p[0],-p[2],p[1]))
for name,pos,power,size in [('Key',(-2,3,-3),650,4),('Fill',(2,2,-2),350,3),('Rim',(0,3,2),650,3)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
 o=bpy.data.objects.new(name,data);s.collection.objects.link(o);o.location=cv(pos);o.rotation_euler=(cv((0,1,0))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('InspectionCamera',bpy.data.cameras.new('InspectionCamera'));s.collection.objects.link(cam);s.camera=cam;cam.data.type='ORTHO'
views=[('body-front',(0,1,-4),(0,.92,0),2.05),('body-three-quarter',(3,1.5,-4),(0,.92,0),2.05),('face-front',(0,1.66,-3),(0,1.65,0),.42),('face-profile',(3,1.65,-.05),(0,1.65,0),.42),('hand',(.50,.78,-2),(.28,.755,0),.24)]
for name,pos,target,scale in views:
 cam.location=cv(pos);cam.rotation_euler=(cv(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
 s.render.resolution_x=720;s.render.resolution_y=900 if name.startswith('body') else 720;s.render.resolution_percentage=100
 s.render.filepath=str(D/(name+'.png'));bpy.ops.render.render(write_still=True)
print('MODULAR_HUMAN_PREVIEW_COMPLETE',flush=True)
