"""Review renders for weapon kit v3: each rifle assembled with an optic and a light
(attached socket-to-socket, exactly like the runtime), side + three-quarter + optic close-up.
  blender --background --factory-startup --python tools/blender/render_weapon_v3_review.py -- rifle optic light
Writes tools/blender/generated/weapon_kit_v3/previews/review_<rifle>_<optic>_<light>.png"""
from pathlib import Path
import bpy, math, sys
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / 'tools/blender/generated/weapon_kit_v3'
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else ['compact_patrol_rifle', 'reflex_micro', 'light_clamp']
rifle, optic, light = (args + ['', '', ''])[:3]

scene = bpy.context.scene
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.view_settings.view_transform = 'AgX'
scene.world = scene.world or bpy.data.worlds.new('W'); scene.world.use_nodes = True
bg = scene.world.node_tree.nodes.get('Background'); bg.inputs[0].default_value = (.20, .22, .25, 1); bg.inputs[1].default_value = .6


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    # the importer multiplies COLOR_0 (our wear mask) into base colour; the game does not
    for o in new:
        if o.type != 'MESH': continue
        for m in o.data.materials:
            if m is None or not m.use_nodes: continue
            nt = m.node_tree; bsdf = next((x for x in nt.nodes if x.type == 'BSDF_PRINCIPLED'), None)
            tex = next((x for x in nt.nodes if x.type == 'TEX_IMAGE'), None)
            if bsdf and tex: nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return new


def find(objs, suffix):
    for o in objs:
        if o.name.endswith(suffix): return o
    return None


def root_of(objs):
    return [o for o in objs if o.parent is None][0]


R = imp(KIT / 'godot' / (rifle + '.glb')); rroot = root_of(R)
bpy.context.view_layer.update()


def attach(path, rifle_socket):
    if not path or not rifle_socket: return
    A = imp(path); aroot = root_of(A); bpy.context.view_layer.update()
    mount = find(A, 'Socket_Mount')
    # place the attachment so its Socket_Mount coincides with the rifle socket
    aroot.matrix_world = rifle_socket.matrix_world @ (aroot.matrix_world.inverted() @ mount.matrix_world).inverted() @ Matrix.Identity(4)
    bpy.context.view_layer.update()


attach(KIT / 'godot/optics' / (optic + '.glb') if optic else None, find(R, 'Socket_OpticMount'))
attach(KIT / 'godot/lights' / (light + '.glb') if light else None, find(R, 'Socket_LightMount'))

for loc, e, s in [((1.6, -1.2, 1.6), 600, 2.5), ((-1.4, -.8, .6), 180, 2.5), ((0, 1.6, 1.2), 260, 2)]:
    bpy.ops.object.light_add(type='AREA', location=loc); L = bpy.context.object; L.data.energy = e; L.data.size = s
    L.rotation_euler = (Vector((0, 0, .05)) - L.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(); cam = bpy.context.object; scene.camera = cam
out = KIT / 'previews'; out.mkdir(parents=True, exist_ok=True)
tag = '_'.join([a for a in (rifle, optic, light) if a])
views = {
    'side': (Vector((1.35, -.14, .07)), Vector((0, -.14, .07)), 35),
    'threeq': (Vector((.75, .62, .30)), Vector((0, -.16, .06)), 40),
    'optic': (Vector((.24, .20, .18)), Vector((0, .04, .11)), 40),
    'hip': (Vector((-.06, .40, .17)), Vector((.03, -.30, .085)), 40),
}
for v, (pos, tgt, lens_mm) in views.items():
    cam.location = pos; cam.data.lens = lens_mm
    cam.rotation_euler = (tgt - pos).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(out / f'review_{tag}_{v}.png'); bpy.ops.render.render(write_still=True)
    print('W3_REVIEW', v, flush=True)
