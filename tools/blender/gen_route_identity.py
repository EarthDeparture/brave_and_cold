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
def export(name):
 objects=[]
 for group,parts in PARTS.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=group;objects.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 path=RUNTIME/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_animations=False)
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
  x=-2.35+k*.43;z=-1.98;g='ShelfStock';cylinder('food_tin',(x,level-.09,z),(x,level+.09,z),.065,'aged_steel',g,16);cylinder('rolled_lid',(x,level+.086,z),(x,level+.094,z),.069,'aged_steel',g,16);face('food_label',(x,level,z+.066),(.11,.13),'beans',g)
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
for k in range(4):
 x=1.40+k*.23;cylinder('hanging_handle',(x,1.66,-2.057),(x,1.94,-2.057),.023,'timber');cylinder('tool_shaft',(x,1.94,-2.057),(x,2.17,-2.057),.007,'aged_steel');box('tool_head',(x,2.13,-2.05),(.10,.055,.032),'aged_steel')
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
(OUT/'route_identity.json').write_text(json.dumps({'source':'tools/blender/gen_route_identity.py','source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'graphics':'tools/route/generate_route_graphics.py','license':'Original project-authored geometry and graphics','units':'metres','assets':receipt},indent=2)+'\n')
print('ROUTE_IDENTITY_COMPLETE',json.dumps(receipt),flush=True)
