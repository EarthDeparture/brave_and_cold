"""Original route dressing, metres in authored Godot coordinates. No downloads."""
import bpy, json, hashlib, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'tools/blender/generated/lookout_opening';RUNTIME=ROOT/'brave-and-cold/assets/lookout_opening';OUT.mkdir(parents=True,exist_ok=True);RUNTIME.mkdir(parents=True,exist_ok=True)
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
 points=[o.matrix_world@v.co for o in objects for v in o.data.vertices];lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
 receipt[name]={'bounds_blender_m':[lo,hi],'native_source':'tools/blender/generated/lookout_opening/'+name+'.blend','triangles':triangles,'mesh_groups':[o.name for o in objects],'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);PARTS.clear()

# Texture-supported original cabinet, relay mast and occupation detail.
M['snow']=material('packed_snow',(.73,.80,.85),.98)
M['concrete']=material('concrete',(.42,.45,.43),.98)
M['ceramic']=material('ceramic',(.54,.57,.52),.33)
M['blue_canvas']=material('blue_canvas',(.12,.20,.23),.96)
M['amber']=material('amber_lens',(.65,.27,.025),.28)
# Three-legged lattice mast: 8.8 m, grounded shoes, 2 m wide lower footprint.
legs=[(-1.04,-1.1),(1.04,-1.1),(0,-2.15)]
for x,z in legs:
 box('concrete_shoe',(x,.07,z),(.38,.14,.38),'concrete',bevel=.025)
 box('base_plate',(x,.15,z),(.28,.025,.28),'aged_steel')
 for xx in [-.10,.10]:
  for zz in [-.10,.10]:cylinder('anchor_bolt',(x+xx,.16,z+zz),(x+xx,.21,z+zz),.012,'brass',segments=8)
 cylinder('mast_leg',(x,.17,z),(x*.18,8.8,-1.45+(z+1.45)*.18),.045,'aged_steel')
for h in range(9):
 t=h/9;u=(h+1)/9
 for j in range(3):
  a=legs[j];b=legs[(j+1)%3]
  aa=(a[0]*(1-t*.82),h+.18,-1.45+(a[1]+1.45)*(1-t*.82))
  bb=(b[0]*(1-t*.82),h+.18,-1.45+(b[1]+1.45)*(1-t*.82))
  cc=(b[0]*(1-u*.82),h+1.05,-1.45+(b[1]+1.45)*(1-u*.82))
  cylinder('ring_brace',aa,bb,.021,'aged_steel',segments=8)
  cylinder('diagonal',aa,cc,.017,'aged_steel',segments=8)
# Antenna hardware, lightning rod, grounded cable and ceramic isolators.
cylinder('lightning_rod',(0,8.2,-1.45),(0,9.7,-1.45),.021,'aged_steel')
for h in [7.5,8.15]:
 cylinder('antenna_boom',(-.25,h,-1.45),(1.3,h,-1.45),.025,'aged_steel')
 for k in range(5):cylinder('yagi_element',(.2+k*.23,h,-1.77),(.2+k*.23,h,-1.13),.009,'aged_steel',segments=8)
cord('antenna_feed',[(.1,8.15,-1.45),(.20,5,-1.3),(.85,.4,-1.1),(.55,.5,-.2)],.013,'rubber')
cord('ground_bond',[(0,9,-1.45),(-1,1,-1.1),(-1,.10,-1.1),(-1.35,.02,-.75)],.008,'brass')
# Maintained cabinet: folded doors, seam, hinges, glands, lockout tag, readable plate.
box('cabinet',(0,.91,0),(1.24,1.36,.82),'painted_steel',bevel=.025)
for x in [-.45,.45]:box('cabinet_foot',(x,.13,0),(.14,.26,.52),'aged_steel')
box('door',(0,.95,.425),(1.17,1.20,.034),'painted_steel',bevel=.012)
box('roof_cap',(0,1.625,0),(1.35,.055,.94),'aged_steel')
box('snow_lip',(0,1.666,-.09),(1.30,.035,.75),'snow',bevel=.013)
for x in [-.50,.50]:
 for y in [.55,1.35]:box('hinge',(x,y,.451),(.045,.10,.03),'aged_steel',bevel=.005)
box('latch',(.44,.95,.466),(.045,.17,.026),'aged_steel')
face('transfer_plate',(-.12,1.08,.446),(.74,.48),'cabinet')
face('hazard_label',(.25,.56,.446),(.40,.16),'hazard')
for y in [.65,.69,.73,.77]:box('vent',(-.37,y,.446),(.23,.012,.007),'rubber',bevel=0)
box('tag',(.43,.80,.489),(.10,.17,.005),'red_lead',bevel=.001)
cord('tag_tie',[(.44,.87,.47),(.46,.91,.49),(.42,.96,.47)],.002,'rubber')
for x in [-.24,.24]:cylinder('gland',(x,.37,-.42),(x,.37,-.51),.037,'rubber')
box('battery_box',(-.92,.38,-.35),(.43,.59,.58),'painted_steel')
face('battery_plate',(-.92,.42,-.052),(.31,.25),'battery')
# Snow foundations are shoes only: the existing terrain is untouched.
export('relay_station')
# Textile blanket: 45 x 61 sculpted mesh, draped edge folds rather than a flat slab.
vs=[];faces=[];nx,nz=45,61
for iz in range(nz):
 z=-1.50+iz/(nz-1)*1.55
 for ix in range(nx):
  x=-2.19+ix/(nx-1)*1.18
  edge=max(0,abs(x+1.60)-.48)
  y=.805-edge*.36+.010*math.sin(z*31+x*16)+.013*math.sin(z*13)*math.cos(x*22)
  vs.append(cv((x,y,z)))
for iz in range(nz-1):
 for ix in range(nx-1):
  a=iz*nx+ix;faces.append((a+nx,a+nx+1,a+1,a))
me=bpy.data.meshes.new('quilt');me.from_pydata(vs,[],faces);me.update()
for poly in me.polygons:poly.use_smooth=True
uv=me.uv_layers.new(name='UVMap')
for loop in me.loops:
 i=loop.vertex_index;uv.data[loop.index].uv=(i%nx/(nx-1)*3,i//nx/(nz-1)*4)
o=bpy.data.objects.new('WovenQuilt',me);bpy.context.collection.objects.link(o);add(o,'Bedding',label_mat('cloth'))
for z in [-1.41,-1.05,-.68,-.31]:
 pts=[(-2.19+i*.059,.823+.004*math.sin(i),z) for i in range(21)]
 cord('quilt_seam',pts,.0018,'canvas')
# Supplies fit within the original rack; visual groups are hideable when depleted.
for i in range(4):
 x=1.52+i*.23
 cylinder('tin',(x,.52,1.62),(x,.69,1.62),.065,'aged_steel','PantryFood',24)
 wrapped_label('ration_label',(x,.605,1.62),.0658,.14,'rations','PantryFood')
for x in [1.58,1.98]:box('canvas_pouch',(x,.93,1.62),(.32,.19,.25),'canvas','PantryFood',bevel=.035)
# Folded wool, stove kettle and split logs remain inside existing furniture footprints.
box('folded_wool',(1.87,1.25,1.62),(.75,.14,.25),'blue_canvas','PantryFixed',bevel=.025)
for i in range(6):
 x=1.49+i%3*.28;y=.15+(i//3)*.12
 cylinder('split_firewood',(x,y,1.49),(x,y,1.76),.058,'timber','HomeWood',8)
cylinder('kettle_body',(-1.61,.726,1.20),(-1.61,.92,1.20),.12,'aged_steel','StoveDetail',24)
cylinder('kettle_lid',(-1.61,.93,1.20),(-1.61,.946,1.20),.11,'aged_steel','StoveDetail',24)
cylinder('lid_knob',(-1.61,.95,1.20),(-1.61,.98,1.20),.022,'rubber','StoveDetail')
cord('kettle_bail',[(-1.73,.86,1.20),(-1.72,1.08,1.20),(-1.50,1.08,1.20),(-1.49,.86,1.20)],.007,'aged_steel')
# New rounded pillow slips over the original rectangular insert.
box('pillow',(-1.60,.83,-1.70),(.87,.21,.40),'cream','Bedding',bevel=.075)
# Stove window frame and grate; emission is driven in Godot, independent of electricity.
for x in [-1.786,-1.514]:box('stove_window_frame',(x,.42,1.495),(.018,.21,.015),'aged_steel','StoveDetail',bevel=.002)
for y in [.32,.52]:box('stove_window_frame',(-1.65,y,1.495),(.29,.015,.015),'aged_steel','StoveDetail',bevel=.002)
for x in [-1.72,-1.65,-1.58]:box('stove_grate',(x,.42,1.505),(.009,.19,.012),'aged_steel','StoveDetail',bevel=.001)
# Service log on the available left section of the existing desk.
box('log_folder',(.73,.861,-1.34),(.39,.018,.48),'canvas','ServiceLog')
face('service_log',(.73,.872,-1.34),(.36,.44),'log','ServiceLog',up=True)
cylinder('pencil',(.94,.881,-1.48),(.94,.881,-1.13),.003,'cream','ServiceLog',8)
export('lookout_home_detail')
# Reserved replacement: moulded transit case, seam, catches and durable printed tag.
box('case_body',(0,.10,0),(.38,.20,.26),'painted_steel',bevel=.018)
box('case_lid',(0,.21,0),(.40,.055,.28),'painted_steel',bevel=.012)
for x in [-.14,.14]:
 box('catch',(x,.19,.148),(.044,.045,.025),'aged_steel',bevel=.004)
 box('rear_hinge',(x,.195,-.147),(.05,.03,.025),'aged_steel',bevel=.004)
cord('carry_handle',[(-.07,.10,.155),(-.07,.10,.20),(.07,.10,.20),(.07,.10,.155)],.009,'rubber')
face('reservation_tag',(0,.241,0),(.33,.23),'reserved',up=True)
export('depot_reserved_case')
# Open lattice gate: pivot at its left post, same 3 m aperture as runtime collision.
for x in [0,3]:cylinder('gate_upright',(x,.12,0),(x,1.76,0),.035,'aged_steel')
for y in [.15,1.73]:cylinder('gate_rail',(0,y,0),(3,y,0),.025,'aged_steel')
for slope in [-1,1]:
 for k in range(-9,25):
  x0=k*.16;low=max(0,-x0/slope) if slope>0 else max(0,(x0-3)/-slope)
  high=min(1.56,(3-x0)/slope) if slope>0 else min(1.56,x0/-slope)
  if high<=low:continue
  cylinder('diamond_wire',(x0+slope*low,.16+low,0),(x0+slope*high,.16+high,0),.002,'aged_steel',segments=6)
box('gate_sign',(1.5,1.12,.026),(.66,.31,.022),'painted_steel')
face('keep_gate_shut',(1.5,1.12,.042),(.62,.27),'gate')
export('refuge_gate')
receipt['source']={'generator':'tools/blender/gen_lookout_opening.py','license':'Original project-authored geometry and graphics; no third-party assets','seed':20261004,'coordinate_units':'metres','runtime':'Godot GLB','blender':bpy.app.version_string}
receipt['source']['generator_sha256']=hashlib.sha256(Path(__file__).read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest()
receipt['source']['graphics_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((OUT/'textures').glob('*.png'))}
(RUNTIME/'manifest.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('LOOKOUT_ASSETS_EXPORTED',json.dumps(receipt))
