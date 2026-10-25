"""Original metre-scale maintenance gate, route markers and shoulder drainage kit."""
from pathlib import Path
import bpy,math,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text(encoding='utf8');exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/route_detail';RT=R/'brave-and-cold/assets/route_detail';receipt={};clear()
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
M['steel']=mat('weathered_galvanized',(.30,.35,.34),.64,.7)
M['rust']=mat('hardware_oxidation',(.24,.12,.055),.88,.25)
M['stone']=mat('cold_concrete',(.36,.39,.38),.94,0,texture=RT/'textures/concrete_alb.png')
M['pebble']=mat('cold_gravel',(.3,.32,.32),.94,0,texture=RT/'textures/gravel_alb.png')
M['dark']=mat('culvert_interior',(.018,.025,.022),1,0)
def save(name):
 bpy.context.view_layer.update();points=[]
 for o in bpy.context.scene.objects:
  if o.type=='MESH':
   for v in o.data.vertices:
    p=o.matrix_world@v.co;points.append((p.x,p.z,-p.y))
 lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
 export(name);e=receipt[name];e['source']='tools/blender/generated/route_detail/'+name+'.blend'
 e['bounds_min_xyz']=lo;e['bounds_max_xyz']=hi;e['dimensions_m']=[hi[i]-lo[i] for i in range(3)]
 assert e['triangles']<6500 and e['mesh_nodes']<=6
# A rigid three-metre leaf rotates as one assembly about its left hinge.
for x in [.065,2.975]:cyl('Frame',(x,.14,0),(x,1.76,0),.031,'steel',16)
for yy in [.15,1.73]:cyl('Rail',(.065,yy,0),(2.975,yy,0),.029,'steel',16)
for slope in [-1,1]:
 for k in range(-9,25):
  x0=k*.16;low=max(0,-x0/slope) if slope>0 else max(0,(x0-2.91)/-slope)
  high=min(1.56,(2.91-x0)/slope) if slope>0 else min(1.56,x0/-slope)
  if high>low:cyl('DiamondWire',(.065+x0+slope*low,.16+low,0),(.065+x0+slope*high,.16+high,0),.0025,'steel',5)
for yy in [.34,1.45]:
 cyl('HingePin',(0,yy-.075,0),(0,yy+.075,0),.024,'steel',16)
 cyl('HingeArm',(0,yy,0),(.09,yy,0),.021,'rust',12)
 box('HingeClamp',(.095,yy,0),(.055,.13,.075),'steel',.005)
 for z in [-.042,.042]:cyl('ClampBolt',(.095,yy,z-.005),(.095,yy,z+.005),.013,'steel',6)
box('LatchPlate',(2.92,1.04,.04),(.16,.19,.035),'steel',.005)
cyl('LatchHandle',(2.85,1.02,.083),(2.98,1.02,.083),.012,'rust',12)
box('SignPlate',(.68,1.15,.022),(.69,.35,.024),'forest_enamel',.012)
label('GateNotice',(.68,1.15,.037),(.65,.31),'field_gate')
save('compound_gate')
# Markers keep one route identity. Narrow footprint leaves the walking lane free.
box('WeatheredPost',(0,.68,0),(.12,1.36,.12),'timber',.008)
box('OrangeCollar',(0,1.13,0),(.125,.07,.125),'ochre',.003)
box('Plate',(0,1.36,.071),(.22,.30,.018),'forest_enamel',.008)
label('RouteNotice',(0,1.36,.081),(.20,.28),'field_marker')
box('SnowCap',(0,1.523,.015),(.25,.022,.19),'snow',.010)
save('service_marker')
# Low, visibly open drain headwall; no hidden tube across the walkable corridor.
wall=box('Headwall',(0,.31,0),(1.12,.62,.34),'stone',.018)
cutter=cyl('TemporaryRoundOpening',(0,.28,-.4),(0,.28,.4),.236,'dark',32)
bpy.context.view_layer.objects.active=wall;wall.select_set(True)
mod=wall.modifiers.new('Actual circular drainage opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
# Open pipe lining: four radial loops, no square black card behind a round rim.
vs=[];fs=[];n=32
for z,rr in [(-.17,.241),(.175,.241),(.175,.220),(-.17,.220)]:
 for k in range(n):vs.append(cv((rr*math.cos(k*math.tau/n),.28+rr*math.sin(k*math.tau/n),z)))
for j in range(4):
 for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,((j+1)%4)*n+(k+1)%n,((j+1)%4)*n+k))
me=bpy.data.meshes.new('open_culvert_lining');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('PipeLining',me);bpy.context.collection.objects.link(o);finish(o,'steel')
for face in me.polygons:face.use_smooth=True
cyl('DeepPipeShadow',(0,.28,-.178),(0,.28,-.184),.219,'dark',32)
for x in [-.12,0,.12]:
 height=math.sqrt(.218**2-x*x)
 cyl('DrainGuard',(x,.28-height,.11),(x,.28+height,.11),.007,'steel',10)
box('SnowLip',(0,.62,0),(1.12,.022,.35),'snow',.010)
save('drain_headwall')
# Sparse cut branches and grit for shoulders, not walking obstacles.
for i in range(5):
 x=(i-2)*.11;z=math.sin(i*2)*.15
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=cv((x,.028,z)));o=bpy.context.object;o.scale=(.06+.015*(i%3),.04,.025);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,'pebble')
for i in range(3):cyl('DryTwig',(-.35+i*.09,.03,-.22),(.15+i*.04,.025,.19),.008,'timber',8)
save('shoulder_debris')
receipt['provenance']={'source':'Original project-authored metre-scale Blender geometry','license':'Original project assets; no external models','units':'metres','blender':bpy.app.version_string}
receipt['generators']={f:hashlib.sha256(Path(__file__).with_name(f).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest() for f in ['gen_route_detail.py','gen_route_graphics.py','gen_first_week.py']}
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print('ROUTE_ASSETS',json.dumps(receipt))
