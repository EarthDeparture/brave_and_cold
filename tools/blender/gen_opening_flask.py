"""Original hollow-neck flask; same metric grip envelope as the old closed shell."""
from pathlib import Path
import bpy,math,json,hashlib,numpy as np
R=Path(__file__).resolve().parents[2]
src=Path(__file__).with_name('gen_first_week.py').read_text();exec(src[:src.index('clear()\n# Reusable')])
OUT=R/'tools/blender/generated/opening_props';RT=R/'brave-and-cold/assets/opening_props';OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0;clear()
# Shared source material; explicit cylinder UVs preserve texture scale.
base=bpy.data.images.load(str(R/'tools/blender/generated/field_survival_kit_v1/textures/enamel_base.png'))
pixels=np.array(base.pixels[:],dtype=np.float32).reshape(base.size[1],base.size[0],4)
pixels[:,:,:3]*=np.array([.11,.17,.13])
rng=np.random.default_rng(91710)
for i in range(46):
 x=int(rng.integers(2,base.size[0]-12));y=int(rng.integers(3,base.size[1]-3));width=int(rng.integers(3,11))
 pixels[y:y+1,x:x+width,:3]=[.14,.15,.13]
paint=bpy.data.images.new('OriginalFieldGreenEnamel',width=base.size[0],height=base.size[1]);paint.pixels.foreach_set(pixels.ravel());paint.file_format='PNG';paint.filepath_raw=str(OUT/'flask_enamel.png');paint.save()
M['forest_enamel']=mat('forest_enamel',(1,1,1),.70,.25,texture=OUT/'flask_enamel.png')
M['interior']=mat('flask_interior',(.075,.08,.07),.55,.25)
def shell(name,rings,material,cap_bottom=False):
 n=48;vs=[];fs=[]
 for y,r in rings:
  for k in range(n+1):vs.append(cv((math.sin(k*math.tau/n)*r,y,math.cos(k*math.tau/n)*r)))
 for j in range(len(rings)-1):
  for k in range(n):fs.append((j*(n+1)+k,j*(n+1)+k+1,(j+1)*(n+1)+k+1,(j+1)*(n+1)+k))
 if cap_bottom:fs.append(tuple(reversed(range(n))))
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new()
 for f in me.polygons:
  f.use_smooth=len(f.vertices)==4
  for li in f.loop_indices:
   vi=me.loops[li].vertex_index;uv.data[li].uv=(vi%(n+1)/n,rings[vi//(n+1)][0]/.232)
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,material)
shell('FlaskBody',[(0,.031),(.006,.038),(.020,.042),(.177,.042),(.194,.040),(.213,.026),(.224,.022),(.232,.022)],'forest_enamel',True)
# Connected rolled lip and inset neck cavity; no solid disk across the mouth.
shell('RolledLip',[(.230,.022),(.234,.023),(.237,.021),(.234,.018),(.228,.018)],'steel')
shell('InsideNeck',[(.228,.018),(.204,.018),(.203,.0002)],'interior')
shell('BaseSeam',[(.005,.038),(.007,.039),(.009,.039),(.012,.0385)],'steel')
cap=empty('FlaskCap',(0,0,0))
cyl('CapGasket',(0,.237,0),(0,.241,0),.024,'rubber',32,cap)
cyl('Cap',(0,.241,0),(0,.264,0),.026,'steel',48,cap)
for k in range(24):
 a=k*math.tau/24;cyl('CapKnurl',(math.sin(a)*.026,.245,math.cos(a)*.026),(math.sin(a)*.026,.260,math.cos(a)*.026),.0008,'steel',6,cap)
# Wrap the existing original label around the cylinder rather than floating.
M['flask_graphic']=mat('flask_graphic',(1,1,1),texture=R/'tools/blender/generated/first_week/water.png')
vs=[];fs=[];n=12
for y in [.07,.16]:
 for k in range(n+1):
  angle=(k/n-.5)*1.48;vs.append(cv((math.sin(angle)*.0423,y,math.cos(angle)*.0423)))
for k in range(n):fs.append((k,k+1,n+2+k,n+1+k))
me=bpy.data.meshes.new('WrappedLabel');me.from_pydata(vs,[],fs);me.update();uv=me.uv_layers.new()
for f in me.polygons:
 for li in f.loop_indices:
  vi=me.loops[li].vertex_index;uv.data[li].uv=(vi%(n+1)/n,vi//(n+1))
o=bpy.data.objects.new('WrappedLabel',me);bpy.context.collection.objects.link(o);finish(o,'flask_graphic')
export('field_flask')
receipt['field_flask']['source']='tools/blender/generated/opening_props/field_flask.blend'
receipt['provenance']={'origin':'Original metric Blender model; existing original project enamel and water-label graphics','grip_envelope_m':[.084,.264,.084],'cap_node':'FlaskCap; hide only this node for drinking','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
receipt['provenance']['enamel_sha256']=hashlib.sha256((OUT/'flask_enamel.png').read_bytes()).hexdigest()
(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n');print('OPENING_FLASK_EXPORTED')
