"""Make the hinged medical case hollow and align the lid's physical hinge."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector,Euler
script=Path(__file__).with_name('gen_field_survival_kit.py').read_text(encoding='utf-8')
exec(script[:script.index("\nbpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)")])
meta=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));r=meta['assets']['first_aid_case']
bpy.ops.wm.open_mainfile(filepath=str(OUT/r['native']));current=bpy.data.objects['first_aid_case']
M['green']=bpy.data.materials['FieldKit_green']
old=next(o for o in current.children if o.type=='MESH' and o.data.materials[0]==M['green'])
bpy.data.objects.remove(old,do_unlink=True)
box('CaseBack',(0,.105,-.039),(.255,.21,.007),'green',.003)
for side in [-1,1]:
    box('CaseWallX',(side*.124,.105,.002),(.007,.21,.079),'green',.003)
    box('CaseWallY',(0,.105+side*.101,.002),(.241,.007,.079),'green',.003)
hinge=next(o for o in current.children if '__Pivot_MedicalLid' in o.name)
bpy.context.view_layer.update();worlds={o:o.matrix_world.copy() for o in hinge.children};hinge.location=cv((0,.022,.044));bpy.context.view_layer.update()
for o,matrix in worlds.items():o.matrix_world=matrix
# One static body surface, keeping the hinged lid's material group independent.
parts=[o for o in current.children if o.type=='MESH' and o.data.materials[0]==M['green']]
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name='first_aid_case__FieldKit_green'
bpy.context.view_layer.update();lo,hi,size=bounds(current)
meshes=[o for o in current.children_recursive if o.type=='MESH'];r['triangles']=sum(len(f.vertices)-2 for o in meshes for f in o.data.polygons);r['mesh_nodes']=len(meshes);r['measured_size_m']=size
bpy.ops.object.select_all(action='DESELECT');current.select_set(True)
for o in current.children_recursive:o.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/r['native']),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/r['glb']),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
r['glb_sha256']=hashlib.sha256((OUT/r['glb']).read_bytes()).hexdigest();r['native_sha256']=hashlib.sha256((OUT/r['native']).read_bytes()).hexdigest()
meta['medical_case_refinement']='Hollow five-sided case, hinge at the lower front lid edge; separate editable lid.'
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
# Actual opened-state diagnostic: the lid clears the storage cavity.
hinge.rotation_euler.x=math.radians(-70)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=450;scene.render.resolution_y=450;scene.render.resolution_percentage=100
if scene.world is None:scene.world=bpy.data.worlds.new('ReviewWorld')
scene.world.color=(.055,.055,.055);scene.view_settings.view_transform='AgX'
for loc,energy,size in [((3,-4,5),480,4),((-3,-2,2.5),240,3),((1,3,4),350,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=size;o.rotation_euler=(Vector((0,0,.12))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=.39;center=Vector((0,0,.12));cam.location=center+Vector((1.5,-2.6,1.65))*.26;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(SHOTS/'first_aid_case_open_diagnostic.png');bpy.ops.render.render(write_still=True)
hinge.rotation_euler.x=0;scene.render.filepath=str(SHOTS/'first_aid_case.png');bpy.ops.render.render(write_still=True)
# Replace only this collection in the master library, retaining the gallery position.
library=OUT/'field_survival_library.blend';bpy.ops.wm.open_mainfile(filepath=str(library));old=bpy.data.collections['first_aid_case_Editable'];position=bpy.data.objects['first_aid_case'].location.copy()
for o in list(old.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.data.collections.remove(old)
with bpy.data.libraries.load(str(OUT/r['native']),link=False) as (available,loaded):loaded.collections=['first_aid_case_Editable']
coll=loaded.collections[0];bpy.context.scene.collection.children.link(coll);next(o for o in coll.objects if o.name=='first_aid_case').location=position
bpy.ops.wm.save_as_mainfile(filepath=str(library),compress=True)
print('HOLLOW_CASE_REFINE_PASS',r['triangles'])
