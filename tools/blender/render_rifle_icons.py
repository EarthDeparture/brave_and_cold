"""Inventory icons for the eight rifles: transparent side views of the shipped GLBs.
  blender --background --factory-startup --python tools/blender/render_rifle_icons.py
Writes brave-and-cold/assets/ui/rifles/<id>.png (512x192)."""
from pathlib import Path
import bpy, math
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'brave-and-cold/assets/weapons/north_ridge'
OUT = ROOT / 'brave-and-cold/assets/ui/rifles'; OUT.mkdir(parents=True, exist_ok=True)
IDS = ["timber_bolt_carbine", "ranger_box_rifle", "frontier_vented_rifle", "ridge_scout_rifle",
       "brush_lever_rifle", "north_service_rifle", "compact_patrol_rifle", "expedition_rifle"]

scene = bpy.context.scene
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)   # factory cube/light/camera
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 512, 192
scene.render.film_transparent = True
scene.view_settings.view_transform = 'Standard'
for loc, e in [((2, -1.5, 2.5), 260), ((2.5, 2, -.5), 90), ((-2, 0, 2), 90)]:
    bpy.ops.object.light_add(type='AREA', location=loc); L = bpy.context.object; L.data.energy = e; L.data.size = 3
    L.rotation_euler = (Vector((0, 0, 0)) - L.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(3, 0, 0)); cam = bpy.context.object; scene.camera = cam
cam.data.type = 'ORTHO'; cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat('-Z', 'Z').to_euler()
cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()

for rid in IDS:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SRC / (rid + '.glb')))
    new = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in new if o.type == 'MESH' and o.visible_get() and 'strap' not in o.name.lower() for c in o.bound_box]
    # tiny-scaled helper meshes (spent case, insert round) would pull the frame; ignore near-zero ones
    pts = [p for p in pts]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    centre = (lo + hi) / 2
    print('BOUNDS', rid, tuple(round(v,3) for v in lo), tuple(round(v,3) for v in hi), len(new), flush=True)
    cam.location = Vector((centre.x + 3, centre.y, centre.z))
    cam.data.ortho_scale = max(hi.y - lo.y, (hi.z - lo.z) * 512 / 192) * 1.06
    scene.render.filepath = str(OUT / (rid + '.png')); bpy.ops.render.render(write_still=True)
    for o in new: bpy.data.objects.remove(o, do_unlink=True)
    print('RIFLE_ICON', rid, flush=True)


