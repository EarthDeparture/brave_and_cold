"""Refresh the final wide tuning print without rebuilding unrelated geometry."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector
OUT=Path(__file__).parent/'generated/field_survival_kit_v1'
meta=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));r=meta['assets']['portable_radio']
bpy.ops.wm.open_mainfile(filepath=str(OUT/r['native']))
replacement=bpy.data.images.load(str(OUT/'textures/radio_dial.png'),check_existing=False);replacement.pack()
for m in bpy.data.materials:
    if m.use_nodes:
        for node in m.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image and 'radio_dial' in node.image.name:node.image=replacement
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/r['native']),compress=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/r['glb']),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
r['glb_sha256']=hashlib.sha256((OUT/r['glb']).read_bytes()).hexdigest();r['native_sha256']=hashlib.sha256((OUT/r['native']).read_bytes()).hexdigest()
meta['radio_print_refresh']='Original 1536x256 tuning-scale texture, updated in native source and GLB.'
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
# Refresh the matching Blender contact-sheet tile under identical lighting.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
if scene.world is None:scene.world=bpy.data.worlds.new('ReviewWorld')
scene.render.resolution_x=450;scene.render.resolution_y=450;scene.render.resolution_percentage=100;scene.world.color=(.055,.055,.055);scene.view_settings.view_transform='AgX'
for loc,energy,size in [((3,-4,5),480,4),((-3,-2,2.5),240,3),((1,3,4),350,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=size;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=.47*1.5
center=Vector((0,0,.235));cam.location=center+Vector((1.5,-2.6,1.65))*.47;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'previews/portable_radio.png');bpy.ops.render.render(write_still=True)
print('RADIO_PRINT_REFRESH_PASS')
# Keep the editable multi-asset library in sync and frame the complete grid.
library=OUT/'field_survival_library.blend';bpy.ops.wm.open_mainfile(filepath=str(library))
replacement=bpy.data.images.load(str(OUT/'textures/radio_dial.png'),check_existing=False);replacement.pack()
for m in bpy.data.materials:
    if m.use_nodes:
        for node in m.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image and 'radio_dial' in node.image.name:node.image=replacement
from mathutils import Euler
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            view=area.spaces.active.region_3d;view.view_location=Vector((4.55,1.95,.2));view.view_distance=10.5;view.view_rotation=Euler((.8,0,0)).to_quaternion();area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(library),compress=True)
print('LIBRARY_PRINT_SYNC_PASS')
