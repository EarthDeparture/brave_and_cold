"""Weapon kit v3 (2026-10-18): realistic, modular rifles + separate optics and lights.

Why: kit v2 (painted sheet) read as toys (flat extruded slabs, lime/orange/red paint) and its
optics were merged into the receiver mesh, so red dots could not be fixed and nothing could be
mounted. v3 keeps the runtime contract (asset ids, Pivot_/Socket_ names, NLA clips, trigger-hand
origin, -Z forward, cy = .075 bore) and adds mount sockets:
  Socket_OpticMount  top of the rail / bases (optic Socket_Mount goes here)
  Socket_IronAim     rear sight on the iron sight line (aim height without an optic)
  Socket_LightMount  barrel clamp point (light Socket_Mount goes here)
  Socket_MuzzleThread (threaded barrels only)
Optics: Socket_Mount, Socket_Eye (optical axis, eye end), lenses named *Lens*, the dot plane
named DotLens (reflex / red-dot tube). Lights: Socket_Mount, Socket_Beam (lamp face, -Z).
Every mesh carries a vertex-colour mask: R = convex edge wear, G = cavity (1 = open), used by
the Godot weapon shader. No real internal mechanisms are modelled (visual shells + pivots only).

  blender --background --factory-startup --python tools/blender/gen_weapon_kit_v3.py [-- --render]
Textures first: tools/terrain/.venv/Scripts/python.exe tools/blender/gen_weapon_kit_v3_textures.py
"""
from pathlib import Path
import bpy, bmesh, math, json, hashlib, sys
from mathutils import Vector

HERE = Path(__file__).resolve().parent
_codex = (HERE / 'gen_north_ridge_weapons.py').read_text(encoding='utf-8')
exec(_codex[:_codex.index('\nSPECS=[')])   # node/socket/mesh/tube_z/wire/casing/clip/make_clips + field-kit helpers

OUT = ROOT / 'tools/blender/generated/weapon_kit_v3'
TEX = OUT / 'textures'; ENGINE = OUT / 'godot'; SHOTS = OUT / 'previews'; SRC = OUT / 'source'
for p in (ENGINE, SHOTS, SRC): p.mkdir(parents=True, exist_ok=True)
M = {}; RECORD = {}; ASSETS = []; COMPONENTS = {}; CLIPS = {}
ONLY = None
if '--only' in sys.argv: ONLY = sys.argv[sys.argv.index('--only') + 1].split(',')

# roughness, metallic, family (Godot weapon shader picks wear colour by family)
PROPS = {
    'walnut': (.62, 0, 'wood'), 'birch': (.66, 0, 'wood'), 'birch_dark': (.64, 0, 'wood'), 'laminate': (.55, 0, 'wood'),
    'blued': (.38, .75, 'metal'), 'parkerized': (.62, .55, 'metal'), 'alloy_black': (.55, .2, 'metal'),
    'steel_bright': (.30, .85, 'metal'), 'synthetic_black': (.72, 0, 'synthetic'), 'camo_dip': (.70, 0, 'synthetic'),
    'rubber': (.85, 0, 'synthetic'), 'brass': (.32, .9, 'metal'), 'glass': (.05, .2, 'glass'),
    'sling_canvas': (.9, 0, 'fabric'), 'tape_grey': (.6, 0, 'fabric'), 'lamp_lens': (.05, 0, 'glass'),
}
UV_M = 1 / 0.24   # one tile per 24 cm: grain scale reads as real wood at viewmodel distance


def material(key):
    if key in M: return M[key]
    m = bpy.data.materials.new('W3_' + key); m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = image(TEX / (key + '.png'))
    m.node_tree.links.new(t.outputs['Color'], bs.inputs['Base Color'])
    r, mt, fam = PROPS[key]
    bs.inputs['Roughness'].default_value = r; bs.inputs['Metallic'].default_value = mt
    if fam == 'glass':
        bs.inputs['Alpha'].default_value = .25
    px = t.image.pixels[:4]; m.diffuse_color = (px[0], px[1], px[2], 1)
    M[key] = m; return m


def project_uv(o):
    """Per-face planar projection in game space: grain runs along the gun (game Z)."""
    bpy.context.view_layer.update()
    me = o.data; uv = me.uv_layers.active or me.uv_layers.new()
    mw = o.matrix_world; nm = mw.to_3x3()
    for f in me.polygons:
        n = nm @ f.normal; g = (abs(n.x), abs(n.z), abs(n.y))
        ax = g.index(max(g))
        for li in f.loop_indices:
            p = gv(mw @ me.vertices[me.loops[li].vertex_index].co)
            if ax == 0: uv.data[li].uv = (p[2] * UV_M, p[1] * UV_M)
            elif ax == 1: uv.data[li].uv = (p[2] * UV_M, p[0] * UV_M)
            else: uv.data[li].uv = (p[0] * UV_M, p[1] * UV_M)


def bind(o, key, parent=None, uv=True):
    o.data.materials.append(material(key))
    project_uv(o)
    parent = parent or current
    if parent:
        bpy.context.view_layer.update(); matrix = o.matrix_world.copy(); o.parent = parent; o.matrix_world = matrix
    return o


# ---------------------------------------------------------------- v3 shape helpers (game coords)
def _smooth(o, angle=40):
    for f in o.data.polygons: f.use_smooth = True
    try: o.data.set_sharp_from_angle(angle=math.radians(angle))
    except Exception: pass
    return o


def loft(name, sections, key, n=24, sub=3, parent=None):
    """Smooth stock/fore-end: sections (z_game, y_top, y_bot, half_width, squareness, x_off).
    Catmull-Rom between key sections (sub points per span); superellipse rings."""
    S = [tuple(s) + (2.6, 0.0)[len(s) - 4:] if len(s) < 6 else tuple(s) for s in sections]
    S = [s if len(s) == 6 else (s + (0.0,)) for s in S]

    def cr(a, b, c, d, t):
        return tuple(.5 * ((2 * b[i]) + (-a[i] + c[i]) * t + (2 * a[i] - 5 * b[i] + 4 * c[i] - d[i]) * t * t + (-a[i] + 3 * b[i] - 3 * c[i] + d[i]) * t ** 3) for i in range(6))
    pts = []
    for i in range(len(S) - 1):
        a = S[max(i - 1, 0)]; b = S[i]; c = S[i + 1]; d = S[min(i + 2, len(S) - 1)]
        for k in range(sub): pts.append(cr(a, b, c, d, k / sub))
    pts.append(S[-1])
    vs = []; fs = []
    for z, top, bot, hw, sq, xo in pts:
        mid = (top + bot) / 2; hh = (top - bot) / 2; e = 2.0 / max(sq, 1.01)
        for k in range(n):
            a = k * TAU / n; c_, s_ = math.cos(a), math.sin(a)
            vs.append((xo + hw * math.copysign(abs(c_) ** e, c_), mid + hh * math.copysign(abs(s_) ** e, s_), z))
    for j in range(len(pts) - 1):
        for k in range(n): fs.append((j * n + k, j * n + (k + 1) % n, (j + 1) * n + (k + 1) % n, (j + 1) * n + k))
    fs.append(tuple(reversed(range(n)))); fs.append(tuple(range((len(pts) - 1) * n, len(pts) * n)))
    o = mesh(name, vs, fs, key, parent, smooth=True)
    return _smooth(o, 50)


def lathe_d(name, stations, key, cy=.075, x=0.0, n=28, parent=None, cap=True):
    """Revolve around the bore-parallel axis: stations (forward distance d, radius).
    cap=False leaves both end rings open (sight tubes you look through)."""
    o = tube_z(name, [(d, r, cy) for d, r in stations], key, parent, n=n, cap=cap)
    if x:
        for v in o.data.vertices: v.co.x += x
    return _smooth(o, 35)


def ring_d(name, d, r_in, r_out, w, key, cy=.075, x=0.0, n=28, parent=None):
    """Hollow ring (scope ring, barrel band) of width w at forward distance d."""
    vs = []; fs = []
    for dd, r in [(d, r_out), (d + w, r_out), (d + w, r_in), (d, r_in)]:
        for k in range(n):
            a = k * TAU / n; vs.append((x + math.cos(a) * r, cy + math.sin(a) * r, -dd))
    for j in range(4):
        for k in range(n): fs.append((j * n + k, ((j + 1) % 4) * n + k, ((j + 1) % 4) * n + (k + 1) % n, j * n + (k + 1) % n))
    return _smooth(mesh(name, vs, fs, key, parent, smooth=True), 35)


def plate(name, pts_zy, x0, x1, key, parent=None, edge=.0012):
    """Side-profile plate (points (z, y)) between x0 and x1 (sights, levers, guards)."""
    n = len(pts_zy); vs = [(xx, y, z) for xx in (x0, x1) for z, y in pts_zy]
    fs = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(k, k + n, (k + 1) % n + n, (k + 1) % n) for k in range(n)]
    o = mesh(name, vs, fs, key, parent); bevel(o, edge); return o


def sphere(name, p, r, key, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=r, location=cv(p))
    o = bpy.context.object; o.name = name
    for f in o.data.polygons: f.use_smooth = True
    return bind(o, key, parent)


def lens(name, d, r, cy, key='glass', x=0.0, n=28, parent=None, tilt=0.0):
    """Thin lens disc facing along the bore (both faces), optional backward tilt (reflex)."""
    vs = []
    for k in range(n):
        a = k * TAU / n; yy = math.sin(a) * r; zz = -d - yy * math.tan(tilt)
        vs.append((x + math.cos(a) * r, cy + yy, zz))
    fs = [tuple(range(n)), tuple(reversed(range(n)))]
    me = bpy.data.meshes.new(name); me.from_pydata([cv(p) for p in vs], [], [fs[0]]); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    return bind(o, key, parent)


def rect_lens(name, d, w, h, cy, key='glass', tilt=0.0, parent=None):
    vs = [(-w / 2, cy - h / 2, -d + (h / 2) * math.tan(tilt)), (w / 2, cy - h / 2, -d + (h / 2) * math.tan(tilt)),
          (w / 2, cy + h / 2, -d - (h / 2) * math.tan(tilt)), (-w / 2, cy + h / 2, -d - (h / 2) * math.tan(tilt))]
    me = bpy.data.meshes.new(name); me.from_pydata([cv(p) for p in vs], [], [(0, 1, 2, 3)]); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    return bind(o, key, parent)


# ---------------------------------------------------------------- wear mask (vertex colours)
def wear_colors(o):
    """R = convexity (edge wear), G = 1 - cavity (open = 1). Local-space, transform-safe."""
    me = o.data
    if 'Col' in me.color_attributes: return
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table(); bm.normal_update()
    conv = {}
    for v in bm.verts:
        if not v.link_edges: conv[v.index] = 0.0; continue
        acc = 0.0
        for e in v.link_edges:
            ov = e.other_vert(v); dv = (ov.co - v.co)
            if dv.length < 1e-7: continue
            acc += -v.normal.dot(dv.normalized())
        conv[v.index] = acc / len(v.link_edges)
    bm.free()
    attr = me.color_attributes.new('Col', 'BYTE_COLOR', 'POINT')
    for i, v in enumerate(me.vertices):
        c = conv.get(i, 0.0)
        wear = max(0.0, min(1.0, (c - 0.06) * 3.5)); open_ = 1.0 - max(0.0, min(1.0, (-c - 0.06) * 3.5))
        attr.data[i].color = (wear, open_, 0.0, 1.0)
    me.color_attributes.active_color = attr


# ---------------------------------------------------------------- exporter (v3: vertex colours, kinds)
def export_v3(kind):
    bpy.context.scene.frame_set(0); groups = {}
    for o in list(current.children_recursive):
        if o.type == 'MESH': wear_colors(o)
    hidden = [o for o in current.children_recursive if o.type == 'EMPTY' and max(o.scale) < .001]
    for o in hidden: o.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    for o in list(current.children_recursive):
        if o.type == 'MESH':
            # lenses stay separate objects (the runtime swaps their material)
            keep = 'Lens' in o.name
            groups.setdefault((o.parent, o.data.materials[0], o.name if keep else ''), []).append(o)
    for (parent, mat_, keepname), arr in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in arr: o.select_set(True)
        bpy.context.view_layer.objects.active = arr[0]
        if len(arr) > 1: bpy.ops.object.join()
        bpy.context.object.name = parent.name + '__' + (keepname + '__' if keepname else '') + mat_.name
    for o in hidden: o.scale = (.0001, .0001, .0001)
    bpy.context.view_layer.update(); lo, hi, size = bounds(current)
    meshes = [o for o in current.children_recursive if o.type == 'MESH']
    tri = sum(len(f.vertices) - 2 for o in meshes for f in o.data.polygons)
    assert tri < 40000, (current.name, tri)
    bpy.ops.object.select_all(action='DESELECT'); current.select_set(True)
    for o in current.children_recursive: o.select_set(True)
    sub = {'rifle': '', 'optic': 'optics/', 'light': 'lights/', 'muzzle': 'muzzle/'}[kind]
    (ENGINE / sub).mkdir(parents=True, exist_ok=True)
    path = ENGINE / sub / (current.name + '.glb')
    rest = {o: o.matrix_basis.copy() for o in [current] + list(current.children_recursive)}
    kw = dict(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True, export_extras=True,
              export_materials='EXPORT', export_cameras=False, export_lights=False, export_animations=(kind == 'rifle'),
              export_animation_mode='NLA_TRACKS', export_merge_animation='NLA_TRACK', export_force_sampling=True)
    try: bpy.ops.export_scene.gltf(**kw, export_vertex_color='ACTIVE')
    except TypeError: bpy.ops.export_scene.gltf(**kw, export_colors=True)
    for o, matrix in rest.items():
        if o.animation_data:
            for track in o.animation_data.nla_tracks: track.mute = True
        o.matrix_basis = matrix
    bpy.context.scene.frame_set(0); bpy.context.view_layer.update()
    coll = bpy.data.collections.new(current.name + '_Editable'); bpy.context.scene.collection.children.link(coll)
    for o in [current] + list(current.children_recursive):
        for c in list(o.users_collection): c.objects.unlink(o)
        coll.objects.link(o)
    RECORD[current.name] = {'kind': kind, 'description': current['description'], 'dimensions_m': size, 'bounds_min': lo, 'bounds_max': hi,
                            'triangles': tri, 'mesh_nodes': len(meshes), 'glb': 'godot/' + sub + path.name,
                            'glb_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                            'nodes': [o.name for o in current.children_recursive if o.type == 'EMPTY'],
                            'animations': CLIPS.get(current.name, {})}
    print('W3_ASSET', kind, current.name, tri, flush=True)


# ---------------------------------------------------------------- shared rifle parts
def trigger_guard_v3(key='alloy_black'):
    # rounded bow + flat plate under the action
    plate('GuardPlate', [(.070, .030), (-.050, .030), (-.050, .022), (.070, .022)], -.010, .010, key)
    wire('TriggerGuardBow', [(0, .024, .050), (0, -.006, .054), (0, -.026, .040), (0, -.030, .014), (0, -.022, -.012), (0, .000, -.020), (0, .022, -.024)], key, .0032)
    trigger = node('Trigger', (0, -.001, .024))
    wire('CurvedTrigger', [(0, .012, .022), (0, -.006, .026), (0, -.020, .020)], 'steel_bright', .0022, trigger)
    return trigger


def mag_rotary(p, key='synthetic_black'):
    """Flush rotary-style magazine (only its outer shell)."""
    mag = node('Magazine', p); x, y, z = p
    loft('MagShell', [(z - .028, y + .010, y - .034, .016, 3.0), (z - .024, y + .012, y - .036, .0175, 3.0),
                      (z + .024, y + .012, y - .036, .0175, 3.0), (z + .028, y + .010, y - .034, .016, 3.0)], key, n=16, sub=1, parent=mag)
    box('MagRelease', (0, y - .036, z - .026), (.010, .004, .010), 'alloy_black', .001, mag)
    socket('MagazineHand', (0, y - .020, z), mag)
    return mag


def mechanics_v3(mode, aim_y, hl_y, mag_builder=None, mag_pos=(0, .026, -.100), hl_x=-.038):
    trigger = trigger_guard_v3()
    bolt = node('Bolt', (0, .079, -.050)); box('BoltBody', (.010, .081, -.050), (.012, .014, .060), 'steel_bright', .003, bolt)
    handle = node('BoltHandle', (.026, .081, -.022), bolt)
    charge = node('ChargingHandle', (.021, .074, -.070))
    if mode == 'semi':
        cylinder('ChargingRod', (.016, .074, -.070), (.030, .074, -.070), .0028, 'steel_bright', 12, charge)
        lathe_d('ChargingKnob', [(.066, .0001), (.066, .0048), (.074, .0048), (.074, .0001)], 'alloy_black', cy=.074, x=.032, n=16, parent=charge)
    release = node('MagazineRelease', (0, .022, -.072))
    safety = node('Safety', (0, .030, .006)); cylinder('CrossBoltSafety', (-.014, .030, .006), (.014, .030, .006), .0030, 'steel_bright', 12, safety)
    mag = mag_builder(mag_pos) if (mode != 'lever' and mag_builder) else None
    hr = socket('HandR', (.041, -.024, .067)); hl = socket('HandL', (hl_x, hl_y, -.38))
    socket('Muzzle', (0, .075, -MUZ3[current.name])); socket('Aim', (0, aim_y, .052)); socket('Ejection', (.020, .082, -.055))
    socket('MagazineInsert', mag_pos); socket('TriggerFinger', (.021, -.026, .023)); socket('BoltHand', (.032, .074, -.070), charge if mode == 'semi' else handle)
    case = node('SpentCase', (.022, .082, -.050)); casing('VisualCase', (.022, .082, -.050), case); case.scale = Vector((.0001,) * 3)
    return {'bolt': bolt, 'handle': handle, 'charge': charge, 'trigger': trigger, 'release': release, 'mag': mag, 'hr': hr, 'hl': hl, 'case': case}


MUZ3 = {'compact_patrol_rifle': .625}


# ---------------------------------------------------------------- rifles
def compact_patrol_rifle():
    """Compact .22 rimfire carbine: birch carbine stock with barrel band, black alloy receiver
    with a scope rail, tapered blued barrel, folding-leaf rear and bead front iron sights."""
    m = MUZ3[current.name]
    # receiver: narrow rounded-top alloy body
    loft('Receiver', [(.034, .0905, .044, .0138, 2.4), (.030, .0935, .040, .0148, 2.6), (-.140, .0935, .040, .0148, 2.6), (-.146, .0910, .043, .0140, 2.4)], 'alloy_black', n=24, sub=1)
    box('EjectionRecess', (.0148, .083, -.040), (.0016, .016, .050), 'synthetic_black', .0006)
    box('ReceiverCrossPinR', (.0150, .060, -.010), (.0010, .006, .006), 'steel_bright', .0005)
    box('ReceiverCrossPinF', (.0150, .060, -.120), (.0010, .006, .006), 'steel_bright', .0005)
    # weaver-style rail on top, with cross slots
    box('ScopeRail', (0, .0958, -.055), (.0175, .0058, .150), 'alloy_black', .0012)   # top .0987, under the .1000 sight line
    for k in range(8): box('RailSlot', (0, .0982, -.000 - k * .018), (.0185, .0012, .0035), 'synthetic_black', .0003)
    socket('OpticMount', (0, .0987, -.055))
    # barrel: tapered, crowned, blued
    lathe_d('Barrel', [(.140, .0098), (.150, .0098), (.155, .0094), (.40, .0086), (m - .004, .0080), (m, .0072), (m, .0001)], 'blued', n=28)
    loft('BarrelBand', [(-.4245, .0852, .0418, .0212, 2.4), (-.4355, .0850, .0424, .0210, 2.4)], 'blued', n=26, sub=1)
    socket('LightMount', (0, .075, -.36))
    # iron sights: folding leaf rear (U notch bottom at .1000) and bead front (bead top .1000): 25 mm over the bore
    plate('RearSightBase', [(-.255, .0838), (-.285, .0838), (-.285, .0880), (-.255, .0880)], -.0055, .0055, 'blued')
    plate('RearLeafL', [(-.266, .0870), (-.272, .0870), (-.272, .1030), (-.266, .1030)], -.0062, -.0017, 'blued', edge=.0005)
    plate('RearLeafR', [(-.266, .0870), (-.272, .0870), (-.272, .1030), (-.266, .1030)], .0017, .0062, 'blued', edge=.0005)
    plate('RearLeafBottom', [(-.266, .0870), (-.272, .0870), (-.272, .1000), (-.266, .1000)], -.0018, .0018, 'blued', edge=.0004)
    plate('FrontRamp', [(-(m - .045), .0848), (-(m - .015), .0848), (-(m - .018), .0910), (-(m - .036), .0910)], -.0032, .0032, 'blued')
    plate('FrontPost', [(-(m - .024), .0905), (-(m - .028), .0905), (-(m - .028), .0978), (-(m - .024), .0978)], -.0010, .0010, 'blued', edge=.0003)
    sphere('FrontBead', (0, .0985, -(m - .026)), .0016, 'brass')
    socket('IronAim', (0, .1000, -.269))
    # birch carbine stock + fore-end in one loft (barrel channel shows the barrel top)
    loft('Stock', [
        (-.470, .074, .056, .0125, 2.2), (-.462, .079, .048, .0180, 2.4), (-.40, .0805, .042, .0200, 2.6),
        (-.26, .0815, .036, .0207, 2.7), (-.15, .0830, .032, .0210, 2.8), (-.03, .0820, .030, .0204, 2.8),
        (.030, .0800, .010, .0192, 2.6), (.070, .0740, -.010, .0168, 2.4), (.110, .0662, -.002, .0157, 2.3),
        (.170, .0690, -.010, .0165, 2.4), (.250, .0724, -.032, .0183, 2.6), (.325, .0750, -.050, .0200, 2.8),
        (.338, .0752, -.053, .0201, 2.9)], 'birch', n=26, sub=3)
    plate('ButtPlate', [(.338, .0754), (.348, .0750), (.348, -.0530), (.338, -.0534)], -.0200, .0200, 'synthetic_black', edge=.002)
    for k in range(6): box('ButtPlateRib', (0, .066 - k * .021, .3484), (.034, .0016, .0012), 'rubber', .0003)
    ring_d('FrontSwivel', .400, .0028, .0045, .004, 'steel_bright', cy=.040)
    ring_d('RearSwivel', -.300, .0028, .0045, .004, 'steel_bright', cy=-.034)
    return mechanics_v3('semi', .1000, .046, mag_rotary, (0, .064, -.090), hl_x=.014)   # support palm under the wood   # flush with the stock bottom


# ---------------------------------------------------------------- optics (origin = Socket_Mount at the rail top)
def optic_reflex_micro():
    """Open micro reflex on a low rail clamp: alloy shell, open hood, tilted coated window."""
    box('ClampBase', (0, .0030, .000), (.0200, .0060, .0420), 'alloy_black', .0012)
    cylinder('ClampScrew', (.011, .0030, -.006), (.016, .0030, -.006), .0030, 'steel_bright', 14)
    loft('LowerHousing', [(.022, .016, .005, .0115, 3.2), (.018, .018, .005, .0125, 3.2), (-.012, .018, .005, .0125, 3.2), (-.020, .015, .005, .0115, 3.2)], 'alloy_black', n=20, sub=1)
    # hood: two side posts and a top bar, the window is open at the back
    for sx in (-1, 1):
        plate('HoodPost', [(-.008, .017), (-.019, .017), (-.019, .040), (-.012, .041), (-.008, .036)], sx * .0128, sx * .0100, 'alloy_black', edge=.0008)
    plate('HoodTop', [(-.006, .0395), (-.020, .0395), (-.020, .0425), (-.006, .0425)], -.0128, .0128, 'alloy_black', edge=.0008)
    box('Emitter', (0, .0190, .015), (.0035, .0030, .0030), 'synthetic_black', .0005)
    box('BrightnessButton', (.0130, .0110, .010), (.0020, .0040, .0060), 'rubber', .0004)
    rect_lens('DotLens', .0145, .0205, .0215, .0285, 'glass', tilt=math.radians(10))
    socket('Mount', (0, 0, 0)); socket('Eye', (0, .0285, .030))


def optic_reddot_tube():
    """1-inch red-dot tube on a riser mount: front objective carries the dot, both eyes open."""
    cy = .030
    box('RiserBase', (0, .0040, -.006), (.0200, .0080, .0460), 'alloy_black', .0012)
    for d in (-.012, .008):
        box('RingStand', (0, .011, d), (.0130, .0090, .0110), 'alloy_black', .0010)
        ring_d('Ring', -d - .0055, .0158, .0185, .011, 'alloy_black', cy=cy)
    lathe_d('Tube', [(-.038, .0150), (-.032, .0162), (-.024, .0158), (.030, .0158), (.038, .0172), (.048, .0172),
                     (.048, .0153), (.040, .0153), (.036, .0147), (-.036, .0147)], 'alloy_black', cy=cy, n=32, cap=False)   # open tube, inner wall
    lathe_d('EyeRim', [(-.034, .0148), (-.040, .0148), (-.040, .0168), (-.033, .0168)], 'rubber', cy=cy, n=32, cap=False)
    box('TurretTop', (0, cy + .0185, -.004), (.012, .007, .012), 'alloy_black', .0015)
    box('TurretSide', (.0185, cy, -.004), (.007, .012, .012), 'alloy_black', .0015)
    cylinder('BrightnessKnob', (-.0160, cy, -.004), (-.0230, cy, -.004), .0072, 'alloy_black', 18)
    lens('RearLens', -.037, .0138, cy, 'glass')
    lens('DotLens', .044, .0150, cy, 'glass')
    socket('Mount', (0, 0, 0)); socket('Eye', (0, cy, .040))


def optic_scope_4x():
    """4x hunting scope on two rings + bases (tube 1", 40 mm objective), duplex."""
    cy = .038
    for d in (-.040, .060):
        box('ScopeBase', (0, .0040, d), (.0160, .0080, .0180), 'blued', .0010)
        box('RingStand', (0, .0120, d), (.0130, .0080, .0120), 'blued', .0010)
        ring_d('ScopeRing', -d - .0060, .0128, .0152, .012, 'blued', cy=cy)
    lathe_d('ScopeBody', [(-.118, .0185), (-.110, .0195), (-.074, .0190), (-.052, .0128), (.060, .0128), (.080, .0128),
                         (.118, .0225), (.150, .0230), (.150, .0212), (.128, .0208)], 'blued', cy=cy, n=32, cap=False)
    lathe_d('EyeBell', [(-.116, .0162), (-.122, .0162), (-.122, .0170), (-.118, .0185)], 'rubber', cy=cy, n=32, cap=False)
    lathe_d('TurretTop', [(-.010, .0001), (-.010, .0105), (.010, .0105), (.010, .0001)], 'blued', cy=cy + .0128 + .010, n=20)
    lathe_d('TurretSide', [(-.010, .0001), (-.010, .0105), (.010, .0105), (.010, .0001)], 'blued', cy=cy, x=.0128 + .010, n=20)
    lens('ScopeEyeLens', -.121, .0160, cy, 'glass')
    lens('ScopeObjLens', .148, .0205, cy, 'glass')
    socket('Mount', (0, 0, 0)); socket('Eye', (0, cy, .120)); socket('Scope', (0, cy, .120))


# ---------------------------------------------------------------- weapon lights (origin = Socket_Mount on the barrel axis)
def light_barrel_clamp():
    """Hunting light on a barrel clamp at 3 o'clock: alloy body, bezel, tail switch, clamp ring."""
    x = .0255; cy = 0.0
    ring_d('ClampRing', -.006, .0090, .0125, .012, 'alloy_black', cy=0.0)
    box('ClampArm', (.0160, 0.0, .000), (.0110, .0100, .0120), 'alloy_black', .0012)
    cylinder('ClampScrew', (.016, -.0060, .000), (.016, -.0110, .000), .0024, 'steel_bright', 12)
    lathe_d('LightBody', [(-.060, .0115), (-.054, .0120), (.020, .0120), (.026, .0145), (.040, .0150), (.040, .0001)], 'alloy_black', cy=cy, x=x, n=28)
    lathe_d('TailCap', [(-.068, .0001), (-.068, .0090), (-.060, .0110)], 'rubber', cy=cy, x=x, n=24)
    lens('LampLens', .0395, .0128, cy, 'lamp_lens', x=x)
    socket('Mount', (0, 0, 0)); socket('Beam', (x, cy, -.041))


def light_taped():
    """A household flashlight taped under the barrel: grey body, two tape wraps."""
    y = -.026
    lathe_d('TorchBody', [(-.090, .0130), (-.084, .0135), (.040, .0135), (.050, .0170), (.070, .0175), (.070, .0001)], 'parkerized', cy=y, n=28)
    lathe_d('TorchTail', [(-.096, .0001), (-.096, .0110), (-.090, .0130)], 'rubber', cy=y, n=24)
    box('TorchSwitch', (0, y - .0140, -.020), (.0070, .0030, .0110), 'rubber', .0008)
    lens('LampLens', .0695, .0150, y, 'lamp_lens')
    for d in (-.050, .020):
        # tape wrap around barrel + torch: a stadium loop in cross-section
        loft('TapeWrap', [(-d - .009, .0115, y - .0150, .0148, 3.4), (-d, .0120, y - .0155, .0153, 3.4), (-d + .009, .0115, y - .0150, .0148, 3.4)], 'tape_grey', n=24, sub=1)
    socket('Mount', (0, 0, 0)); socket('Beam', (0, y, -.071))


# ---------------------------------------------------------------- build
RIFLES = [('compact_patrol_rifle', 'semi', compact_patrol_rifle, 'Compact .22 rimfire carbine, birch stock, alloy receiver with rail, iron sights')]
OPTICS = [('reflex_micro', optic_reflex_micro, 'Open micro reflex sight on a rail clamp'),
          ('reddot_tube', optic_reddot_tube, '1-inch red-dot tube on a riser mount'),
          ('scope_4x', optic_scope_4x, '4x hunting scope on rings and bases')]
LIGHTS = [('light_clamp', light_barrel_clamp, 'Hunting light on a barrel clamp'),
          ('light_taped', light_taped, 'Household flashlight taped under the barrel')]

for name, mode, build, description in RIFLES:
    if ONLY and name not in ONLY: continue
    start(name, description, [.05, .2, MUZ3[name] + .36])
    current['forward_axis'] = '-Z'; current['origin'] = 'trigger-hand reference'
    current['reload_style'] = 'individual_round' if mode == 'lever' else 'detachable_magazine'
    parts = build(); make_clips(parts, mode); export_v3('rifle')
for kind, table in (('optic', OPTICS), ('light', LIGHTS)):
    for name, build, description in table:
        if ONLY and name not in ONLY: continue
        start(name, description, [.05, .05, .2]); build(); export_v3(kind)

meta = {'name': 'Weapon Kit v3', 'version': '3.0.0', 'units': 'metres', 'forward_axis': '-Z',
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'assets': RECORD}
old = OUT / 'manifest.json'
if ONLY and old.exists():
    prev = json.loads(old.read_text()); prev['assets'].update(RECORD); meta['assets'] = prev['assets']
old.write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8', newline='\n')
print('W3_EXPORT_DONE', len(RECORD), flush=True)
