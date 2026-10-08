"""Rifle sheet kit v2: the eight game rifles rebuilt to match Troy's painted rifle sheet (2026-10-08).

Keeps the runtime contract of the North Ridge kit (same asset ids, Pivot_/Socket_ names,
NLA clips, trigger-hand origin, -Z forward) so WeaponPresentation / Viewmodel keep working.
Only the visible design changes: scoped bolt-action / hunting silhouettes, painted wood,
camo and coloured scopes, low-poly faceted forms.

  blender --background --factory-startup --python tools/blender/gen_rifle_sheet_weapons.py [-- --render]
Textures first: tools/terrain/.venv/Scripts/python.exe tools/blender/gen_rifle_sheet_textures.py
"""
from pathlib import Path
import bpy, bmesh, math, json, hashlib, sys
from mathutils import Vector

HERE = Path(__file__).resolve().parent
_codex = (HERE / 'gen_north_ridge_weapons.py').read_text(encoding='utf-8')
# Reuse the proven helpers, clip authoring and exporter (everything before the old SPECS table).
exec(_codex[:_codex.index('\nSPECS=[')])

OUT = ROOT / 'tools/blender/generated/rifle_sheet_kit_v2'
SRC = OUT / 'source'; TEX = OUT / 'textures'; ENGINE = OUT / 'godot'; SHOTS = OUT / 'previews'
for p in (SRC, ENGINE, SHOTS): p.mkdir(parents=True, exist_ok=True)
M = {}; RECORD = {}; ASSETS = []; COMPONENTS = {}; CLIPS = {}

# roughness, metallic per painted tile
PROPS = {
    'wood_brown': (.72, 0), 'wood_orange': (.70, 0), 'wood_amber': (.66, 0), 'wood_grain': (.75, 0), 'wood_lime': (.68, 0),
    'camo_green': (.78, 0), 'camo_grey': (.62, .15), 'metal_dark': (.48, .55), 'metal_grey': (.45, .55),
    'scope_dark': (.42, .45), 'scope_red': (.45, .25), 'scope_green': (.45, .25), 'scope_brown': (.55, .2),
    'copper': (.40, .65), 'tape_green': (.85, 0), 'strap_brown': (.85, 0), 'rubber_white': (.80, 0),
    'rubber_dark': (.85, 0), 'lens_orange': (.15, .1), 'glass': (.08, .3), 'brass': (.35, .7), 'steel': (.40, .65)}
ALIAS = {'blued': 'metal_dark', 'rubber': 'rubber_dark'}
UV_M = 1 / 0.30   # one texture tile per 30 cm: bold brush marks at viewmodel distance


def material(key):
    key = ALIAS.get(key, key)
    if key in M: return M[key]
    m = bpy.data.materials.new('Sheet_' + key); m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = image(TEX / (key + '.png'))
    m.node_tree.links.new(t.outputs['Color'], bs.inputs['Base Color'])
    r, mt = PROPS[key]
    bs.inputs['Roughness'].default_value = r; bs.inputs['Metallic'].default_value = mt
    px = t.image.pixels[:4]; m.diffuse_color = (px[0], px[1], px[2], 1)
    M[key] = m; return m


def project_uv(o):
    """Per-face planar projection in game space: grain and camo run along the barrel (Z)."""
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


# ---------------------------------------------------------------- shape helpers (game coords, metres)
def tube(name, d0, d1, r, key, cy=.075, n=10, parent=None):
    return tube_z(name, [(d0, r, cy), (d1, r, cy)], key, parent, n=n)


def band(name, d, r, key, cy=.075, w=.012, n=10, parent=None):
    return tube_z(name, [(d, r, cy), (d + w, r, cy)], key, parent, n=n)


def profile(name, pts, width, key, edge=.005, parent=None):
    return outline_yz(name, pts, width, key, parent, edge)


def sphere(name, p, r, key, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r, location=cv(p))
    o = bpy.context.object; o.name = name; return bind(o, key, parent)


def disc(name, d, r, key, cy, x=0.0, parent=None, n=12):
    return cylinder(name, (x, cy, -d), (x, cy, -d - .002), r, key, n, parent)


def scope(cy, d_eye, d_obj, r_tube, r_eye, r_obj, body, accent=None, rings='metal_dark', mount_y=.097,
          turret=None, mounts=(-.005, -.17), objective_cap=None):
    """Faceted riflescope on two ring mounts; lens faces are dark glass."""
    st = [(d_eye, r_eye * .92, cy), (d_eye + .012, r_eye, cy), (d_eye + .060, r_eye, cy), (d_eye + .090, r_tube, cy),
          (d_obj - .110, r_tube, cy), (d_obj - .060, r_obj, cy), (d_obj, r_obj, cy)]
    tube_z('ScopeBody', st, body, n=12)
    socket('Scope', (0, cy, -d_eye))   # runtime: optic present -> HUD scope picture when fully aimed
    disc('ScopeEyeLens', d_eye - .001, r_eye * .78, 'glass', cy)
    disc('ScopeObjLens', d_obj + .001 - .002, r_obj * .82, 'glass', cy)
    if accent:
        band('ScopeEyeRing', d_eye + .018, r_eye * 1.04, accent, cy, .014, 12)
        band('ScopeObjRing', d_obj - .030, r_obj * 1.04, accent, cy, .016, 12)
    mid = (d_eye + d_obj) / 2
    tk = turret or accent or body
    cylinder('ScopeTurretTop', (0, cy + r_tube, -mid), (0, cy + r_tube + .022, -mid), .010, tk, 10)
    cylinder('ScopeTurretSide', (r_tube, cy, -mid), (r_tube + .020, cy, -mid), .010, tk, 10)
    for d in mounts:
        band('ScopeRing', -d - .006, r_tube * 1.18, rings, cy, .014, 10)
        box('ScopeMount', (0, (mount_y + cy - r_tube) / 2, d), (.016, cy - r_tube - mount_y + .008, .016), rings, .002)
    if objective_cap:
        # flip-up lens cover standing above the objective, like the hunting rifle on the sheet
        cylinder('FlipCap', (0, cy + r_obj * 1.9, -d_obj + .002), (0, cy + r_obj * 1.9, -d_obj - .006), r_obj * .95, objective_cap, 12)
        box('FlipCapHinge', (0, cy + r_obj + .004, -d_obj + .004), (.008, .010, .006), 'copper', .001)


def sling(d_front, y_front, d_back, y_back, sag, key='strap_brown', x=.0):
    pts = []
    for i in range(13):
        t = i / 12
        z = -(d_front + (d_back - d_front) * t); y = y_front + (y_back - y_front) * t - sag * 4 * t * (1 - t)
        pts.append((x, y, z))
    for i in range(12): cylinder('SlingStrap', pts[i], pts[i + 1], .006, key, 4)


def bolt_knob(parent, root=(.024, .081, -.022), bent=True):
    if bent:
        wire('BoltHandleArm', [root, (.046, .068, -.012), (.052, .050, -.008)], 'metal_grey', .0042, parent)
        sphere('BoltKnob', (.052, .050, -.008), .011, 'metal_dark', parent)
    else:
        wire('BoltHandleArm', [root, (.052, root[1], root[2])], 'metal_grey', .0042, parent)
        sphere('BoltKnob', (.056, root[1], root[2]), .010, 'metal_dark', parent)


def round_receiver(key, d0=-.03, d1=.215, r=.021):
    tube('ReceiverTube', d0, d1, r, key, n=12)
    box('ReceiverBelly', (0, .048, -.092), (.036, .032, .23), key, .004)
    box('EjectionPort', (.0205, .083, -.075), (.003, .016, .060), 'rubber_dark', .001)
    box('TriggerHousing', (0, .016, .021), (.034, .040, .090), 'metal_dark', .003)


def box_receiver(key, length=.25, h=.066):
    box('ReceiverBox', (0, .075 - .033 + h / 2, -.092), (.046, h, length), key, .006)
    box('ReceiverTopRail', (0, .075 + h / 2 + .002, -.092), (.030, .006, length * .9), 'metal_dark', .001)
    box('EjectionPort', (.0235, .080, -.075), (.003, .018, .062), 'rubber_dark', .001)
    box('TriggerHousing', (0, .016, .021), (.034, .040, .090), 'metal_dark', .003)


def mag_well():
    box('MagWell', (0, .036, -.103), (.040, .030, .082), 'metal_dark', .003)


def classic_stock(key, butt, drop=0.0, comb=.092, toe=-.050, thumb=False, cheek=False):
    """Straight hunting / service stock in side profile (z back, y up). Wrist sits at the HandR socket."""
    # Slim wrist (~6 cm) like the sheet, then the comb rises and the toe drops toward the butt.
    pts = [(.018, .086), (.075, .080), (.14, .074), (.24, comb - drop * .5 - .004), (butt - .01, comb - drop), (butt, comb - drop - .006),
           (butt, toe - drop), (butt - .03, toe - drop + .002), (.19, .004), (.13, .016), (.085, .010), (.050, -.020), (.018, .030)]
    profile('Stock', pts, .040, key, .007)
    if cheek: box('CheekPiece', (-.016, comb - drop - .004, butt - .13), (.012, .030, .15), key, .006)


def butt_pad(butt, top, bottom, key='rubber_dark', depth=.016, width=.046):
    box('ButtPad', (0, (top + bottom) / 2, butt + depth / 2), (width, top - bottom, depth), key, .004)


def lower_forend(key, d0, d1, top=.064, bottom=.020, nose=.010):
    pts = [(-d0, top), (-(d1 - nose), top), (-d1, top - .010), (-d1, bottom + .008), (-(d1 - nose * 2), bottom), (-d0, bottom - .004)]
    profile('ForeEnd', pts, .044, key, .006)
    return bottom - .004


def full_forend(key, d0, d1, top=.080, bottom=.024):
    pts = [(-d0, top), (-d1 + .02, top - .004), (-d1, top - .016), (-d1, bottom + .010), (-d1 + .03, bottom), (-d0, bottom - .006)]
    profile('FullStockFore', pts, .040, key, .006)
    return bottom - .006


def upper_guard(key, d0, d1, y0=.082, y1=.098):
    profile('UpperGuard', [(-d0, y1), (-d1, y1 - .004), (-d1, y0), (-d0, y0)], .034, key, .005)


def barrel(muzzle, r=.0105, key='metal_dark', start=.20, crown=True):
    tube_z('Barrel', [(start, r, .075), (muzzle - .02, r * .92, .075), (muzzle, r * .92, .075)], key, n=10)
    if crown: band('MuzzleCrown', muzzle - .014, r * 1.18, key, .075, .014, 10)


def front_post(muzzle, key='metal_dark', h=.030):
    box('FrontSightBase', (0, .075 + .012, -muzzle + .035), (.016, .020, .020), key, .002)
    box('FrontSightPost', (0, .075 + .012 + h / 2, -muzzle + .035), (.004, h, .010), key, .001)


# ---------------------------------------------------------------- shared mechanical contract
def small_guard(draw=True):
    # Compact rounded guard like the sheet (the old kit's hexagonal hoop read far too large).
    if draw: wire('TriggerGuard', [(0, -.002, .052), (0, -.026, .056), (0, -.040, .036), (0, -.038, .004), (0, -.022, -.012), (0, -.004, -.010)], 'metal_dark', .0034)
    trigger = node('Trigger', (0, -.001, .024))
    wire('CurvedTrigger', [(0, -.004, .024), (0, -.020, .028), (0, -.031, .019)], 'steel', .0022, trigger)
    return trigger


def mechanics(name, mode, mag_h, hl_y, aim_y, bent_bolt=True, mag_key='metal_dark', mag_lean=.010):
    trigger = small_guard(mode != 'lever')
    bolt = node('Bolt', (0, .079, -.068)); box('SlidingBolt', (0, .079, -.068), (.030, .024, .128), 'steel', .004, bolt)
    handle = node('BoltHandle', (.026, .081, -.022), bolt)
    charge = node('ChargingHandle', (.027, .085, -.053))
    if mode == 'bolt': bolt_knob(handle, bent=bent_bolt)
    elif mode == 'semi': bolt_knob(charge, root=(.020, .085, -.053), bent=False)
    release = node('MagazineRelease', (.027, .019, -.095)); box('ReleasePaddle', (.022, .014, -.095), (.006, .018, .020), 'steel', .001, release)
    safety = node('Safety', (.026, .094, .015)); box('SafetyLever', (.022, .096, .017), (.005, .009, .023), 'metal_dark', .001, safety)
    mag = None
    if mode != 'lever':
        mag_well()
        mag = magazine((0, .026, -.103), mag_h, mag_lean)
        if mag_key != 'metal_dark':
            for o in mag.children_recursive:
                if o.type == 'MESH': o.data.materials[0] = material(mag_key)
    hr = socket('HandR', (.041, -.024, .067)); hl = socket('HandL', (-.038, hl_y, -.38))
    socket('Muzzle', (0, .075, -MUZ[name])); socket('Aim', (0, aim_y, .052)); socket('Ejection', (.029, .079, -.065))
    socket('MagazineInsert', (0, .026, -.103)); socket('TriggerFinger', (.021, -.026, .023)); socket('BoltHand', (.052, .050, -.008), handle)
    case = node('SpentCase', (.037, .079, -.056)); casing('VisualCase', (.037, .079, -.056), case); case.scale = Vector((.0001,) * 3)
    parts = {'bolt': bolt, 'handle': handle, 'charge': charge, 'trigger': trigger, 'release': release, 'mag': mag, 'hr': hr, 'hl': hl, 'case': case}
    return parts


MUZ = {'frontier_vented_rifle': .70, 'ridge_scout_rifle': .76, 'timber_bolt_carbine': .70, 'brush_lever_rifle': .68,
       'ranger_box_rifle': .72, 'north_service_rifle': .68, 'compact_patrol_rifle': .57, 'expedition_rifle': .78}


# ---------------------------------------------------------------- the eight rifles (sheet order)
def frontier_vented_rifle():
    # Sheet top-left: plain brown stock, grey-camo vented shroud, scope with red cap turret, copper bands, sling.
    m = MUZ[current.name]
    classic_stock('wood_brown', .37, drop=.004, comb=.090)
    butt_pad(.37, .086, -.054, 'rubber_dark')
    box_receiver('camo_grey', .25, .060)
    tube_z('VentShroud', [(.20, .029, .074), (.57, .029, .074), (.59, .022, .074)], 'camo_grey', n=12)
    for k in range(9):
        for side in (-1, 1):
            cylinder('ShroudVent', (side * .0265, .074, -.25 - k * .036), (side * .0300, .074, -.25 - k * .036), .0075, 'rubber_dark', 8)
    barrel(m, .0105, 'metal_dark', start=.58)
    band('TapeWrap', .50, .0305, 'tape_green', .074, .030, 12)
    for d in (.24, .53): band('CopperBand', d, .0315, 'copper', .074, .010, 12)
    front_post(m)
    scope(.150, -.05, .26, .016, .019, .021, 'scope_dark', None, 'copper', mount_y=.106, turret='scope_red', mounts=(-.0, -.18))
    sphere('RedTurretCap', (0, .150 + .016 + .026, -.105), .013, 'scope_red')
    sling(.53, .045, -.30, -.030, .16)
    return mechanics(current.name, 'semi', .10, .045, .150)


def ridge_scout_rifle():
    # Sheet top-right: orange stock with white skeleton butt block, long grey-camo receiver, big dark scope with red ends.
    m = MUZ[current.name]
    classic_stock('wood_orange', .33, drop=.0, comb=.094, toe=-.040)
    box('SkeletonButt', (0, .030, .345), (.040, .130, .030), 'rubber_white', .006)
    box('SkeletonButtLink', (0, .088, .315), (.030, .016, .030), 'rubber_white', .004)
    box_receiver('camo_grey', .30, .062)
    for k in range(3): box('ReceiverFlute', (.0235, .066 + k * .011, -.10), (.002, .004, .22), 'metal_grey', .0006)
    bot = lower_forend('wood_orange', .17, .54, top=.062, bottom=.024)
    tube_z('FlutedBarrel', [(.20, .0125, .075), (.66, .0115, .075)], 'camo_grey', n=8)
    barrel(m, .0100, 'metal_grey', start=.66)
    box('MuzzleDevice', (0, .075, -m + .025), (.026, .026, .050), 'metal_grey', .003)
    scope(.152, -.06, .30, .018, .023, .027, 'scope_dark', 'scope_red', 'metal_grey', mount_y=.106, turret='scope_red', mounts=(-.01, -.20))
    return mechanics(current.name, 'semi', .055, bot, .152)


def timber_bolt_carbine():
    # Sheet middle-left: green-camo full stock (Mosin-like), short brown scout scope, steel bands, bent bolt, sling.
    m = MUZ[current.name]
    classic_stock('camo_green', .36, drop=.010, comb=.084, toe=-.048)
    butt_pad(.36, .074, -.058, 'metal_grey', .010)
    round_receiver('metal_grey')
    bot = full_forend('camo_green', .12, .60, top=.074, bottom=.026)
    upper_guard('camo_green', .21, .54, .080, .095)
    barrel(m, .0100, 'metal_dark', start=.20)
    for d in (.30, .56): band('BarrelBand', d, .030, 'metal_grey', .062, .012, 10)
    front_post(m, h=.024)
    scope(.128, .02, .22, .0125, .015, .015, 'scope_brown', None, 'metal_dark', mount_y=.097, mounts=(-.045, -.15))
    sling(.45, .030, -.28, -.036, .15)
    return mechanics(current.name, 'bolt', .085, bot, .128)


def brush_lever_rifle():
    # Sheet middle-right: brown woodgrain thumbhole stock, block scope with orange lenses, lever loop.
    m = MUZ[current.name]
    # thumbhole: lower butt/grip piece plus a separate comb bridge, leaving a real gap between them
    profile('ThumbholeLower', [(.035, .040), (.10, .026), (.16, .040), (.26, .070), (.35, .072), (.36, .070), (.36, -.050),
                               (.33, -.050), (.19, -.016), (.11, -.036), (.07, -.040), (.03, -.012)], .040, 'wood_grain', .007)
    profile('ThumbholeComb', [(.018, .088), (.16, .094), (.36, .098), (.36, .066), (.25, .072), (.14, .068), (.07, .066), (.018, .060)], .036, 'wood_grain', .006)
    butt_pad(.36, .098, -.050, 'rubber_dark')
    box_receiver('metal_grey', .24, .062)
    bot = lower_forend('wood_grain', .17, .46, top=.060, bottom=.030)
    barrel(m, .0105, 'metal_dark')
    tube('LeverMagTube', .17, m - .06, .0085, 'metal_dark', cy=.044, n=10)
    front_post(m)
    # block scope: painted wooden housing, round orange lens faces front and back
    box('BlockScope', (0, .136, -.11), (.040, .040, .17), 'wood_brown', .006)
    for d, nm in ((.025, 'BlockLensRear'), (.195, 'BlockLensFront')):
        disc(nm, d - .003, .015, 'lens_orange', .136)
    box('BlockScopeBase', (0, .108, -.11), (.024, .018, .12), 'metal_grey', .002)
    socket('Scope', (0, .136, -.025))
    parts = mechanics(current.name, 'lever', 0, bot, .136)
    lever = node('Lever', (0, -.008, .006))
    wire('LeverLoop', [(0, -.010, .045), (0, -.028, .086), (0, -.064, .084), (0, -.076, .040), (0, -.052, -.008), (0, -.012, -.012)], 'metal_grey', .0042, lever)
    gate = node('LoadingGate', (.026, .052, -.086)); box('GatePlate', (.026, .052, -.086), (.003, .018, .045), 'steel', .001, gate)
    round_ = node('InsertRound', (.041, .044, -.072)); casing('InsertionRound', (.041, .044, -.072), round_, round_tip=True)
    round_.scale = Vector((.0001,) * 3); socket('LoadingGate', (.028, .046, -.082))
    parts.update({'lever': lever, 'gate': gate, 'round': round_})
    return parts


def ranger_box_rifle():
    # Sheet bottom-left: amber hunting stock to the muzzle, long red scope with copper rings and flip cap.
    m = MUZ[current.name]
    classic_stock('wood_amber', .38, drop=.010, comb=.090, toe=-.050, cheek=True)
    butt_pad(.38, .080, -.060, 'rubber_white', .012)
    round_receiver('metal_dark')
    bot = full_forend('wood_amber', .12, .56, top=.072, bottom=.030)
    barrel(m, .0102, 'metal_dark', start=.20)
    for d in (.32, .55): band('BarrelBand', d, .028, 'rubber_white', .062, .010, 10)
    scope(.140, -.08, .34, .016, .018, .020, 'scope_red', 'copper', 'copper', mount_y=.097, turret='copper', mounts=(-.01, -.22), objective_cap='scope_red')
    for d in (-.03, .10, .20): band('ScopeCopperBand', d, .0185, 'copper', .140, .010, 12)
    return mechanics(current.name, 'semi', .055, bot, .140)


def north_service_rifle():
    # Sheet middle-right lower: lime Enfield-style stock with top handguard, copper bands, red-dot tube sight.
    m = MUZ[current.name]
    # wrist has a shallow pistol swell (game treats this rifle as pistol-grip)
    pts = [(.018, .086), (.10, .084), (.22, .084), (.36, .086), (.37, .080), (.37, -.054), (.34, -.052), (.20, -.012),
           (.12, -.030), (.090, -.062), (.060, -.066), (.042, -.026), (.018, .030)]
    profile('Stock', pts, .040, 'wood_lime', .007)
    butt_pad(.37, .086, -.054, 'metal_grey', .010)
    round_receiver('metal_grey')
    bot = full_forend('wood_lime', .12, .60, top=.074, bottom=.028)
    upper_guard('wood_lime', .20, .58, .081, .096)
    barrel(m, .0100, 'metal_dark', start=.20)
    for d in (.40, .57): band('CopperBand', d, .031, 'copper', .064, .014, 10)
    box('NoseCap', (0, .086, -m + .045), (.022, .036, .040), 'metal_dark', .003)
    front_post(m, h=.030)
    scope(.132, .00, .19, .013, .015, .017, 'metal_grey', 'lens_orange', 'copper', mount_y=.097, turret='scope_red', mounts=(-.03, -.15))
    band('RedDotObjective', .175, .0185, 'scope_red', .132, .016, 12)
    return mechanics(current.name, 'semi', .12, bot, .132)


def compact_patrol_rifle():
    # Not on the sheet: compact companion in the same palette (grey camo, orange wood, small red sight).
    m = MUZ[current.name]
    fold = node('FoldingStock', (.034, .04, .03))
    for side in (-1, 1): wire('WireStock', [(side * .022, .04, .02), (side * .027, -.05, .30), (side * .027, .063, .30), (side * .022, .04, .02)], 'metal_dark', .006, fold)
    box('StockShoulderPad', (0, .01, .30), (.058, .12, .014), 'rubber_dark', .003, fold)
    profile('WoodPistolGrip', [(.046, .018), (.089, .012), (.092, -.14), (.05, -.15), (.014, -.034)], .033, 'wood_orange', .004)
    box_receiver('camo_grey', .24, .064)
    bot = lower_forend('wood_orange', .17, .40, top=.062, bottom=.024)
    barrel(m, .0110, 'metal_dark')
    box('MuzzleDevice', (0, .075, -m + .02), (.024, .024, .040), 'metal_dark', .003)
    front_post(m)
    box('RedDotHousing', (0, .128, -.06), (.034, .034, .06), 'scope_red', .006)
    disc('RedDotLens', .03 - .002, .012, 'lens_orange', .128)
    box('RedDotBase', (0, .106, -.06), (.022, .012, .05), 'metal_dark', .002)
    socket('Scope', (0, .128, -.03))
    parts = mechanics(current.name, 'semi', .15, bot, .128)
    parts['fold'] = fold
    return parts


def expedition_rifle():
    # Sheet bottom-right: grey-camo chassis sniper, adjustable cheek riser, big green scope, muzzle brake.
    m = MUZ[current.name]
    profile('ChassisButt', [(.10, .072), (.38, .072), (.40, .060), (.40, -.050), (.36, -.058), (.24, -.040), (.14, .005), (.10, .030)], .042, 'camo_grey', .006)
    box('CheekRiser', (0, .090, .27), (.036, .030, .16), 'camo_grey', .005)
    for d in (.225, .315): cylinder('RiserPost', (0, .072, d), (0, .078, d), .005, 'metal_dark', 8)
    butt_pad(.40, .072, -.058, 'rubber_dark', .020, .050)
    profile('PistolGrip', [(.042, .018), (.085, .014), (.104, -.125), (.063, -.14), (.014, -.025)], .034, 'camo_grey', .004)
    box('ChassisSpine', (0, .045, .06), (.034, .036, .12), 'camo_grey', .004)
    box_receiver('camo_grey', .26, .060)
    box('ChassisForend', (0, .058, -.33), (.050, .050, .32), 'camo_grey', .006)
    for k in range(4): box('ForendSlot', (.0255, .060, -.22 - k * .07), (.002, .014, .040), 'rubber_dark', .0006)
    barrel(m, .0125, 'metal_dark', start=.48)
    box('MuzzleBrake', (0, .075, -m + .030), (.030, .028, .060), 'metal_dark', .004)
    for k in range(3): box('BrakePort', (.0152, .075, -m + .012 + k * .016), (.002, .016, .008), 'rubber_dark', .0005)
    scope(.152, -.07, .33, .017, .022, .029, 'scope_green', 'scope_red', 'metal_dark', mount_y=.106, turret='metal_dark', mounts=(-.02, -.21))
    return mechanics(current.name, 'semi', .15, .033, .152, mag_key='metal_dark', mag_lean=.019)


SPECS = [
    ('frontier_vented_rifle', 'semi', frontier_vented_rifle, 'Plain brown stock, vented grey-camo shroud, red-cap scope, copper bands, sling'),
    ('ridge_scout_rifle', 'semi', ridge_scout_rifle, 'Orange stock, white skeleton butt, long grey-camo receiver, big dark scope with red ends'),
    ('timber_bolt_carbine', 'bolt', timber_bolt_carbine, 'Green-camo full stock bolt rifle, short brown scout scope, sling'),
    ('brush_lever_rifle', 'lever', brush_lever_rifle, 'Woodgrain thumbhole lever rifle with orange-lens block sight'),
    ('ranger_box_rifle', 'semi', ranger_box_rifle, 'Amber hunting stock, long red scope with copper rings and flip cap'),
    ('north_service_rifle', 'semi', north_service_rifle, 'Lime service stock, copper bands, red-dot tube sight'),
    ('compact_patrol_rifle', 'semi', compact_patrol_rifle, 'Folding-stock compact rifle in the sheet palette'),
    ('expedition_rifle', 'semi', expedition_rifle, 'Grey-camo chassis sniper rifle, green scope, muzzle brake'),
]
for name, mode, build, description in SPECS:
    start(name, description, [.09, .25, MUZ[name] + .40])
    current['forward_axis'] = '-Z'; current['origin'] = 'trigger-hand reference'
    current['reload_style'] = 'individual_round' if mode == 'lever' else 'detachable_magazine'
    current['art_source'] = 'Troy rifle reference sheet 2026-10-08 (rifle_sheet_kit_v2)'
    parts = build()
    make_clips(parts, mode); export_asset()

meta = {'name': 'Rifle Sheet Kit v2', 'version': '2.0.0', 'units': 'metres', 'forward_axis': '-Z',
        'origin': 'Weapon trigger-hand reference', 'provenance': "Original Blender geometry and painted tiles following Troy's own rifle sheet",
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'assets': RECORD}
(OUT / 'manifest.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8', newline='\n')
print('RIFLE_SHEET_EXPORT_DONE', len(RECORD), flush=True)

if '--render' in sys.argv:
    # Recreate the sheet: two columns, rifles tilted muzzle-up, near-black backdrop, right side facing camera.
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1920; scene.render.resolution_y = 1080; scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'
    scene.world = scene.world or bpy.data.worlds.new('World'); scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background'); bg.inputs[0].default_value = (.006, .006, .006, 1); bg.inputs[1].default_value = 1.0
    for coll in bpy.data.collections:
        if coll.name.endswith('_Editable'): coll.hide_render = False
    layout = {'frontier_vented_rifle': (-.76, .50), 'ridge_scout_rifle': (.44, .54), 'timber_bolt_carbine': (-.76, .10),
              'brush_lever_rifle': (.44, .14), 'ranger_box_rifle': (-.76, -.30), 'north_service_rifle': (.44, -.26),
              'compact_patrol_rifle': (-.70, -.72), 'expedition_rifle': (.44, -.68)}
    scene.frame_set(0)
    for asset in ASSETS:
        if asset.name in layout:
            ly, lz = layout[asset.name]
            asset.rotation_euler = (math.radians(14), 0, 0)
            asset.location = (0, ly - .02, lz)
    def area(loc, energy, size, color=(1, 1, 1)):
        bpy.ops.object.light_add(type='AREA', location=loc); o = bpy.context.object
        o.data.energy = energy; o.data.size = size; o.data.color = color
        o.rotation_euler = (Vector((0, 0, 0)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    area((3.0, -1.5, 3.0), 380, 4); area((3.5, 2.5, -.5), 140, 4, (.92, .96, 1)); area((-2.0, 0, 3.0), 160, 3)
    bpy.ops.object.camera_add(location=(3.2, 0, 0)); cam = bpy.context.object; scene.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 3.0
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(SHOTS / 'rifle_sheet.png'); bpy.ops.render.render(write_still=True)
    print('RIFLE_SHEET_RENDER_DONE', flush=True)
