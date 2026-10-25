"""Original articulated winter infected; editable hip/knee/shoulder/elbow rig."""
from pathlib import Path
import bpy,math,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text();exec(src[:src.index('clear()\n# Reusable')]);OUT=R/'tools/blender/generated/infected';RT=R/'brave-and-cold/assets/infected';OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
M['skin']=mat('pallid_skin',(.45,.43,.36),.87);M['coat']=mat('winter_canvas',(.19,.25,.20),.92,texture=R/'tools/blender/generated/clinic/cloth.png');M['dark']=mat('work_trousers',(.15,.17,.16),.91);M['eye']=mat('shadowed_eyes',(.09,.105,.09),.55);M['wound']=mat('dry_wound',(.24,.08,.065),.94)
def oval(name,p,sz,ma,parent=None,segments=24,rings=16):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=cv(p));o=bpy.context.object;o.name=name;o.scale=(sz[0],sz[2],sz[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True
 return finish(o,ma,parent)
def limb(name,center,profile,ma,parent):
 vs=[];fs=[];n=24
 for y,rx,rz in profile:
  for k in range(n):vs.append(cv((center[0]+math.cos(k*math.tau/n)*rx,y,center[1]+math.sin(k*math.tau/n)*rz)))
 for j in range(len(profile)-1):
  for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 fs.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))]);me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 for f in me.polygons:f.use_smooth=len(f.vertices)==4
 return finish(o,ma,parent)
def finish(o,m,parent=None):
 o.data.materials.append(M[m])
 if parent:
  bpy.context.view_layer.update();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o
# Compact human proportions, broad shoulders, pelvis and tapered waist under clothing.
oval('Pelvis',(0,.94,0),(.18,.14,.115),'dark');oval('JacketTorso',(0,1.22,.014),(.23,.29,.14),'coat');oval('ShoulderYoke',(0,1.43,0),(.27,.10,.13),'coat')
cyl('Neck',(0,1.44,0),(0,1.55,0),.057,'skin');oval('Head',(0,1.66,-.018),(.089,.122,.093),'skin')
oval('Jaw',(0,1.595,-.028),(.075,.047,.075),'skin');oval('Nose',(0,1.653,-.112),(.018,.032,.035),'skin',segments=16,rings=12)
for side in [-1,1]:
 oval('Ear',(side*.088,1.655,-.01),(.014,.032,.022),'skin',segments=16,rings=12)
 oval('Cheek',(side*.040,1.635,-.093),(.030,.034,.022),'skin',segments=16,rings=12)
 oval('SunkenEye',(side*.033,1.690,-.097),(.022,.011,.012),'eye',segments=16,rings=8)
 oval('Brow',(side*.032,1.707,-.096),(.027,.010,.018),'skin',segments=16,rings=8)
cyl('Mouth',(-.031,1.607,-.092),(.029,1.607,-.094),.0035,'wound',12)
# Ragged neckline, zipper, pocket flaps and restrained wear rather than shiny plastic.
for side in [-1,1]:
 box('CoatCollar',(side*.071,1.467,-.08),(.075,.08,.05),'coat',.013);box('PocketFlap',(side*.13,1.10,-.125),(.13,.045,.02),'coat',.006)
cyl('Zipper',(0,1.015,-.132),(0,1.44,-.133),.003,'steel',8)
for i in range(4):cyl('TorsoCrease',(-.14,1.06+i*.085,-.122),(-.02,1.045+i*.085,-.137),.004,'coat',8)
# Limbs use nested joints; skin volumes retain continuity through each pivot.
for sign,n in [(-1,'l'),(1,'r')]:
 hip=empty('zombie_leg_'+n,(sign*.10,.92,0));limb('Thigh',(sign*.10,0),[(.93,.082,.09),(.84,.095,.102),(.68,.087,.088),(.48,.061,.069)],'dark',hip)
 knee=empty('zombie_knee_'+n,(sign*.10,.48,.01));knee.parent=hip;knee.matrix_parent_inverse=hip.matrix_world.inverted();limb('Calf',(sign*.10,.01),[(.50,.062,.07),(.39,.077,.08),(.21,.060,.061),(.11,.047,.052)],'dark',knee);oval('Boot',(sign*.10,.085,-.035),(.078,.085,.14),'rubber',knee);box('BootSole',(sign*.10,.029,-.035),(.16,.035,.27),'rubber',.012,knee)
 shoulder=empty('zombie_arm_'+n,(sign*.255,1.405,0));limb('UpperSleeve',(sign*.275,0),[(1.44,.07,.07),(1.33,.078,.079),(1.19,.069,.069),(1.06,.059,.06)],'coat',shoulder)
 elbow=empty('zombie_elbow_'+n,(sign*.285,1.07,-.006));elbow.parent=shoulder;elbow.matrix_parent_inverse=shoulder.matrix_world.inverted();limb('ForeSleeve',(sign*.287,-.005),[(1.09,.058,.06),(.97,.065,.067),(.84,.052,.051),(.80,.052,.051)],'coat',elbow);oval('Cuff',(sign*.286,.806,-.01),(.058,.03,.058),'rubber',elbow)
 oval('Palm',(sign*.286,.750,-.01),(.045,.072,.031),'skin',elbow,20,12)
 for k in range(4):
  x=sign*.286+(k-1.5)*.020;length=[.062,.077,.073,.053][k];cyl('Finger',(x,.720,-.012),(x,.720-length,-.038),.008,'skin',12,elbow)
 cyl('Thumb',(sign*.286-sign*.035,.780,-.01),(sign*.286-sign*.061,.724,-.040),.012,'skin',12,elbow)
box('TrouserBelt',(0,.966,-.08),(.28,.030,.09),'rubber',.006)
# Copy static rest silhouette for distant population rendering.
bpy.context.view_layer.update()
proxy=[]
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH':continue
 cp=obj.copy();cp.data=obj.data.copy();bpy.context.collection.objects.link(cp);xf=obj.matrix_world.copy();cp.parent=None;cp.matrix_world=xf;proxy.append(cp)
 attrs=cp.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 for poly in cp.data.polygons:
  col=cp.data.materials[poly.material_index].diffuse_color
  for li in poly.loop_indices:attrs.data[li].color=col
bpy.ops.object.select_all(action='DESELECT')
for obj in proxy:obj.select_set(True)
bpy.context.view_layer.objects.active=proxy[0];bpy.ops.object.join();proxyobj=bpy.context.object;proxyobj.name='WinterInfectedProxy';mod=proxyobj.modifiers.new('Distant silhouette','DECIMATE');mod.ratio=.16;bpy.ops.object.modifier_apply(modifier=mod.name)
proxyobj.data.materials.clear();vm=mat('baked_vertex_palette',(1,1,1));color=vm.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name='Color';vm.node_tree.links.new(color.outputs['Color'],vm.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);proxyobj.data.materials.append(vm)
for poly in proxyobj.data.polygons:poly.material_index=0
bpy.ops.export_scene.gltf(filepath=str(RT/'winter_infected_proxy.glb'),export_format='GLB',use_selection=True,export_yup=True)
proxytri=sum(len(f.vertices)-2 for f in proxyobj.data.polygons);bpy.data.objects.remove(proxyobj,do_unlink=True)
export('winter_infected');receipt['proxy']={'triangles':proxytri,'sha256':hashlib.sha256((RT/'winter_infected_proxy.glb').read_bytes()).hexdigest()};receipt['winter_infected']['source']='tools/blender/generated/infected/winter_infected.blend';receipt['provenance']={'license':'Original project-authored geometry; original project canvas graphic','blender':bpy.app.version_string,'rig':'Node joints / shoulder, elbow, hip, knee','units':'metres','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()};(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
