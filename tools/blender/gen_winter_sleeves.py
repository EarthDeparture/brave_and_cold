"""Original winter parka sleeves: small cloth folds, stitched cuff and smooth elbow taper."""
from pathlib import Path
import bpy,math,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'brave-and-cold/assets/environment_detail/viewmodel';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'tools/blender/generated/environment_detail'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('survivor_cloth');mat.diffuse_color=(.06,.085,.045,1)
objects=[]
for name,phase in [('vm_sleeve_r',0),('vm_sleeve_l',.6)]:
 v=[];c=[];f=[];uv=[];sides=20;rings=44
 for j in range(rings):
  z=j/(rings-1)*.52
  cuff=z<.044
  base=(.029+.0013*math.cos(z*620)) if cuff else .038+(z-.044)/.476*.036
  for k in range(sides):
   angle=k/sides*math.tau
   folds=(.0027*math.sin(z*58+2*angle+phase)+.0015*math.sin(z*101-angle)) * min(1,max(0,(z-.045)/.04)) * min(1,(.55-z)/.06)
   r=base+folds
   # Godot +Z forearm to Blender -Y.
   v.append((math.cos(angle)*r,-z,math.sin(angle)*r*.92))
   shade=.96+.04*math.sin(z*17+angle)
   color=(.024,.030,.020) if cuff else (.064,.083,.048)
   c.append(tuple(x*shade for x in color)+(1,));uv.append((k/sides,z/.52))
 for j in range(rings-1):
  for k in range(sides):f.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
 # Wrist/elbow openings sit inside the fitted cuff and off screen; no inner cap across the wrist.
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(v,[],f);mesh.update()
 import bmesh
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
 col=mesh.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER');tex=mesh.uv_layers.new(name='UV')
 for p in mesh.polygons:
  p.use_smooth=True
  for li in p.loop_indices:
   i=mesh.loops[li].vertex_index;col.data[li].color=c[i];tex.data[li].uv=uv[i]
 mesh.color_attributes.active_color=col;mesh.color_attributes.render_color_index=0
 mesh.materials.append(mat);obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);objects.append(obj)
bpy.ops.object.select_all(action='SELECT')
path=OUT/'winter_sleeves.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'winter_sleeves.blend'))
receipt={'origin':'Original Blender cloth geometry','generator':'tools/blender/gen_winter_sleeves.py','length_m':.52,'wrists':'Unchanged origin and runtime transforms','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'models':[]}
for obj in objects:
 obj.data.calc_loop_triangles();receipt['models'].append({'name':obj.name,'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles)})
(OUT/'provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('WINTER_SLEEVES',receipt['models'])
