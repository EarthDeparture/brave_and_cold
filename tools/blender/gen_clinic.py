"""Original North Ridge clinic shell, fixtures and finite stock. Metre scale."""
from pathlib import Path
import bpy,math,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text()
exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/clinic';RT=R/'brave-and-cold/assets/clinic';OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
M['floor']=mat('ClinicLinoleum',(.50,.53,.49),.82,texture=OUT/'linoleum.png');M['forest_enamel']=mat('ClinicWeatheredPaint',(.25,.33,.28),.88,texture=OUT/'siding.png')
M['plaster']=mat('warm_plaster',(.69,.70,.63),texture=OUT/'plaster.png');M['red']=mat('clinic_red',(.44,.105,.07));M['cloth']=mat('exam_canvas',(.30,.40,.38),texture=OUT/'cloth.png')
# Solid foundation, raised single continuous floor and vertical siding.
box('Foundation',(0,-.40,0),(10.24,1.40,7.84),'steel',.012)
box('Floor',(0,.25,0),(10,.1,7.6),'floor',.004)
# Front and rear walls have actual full-height door gaps.
for z,g in [(3.8,0),(-3.8,-2.5)]:
 for a,b in [(-5,g-.7),(g+.7,5)]:box('ExteriorWall',((a+b)/2,1.85,z),(b-a,3.10,.20),'forest_enamel',.005)
 box('DoorLintel',(g,2.87,z),(1.4,1.06,.20),'forest_enamel',.005)
# Side windows with real holes.
for x,zz in [(-5,1.5),(5,0)]:
 for a,b in [(-3.8,zz-.7),(zz+.7,3.8)]:box('SideWall',(x,1.85,(a+b)/2),(.20,3.10,b-a),'forest_enamel',.004)
 box('WindowSillWall',(x,.84,zz),(.20,1.08,1.4),'forest_enamel',.004);box('WindowHeadWall',(x,2.80,zz),(.20,1.20,1.4),'forest_enamel',.004)
for x in [-5.12,5.12]:
 for z in [-3.9,3.9]:box('CornerTrim',(x,1.85,z),(.12,3.10,.12),'cream',.003)
for z in [-3.8,3.8]:
 for i in range(13):
  x=-4.8+i*.8
  if z==3.8 and abs(x)<.8 or z<0 and abs(x+2.5)<.8:continue
  box('SidingBatten',(x,1.85,z+( .11 if z>0 else -.11)),(.055,3.10,.025),'cream',.001)
# Interior partitions use broad, unobstructed 1.4 m doorways.
for a,b in [(-3.7,.35),(1.75,3.7)]:box('ExamPartition',(1,1.85,(a+b)/2),(.10,3.1,b-a),'plaster',.003)
box('ExamHeader',(1,2.95,1.05),(.10,.9,1.4),'plaster',.003)
for a,b in [(-4.9,-3.2),(-1.8,.95)]:box('SupplyPartition',((a+b)/2,1.85,-.7),(b-a,3.1,.10),'plaster',.003)
box('SupplyHeader',(-2.5,2.95,-.7),(1.4,.9,.1),'plaster',.003)
# Gable roof planes and snow skin; roof ridge parallel with X.
for side in [-1,1]:
 a=cv((-5.35,3.42,side*4.15));b=cv((5.35,3.42,side*4.15));c=cv((5.35,4.52,0));d=cv((-5.35,4.52,0));me=bpy.data.meshes.new('roof');me.from_pydata([a,b,c,d],[],[(0,1,2,3)] if side<0 else [(3,2,1,0)]);me.update();o=bpy.data.objects.new('SnowRoof',me);bpy.context.collection.objects.link(o);finish(o,'snow');mod=o.modifiers.new('thickness','SOLIDIFY');mod.thickness=.10;bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
# Closed gable end faces; no open roof cavity when viewed from the side.
for x in [-5.05,5.05]:
 me=bpy.data.meshes.new('GableEnd');me.from_pydata([cv(v) for v in [(x,3.38,-3.9),(x,3.38,3.9),(x,4.50,0)]],[],[(0,1,2)] if x>0 else [(2,1,0)]);me.update();o=bpy.data.objects.new('GableEnd',me);bpy.context.collection.objects.link(o);finish(o,'forest_enamel')
box('Ceiling',(0,3.40,0),(10.1,.1,7.7),'plaster',.001)
# Front covered porch; ramps generated against surveyed ground in Godot.
box('FrontPorch',(0,.25,4.3),(3,.1,1.0),'timber',.002)
box('RearStep',(-2.5,.25,-4.3),(2,.1,1.0),'timber',.002)
for x in [-1.3,1.3]:box('PorchPost',(x,1.85,4.7),(.09,3.1,.09),'timber',.002)
box('PorchCanopy',(0,3.40,4.3),(3.3,.12,1.4),'snow',.005)
# Waiting bench and check-in desk, well outside the circulation lane.
for x in [-4.3,-3.6,-2.9]:
 for z in [2.2,2.6]:box('BenchFoot',(x,.52,z),(.06,.44,.06),'steel')
box('BenchSeat',(-3.6,.77,2.4),(2.5,.08,.55),'timber');box('BenchBack',(-3.6,1.06,2.66),(2.5,.48,.06),'timber')
box('CheckInDesk',(-3.2,.78,.03),(2.4,.96,.60),'cream',.018);box('DeskTop',(-3.2,1.28,.03),(2.5,.05,.66),'timber',.01)
# Exam bed, pillow, lamp, tray, sink and cabinet.
for x in [2.5,4.4]:
 for z in [-1.6,-.8]:cyl('ExamBedLeg',(x,.3,z),(x,.89,z),.027,'steel')
box('ExamMattress',(3.45,1.0,-1.2),(2.20,.20,.86),'cloth',.065);box('Pillow',(4.2,1.16,-1.2),(.45,.13,.65),'cream',.035)
cyl('ExamStand',(4.6,.3,1.8),(4.6,2.0,1.8),.035,'steel');cyl('StandArm',(4.6,2,1.8),(4.2,2,1.4),.025,'steel');box('LampHead',(4.2,1.95,1.4),(.25,.12,.25),'cream',.025)
box('SinkCabinet',(3.75,.76,-3.35),(1.9,.92,.50),'cream',.02);box('SinkBasin',(3.75,1.25,-3.35),(.8,.09,.45),'steel',.03);cyl('Tap',(4.1,1.29,-3.4),(4.1,1.53,-3.4),.012,'steel')
# Supply room shelving against rear-left side.
for x in [-4.7,-3.6]:box('ShelfUpright',(x,1.25,-2.65),(.05,1.9,.05),'steel')
for y in [.45,.95,1.45,1.95]:box('Shelf',(-4.15,y,-2.65),(1.16,.04,.55),'cream',.002)
stock=empty('MedicalStock',(0,0,0))
for i in range(5):
 part=empty('DressingUnit'+str(i),(0,0,0));part.parent=stock
 cyl('Dressing',(-4.5+i*.18,.98,-2.65),(-4.5+i*.18,1.10,-2.65),.049,'cream',24,part)
 label('DressingLabel'+str(i),(-4.5+i*.18,1.045,-2.598),(.083,.103),'dressing',part)
stock=empty('TreatmentStock',(0,0,0))
for i in range(2):
 part=empty('AntisepticUnit'+str(i),(0,0,0));part.parent=stock
 cyl('Antiseptic',(-4.45+i*.26,1.48,-2.65),(-4.45+i*.26,1.68,-2.65),.051,'forest_enamel',24,part)
 cyl('BottleCap',(-4.45+i*.26,1.68,-2.65),(-4.45+i*.26,1.71,-2.65),.034,'cream',20,part)
 label('AntisepticLabel'+str(i),(-4.45+i*.26,1.58,-2.597),(.078,.115),'antiseptic',part)
part=empty('AntibioticUnit',(0,0,0));part.parent=stock
box('MedicineCarton',(-3.95,1.54,-2.65),(.12,.11,.13),'cream',.003,part)
stock=empty('MaintenanceStock',(0,0,0));box('RepairKit',(-4.15,.55,-2.65),(.50,.13,.22),'ochre',.008,stock)
# Bound detail to fixtures, leaving all circulation clear.
box('WallChartBacking',(1.065,1.9,-1.40),(.012,.76,.58),'cream',.001)
# Chart plane at rear wall, facing the room.
label('HygieneChart',(3.65,2.03,-3.687),(.65,.88),'chart')
box('BedPaperRoll',(2.52,1.15,-1.2),(.07,.08,.81),'cream',.018)
box('TrayStand',(2.1,.83,-2.80),(.40,.055,.33),'steel',.006)
cyl('TrayLeg',(2.1,.3,-2.80),(2.1,.80,-2.80),.018,'steel',16)
box('UsedFoldedTowel',(2.10,.88,-2.80),(.29,.05,.21),'cloth',.01)
# Original printed identity, hours and triage notice: physically mounted.
box('SignBacking',(0,2.97,3.94),(2.8,.55,.035),'cream');label('clinic_sign',(0,2.97,3.962),(2.7,.48),'sign')
box('NoticeBacking',(-1.1,1.75,3.95),(.62,.83,.02),'timber');label('clinic_notice',(-1.1,1.75,3.965),(.58,.78),'notice')
box('ReceptionNotice',(-3.2,1.45,-.20),(.62,.30,.022),'timber');label('reception_notice',(-3.2,1.45,-.181),(.58,.26),'hours')
for x in [-.42,.42]:
 box('RedCrossHorizontal',(x,2.97,3.97),(.23,.065,.025),'red') if False else None
# Metre-scale planar UVs prevent default cube islands stretching the floor and walls.
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 if obj.name=='Floor':
  uv=obj.data.uv_layers.active
  for loop in obj.data.loops:
   point=obj.matrix_world@obj.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(point.x/2,-point.y/2)
 elif obj.name.startswith(('ExteriorWall','SideWall','DoorLintel','WindowSillWall','WindowHeadWall')):
  uv=obj.data.uv_layers.active
  if uv:
   for face in obj.data.polygons:
    for li in face.loop_indices:
     point=obj.matrix_world@obj.data.vertices[obj.data.loops[li].vertex_index].co;uv.data[li].uv=((point.x if abs(face.normal.y)>.5 else -point.y)/4.2,point.z/.9)
  # Paint interior-facing broad wall surfaces in washable warm plaster.
  obj.data.materials.append(M['plaster'])
  for face in obj.data.polygons:
   center=obj.matrix_world@face.center;normal=obj.matrix_world.to_3x3()@face.normal
   if center.x*normal.x+center.y*normal.y<-.1 and abs(normal.z)<.2:face.material_index=1
export('clinic');receipt['clinic']['source']='tools/blender/generated/clinic/clinic.blend';receipt['provenance']={'license':'Original project-authored geometry and graphics','blender':bpy.app.version_string,'units':'metres','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()};receipt['graphics']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')};(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
