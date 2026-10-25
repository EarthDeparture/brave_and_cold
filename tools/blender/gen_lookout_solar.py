"""Original 120 W winter rack: metre-scale, editable native source and GLB."""
from pathlib import Path
import bpy,math,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text();exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/lookout_solar';RT=R/'brave-and-cold/assets/lookout_solar'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
M['pv']=mat('weathered_solar_cells',(1,1,1),rough=.37,metal=.15,texture=OUT/'pv_cells.png')
M['print']=mat('local_charger_identification',(1,1,1),texture=OUT/'charger_plate.png')
M['steel'].diffuse_color=(.26,.31,.29,1)
angle=math.radians(30);cy=1.33
def plane(cx,u,v,n=0):return (cx+u,cy+math.cos(angle)*v+math.sin(angle)*n,-math.sin(angle)*v+math.cos(angle)*n)
def slab(name,cx,u,v,size,material):
 o=box(name,plane(cx,u,v),size,material,.004);o.rotation_euler.x=-angle;return o
def quad(name,pts,material,uv=True,parent=None):
 me=bpy.data.meshes.new(name);me.from_pydata([cv(v) for v in pts],[],[(0,1,2,3)]);me.update()
 if uv:
  layer=me.uv_layers.new()
  for i,xy in enumerate([(0,0),(1,0),(1,1),(0,1)]):layer.data[i].uv=xy
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(M[material])
 if parent:o.parent=parent
 return o
for cx,side in [(-.60,'Left'),(.60,'Right')]:
 slab('PanelBacking',cx,0,0,(1.12,1.78,.033),'forest_enamel')
 quad('PhotovoltaicCells', [plane(cx,-.529,-.84,.021),plane(cx,.529,-.84,.021),plane(cx,.529,.84,.021),plane(cx,-.529,.84,.021)],'pv')
 for u in [-.55,.55]:slab('ExtrudedSideFrame',cx,u,0,(.025,1.79,.043),'steel')
 for v in [-.88,.88]:slab('ExtrudedEndFrame',cx,0,v,(1.1,.025,.043),'steel')
 for u in [-.51,.51]:
  for v in [-.835,.835]:
   a=plane(cx,u,v,.025);b=plane(cx,u,v,.033);cyl('RetainingBolt',a,b,.007,'steel',12)
 # Snow geometry uses local panel axes; runtime scales height from the lower edge.
 snow=empty('Snow'+side,plane(cx,0,-.85,.029));snow.rotation_euler.x=-angle
 # A thick, uneven snow layer, with a broken leading edge and broad drifts.
 # Flat opaque cards were rejected in the first actual-renderer review.
 me=bpy.data.meshes.new('SnowSurface');verts=[];faces=[];nx=12;ny=9
 for j in range(ny+1):
  for i in range(nx+1):
   u=-.523+1.046*i/nx;t=j/ny
   top=1.65+.055*math.sin(i*1.7+(0 if side=='Left' else 1.2))
   v=t*top;lift=.012+.045*math.sin(t*math.pi)**2+.014*(.5+.5*math.sin(u*12+v*6))
   verts.append((u,v,lift))
 for j in range(ny):
  for i in range(nx):
   a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
 perimeter=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+list(range(ny*(nx+1)+nx-1,ny*(nx+1)-1,-1))+[j*(nx+1) for j in range(ny-1,0,-1)]
 for k,a in enumerate(perimeter):
  b=perimeter[(k+1)%len(perimeter)];aa=len(verts);verts.extend([(verts[a][0],verts[a][1],0),(verts[b][0],verts[b][1],0)]);faces.append((a,aa,aa+1,b))
 me.from_pydata([cv(v) for v in verts],[],faces);me.update();o=bpy.data.objects.new('SnowSurface',me);bpy.context.collection.objects.link(o);o.data.materials.append(M['snow']);o.parent=snow
for x in [-1.12,1.12]:
 for z in [-.42,.42]:
  top=.61 if z>0 else 2.05
  box('GalvanisedLeg',(x,(top+.18)/2,z),(.052,top-.18,.052),'steel',.003)
  box('DiscreteFoot',(x,.17,z),(.18,.035,.18),'steel',.004)
 cyl('TriangularBrace',(x,.27,.42),(x,1.85,-.42),.016,'steel',12)
for z,y in [(.42,.56),(-.42,1.98)]:box('MountingRail',(0,y,z),(2.38,.055,.055),'steel',.003)
box('LowerBrace',(0,.3,-.42),(2.3,.04,.04),'steel',.002)
for x in [-1.12,1.12]:cyl('BraceBolt',(x,.56,.39),(x,.56,.47),.009,'steel',12)
box('ControllerHousing',(1.02,1.1,.48),(.40,.54,.16),'forest_enamel',.012)
box('ControllerFront',(1.02,1.1,.569),(.36,.50,.017),'steel',.005)
quad('ChargerPlate',[(.857,1.10,.579),(1.183,1.10,.579),(1.183,1.33,.579),(.857,1.33,.579)],'print')
box('StatusWindow',(1.02,.995,.582),(.34,.10,.008),'rubber',.003)
for y in [.865,1.335]:cyl('ControllerFastener',(.864,y,.578),(.864,y,.588),.008,'steel',12)
for x in [.96,1.08]:
 cyl('CableGland',(x,.77,.48),(x,.84,.48),.017,'rubber',16)
 for a,b in [((x,.77,.48),(x,.47,.48)),((x,.47,.48),(x-.22,.24,.2)),((x-.22,.24,.2),(-.75,.21,-.38))]:cyl('InsulatedCable',a,b,.010,'rubber',12)
# Connectors remain separately named for future maintenance animations.
connector=empty('PVDisconnect',(1.0,.81,.48));box('DisconnectBody',(1,.82,.48),(.16,.08,.06),'ochre',.005,connector)
bpy.context.view_layer.update()
coords=[]
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':
  for v in ob.data.vertices:
   p=ob.matrix_world@v.co;coords.append((p.x,p.z,-p.y))
lo=[min(p[i] for p in coords) for i in range(3)];hi=[max(p[i] for p in coords) for i in range(3)]
export('relay_solar_array')
entry=receipt['relay_solar_array'];entry['source']='tools/blender/generated/lookout_solar/relay_solar_array.blend';entry['measured_bounds_min_xyz']=lo;entry['measured_bounds_max_xyz']=hi;entry['measured_dimensions_m']=[hi[i]-lo[i] for i in range(3)];entry['rated_w']=120;entry['snow_nodes']=['SnowLeft','SnowRight'];entry['collisions']='Runtime physical-rack rectangle plus surveyed foot extensions; no ground slab.'
receipt['provenance']={'license':'Original project-authored geometry and generated printwork','seed':7106,'units':'metres','blender':bpy.app.version_string,'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'graphics_generator_sha256':hashlib.sha256(Path(__file__).with_name('gen_solar_graphics.py').read_bytes()).hexdigest()}
receipt['graphics']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'pv_cells.png',OUT/'charger_plate.png']}
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('SOLAR_ASSET',json.dumps(entry))
