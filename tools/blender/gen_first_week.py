"""Original field equipment, authored in metres. Blender 5.2 background export.
No providers/downloads. Native sources, measured triangles and exact GLB hashes retained.
"""
from pathlib import Path
import bpy, math, json, hashlib
from mathutils import Vector
R=Path(__file__).resolve().parents[2];OUT=R/'tools/blender/generated/first_week';RT=R/'brave-and-cold/assets/first_week'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
def cv(v):return Vector((v[0],-v[2],v[1]))
def mat(name,c,rough=.8,metal=0,texture=None):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1);bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 if texture:
  n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(texture));m.node_tree.links.new(n.outputs['Color'],bs.inputs['Base Color'])
 return m
M={n:mat(n,c,rough,metal) for n,c,rough,metal in [('forest_enamel',(.12,.19,.15),.65,.25),('steel',(.29,.32,.30),.53,.7),('rubber',(.035,.043,.041),.88,0),('cream',(.68,.64,.48),.88,0),('ochre',(.56,.38,.07),.78,.15),('snow',(.70,.79,.86),.96,0),('timber',(.27,.18,.095),.92,0)]}
wood=R/'brave-and-cold/assets/environment_detail/textures/timber_alb.png'
if wood.exists():M['timber']=mat('weathered_timber',(.27,.18,.095),texture=wood)
receipt={};roots=[]
def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def finish(o,m,parent=None):
 o.data.materials.append(M[m]);
 if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o
def box(name,p,size,m,b=.006,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if b:
  mod=o.modifiers.new('soft manufactured edges','BEVEL');mod.width=min(b,min(size)/3);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('weighted face normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,m,parent)
def cyl(name,a,b,r,m,segments=20,parent=None):
 aa,bb=cv(a),cv(b);d=bb-aa;bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r,depth=d.length,location=(aa+bb)*.5);o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
 for face in o.data.polygons:face.use_smooth=len(face.vertices)==4
 return finish(o,m,parent)
def empty(name,p):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=cv(p);return o
def label(name,p,size,image,parent=None):
 x,y,z=p;w,h=size;me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in [(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)]],[],[(0,1,2,3)]);me.update();uv=me.uv_layers.new()
 for i,xy in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=xy
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);M[name]=mat(name,(1,1,1),texture=OUT/(image+'.png'));return finish(o,name,parent)
def export(name):
 groups={}
 for obj in list(bpy.context.scene.objects):
  if obj.type=='MESH':groups.setdefault((obj.parent.name if obj.parent else '',obj.data.materials[0].name),[]).append(obj)
 for (parent_name,material_name),objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  if len(objects)>1:bpy.ops.object.join()
  bpy.context.object.name='Surface_'+material_name
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes);assert tri<20000,(name,tri)
 for im in bpy.data.images:
  if im.filepath:im.pack()
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(RT/(name+'.glb')),export_format='GLB',export_yup=True,export_materials='EXPORT',export_extras=True)
 receipt[name]={'triangles':tri,'bytes':(RT/(name+'.glb')).stat().st_size,'sha256':hashlib.sha256((RT/(name+'.glb')).read_bytes()).hexdigest(),'source':'tools/blender/generated/first_week/'+name+'.blend','source_sha256':hashlib.sha256((OUT/(name+'.blend')).read_bytes()).hexdigest(),'mesh_nodes':len(meshes)}
 clear()
clear()
# Reusable enamel field flask, rounded profile and screw cap.
rings=[(0,.031),(.008,.038),(.025,.042),(.18,.042),(.20,.039),(.217,.025),(.232,.022)];vs=[];fs=[];n=32
for y,rr in rings:
 for k in range(n):vs.append(cv((math.sin(k*math.tau/n)*rr,y,math.cos(k*math.tau/n)*rr)))
for j in range(len(rings)-1):
 for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
fs.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+k for k in range(n))]);me=bpy.data.meshes.new('flask_shell');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('EnamelFlask',me);bpy.context.collection.objects.link(o);finish(o,'forest_enamel')
for f in me.polygons:f.use_smooth=len(f.vertices)==4
cyl('cap_gasket',(0,.233,0),(0,.240,0),.024,'rubber');cyl('ScrewCap',(0,.240,0),(0,.264,0),.026,'steel',32)
for k in range(20):
 a=k*math.tau/20;cyl('cap_grip',(math.sin(a)*.026,.245,math.cos(a)*.026),(math.sin(a)*.026,.261,math.cos(a)*.026),.001,'rubber',6)
label('flask_graphic',(0,.115,.0425),(.061,.09),'water');export('water_bottle')
# Waterproof finite crew crate; pivoted lid with hardware.
box('CacheBase',(0,.025,0),(.9,.05,.58),'forest_enamel',.014)
for x in [-.435,.435]:box('CacheSide',(x,.27,0),(.03,.49,.58),'forest_enamel',.008)
for z in [-.275,.275]:box('CacheWall',(0,.27,z),(.84,.49,.03),'forest_enamel',.008)
box('BayDivider',(.08,.22,0),(.014,.34,.51),'cream',.002)
stock=empty('CacheWaterStock',(0,0,0))
for x in [-.30,-.13]:
 cyl('StoredFlask',(x,.05,-.06),(x,.32,-.06),.046,'forest_enamel',24,stock);cyl('StoredCap',(x,.32,-.06),(x,.35,-.06),.025,'steel',20,stock)
stock=empty('CacheMedicalStock',(0,0,0))
for z in [-.13,.02]:cyl('WrappedDressing',(.30,.055,z),(.30,.12,z),.044,'cream',24,stock)
stock=empty('CacheFoodStock',(0,0,0))
for z in [-.12,.02]:cyl('FoodTin',(.16,.05,z),(.16,.17,z),.053,'ochre',24,stock)
stock=empty('CacheMatchStock',(0,0,0));box('MatchPacket',(-.24,.085,.17),(.14,.06,.08),'ochre',.003,stock)
for x in [-.44,.44]:box('SideSeal',(x,.50,0),(.03,.02,.59),'rubber')
for z in [-.28,.28]:box('FrontSeal',(0,.50,z),(.85,.02,.03),'rubber')
lid=empty('CacheLid',(0,.51,-.30));box('RaisedLid',(0,.54,0),(.94,.08,.62),'forest_enamel',.015,lid)
for x in [-.40,.40]:
 box('CornerGuard',(x,.23,.30),(.075,.39,.03),'rubber')
 box('Latch',(x,.47,.32),(.065,.13,.025),'steel');cyl('LatchPin',(x-.035,.47,.334),(x+.035,.47,.334),.007,'steel')
for x in [-.28,.28]:box('Hinge',(x,.51,-.322),(.1,.035,.025),'steel')
for x in [-.475,.475]:
 cyl('Handle',(x,.27,-.11),(x,.27,.11),.014,'rubber');cyl('HandleFoot',(x,.27,-.11),(x*.94,.27,-.11),.012,'steel')
label('cache_graphic',(0,.28,.3005),(.56,.19),'cache')
box('Clipboard',(.32,.74,.26),(.26,.29,.022),'timber');label('cache_note',(.32,.74,.274),(.23,.26),'note');box('PaperClip',(.32,.873,.286),(.08,.023,.018),'steel')
export('field_cache')
# Forestry marker and chopping block; logs themselves use the existing saved splitting system.
for x in [-.42,.42]:box('Post',(x,.65,0),(.09,1.30,.09),'timber')
for y in [.82,1.04]:box('SignBoard',(0,y,.03),(.98,.20,.045),'timber')
label('timber_graphic',(0,.93,.057),(.9,.36),'timber')
for x in [-.40,.40]:
 for y in [.82,1.04]:cyl('SignBolt',(x,y,.055),(x,y,.070),.009,'steel',12)
cyl('ChoppingBlock',(0,0,.7),(0,.38,.7),.24,'timber',24)
box('SnowCap',(0,.383,.7),(.40,.022,.33),'snow',.009)
export('timber_marker')
# Accessible crew-spur disconnect; meter window and lockout hardware.
for x in [-.29,.29]:box('CabinetLeg',(x,.39,0),(.06,.78,.06),'steel')
box('Housing',(0,1.05,0),(.7,.75,.33),'forest_enamel',.018);box('Front',(0,1.04,.182),(.64,.67,.025),'forest_enamel',.01)
box('MeterFrame',(-.14,1.17,.207),(.23,.19,.025),'rubber');label('meter_graphic',(-.14,1.17,.224),(.21,.17),'meter')
box('LockoutPlate',(.18,.98,.219),(.14,.28,.025),'ochre');cyl('DisconnectHandle',(.18,.96,.245),(.18,1.13,.245),.02,'rubber')
for y in [.82,1.26]:box('Hinge',(-.34,y,.18),(.036,.10,.035),'steel')
for i in range(7):box('CoolingSlot',(-.14,.86+i*.013,.211),(.17,.004,.004),'rubber',0)
box('SnowBrow',(0,1.445,0),(.78,.035,.40),'snow',.015);label('feeder_graphic',(0,1.55,.06),(.68,.15),'feeder')
box('NoticeBacking',(0,1.55,.048),(.71,.18,.02),'steel',.003)
for x in [-.25,.25]:box('NoticeBracket',(x,1.48,.01),(.03,.15,.03),'steel',.002)
export('feeder_cabinet')
receipt['provenance']={'license':'Original project-authored geometry/graphics; existing original timber texture reused','blender':bpy.app.version_string,'units':'metres','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
receipt['graphics']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8');print('FIRST_WEEK_ASSETS',json.dumps(receipt))
