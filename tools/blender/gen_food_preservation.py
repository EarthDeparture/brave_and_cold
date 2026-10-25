"""Original stove-adjacent 4-portion rack and dried portion. Metres, packed Blender sources."""
from pathlib import Path
import bpy, math, json, hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text(encoding='utf8');exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/food_preservation';RT=R/'brave-and-cold/assets/food_preservation'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
M['dried']=mat('dried_fibres',(1,1,1),.92,0,OUT/'dried_fibres.png')
M['rack_steel']=mat('worn_galvanized',(.28,.32,.29),.65,.58)
base_export=export
def export(name):
 bpy.context.view_layer.update();pts=[]
 for o in bpy.context.scene.objects:
  if o.type=='MESH':
   for v in o.data.vertices:
    p=o.matrix_world@v.co;pts.append((p.x,p.z,-p.y))
 lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 base_export(name);e=receipt[name];e['source']=f'tools/blender/generated/food_preservation/{name}.blend'
 e['bounds_min_xyz']=lo;e['bounds_max_xyz']=hi;e['dimensions_m']=[hi[i]-lo[i] for i in range(3)]
 assert e['triangles']<12000,(name,e['triangles'])
def strip(name,at,parent=None,seed=0):
 # Curved, tapered and uneven cut meat, not a box or disconnected finger-like capsules.
 x,y,z=at;vs=[];fs=[];segments=10;rings=9
 for j in range(rings):
  t=j/(rings-1);width=.022*(.68+.30*math.sin(t*math.pi))*(1+.09*math.sin(j*1.9+seed))
  for i in range(segments):
   a=i*math.tau/segments;vs.append(cv((x+width*math.cos(a)+.007*math.sin(t*4+seed),y+t*.21,z+.007*math.sin(a)+.007*math.sin(t*5+seed))))
 for j in range(rings-1):
  for i in range(segments):fs.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
 fs.extend([tuple(reversed(range(segments))),tuple((rings-1)*segments+i for i in range(segments))])
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new()
 for poly in me.polygons:
  poly.use_smooth=len(poly.vertices)==4
  for loop in poly.loop_indices:
   idx=me.loops[loop].vertex_index;uv.data[loop].uv=((idx%segments)/segments,(idx//segments)/(rings-1))
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);finish(o,'dried',parent)
# Wall cabinet with ventilated mesh front, heat shield and accessible lift latch.
box('BackHeatShield',(0,.33,-.137),(.54,.66,.016),'rack_steel',.005)
for x in [-.258,.258]:box('FoldedSide',(x,.33,0),(.025,.66,.28),'forest_enamel',.006)
for y in [.012,.648]:box('FoldedTopBottom',(0,y,0),(.52,.024,.28),'forest_enamel',.004)
for x in [-.225,.225]:
 box('WallBracket',(x,.33,-.159),(.06,.76,.024),'rack_steel',.004)
 for y in [-.013,.674]:cyl('MountScrew',(x,y,-.14),(x,y,-.118),.012,'steel',16)
for y in [.12,.37,.61]:
 for z in [-.10,-.04,.02,.08]:cyl('TrayWire',(-.236,y,z),(.236,y,z),.0025,'steel',8)
 for x in [-.20,-.10,0,.10,.20]:cyl('TrayCrossWire',(x,y,-.11),(x,y,.10),.0025,'steel',8)
for i in range(4):
 p=empty('Portion%d'%i,(0,0,0));xx=-.176+(i%2)*.34;yy=.15+(i//2)*.25
 for j in range(3):
  strip('SlicedPortion',(xx+(j-1)*.032,yy,-.008),p,i*5+j)
  xhook=xx+(j-1)*.032+.007*math.sin(4+i*5+j)
  cyl('PortionHook',(xhook,yy+.208,-.008),(xhook,yy+.222,.022),.0016,'steel',8,p)
door=empty('RackDoor',(-.25,.33,.147))
for x in [-.238,.238]:box('DoorFrame',(x,.33,.146),(.024,.63,.026),'rack_steel',.004,door)
for y in [.026,.633]:box('DoorFrame',(0,y,.146),(.49,.024,.026),'rack_steel',.004,door)
# Bounded coarse wire mesh: opaque wires avoid transparency sorting and reveal contents.
for x in [-.205+i*.034 for i in range(13)]:cyl('DoorVerticalWire',(x,.05,.145),(x,.61,.145),.0013,'rack_steel',6,door)
for y in [.06+i*.035 for i in range(16)]:cyl('DoorHorizontalWire',(-.22,y,.146),(.22,y,.146),.0013,'rack_steel',6,door)
for y in [.12,.52]:cyl('DoorHinge',(-.266,y-.024,.14),(-.266,y+.024,.14),.013,'steel',12,door)
cyl('LiftLatch',(.27,.29,.16),(.27,.37,.16),.009,'steel',12,door)
box('PlateBacking',(0,.727,.014),(.44,.157,.023),'forest_enamel',.003)
label('rack_instructions',(0,.727,.026),(.427,.142),'rack_plate')
export('stove_drying_rack')
for j in range(3):strip('DriedStrip',((j-1)*.042,0,0),None,j)
# Export standing strips for pickup, then rotate the prop at spawn to lie flat.
export('dried_portion')
receipt['provenance']={'license':'Original project-authored geometry and deterministic printwork/fibre textures; no third-party assets','seed':7108,'units':'metres','blender':bpy.app.version_string}
for file in ['gen_food_preservation.py','gen_food_graphics.py','gen_first_week.py']:
 receipt.setdefault('generators',{})[file]=hashlib.sha256(Path(__file__).with_name(file).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest()
receipt['graphics']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
print('FOOD_ASSETS',json.dumps(receipt))
