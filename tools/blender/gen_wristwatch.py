"""Original technician's field watch; live hands are separate Godot pivots."""
from pathlib import Path
import bpy,math,json,hashlib
src=Path(__file__).with_name('gen_first_week.py').read_text();exec(src[:src.index('clear()\n# Reusable')]);OUT=R/'tools/blender/generated/wristwatch';RT=R/'brave-and-cold/assets/wristwatch';OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True);receipt={};clear()
# Leather bracelet, four rings with inner and outer surfaces, around the wrist axis.
vs=[];fs=[];n=48
for z in [-.020,.020]:
 for inner in [False,True]:
  for k in range(n):a=k*math.tau/n;vs.append(cv((math.cos(a)*(.037 if inner else .040),math.sin(a)*(.030 if inner else .033),z)))
for k in range(n):
 j=(k+1)%n;fs.extend([(k,j,2*n+j,2*n+k),(n+j,n+k,3*n+k,3*n+j),(j,k,n+k,n+j),(2*n+k,2*n+j,3*n+j,3*n+k)])
me=bpy.data.meshes.new('LeatherBand');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('LeatherBand',me);bpy.context.collection.objects.link(o);finish(o,'rubber')
cyl('WatchCase',(0,.033,0),(0,.041,0),.023,'steel',48);cyl('Crown',(.022,.037,.003),(.026,.037,.003),.003,'steel',20)
# Original printed face with indices, old-school lume, no baked clock time.
p=OUT/'dial.png';M['dial']=mat('field_watch_dial',(1,1,1),texture=p);me=bpy.data.meshes.new('Dial');me.from_pydata([cv(v) for v in [(-.0205,.0412,-.0205),(.0205,.0412,-.0205),(.0205,.0412,.0205),(-.0205,.0412,.0205)]],[],[(3,2,1,0)]);me.update();uv=me.uv_layers.new()
for li,xy in zip(me.polygons[0].loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=xy
o=bpy.data.objects.new('WatchFace',me);bpy.context.collection.objects.link(o);finish(o,'dial')
for name,length,w in [('HourHand',.0105,.0015),('MinuteHand',.016,.001)]:
 pivot=empty(name,(0,.0418,0));box(name+'Needle',(0,.042,-length/2),(w,.0005,length),'cream',0,pivot)
cyl('HandPin',(0,.042,0),(0,.043,0),.0018,'steel',20)
export('field_watch');receipt['field_watch']['source']='tools/blender/generated/wristwatch/field_watch.blend';receipt['provenance']={'license':'Original project-authored geometry/printwork','blender':bpy.app.version_string,'units':'metres','generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()};receipt['graphics']={'dial.png':hashlib.sha256(p.read_bytes()).hexdigest()};(RT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
