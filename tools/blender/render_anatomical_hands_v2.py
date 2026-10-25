"""Actual Blender anatomy/pose renders; never an illustrative stand-in."""
import bpy
from mathutils import Vector,Quaternion
import math
def render_all(out,right,left,nails_r,nails_l,rig,left_rig,poses,choose_pose,cage):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
    scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
    scene.world=bpy.data.worlds.new('Neutral anatomy review');scene.world.color=(.065,.065,.065)
    lights=[]
    for location,power,size in [((.30,-.25,.55),4.5,.35),((-.35,.1,.35),2.0,.3),((.2,.4,.45),2.8,.3)]:
        bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=power;light.data.size=size;light.rotation_euler=(Vector((0,.035,0))-light.location).to_track_quat('-Z','Y').to_euler()
        lights.append(light)
    bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=.325
    rig.location=(0,0,0);left_rig.location=(0,0,0)
    left.hide_render=True;nails_l.hide_render=True
    def pose(name,side=1):
        which=rig if side==1 else left_rig;skin=right if side==1 else left
        choose_pose(which,name,side)
        for key in skin.data.shape_keys.key_blocks:key.value=float(key.name=='corrective_'+name)
        bpy.context.view_layer.update()
    def shot(name,direction,center=(0,.035,0),scale=.325):
        center=Vector(center);direction=Vector(direction);camera.data.ortho_scale=scale;camera.location=center+direction;q=(center-camera.location).to_track_quat('-Z','Y')
        if direction.z<0:q=q@Quaternion(Vector((0,0,1)),math.pi)
        camera.rotation_euler=q.to_euler()
        for light,offset in zip(lights,[(.16,-.13,.0),(-.24,.08,.0),(.08,.20,.0)]):
            light.location=center+direction.normalized()*(.45 if light!=lights[2] else -.35)+Vector(offset);light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(name+'.png'));bpy.ops.render.render(write_still=True)
    pose('Open')
    shot('open_dorsal',(0,-.045,.6));shot('open_palm',(0,-.035,-.6));shot('open_three_quarter',(.35,-.10,.55));shot('open_profile',(.6,-.02,.1))
    shot('open_hand_detail',(.08,-.045,.6),center=(0,.078,0),scale=.218)
    for name in poses:
        pose(name);shot('pose_'+name,(.25,-.16,.50))
    right.hide_render=True;nails_r.hide_render=True;left.hide_render=False;nails_l.hide_render=False
    pose('Open',-1);shot('left_open',(0,-.045,.6))
    left.hide_render=True;nails_l.hide_render=True;cage.hide_render=False;cage.hide_set(False);cage.location=(0,0,0)
    clay=bpy.data.materials.new('TopologyClay');clay.diffuse_color=(.46,.28,.26,1);clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.46,.28,.26,1);cage.data.materials.append(clay)
    wire=cage.copy();wire.data=cage.data.copy();bpy.context.collection.objects.link(wire)
    ink=bpy.data.materials.new('TopologyInk');ink.use_nodes=True;ink.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.028,.024,.023,1);wire.data.materials.clear();wire.data.materials.append(ink)
    modifier=wire.modifiers.new('Visible cage edges','WIREFRAME');modifier.thickness=.00018;modifier.use_replace=True
    shot('quad_cage_dorsal',(0,-.045,.6));shot('quad_cage_palm',(0,-.035,-.6))
    print('ANATOMY_RENDER_PASS',flush=True)
