"""A/B review sheet for weapon kit v3: every rifle assembled with its factory fit (socket to
socket, like the runtime), side + three-quarter + hip-eye views, plus optional icon renders.
  blender --background --factory-startup --python tools/blender/render_weapon_v3_sheet.py [-- --icons] [-- --only id,id]
Writes tools/blender/generated/weapon_kit_v3/previews/sheet_<rifle>_<view>.png
(--icons: brave-and-cold/assets/ui/rifles/<id>.png, 512x192 transparent side views)."""
from pathlib import Path
import bpy, json, sys
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / 'tools/blender/generated/weapon_kit_v3'
GAME = ROOT / 'brave-and-cold'
RIFLES = json.loads((GAME / 'data/rifles.json').read_text(encoding='utf-8'))
ATT = json.loads((GAME / 'data/attachments.json').read_text(encoding='utf-8'))
ICONS = '--icons' in sys.argv
ONLY = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
FIT = {}
if '--fit' in sys.argv:   # rifle:optic:light:mount:muzzle overrides
    for s in sys.argv[sys.argv.index('--fit') + 1].split(','):
        p = (s.split(':') + [''] * 5)[:5]; FIT[p[0]] = {'optic': p[1], 'light': p[2], 'mount': p[3], 'muzzle': p[4]}

scene = bpy.context.scene
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
scene.render.engine = 'BLENDER_EEVEE'
scene.view_settings.view_transform = 'Standard' if ICONS else 'AgX'
scene.world = scene.world or bpy.data.worlds.new('W'); scene.world.use_nodes = True
bg = scene.world.node_tree.nodes.get('Background'); bg.inputs[0].default_value = (.20, .22, .25, 1); bg.inputs[1].default_value = .6


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:   # the importer multiplies COLOR_0 (our wear mask) into base colour; the game does not
        if o.type != 'MESH': continue
        for m in o.data.materials:
            if m is None or not m.use_nodes: continue
            nt = m.node_tree; bsdf = next((x for x in nt.nodes if x.type == 'BSDF_PRINCIPLED'), None)
            tex = next((x for x in nt.nodes if x.type == 'TEX_IMAGE'), None)
            if bsdf and tex: nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return new


def find(objs, suffix):
    return next((o for o in objs if o.name.endswith(suffix)), None)


def attach(glb_rel, sock, objs):
    if not glb_rel or sock is None: return []
    A = imp(GAME / glb_rel.replace('res://', '')); aroot = [o for o in A if o.parent is None][0]
    bpy.context.view_layer.update()
    mount = find(A, 'Socket_Mount')
    aroot.matrix_world = sock.matrix_world @ (aroot.matrix_world.inverted() @ mount.matrix_world).inverted()
    bpy.context.view_layer.update(); objs.extend(A); return A


for loc, e, s in [((1.6, -1.2, 1.6), 600, 2.5), ((-1.4, -.8, .6), 180, 2.5), ((0, 1.6, 1.2), 260, 2)]:
    bpy.ops.object.light_add(type='AREA', location=loc); L = bpy.context.object; L.data.energy = e * (.45 if ICONS else 1); L.data.size = s
    L.rotation_euler = (Vector((0, 0, .05)) - L.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(); cam = bpy.context.object; scene.camera = cam
out = KIT / 'previews'; out.mkdir(parents=True, exist_ok=True)
if '--parts' in sys.argv:
    # gear / gunsmith icons for loose parts: 3/4 view from the right, transparent, 256x160
    PD = GAME / 'assets/ui/parts'; PD.mkdir(parents=True, exist_ok=True)
    parts = {k: v['glb'] for k, v in ATT.items() if not k.startswith('_') and 'glb' in v}
    parts['flashlight'] = 'res://assets/weapons/v3/lights/flashlight_hand.glb'
    scene.render.resolution_x, scene.render.resolution_y = 256, 160; scene.render.film_transparent = True
    scene.view_settings.view_transform = 'Standard'
    for aid, glb in parts.items():
        objs = imp(GAME / glb.replace('res://', '')); bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in objs if o.type == 'MESH' for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); c = (lo + hi) / 2
        cam.data.type = 'ORTHO'; d = Vector((1.0, -0.35, 0.45)).normalized() * 2.0
        cam.location = c + d; cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam.data.ortho_scale = max((hi - lo).length * 0.95, 0.05)
        scene.render.filepath = str(PD / (aid + '.png')); bpy.ops.render.render(write_still=True)
        for o in objs: bpy.data.objects.remove(o, do_unlink=True)
        print('W3_PART_ICON', aid, flush=True)
    raise SystemExit(0)
for rid, spec in RIFLES.items():
    if rid.startswith('_') or not spec.get('v3') or (ONLY and rid not in ONLY): continue
    fit = dict(spec.get('factory', {})); fit.update(FIT.get(rid, {}))
    objs = imp(KIT / 'godot' / (rid + '.glb'))
    for o in objs:   # hidden helper nodes (spent case, insert round) keep their tiny scale
        pass
    bpy.context.view_layer.update()
    optic_sock = find(objs, 'Socket_OpticMount')
    if fit.get('mount'):
        A = attach(ATT[fit['mount']]['glb'], find(objs, 'Socket_ScoutMount'), objs); optic_sock = find(A, 'Socket_OpticMount')
    if fit.get('optic'): attach(ATT[fit['optic']]['glb'], optic_sock, objs)
    if fit.get('light'): attach(ATT[fit['light']]['glb'], find(objs, 'Socket_LightMount'), objs)
    if fit.get('muzzle'): attach(ATT[fit['muzzle']]['glb'], find(objs, 'Socket_MuzzleThread'), objs)
    bpy.context.view_layer.update()
    if ICONS:
        scene.render.resolution_x, scene.render.resolution_y = 512, 192; scene.render.film_transparent = True
        pts = [o.matrix_world @ Vector(c) for o in objs if o.type == 'MESH' and max(o.matrix_world.to_scale()) > .01 for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); c = (lo + hi) / 2
        cam.data.type = 'ORTHO'; cam.location = Vector((c.x + 3, c.y, c.z))
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam.data.ortho_scale = max(hi.y - lo.y, (hi.z - lo.z) * 512 / 192) * 1.06
        scene.render.filepath = str(GAME / 'assets/ui/rifles' / (rid + '.png')); bpy.ops.render.render(write_still=True)
    else:
        scene.render.resolution_x, scene.render.resolution_y = 1200, 600
        m = RIFLES[rid].get('_muzzle', .66)
        views = {'side': (Vector((2.05, .19, .07)), Vector((0, .19, .07)), 35),
                 'threeq': (Vector((.70, .55, .26)), Vector((0, -.14, .07)), 40),
                 'hip': (Vector((-.06, .40, .17)), Vector((.03, -.30, .085)), 40)}
        for v, (pos, tgt, lens_mm) in views.items():
            cam.data.type = 'PERSP'; cam.location = pos; cam.data.lens = lens_mm
            cam.rotation_euler = (tgt - pos).to_track_quat('-Z', 'Y').to_euler()
            scene.render.filepath = str(out / f'sheet_{rid}_{v}.png'); bpy.ops.render.render(write_still=True)
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    print('W3_SHEET', rid, flush=True)
