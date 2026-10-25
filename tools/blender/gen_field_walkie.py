"""Original desk walkie and charge cradle, metres, no external assets."""
import bpy, math, json, hashlib, random
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2];OUT=R/'tools/blender/generated/field_walkie';OUT.mkdir(parents=True,exist_ok=True)
A=R/'brave-and-cold/assets/field_walkie';A.mkdir(parents=True,exist_ok=True)
random.seed(20261005)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def cv(v):return Vector((v[0],-v[2],v[1]))
def mat(name,color,rough=.7,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal;return m
M={'shell':mat('Weathered olive polymer',(.135,.17,.13),.62),'rubber':mat('Rubber seals',(.025,.031,.027),.84),'steel':mat('Nickel fittings',(.32,.36,.33),.35,.7),'screen':mat('Dark LCD lens',(.025,.046,.035),.32),'orange':mat('PTT safety mark',(.53,.24,.06),.75),'print':mat('Ivory lettering',(.73,.76,.62),.85),'contact':mat('Brass charge contacts',(.49,.37,.14),.3,.7)}
G={}
def add(o,group,material):o.data.materials.append(M[material]);G.setdefault(group,[]).append(o);return o
def box(name,c,size,material,group='Handset',bevel=.002):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(c));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Moulded bevel','BEVEL');mod.width=min(bevel,min(size)/3);mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return add(o,group,material)
def cyl(name,a,b,r,material,group='Handset',vertices=16):
 aa,bb=cv(a),cv(b);d=bb-aa;bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(aa+bb)/2);o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
 for face in o.data.polygons:face.use_smooth=len(face.vertices)==4
 return add(o,group,material)
def label(text,c,height,material,group):
 # Built-in text is converted into our own geometry; no runtime font dependency.
 bpy.ops.object.text_add(location=cv(c));o=bpy.context.object;o.name=text;o.data.body=text;o.data.align_x='CENTER';o.data.size=height;o.data.resolution_u=2;o.rotation_euler=(math.pi/2,0,0);o.data.extrude=0
 bpy.ops.object.convert(target='MESH');return add(bpy.context.object,group,material)
box('Cradle base',(0,.010,0),(.100,.020,.088),'rubber','Cradle',.006)
box('Charge cup',(0,.027,-.004),(.081,.028,.051),'shell','Cradle',.007)
box('Charge recess',(0,.040,-.004),(.063,.006,.038),'rubber','Cradle',.004)
for x in [-.016,.016]:cyl('Gold contact',(x,.041,0),(x,.044,0),.003,'contact','Cradle',12)
cyl('LED bezel',(.032,.022,.035),(.032,.025,.035),.0045,'steel','Cradle',12)
label('CHARGE',(-.010,.015,.045),.006,'print','Cradle')
# Short power lead lies on the existing desk, behind the cradle.
points=[(.030,.006,-.043),(.039,.006,-.066),(.061,.005,-.090),(.061,.005,-.160),(.075,.005,-.22)]
for a,b in zip(points,points[1:]):cyl('Power lead',a,b,.0022,'rubber','Cradle',8)
box('Handset body',(0,.119,-.004),(.070,.155,.036),'shell',bevel=.007)
box('Rear case seam',(0,.114,-.023),(.066,.139,.004),'rubber',bevel=.002)
for x in [-.035,.035]:
 box('Bumper rib',(x,.119,-.004),(.007,.140,.039),'rubber',bevel=.003)
 for y in [.060,.079,.098,.117]:box('Grip tread',(x*1.055,y,.002),(.003,.005,.028),'rubber',bevel=.001)
box('Speaker surround',(0,.079,.016),(.054,.057,.003),'rubber',bevel=.004)
for row in range(8):box('Speaker vent',(0,.056+row*.0065,.018),(.046,.0024,.002),'steel',bevel=.0006)
box('LCD surround',(0,.139,.016),(.056,.040,.004),'rubber',bevel=.004)
box('Unpowered LCD',(0,.139,.019),(.049,.032,.0015),'screen',bevel=.001)
label('A DISP',(0,.146,.0201),.0068,'print','Display')
label('B PUBLIC',(0,.136,.0201),.0068,'print','Display')
label('FIELD 07',(0,.184,.016),.007,'print','Handset')
for x in [-.020,.0,.020]:box('Key',(x,.111,.019),(.014,.007,.004),'rubber',bevel=.002)
box('PTT switch',(-.039,.139,.002),(.005,.035,.030),'orange',bevel=.002)
box('Rear belt clip',(0,.115,-.033),(.020,.075,.008),'rubber',bevel=.004)
for x in [-.025,.025]:
 for y in [.047,.188]:cyl('Case screw',(x,y,.015),(x,y,.018),.002,'steel',vertices=12)
for x in [.0,.022]:
 cyl('Control collar',(x,.197,-.004),(x,.203,-.004),.006,'steel')
 cyl('Control knob',(x,.203,-.004),(x,.213,-.004),.006,'rubber')
cyl('Antenna collar',(-.023,.197,-.004),(-.023,.208,-.004),.006,'steel')
cyl('Flexible antenna',(-.023,.208,-.004),(-.023,.319,-.004),.0037,'rubber')
cyl('Antenna cap',(-.023,.319,-.004),(-.023,.324,-.004),.004,'rubber')
objects={}
for group,parts in G.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=group;objects[group]=o
 attr=o.data.color_attributes.new(name='Patina',type='FLOAT_COLOR',domain='CORNER');o.data.color_attributes.active_color=attr
 for face in o.data.polygons:
  for li in face.loop_indices:
   v=o.data.vertices[o.data.loops[li].vertex_index].co;k=.89+.08*math.sin(v.x*117+v.y*31+v.z*59)+.02*random.random();attr.data[li].color=(k,k,k,1)
world=objects['Display'].matrix_world.copy();objects['Display'].parent=objects['Handset'];objects['Display'].matrix_world=world
bpy.ops.object.select_all(action='DESELECT')
for o in objects.values():o.select_set(True)
path=A/'field_walkie.glb';bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'field_walkie.blend'))
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects.values());assert triangles<6500,triangles
receipt={'asset':'field_walkie','seed':20261005,'license':'Original project-authored geometry and lettering; no downloaded assets','source':'tools/blender/gen_field_walkie.py','native':'tools/blender/generated/field_walkie/field_walkie.blend','blender':bpy.app.version_string,'triangles':triangles,'semantic_nodes':list(objects),'units':'metres','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'generator_sha256':hashlib.sha256(Path(__file__).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()}
(A/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print('FIELD_WALKIE_EXPORTED',json.dumps(receipt))
