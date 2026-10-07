"""Skin the original winter-worker foundation; preserve node driver names."""
from pathlib import Path
import bpy,math,json,hashlib
from mathutils import Vector
R=Path(__file__).resolve().parents[2];OUT=R/'tools/blender/generated/infected_skin';RT=R/'brave-and-cold/assets/infected/skin'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'tools/blender/generated/infected/winter_infected.blend'))
bpy.context.preferences.filepaths.save_version=0
def cv(v):return Vector((v[0],-v[2],v[1]))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
regions={o.name: o.parent.name if o.parent else '' for o in meshes}
bpy.context.view_layer.update()
for ob in meshes:
 xf=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=xf
 bpy.context.view_layer.objects.active=ob;ob.select_set(True)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);ob.select_set(False)
data=bpy.data.armatures.new('WinterWorkerDeformation');rig=bpy.data.objects.new('WinterWorkerSkeleton',data);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
defs={'pelvis':((0,.92,0),(0,1.02,0),None),'spine':((0,1.02,0),(0,1.46,0),'pelvis'),'head':((0,1.46,0),(0,1.78,0),'spine')}
for sign,n in [(-1,'l'),(1,'r')]:
 defs['skin_zombie_leg_'+n]=((sign*.10,.92,0),(sign*.10,.48,.01),'pelvis')
 defs['skin_zombie_knee_'+n]=((sign*.10,.48,.01),(sign*.10,.09,-.015),'skin_zombie_leg_'+n)
 defs['skin_zombie_arm_'+n]=((sign*.255,1.405,0),(sign*.285,1.07,-.006),'spine')
 defs['skin_zombie_elbow_'+n]=((sign*.285,1.07,-.006),(sign*.286,.68,-.028),'skin_zombie_arm_'+n)
for name,(head,tail,parent) in defs.items():
 b=data.edit_bones.new(name);b.head=cv(head);b.tail=cv(tail)
 if parent:b.parent=data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
def smooth(a,b,v):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
for ob in meshes:
 groups={name:ob.vertex_groups.new(name=name) for name in defs}
 for v in ob.data.vertices:
  x,y,z=v.co.x,v.co.z,-v.co.y;side='l' if x<0 else 'r';ax=abs(x)
  region=regions[ob.name]
  if 'zombie_arm_' in region or 'zombie_elbow_' in region:
   side=region[-1]
   elbow=1-smooth(1.015,1.125,y);shoulder=smooth(1.36,1.46,y)*.35
   weights={'skin_zombie_elbow_'+side:elbow*(1-shoulder),'skin_zombie_arm_'+side:(1-elbow)*(1-shoulder),'spine':shoulder}
  elif 'zombie_leg_' in region or 'zombie_knee_' in region:
   side=region[-1]
   knee=1-smooth(.42,.55,y);hip=smooth(.82,.98,y)
   weights={'skin_zombie_knee_'+side:knee*(1-hip),'skin_zombie_leg_'+side:(1-knee)*(1-hip),'pelvis':hip}
  elif y>1.45:
   head=smooth(1.46,1.55,y);weights={'head':head,'spine':1-head}
  else:
   spine=smooth(.96,1.10,y);weights={'spine':spine,'pelvis':1-spine}
  for name,w in weights.items():
   if w>1e-7:groups[name].add([v.index],w,'REPLACE')
 ob.parent=rig;mod=ob.modifiers.new('Continuous joint deformation','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=False
# Join surfaces by material; maintain weights while eliminating dozens of draw nodes.
by={}
for ob in meshes:by.setdefault(ob.data.materials[0].name,[]).append(ob)
for ma,objects in by.items():
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objects:ob.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name='Skin_'+ma
for im in bpy.data.images:
 if im.filepath:im.pack()
rig.animation_data_create()
# Original authored pose clips for editable preview and downstream animation work.
# Runtime drives this same skeleton from authoritative gameplay state.
for clip,length in [('idle',1.6),('walk',.92),('notice',.6),('attack',.70),('stagger',.50),('barrier',.8),('death',.7)]:
 action=bpy.data.actions.new(clip);rig.animation_data.action=action
 for frame in range(0,25):
  t=frame/24;phase=t*math.tau
  for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
  for i,n in enumerate(['l','r']):
   wave=math.sin(phase+i*math.pi)
   if clip=='walk':
    rig.pose.bones['skin_zombie_leg_'+n].rotation_euler.x=wave*.40
    rig.pose.bones['skin_zombie_knee_'+n].rotation_euler.x=-max(0,-wave)*.45
    rig.pose.bones['skin_zombie_arm_'+n].rotation_euler.x=.12-wave*.12
   if clip in ['attack','barrier']:
    rig.pose.bones['skin_zombie_arm_'+n].rotation_euler.x=.55+math.sin(t*math.pi)*.60
    rig.pose.bones['skin_zombie_elbow_'+n].rotation_euler.x=.22+math.sin(t*math.pi)*.25
  rig.pose.bones['spine'].rotation_euler.z=math.sin(phase)*(.065 if clip=='stagger' else .008)
  rig.pose.bones['head'].rotation_euler.z=math.sin(t*math.pi)*(.18 if clip=='notice' else .008)
  if clip=='death':rig.pose.bones['spine'].rotation_euler.x=-.25*t
  for pb in rig.pose.bones:pb.keyframe_insert('rotation_euler',frame=1+t*length*30,group=pb.name)
 action.use_fake_user=True
rig.animation_data.action=None
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
bpy.context.scene.render.fps=30
native=OUT/'winter_worker_skin.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
path=RT/'winter_worker_skin.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True,export_all_influences=False)
report={'origin':'Original project-authored winter-worker geometry, now weighted to an 11-bone deforming skeleton','units':'metres; no gameplay collision','native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'bones':list(defs),'clips':['idle','walk','notice','attack','stagger','barrier','death'],'rig_contract':'Existing logical joint names retained as empty driver nodes; runtime state remains authoritative; no animation damage callbacks'}
(RT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('INFECTED_SKIN_EXPORTED',flush=True)
