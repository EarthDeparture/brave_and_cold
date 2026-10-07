"""Original metre-scale skillet and marbled portion, packed source and independent receipts."""
from pathlib import Path
import bpy,math,json,hashlib,shutil
src=Path(__file__).with_name('gen_first_week.py').read_text(encoding='utf8');exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/cooking';RT=R/'brave-and-cold/assets/cooking'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
M['cast_iron']=mat('seasoned_cast_iron',(.047,.052,.044),.67,.62)
M['food']=mat('food_marbling',(1,1,1),.48,0,OUT/'meat_marbling.png')
bpy.data.images.load(str(OUT/'meat_seared.png')).pack()
shutil.copy2(OUT/'meat_seared.png',RT/'meat_seared.png')
M['char']=mat('seared_edge',(.047,.031,.019),.91,0)
# Lathed closed cross-section, correctly sized thick cast base and hollow cooking surface.
rings=[(.0,.0),(.110,.0),(.121,.010),(.126,.035),(.128,.039),(.123,.040),(.118,.013),(.106,.008),(.0,.008)]
vs=[];fs=[];n=48
for r,y in rings:
 for i in range(n):vs.append(cv((math.cos(i*math.tau/n)*r,y,math.sin(i*math.tau/n)*r)))
for j in range(len(rings)-1):
 for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
me=bpy.data.meshes.new('SkilletShell');me.from_pydata(vs,[],fs);me.update()
o=bpy.data.objects.new('CastSkillet',me);bpy.context.collection.objects.link(o);finish(o,'cast_iron')
for f in me.polygons:f.use_smooth=True
box('HandleNeck',(0,.026,.154),(.035,.016,.075),'cast_iron',.006)
box('Handle',(0,.035,.228),(.035,.018,.12),'cast_iron',.008)
# The hanging hole is a true opening formed with bounded strip geometry.
for x in [-.014,.014]:box('HandleEyeSide',(x,.041,.300),(.008,.016,.035),'cast_iron',.002)
for z in [.285,.316]:box('HandleEyeEnd',(0,.041,z),(.028,.016,.006),'cast_iron',.002)
food=empty('PanFood',(0,0,0));vs=[];fs=[];n=32
for j,(y,scale) in enumerate([(.009,.82),(.016,1),(.039,.90),(.047,.72)]):
 for i in range(n):
  a=i*math.tau/n;noise=1+.08*math.sin(a*3)+.035*math.sin(a*7)
  vs.append(cv((math.cos(a)*.087*scale*noise,y,math.sin(a)*.057*scale*noise)))
for j in range(3):
 for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
fs.extend([tuple(reversed(range(n))),tuple(3*n+i for i in range(n))])
me=bpy.data.meshes.new('MarbledCut');me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new()
for f in me.polygons:
 f.use_smooth=True
 for loop in f.loop_indices:
  v=me.vertices[me.loops[loop].vertex_index].co;uv.data[loop].uv=(v.x/.2+.5,-v.y/.15+.5)
o=bpy.data.objects.new('FoodSurface',me);bpy.context.collection.objects.link(o);finish(o,'food',food)
char=empty('SearMarks',(0,0,0))
for x in [-.047,-.016,.015,.046]:box('SearLine',(x,.0475,0),(.005,.001,.051),'char',0,char)
bpy.context.view_layer.update();pts=[]
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  for v in o.data.vertices:
   p=o.matrix_world@v.co;pts.append((p.x,p.z,-p.y))
lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
export('skillet_portion');e=receipt['skillet_portion'];e['source']='tools/blender/generated/cooking/skillet_portion.blend'
e['bounds_min_xyz']=lo;e['bounds_max_xyz']=hi;e['dimensions_m']=[hi[i]-lo[i] for i in range(3)];assert e['triangles']<4000
receipt['provenance']={'license':'Original project-authored geometry and deterministic meat texture','units':'metres','blender':bpy.app.version_string,'seed':7109}
receipt['generators']={file:hashlib.sha256(Path(__file__).with_name(file).read_text(encoding='utf8').replace('\r\n','\n').encode()).hexdigest() for file in ['gen_cooking.py','gen_cooking_graphics.py','gen_first_week.py']}
receipt['graphics']={file:hashlib.sha256((OUT/file).read_bytes()).hexdigest() for file in ['meat_marbling.png','meat_seared.png']}
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8');print('COOKING_ASSET',json.dumps(receipt))
