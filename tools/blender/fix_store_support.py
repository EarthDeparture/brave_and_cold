"""Correct connected prop components against the original store furniture."""
from pathlib import Path
import bpy, json, hashlib
from mathutils import Vector
R=Path(__file__).resolve().parents[2];SRC=R/'tools/blender/generated/route_identity/store_dressing.blend'
OUT=R/'tools/blender/generated/store_supported';RT=R/'brave-and-cold/assets/store_supported'
OUT.mkdir(parents=True,exist_ok=True);RT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SRC));bpy.context.preferences.filepaths.save_version=0
changes=[]
for ob in bpy.context.scene.objects:
 if ob.type!='MESH':continue
 adj=[set() for _ in ob.data.vertices]
 for e in ob.data.edges:
  a,b=e.vertices;adj[a].add(b);adj[b].add(a)
 seen=set()
 for start in range(len(adj)):
  if start in seen:continue
  stack=[start];ids=[];seen.add(start)
  while stack:
   i=stack.pop();ids.append(i)
   for j in adj[i]:
    if j not in seen:seen.add(j);stack.append(j)
  # Joined groups retain the first object's origin. Classify in world space.
  points=[ob.matrix_world@ob.data.vertices[i].co for i in ids]
  x=sum(p.x for p in points)/len(points);y=sum(p.z for p in points)/len(points);z=-sum(p.y for p in points)/len(points)
  dx=max(p.x for p in points)-min(p.x for p in points)
  shift=0
  if ob.name=='ShelfStock':shift=.052 if y<1.05 and dx>.16 else -.013
  elif ob.name=='CounterStock':shift=-.013 if z<-.75 else -.022
  elif ob.name=='CrateStock':shift=.097 if y<1.23 else .0475
  elif 1.3<x<1.92 and 1.39<y<1.7:
   if -.60<z<-.10:shift=-.009
   elif .17<z<.65:shift=-.003
  if shift:
   local_delta=ob.matrix_world.to_3x3().inverted()@Vector((0,0,shift))
   for i in ids:ob.data.vertices[i].co+=local_delta
   changes.append({'group':ob.name,'center':[x,y,z],'shift_y':shift})
native=OUT/'store_dressing_supported.blend';bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(native))
glb=RT/'store_dressing.glb';bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',export_yup=True,export_animations=False,export_vertex_color='ACTIVE')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
(RT/'manifest.json').write_text(json.dumps({'source_sha256':sha(SRC),'native_sha256':sha(native),'glb_sha256':sha(glb),'generator_sha256':sha(Path(__file__)),'license':'Original project dressing; support placement corrected, source preserved','changes':changes},indent=2)+'\n')
print('STORE_SUPPORT_EXPORTED',len(changes),'components',flush=True)
