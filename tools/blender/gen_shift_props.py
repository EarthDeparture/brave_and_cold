"""Original shift-work props for the lookout deck, authored in tower-local Godot
metres with y measured from the deck floor. Both are rail-mounted: no walkway
footprint, no new collision.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/gen_shift_props.py

Requires tools/blender/gen_shift_textures.py to have been run first.
"""
import bpy, json, hashlib, math
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tools/blender/generated/shift_props'; RUNTIME = ROOT / 'brave-and-cold/assets/shift_work'
OUT.mkdir(parents=True, exist_ok=True); RUNTIME.mkdir(parents=True, exist_ok=True)
def cv(v): return Vector((v[0], -v[2], v[1]))
def material(name, color, rough=.8, metal=0):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF'); b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal; return m
def image_mat(name, png):
    m = material(name, (1, 1, 1), .85); n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(str(OUT / 'textures' / png))
    m.node_tree.links.new(n.outputs['Color'], m.node_tree.nodes.get('Principled BSDF').inputs['Base Color']); return m
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
# Muted TLD-like painted palette (linear values).
M = {k: material(k, c, r, mt) for k, c, r, mt in [
    ('white_paint', (.52, .52, .48), .82, 0), ('aged_steel', (.20, .22, .20), .6, .6), ('painted_steel', (.06, .12, .10), .75, .25),
    ('brass', (.31, .24, .11), .5, .7), ('snow', (.78, .80, .84), .9, 0), ('rubber', (.02, .02, .02), .9, 0), ('red_lead', (.30, .04, .02), .8, 0)]}
M['azimuth'] = image_mat('azimuth', 'azimuth.png'); M['weather_plate'] = image_mat('weather_plate', 'weather_plate.png')
PARTS = {}; receipt = {}
def add(o, group, mat): o.data.materials.append(M[mat]); PARTS.setdefault(group, []).append(o); return o
def box(name, c, size, mat, group='FixedProps', bevel=.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=cv(c)); o = bpy.context.object; o.name = name
    o.scale = (size[0], size[2], size[1]); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('b', 'BEVEL'); mod.width = min(bevel, min(size) / 3); mod.segments = 2; bpy.ops.object.modifier_apply(modifier=mod.name)
    return add(o, group, mat)
def cylinder(name, a, b, r, mat, group='FixedProps', segments=14):
    aa, bb = cv(a), cv(b); d = bb - aa
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=r, depth=d.length, location=(aa + bb) * .5)
    o = bpy.context.object; o.name = name; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    for p in o.data.polygons: p.use_smooth = len(p.vertices) == 4
    return add(o, group, mat)
def ring(name, c, outer, inner, depth, mat, group='FixedProps', segments=48):
    x, y, z = c; vs = []
    for yy, rr in [(y - depth / 2, outer), (y + depth / 2, outer), (y - depth / 2, inner), (y + depth / 2, inner)]:
        for i in range(segments):
            a = i * math.tau / segments; vs.append(cv((x + rr * math.cos(a), yy, z + rr * math.sin(a))))
    s = segments; faces = []
    for i in range(s):
        j = (i + 1) % s
        faces.extend([(i, j, s + j, s + i), (s + i, s + j, 3 * s + j, 3 * s + i), (2 * s + j, 2 * s + i, 3 * s + i, 3 * s + j), (j, i, 2 * s + i, 2 * s + j)])
    me = bpy.data.meshes.new(name); me.from_pydata(vs, [], faces); me.update()
    for poly in me.polygons: poly.use_smooth = True
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); return add(o, group, mat)
def disc_face(name, c, r, mat, group='FixedProps', segments=48):
    """Horizontal printed disc; texture top (north) maps to -Z."""
    x, y, z = c; verts = [cv((x, y, z))]; uvs = [(.5, .5)]
    for i in range(segments):
        a = i / segments * math.tau; px, pz = math.sin(a) * r, -math.cos(a) * r
        verts.append(cv((x + px, y, z + pz))); uvs.append((.5 + px / (2 * r), .5 - pz / (2 * r)))
    faces = [(0, 1 + i, 1 + (i + 1) % segments) for i in range(segments)]
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update(); uv = me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        for li in poly.loop_indices: uv.data[li].uv = uvs[me.loops[li].vertex_index]
    me.flip_normals() if me.polygons[0].normal.z < 0 else None
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); return add(o, group, mat)
def plate(name, c, size, mat, group='FixedProps'):
    """Vertical plate facing +X (toward the deck)."""
    x, y, z = c; w, h = size
    verts = [cv((x, y - h / 2, z + w / 2)), cv((x, y - h / 2, z - w / 2)), cv((x, y + h / 2, z - w / 2)), cv((x, y + h / 2, z + w / 2))]
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], [(0, 1, 2, 3)]); me.update(); uv = me.uv_layers.new(name='UVMap')
    for i, xy in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]): uv.data[i].uv = xy
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o); return add(o, group, mat)
def export(name, pivots):
    objects = []
    for group, parts in PARTS.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts: o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join(); o = bpy.context.object; o.name = group
        if group in pivots:
            bpy.context.scene.cursor.location = cv(pivots[group]); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        objects.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    path = RUNTIME / (name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True, export_materials='EXPORT', export_animations=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects); assert tris < 6000, (name, tris)
    bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (name + '.blend')))
    receipt[name] = {'triangles': tris, 'groups': [o.name for o in objects], 'pivots': {k: list(v) for k, v in pivots.items()}, 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False); PARTS.clear()

# ---------------------------------------------------------------- weather station (west rail, outside)
RX = -3.72  # west rail line; deck walkway is x > RX
for z in [-1.22, -.78]:
    box('bracket_arm', (-3.97, 1.06, z), (.52, .04, .04), 'aged_steel')
    box('bracket_brace', (-3.92, .90, z), (.40, .03, .03), 'aged_steel')
    cylinder('rail_clamp', (RX - .06, 1.06, z), (RX + .06, 1.06, z), .035, 'aged_steel', segments=10)
SX, SY, SZ = -4.06, 1.33, -1.0
box('screen_body', (SX, SY, SZ), (.30, .44, .40), 'white_paint')
for i in range(8):
    y = SY - .19 + i * .054
    for side in [-1, 1]: box('louvre', (SX, y, SZ + side * .205), (.30, .014, .02), 'white_paint', bevel=.003)
    box('louvre', (SX - .155, y, SZ), (.02, .014, .40), 'white_paint', bevel=.003)
box('screen_roof', (SX, SY + .245, SZ), (.36, .03, .48), 'white_paint')
box('roof_snow', (SX, SY + .272, SZ), (.33, .025, .44), 'snow', bevel=.01)
box('screen_floor', (SX, SY - .232, SZ), (.32, .02, .42), 'white_paint')
plate('screen_door_plate', (SX + .152, SY + .02, SZ), (.36, .18), 'weather_plate')
for zz in [SZ - .18, SZ + .18]: box('hinge', (SX + .155, SY + .02, zz), (.012, .05, .02), 'aged_steel', bevel=.002)
# Snow gauge on its own short bracket.
box('gauge_arm', (-3.95, 1.06, -.40), (.48, .035, .035), 'aged_steel')
cylinder('snow_gauge', (-4.12, 1.08, -.40), (-4.12, 1.44, -.40), .065, 'brass', segments=18)
cylinder('gauge_rim', (-4.12, 1.44, -.40), (-4.12, 1.46, -.40), .072, 'aged_steel', segments=18)
cylinder('gauge_snow', (-4.12, 1.46, -.40), (-4.12, 1.48, -.40), .058, 'snow', segments=18)
# Anemometer mast clamped to the rail post at z=-1.65.
MZ = -1.65
cylinder('mast', (RX - .08, 1.0, MZ), (RX - .08, 2.70, MZ), .022, 'aged_steel', segments=10)
for y in [1.0, 1.06]: cylinder('mast_clamp', (RX - .12, y, MZ), (RX + .02, y, MZ), .03, 'aged_steel', segments=10)
box('vane_arm', (RX - .08, 2.52, MZ + .14), (.016, .016, .30), 'aged_steel', bevel=.002)
box('vane_tail', (RX - .08, 2.55, MZ + .30), (.006, .12, .10), 'red_lead', bevel=.002)
HUB = (RX - .08, 2.76, MZ)
g = 'AnemometerCups'
cylinder('hub', (HUB[0], HUB[1] - .03, HUB[2]), (HUB[0], HUB[1] + .03, HUB[2]), .025, 'aged_steel', g, 12)
for k in range(3):
    a = k / 3 * math.tau; ex, ez = math.cos(a) * .16, math.sin(a) * .16
    cylinder('cup_arm', HUB, (HUB[0] + ex, HUB[1], HUB[2] + ez), .006, 'aged_steel', g, 6)
    tx, tz = -math.sin(a) * .05, math.cos(a) * .05  # cups open tangentially
    cylinder('cup', (HUB[0] + ex - tx * .5, HUB[1], HUB[2] + ez - tz * .5), (HUB[0] + ex + tx * .5, HUB[1], HUB[2] + ez + tz * .5), .035, 'red_lead', g, 12)
export('weather_station', {'AnemometerCups': HUB})

# ---------------------------------------------------------------- rail-mounted fire finder (front rail post x=-1.85)
FX, FY, FZ = -1.85, 1.24, 3.33
box('post_cap_plate', (FX, 1.145, FZ - .04), (.20, .02, .26), 'aged_steel')
cylinder('pedestal', (FX, 1.15, FZ), (FX, FY - .02, FZ), .045, 'painted_steel', segments=14)
cylinder('ring_body', (FX, FY - .02, FZ), (FX, FY + .012, FZ), .245, 'painted_steel', segments=48)
disc_face('azimuth_face', (FX, FY + .0135, FZ), .232, 'azimuth')
ring('bezel', (FX, FY + .019, FZ), .252, .228, .016, 'aged_steel')  # open bezel: the printed ring stays visible
g = 'Alidade'  # rotates about the disc centre to the sighted bearing
box('alidade_bar', (FX, FY + .03, FZ), (.035, .012, .46), 'brass', g, bevel=.003)
box('front_sight', (FX, FY + .085, FZ - .215), (.03, .10, .006), 'brass', g, bevel=.002)
cylinder('sight_wire', (FX, FY + .04, FZ - .218), (FX, FY + .13, FZ - .218), .0012, 'rubber', g, 4)
box('rear_peep', (FX, FY + .07, FZ + .215), (.03, .07, .006), 'brass', g, bevel=.002)
cylinder('peep_hole', (FX, FY + .085, FZ + .212), (FX, FY + .085, FZ + .219), .006, 'rubber', g, 8)
cylinder('pivot', (FX, FY + .03, FZ), (FX, FY + .045, FZ), .022, 'aged_steel', g, 12)
export('fire_finder', {'Alidade': (FX, FY, FZ)})
(OUT / 'shift_props_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print('SHIFT_PROPS', json.dumps(receipt))
