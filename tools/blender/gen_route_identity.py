"""Original route dressing, metres in authored Godot coordinates. No downloads."""
import bpy, json, hashlib, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'tools/blender/generated/route_identity';RUNTIME=ROOT/'brave-and-cold/assets/route_detail';OUT.mkdir(parents=True,exist_ok=True);RUNTIME.mkdir(parents=True,exist_ok=True)
def cv(v):return Vector((v[0],-v[2],v[1]))
def material(name,color,rough=.8,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;return m
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
M={k:material(k,c,r,m) for k,c,r,m in [('painted_steel',(.06,.12,.10),.77,.25),('aged_steel',(.24,.27,.24),.65,.6),('brass',(.31,.25,.12),.55,.65),('rubber',(.017,.021,.02),.88,0),('paper',(.64,.58,.40),.9,0),('timber',(.20,.13,.07),.9,0),('canvas',(.24,.25,.14),.92,0),('red_lead',(.25,.032,.017),.85,0),('cream',(.58,.52,.36),.9,0)]}
texture=ROOT/'brave-and-cold/assets/environment_detail/textures/timber_alb.png'
if texture.exists():
 m=M['timber'];n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(texture));m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
TEXTURES={};PARTS={};receipt={}
def label_mat(name):
 if name not in TEXTURES:
  m=material('graphic_'+name,(1,1,1));n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(OUT/'textures'/(name+'.png')));m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);TEXTURES[name]=m
 return TEXTURES[name]
def add(obj,group,mat):obj.data.materials.append(M[mat] if isinstance(mat,str) else mat);PARTS.setdefault(group,[]).append(obj);return obj
def box(name,c,size,mat,group='FixedProps',bevel=.007):
 bpy.ops.mesh.primitive_cube_add(size=1,location=cv(c));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=min(bevel,min(size)/3);mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return add(o,group,mat)
def cylinder(name,a,b,r,mat,group='FixedProps',segments=12):
 aa,bb=cv(a),cv(b);d=bb-aa;bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r,depth=d.length,location=(aa+bb)*.5);o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
 for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
 return add(o,group,mat)
def cord(name,points,r,mat):
 for a,b in zip(points,points[1:]):cylinder(name,a,b,r,mat,segments=6)
def face(name,c,size,graphic,group='FixedProps',up=False):
 x,y,z=c;w,h=size
 vertices=[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)] if not up else [(x-w/2,y,z+h/2),(x+w/2,y,z+h/2),(x+w/2,y,z-h/2),(x-w/2,y,z-h/2)]
 me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in vertices],[],[(0,1,2,3)]);me.update();uv=me.uv_layers.new(name='UVMap')
 for i,xy in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=xy
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return add(o,group,label_mat(graphic))
def wrapped_label(name,center,radius,height,graphic,group):
 # Cylindrical paper follows the tin, with its seam behind the readable front.
 x,y,z=center;vertices=[];uvs=[];segments=28;angle=math.radians(150)
 for row in range(2):
  for i in range(segments+1):
   t=i/segments;a=-angle+2*angle*t
   vertices.append(cv((x+math.sin(a)*radius,y+(row-.5)*height,z+math.cos(a)*radius)))
   uvs.append((t,row))
 faces=[(i,i+1,i+segments+2,i+segments+1) for i in range(segments)]
 me=bpy.data.meshes.new(name);me.from_pydata(vertices,[],faces);me.update();uv=me.uv_layers.new(name='UVMap')
 for poly in me.polygons:
  poly.use_smooth=True
  for loop in poly.loop_indices:uv.data[loop].uv=uvs[me.loops[loop].vertex_index]
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return add(o,group,label_mat(graphic))

def ring(name,c,outer,inner,depth,mat,group='FixedProps',segments=24):
 x,y,z=c;vs=[]
 for yy,rr in [(y-depth/2,outer),(y+depth/2,outer),(y-depth/2,inner),(y+depth/2,inner)]:
  for i in range(segments):a=i*math.tau/segments;vs.append(cv((x+rr*math.cos(a),yy,z+rr*math.sin(a))))
 faces=[]
 for i in range(segments):
  j=(i+1)%segments
  faces.extend([(i,j,segments+j,segments+i),(segments+i,segments+j,3*segments+j,3*segments+i),(2*segments+j,2*segments+i,3*segments+i,3*segments+j),(j,i,2*segments+i,2*segments+j)])
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],faces);me.update()
 for poly in me.polygons:poly.use_smooth=True
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return add(o,group,mat)

def profile(name,points,z,depth,mat,group='FixedProps',bevel=.001):
 # Concave forged outlines, not overlapping bars approximating the tool jaws.
 import bmesh
 n=len(points);vs=[cv((x,y,z+side*depth/2)) for side in [-1,1] for x,y in points]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],faces);me.update()
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 mod=o.modifiers.new('Forged edge bevel','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Forged normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return add(o,group,mat)

def wear(obj):
 # Preserve the authored material factor and texture link. Export neutral
 # multiplicative patina separately as COLOR_0, avoiding unsupported MixRGB.
 # The material palette also remains correct if an importer disables colors.
 attr=obj.data.color_attributes.new(name='Wear',type='FLOAT_COLOR',domain='CORNER')
 obj.data.color_attributes.active_color=attr
 for poly in obj.data.polygons:
  for li in poly.loop_indices:
   p=obj.data.vertices[obj.data.loops[li].vertex_index].co
   broad=.5+.5*math.sin(p.x*19+p.y*13+p.z*17)
   fine=.5+.5*math.sin(p.x*831+p.y*457+p.z*619)
   k=.82+.15*broad+.03*fine
   attr.data[li].color=(k,k,k,1)

def export(name):
 objects=[]
 for group,parts in PARTS.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=group;objects.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:
  wear(o);o.select_set(True)
 path=RUNTIME/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_vertex_color='ACTIVE',export_animations=False)
 triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects);assert triangles<20000,(name,triangles)
 bpy.ops.file.pack_all()
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')))
 receipt[name]={'triangles':triangles,'mesh_groups':[o.name for o in objects],'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);PARTS.clear()
box('signboard',(0,3.78,2.565),(3.23,.56,.06),'painted_steel');face('NorthRidgeSign',(0,3.78,2.602),(3.09,.48),'store_sign')
for x in [-1.51,1.51]:cylinder('signbolt',(x,3.78,2.602),(x,3.78,2.610),.012,'aged_steel')
box('hours_holder',(-.81,1.64,2.467),(.43,.43,.018),'aged_steel');face('opening_hours',(-.81,1.64,2.480),(.40,.40),'hours');export('store_identity')
for level in [.93,1.53,2.13]:
 for k in range(6):
  x=-2.35+k*.43;z=-1.98;g='ShelfStock'
  cylinder('food_tin',(x,level-.09,z),(x,level+.09,z),.065,'aged_steel',g,24)
  ring('rolled_lid',(x,level+.090,z),.068,.060,.006,'aged_steel',g)
  ring('bottom_seam',(x,level-.086,z),.066,.062,.004,'aged_steel',g)
  cylinder('pressed_lid',(x,level+.087,z),(x,level+.089,z),.060,'aged_steel',g,24)
  ring('pull_tab',(x+.013,level+.091,z),.012,.006,.002,'aged_steel',g,12)
  wrapped_label('food_label',(x,level,z),.0658,.137,['beans','tomato_beans','maple_beans'][k%3],g)
for k in range(3):
 x=-.48+k*.27;box('medical_pack',(x,.875,-1.98),(.20,.20,.18),'cream','ShelfStock');face('med_label',(x,.875,-1.883),(.18,.16),'medical','ShelfStock')
box('cash_register',(1.63,1.51,.40),(.42,.21,.36),'painted_steel');box('till_drawer',(1.63,1.433,.40),(.44,.055,.38),'aged_steel');box('drawer_handle',(1.63,1.436,.606),(.14,.018,.014),'rubber')
for x in range(5):
 for z in range(3):box('register_key',(1.49+x*.067,1.631,.34+z*.06),(.035,.017,.034),'cream',bevel=.003)
box('receipt_roll',(1.75,1.626,.24),(.13,.05,.07),'paper');box('ledger',(1.56,1.424,-.34),(.34,.027,.43),'canvas');face('ledger_cover',(1.56,1.439,-.34),(.32,.40),'ledger',up=True)
box('counter_first_aid',(1.59,1.50,-.92),(.31,.17,.24),'cream','CounterStock');face('first_aid_face',(1.59,1.50,-.794),(.28,.14),'medical','CounterStock')
for k in range(3):box('matchbox',(1.60,1.434+k*.022,-.64),(.075,.02,.053),'paper','CounterStock');face('match_face',(1.60,1.447+k*.022,-.64),(.068,.047),'matches','CounterStock',up=True)
box('hardware_box',(-2.49,1.11,-.90),(.51,.21,.42),'canvas','CrateStock');face('nails_label',(-2.49,1.11,-.684),(.40,.15),'nails','CrateStock')
for k in range(2):box('folded_wool',(-2.47,1.30+k*.07,-.92),(.44,.065,.34),'cream' if k else 'canvas','CrateStock',.018)
box('tool_backboard',(1.77,1.94,-2.12),(1.05,.70,.06),'timber')
# Four legible hardware silhouettes rather than identical toy hammers.
for x in [1.40,1.63,1.86,2.09]:
 cylinder('peg_hook',(x,2.13,-2.065),(x,2.13,-2.01),.006,'aged_steel',segments=8)
cylinder('hammer_handle',(1.40,1.66,-2.043),(1.40,2.05,-2.043),.017,'timber',segments=12)
box('hammer_head',(1.40,2.07,-2.043),(.14,.046,.039),'aged_steel')
box('hammer_face',(1.332,2.07,-2.043),(.019,.048,.044),'aged_steel')
# Forged open-end spanner: curved jaws and a recessed flat shank.
box('spanner_shank',(1.63,1.94,-2.04),(.027,.23,.014),'aged_steel',bevel=.004)
for yy,offset in [(1.797,180),(2.083,0)]:
 angles=[math.radians(45+offset+i*270/18) for i in range(19)]
 points=[(1.63+math.sin(a)*.044,yy+math.cos(a)*.044) for a in angles]
 points += [(1.63+math.sin(a)*.024,yy+math.cos(a)*.024) for a in reversed(angles)]
 profile('forged_spanner_jaw',points,-2.04,.019,'aged_steel',bevel=.0015)
box('wrench_recess',(1.63,1.94,-2.029),(.011,.15,.001),'rubber',bevel=.002)
# Insulated screwdriver with a blade and moulded handle ribs.
cylinder('screwdriver_grip',(1.86,1.69,-2.04),(1.86,1.84,-2.04),.019,'red_lead',segments=16)
for yy in [1.715,1.75,1.785,1.82]:ring('grip_rib',(1.86,yy,-2.04),.020,.017,.007,'rubber',segments=16)
cylinder('screwdriver_shaft',(1.86,1.84,-2.04),(1.86,2.105,-2.04),.004,'aged_steel',segments=10)
box('driver_blade',(1.86,2.12,-2.04),(.010,.037,.003),'aged_steel',bevel=.001)
# Pliers have moulded grips, forged tapered jaws, and small serrated teeth.
for side in [-1,1]:
 cord('pliers_grip',[(2.09+side*.039,1.70,-2.04),(2.09+side*.030,1.82,-2.04),(2.09,1.94,-2.04)],.010,'rubber')
 shape=[(0,1.933),(.032,1.978),(.026,2.015),(.017,2.065),(.005,2.080),(.001,2.079),(.006,2.070),(.002,2.063),(.007,2.058),(.003,2.051),(.008,2.046),(.004,2.039),(.008,2.031),(.010,2.010),(.008,1.982)]
 profile('forged_pliers_jaw',[(2.09+side*x,y) for x,y in shape],-2.04,.014,'aged_steel',bevel=.001)
cylinder('pliers_pivot',(2.09,1.94,-2.055),(2.09,1.94,-2.025),.015,'aged_steel',segments=16)
export('store_dressing')
y=.89;box('parts_tray',(.91,y+.018,-1.56),(.42,.035,.25),'aged_steel')
for k in range(3):cylinder('spare_fuse',(.78+k*.105,y+.04,-1.53),(.78+k*.105,y+.04,-1.64),.014,'cream');cylinder('fuse_cap',(.78+k*.105,y+.04,-1.53),(.78+k*.105,y+.04,-1.55),.015,'brass')
box('field_meter',(1.32,y+.04,-1.18),(.18,.08,.28),'canvas',bevel=.015);face('meter_display',(1.32,y+.082,-1.22),(.145,.10),'meter',up=True);cylinder('selector_dial',(1.32,y+.079,-1.12),(1.32,y+.093,-1.12),.028,'rubber',segments=20)
cord('red_probe',[(1.36,y+.025,-1.02),(1.44,y+.02,-1.01),(1.51,y+.02,-1.11),(1.52,y+.02,-1.28)],.004,'red_lead');cylinder('probe_tip',(1.52,y+.02,-1.28),(1.52,y+.02,-1.35),.003,'brass')
cord('black_probe',[(1.27,y+.03,-1.04),(1.18,y+.019,-1.05),(1.14,y+.019,-1.19)],.004,'rubber');cylinder('probe_tip',(1.14,y+.019,-1.19),(1.14,y+.019,-1.29),.003,'aged_steel')
box('service_binder',(.92,y+.012,-1.14),(.30,.022,.36),'painted_steel');face('service_order',(.92,y+.026,-1.14),(.275,.335),'workorder',up=True)
# Original replacement face for the existing radio body; the shell stays put.
box('radio_face',(1.78,1.03,-1.167),(.43,.265,.022),'painted_steel')
box('speaker_inset',(1.65,1.016,-1.148),(.135,.166,.009),'rubber')
for row in range(7):
 for col in range(5):cylinder('speaker_perforation',(1.598+col*.025,.948+row*.022,-1.143),(1.598+col*.025,.948+row*.022,-1.139),.004,'aged_steel',segments=6)
box('radio_dial_window',(1.84,1.066,-1.148),(.16,.068,.010),'rubber');face('radio_channel',(1.84,1.066,-1.141),(.148,.055),'radio')
for x in [1.79,1.92]:
 cylinder('radio_knob',(x,.972,-1.143),(x,.972,-1.124),.026,'rubber',segments=20);box('knob_marker',(x,.987,-1.122),(.004,.009,.002),'cream',bevel=0)
# Raised lip of the metal tray holds the spare ceramic fuses.
for z in [-1.677,-1.442]:box('tray_lip',(.91,y+.041,z),(.42,.032,.008),'aged_steel')
for x in [.704,1.116]:box('tray_lip',(x,y+.041,-1.56),(.008,.032,.25),'aged_steel')
box('relay_placard',(0,1.02,-2.083),(.57,.29,.016),'painted_steel');face('relay_label',(0,1.02,-2.07),(.55,.27),'relay');export('lookout_workbench')
for i in range(5):box('door_plaque',(0,2.58,2.70),(.76,.29,.028),'painted_steel');face('home_identity',(0,2.58,2.719),(.71,.25),'home_'+str(i));export('home_identity_'+str(i))
box('service_post',(0,1.08,0),(.13,2.16,.13),'timber');box('service_board',(0,1.83,.02),(1.2,.48,.07),'painted_steel');face('service_track',(0,1.83,.059),(1.14,.43),'relay');export('lookout_wayfinding')

# Replace only the old undifferentiated food blocks in the detail variant.
import sys
sys.path.insert(0,str(Path(__file__).parent))
import gen_store
shell=gen_store.build(include_placeholder_stock=False)
bpy.ops.object.select_all(action='DESELECT');shell.select_set(True)
p=bpy.context.view_layer.objects.active=shell
bpy.ops.export_scene.gltf(filepath=str(RUNTIME/'store_shell.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'store_shell.blend'))
path=RUNTIME/'store_shell.glb'
receipt['store_shell']={'triangles':sum(len(p.vertices)-2 for p in shell.data.polygons),'mesh_groups':[shell.name],'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'route_identity.json').write_text(json.dumps({'source':'tools/blender/gen_route_identity.py','source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'graphics':'tools/route/generate_route_graphics.py','graphics_source_sha256':hashlib.sha256((ROOT/'tools/route/generate_route_graphics.py').read_bytes()).hexdigest(),'graphics_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((OUT/'textures').glob('*.png'))},'license':'Original project-authored geometry and graphics','units':'metres','assets':receipt},indent=2)+'\n')
print('ROUTE_IDENTITY_COMPLETE',json.dumps(receipt),flush=True)
