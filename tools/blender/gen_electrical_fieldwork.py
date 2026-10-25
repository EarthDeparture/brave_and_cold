"""Original finite electrical stock. Metres, bounded meshes, packed native sources."""
from pathlib import Path
import bpy,math,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text();exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/electrical_fieldwork';RT=R/'brave-and-cold/assets/electrical_fieldwork'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
base_export=export
def top_label(name,at,size,image,parent=None):
 x,y,z=at;w,d=size;me=bpy.data.meshes.new(name)
 me.from_pydata([cv(v) for v in [(x-w/2,y,z+d/2),(x+w/2,y,z+d/2),(x+w/2,y,z-d/2),(x-w/2,y,z-d/2)]],[],[(0,1,2,3)]);me.update();uv=me.uv_layers.new()
 for i,xy in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=xy
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);M[name]=mat(name,(1,1,1),texture=OUT/(image+'.png'));return finish(o,name,parent)
def export(name):
 bpy.context.view_layer.update();pts=[]
 for o in bpy.context.scene.objects:
  if o.type=='MESH':
   for v in o.data.vertices:
    p=o.matrix_world@v.co;pts.append((p.x,p.z,-p.y))
 lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 base_export(name);e=receipt[name];e['source']=f'tools/blender/generated/electrical_fieldwork/{name}.blend'
 e['bounds_min_xyz']=lo;e['bounds_max_xyz']=hi;e['dimensions_m']=[hi[i]-lo[i] for i in range(3)]
 assert e['triangles']<6500,(name,e['triangles'])
def fuse(at=(0,0,0),parent=None):
 x,y,z=at
 cyl('CeramicBody',(x-.022,y+.009,z),(x+.022,y+.009,z),.007,'cream',16,parent)
 for dx in [-.025,.025]:cyl('ConductingEnd',(x+dx-.004,y+.009,z),(x+dx+.004,y+.009,z),.008,'steel',16,parent)
def connectors(at=(0,0,0),parent=None):
 x,y,z=at
 for dz in [-.025,.025]:
  cyl('SealedPlug',(x-.042,y+.016,z+dz),(x+.032,y+.016,z+dz),.012,'rubber',16,parent)
  cyl('LockingRing',(x+.005,y+.016,z+dz),(x+.017,y+.016,z+dz),.015,'steel',16,parent)
  cyl('CopperContact',(x+.032,y+.016,z+dz),(x+.040,y+.016,z+dz),.005,'ochre',12,parent)
def controller(at=(0,0,0),parent=None):
 x,y,z=at
 box('CastHousing',(x,y+.053,z),(.25,.09,.15),'forest_enamel',.012,parent)
 for dx in [-.095,-.066,-.037,0,.037,.066,.095]:box('CoolingFin',(x+dx,y+.012,z),(.012,.024,.142),'steel',.002,parent)
 for dx in [-.114,.114]:
  for dz in [-.062,.062]:cyl('CoverBolt',(x+dx,y+.095,z+dz),(x+dx,y+.103,z+dz),.005,'steel',12,parent)
 # Rotate printwork into the upward-facing housing plane.
 top_label('controller_marking',(x,y+.099,z),(.19,.112),'controller',parent)
 # Use a flat small identity panel; top is the primary close-up read.
 box('TerminalBlock',(x,y+.048,z+.094),(.17,.034,.042),'rubber',.003,parent)
 for dx in [-.056,-.018,.018,.056]:
  cyl('TerminalScrew',(x+dx,y+.059,z+.094),(x+dx,y+.069,z+.094),.005,'steel',12,parent)
def coil(at=(0,0,0),parent=None):
 x,y,z=at
 # Continuous helical cable with joined segments and a short loose end.
 pts=[]
 for i in range(145):
  a=i/144*math.tau*3;pts.append((x+math.cos(a)*.17,y+.025+i/144*.055,z+math.sin(a)*.17))
 for i in range(len(pts)-1):cyl('InsulatedLead',pts[i],pts[i+1],.007,'rubber',8,parent)
 for xx in [-.11,.11]:box('ReusableStrap',(x+xx,y+.05,z),(.022,.08,.27),'ochre',.002,parent)
 cyl('LooseLead',pts[-1],(x+.245,y+.04,z+.08),.007,'rubber',8,parent)
 connectors((x+.27,y+.022,z+.08),parent)
fuse();export('dc_fuse')
connectors();export('sealed_connector')
controller();export('winter_controller')
coil();export('dc_cable')
box('WaxedPacket',(0,.019,0),(.23,.038,.15),'cream',.004)
top_label('packet_marking',(0,.0385,0),(.21,.13),'packet')
for xx in [-.11,.11]:box('FoldedEnd',(xx,.026,0),(.012,.020,.148),'ochre',.003)
fuse((-.028,.039,.025));connectors((.012,.039,-.03));export('spare_packet')
box('ServiceCase',(0,.026,0),(.40,.052,.29),'forest_enamel',.009)
box('FittedFoam',(0,.055,0),(.37,.024,.26),'rubber',.005)
for x in [-.16,.16]:box('CaseCorner',(x,.038,.134),(.045,.05,.024),'steel',.004)
stock=empty('ControllerStock',(0,0,0));controller((0,.060,0),stock)
box('OpenLid',(0,.097,-.142),(.40,.14,.024),'forest_enamel',.006)
label('case_marking',(0,.099,-.128),(.36,.12),'controller')
export('controller_case')
box('SlateBacking',(0,.008,0),(.40,.016,.31),'timber',.005)
box('Paper',(0,.018,0),(.37,.002,.28),'cream',0)
# Stock text is a live Label3D, while the printed issue masthead remains authored.
top_label('slate_masthead',(0,.0201,0),(.37,.28),'slate')
box('Clip',(0,.022,-.132),(.10,.015,.026),'steel',.003);export('delivery_slate')
receipt['provenance']={'license':'Original project-authored geometry and generated printwork; existing original timber texture reused','seed':7107,'units':'metres','blender':bpy.app.version_string,'generator_sha256_lf':hashlib.sha256(Path(__file__).read_text().replace('\r\n','\n').encode()).hexdigest(),'graphics_generator_sha256_lf':hashlib.sha256(Path(__file__).with_name('gen_electrical_graphics.py').read_text().replace('\r\n','\n').encode()).hexdigest()}
receipt['graphics']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}
receipt['dependencies']={'helper_source':'tools/blender/gen_first_week.py','helper_sha256_lf':hashlib.sha256(Path(__file__).with_name('gen_first_week.py').read_text().replace('\r\n','\n').encode()).hexdigest(),'timber_texture':'brave-and-cold/assets/environment_detail/textures/timber_alb.png','timber_sha256':hashlib.sha256(wood.read_bytes()).hexdigest()}
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
print('ELECTRICAL_ASSETS',json.dumps(receipt))
