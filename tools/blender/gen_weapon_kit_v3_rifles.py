"""Weapon kit v3, W2 (2026-10-18): the seven remaining rifles + their optics, exec'd by
gen_weapon_kit_v3.py (shares its helpers: loft, lathe_d, ring_d, plate, sphere, lens, box,
cylinder, wire, node, socket, casing, mechanics sockets, MUZ3).

Game coordinates, metres: origin = trigger hand reference, forward -Z, bore axis y = .075.
Proportions are from real archetypes (no brands):
  ranger      walnut bolt sporter, .308-class, 22" barrel, detachable 4, folding leaf + bead
  timber      scout bolt carbine, camo-dipped synthetic, 16.5", forward scout rail, ghost ring
  service     surplus military bolt rifle, birch, full wood, 10-round box, aperture + protected post
  frontier    SKS-type semi carbine, hardwood, gas tube + handguard, cover rail, tangent rear
  brush lever lever carbine, walnut straight grip, tube magazine, buckhorn + bead
  ridge       varmint bolt rifle, grey laminate, heavy stainless barrel, no irons, threaded
  expedition  magnum bolt rifle, black synthetic, muzzle brake, express rear + hooded bead
"""

BOLT = {'lift': 1.05, 'travel': .090}


def _cr_path(pts, sub=5):
    out = []
    for i in range(len(pts) - 1):
        a = pts[max(i - 1, 0)]; b = pts[i]; c = pts[i + 1]; d = pts[min(i + 2, len(pts) - 1)]
        for k in range(sub):
            t = k / sub
            out.append(tuple(.5 * ((2 * b[j]) + (-a[j] + c[j]) * t + (2 * a[j] - 5 * b[j] + 4 * c[j] - d[j]) * t * t + (-a[j] + 3 * b[j] - 3 * c[j] + d[j]) * t ** 3) for j in range(2)))
    out.append(pts[-1]); return out


def strip(name, pts_zy, width, thick, key, parent=None, sub=5):
    """Flat band swept along a smooth side-profile path (trigger guards, lever loops)."""
    P_ = _cr_path(pts_zy, sub); vs = []; fs = []; n = len(P_)
    for i, (z, y) in enumerate(P_):
        z0, y0 = P_[max(i - 1, 0)]; z1, y1 = P_[min(i + 1, n - 1)]
        tz, ty = z1 - z0, y1 - y0; L = math.hypot(tz, ty) or 1.0; nz, ny = -ty / L, tz / L
        for sx, sn in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append((sx * width / 2, y + sn * ny * thick / 2, z + sn * nz * thick / 2))
    for i in range(n - 1):
        for k in range(4): fs.append((i * 4 + k, i * 4 + (k + 1) % 4, (i + 1) * 4 + (k + 1) % 4, (i + 1) * 4 + k))
    fs.append((0, 1, 2, 3)); fs.append(((n - 1) * 4 + 3, (n - 1) * 4 + 2, (n - 1) * 4 + 1, (n - 1) * 4))
    return _smooth(mesh(name, vs, fs, key, parent, smooth=True), 50)


def trigger_guard_v4(key='alloy_black'):
    """Guard plate + a flat rounded bow ~3 cm under the stock line, and a hooked trigger blade."""
    plate('GuardPlate', [(.064, .0300), (-.036, .0300), (-.036, .0230), (.064, .0230)], -.0085, .0085, key, edge=.0010)
    strip('TriggerGuardBow', [(-.028, .0250), (-.030, .0120), (-.022, .0005), (-.006, -.0075), (.014, -.0100), (.034, -.0080),
                              (.048, .0000), (.055, .0120), (.056, .0240)], .0072, .0032, key)
    trigger = node('Trigger', (0, .0230, .018))
    plate('TriggerBlade', [(.016, .0240), (.0125, .0120), (.0120, .0010), (.0160, -.0050), (.0200, -.0040), (.0175, .0040),
                           (.0180, .0130), (.0215, .0240)], -.0028, .0028, 'steel_bright', trigger, edge=.0006)
    return trigger


trigger_guard_v3 = trigger_guard_v4   # compact_patrol_rifle (W1) picks it up too


def turret(name, base, axis, key, r=.0092, h=.0105):
    """Scope adjustment turret: a short drum standing off the saddle with a knurled cap (axis 'y' or 'x')."""
    ax = (0, 1, 0) if axis == 'y' else (1, 0, 0)
    p1 = tuple(base[i] + ax[i] * h for i in range(3)); p2 = tuple(base[i] + ax[i] * (h + .0045) for i in range(3))
    cylinder(name, base, p1, r, key, 24)
    cylinder(name + 'Cap', p1, p2, r * 1.06, key, 24)
    for k in range(12):
        a = k * TAU / 12; o = (math.cos(a) * r * 1.07, math.sin(a) * r * 1.07)
        q = (o[0], p1[1] + .0022, base[2] + o[1]) if axis == 'y' else (p1[0] + .0022, base[1] + o[0], base[2] + o[1])
        box(name + 'Knurl', q, (.0012, .0040, .0012) if axis == 'y' else (.0040, .0012, .0012), key, .0002)


def screw(name, p, axis='y', r=.0024, key='steel_bright', parent=None, sign=-1):
    """Slotted screw head (blued/bright) standing .8 mm proud, slot across it."""
    ax = {'x': (1, 0, 0), 'y': (0, 1, 0), 'z': (0, 0, 1)}[axis]; ax = tuple(sign * a for a in ax)
    p0 = tuple(p[i] - ax[i] * .0004 for i in range(3)); p1 = tuple(p[i] + ax[i] * .0008 for i in range(3))
    cylinder(name, p0, p1, r, key, 12, parent)
    sz = {'x': (.0006, .0007, r * 1.9), 'y': (r * 1.9, .0006, .0007), 'z': (r * 1.9, .0007, .0006)}[axis]
    box(name + 'Slot', tuple(p[i] + ax[i] * .0008 for i in range(3)), sz, 'synthetic_black', .0001, parent)


def barrel3(rear_z, muzzle, r0, r1, key='blued', n=28, thread=False):
    """Tapered barrel from the receiver face (rear_z < 0) to a recessed crown with an open bore."""
    d0 = -rear_z
    st = [(d0, r0 + .0012), (d0 + .014, r0 + .0012), (d0 + .018, r0), (d0 + .12, r0 - .0008),
          (muzzle - .010, r1), (muzzle - .002, r1), (muzzle, r1 - .0010), (muzzle, .0040), (muzzle - .012, .0036)]
    if thread:   # threaded muzzle with a knurled thread protector
        st = st[:4] + [(muzzle - .030, r1), (muzzle - .028, r1 - .0012), (muzzle - .002, r1 - .0012), (muzzle, r1 - .0020), (muzzle, .0040), (muzzle - .012, .0036)]
        lathe_d('ThreadCap', [(muzzle - .026, r1 - .0004), (muzzle - .004, r1 - .0004), (muzzle, r1 - .0016), (muzzle, .0042), (muzzle - .006, .0042)],
                'synthetic_black' if key == 'stainless' else key, n=n, cap=False)
    return lathe_d('Barrel', st, key, n=n, cap=False)


def round_receiver(front_z, rear_z, r=.0165, key='blued'):
    """Round bolt-action receiver tube with a bright bolt showing in the ejection port, and a tang."""
    lathe_d('Receiver', [(-rear_z, .0060), (-rear_z + .004, r - .0035), (-rear_z + .010, r), (-front_z - .006, r), (-front_z, r - .0012)], key, n=32)
    box('BoltInPort', (.0142, .0838, (front_z + rear_z) * .5 - .030), (.0024, .0110, .052), 'steel_bright', .0004)
    lathe_d('FrontRingBand', [(-front_z - .022, r + .0006), (-front_z - .006, r + .0006)], key, n=32)   # front ring is a touch proud
    plate('Tang', [(rear_z - .004, .0812), (rear_z + .050, .0740), (rear_z + .050, .0705), (rear_z - .004, .0722)], -.0060, .0060, key, edge=.0010)


def bolt_parts(rear_z, style='sporter', key='blued'):
    """Bolt (slides +Z) with shroud, safety tab and a handle on the bolt axis (lifts about +Z)."""
    bolt = node('Bolt', (0, .075, rear_z - .040))
    lathe_d('BoltBody', [(-rear_z + .004, .0092), (-rear_z + .125, .0092)], 'steel_bright', n=20, parent=bolt)
    lathe_d('BoltShroud', [(-rear_z - .032, .0035), (-rear_z - .028, .0082), (-rear_z - .008, .0108), (-rear_z + .002, .0112)], key, n=24, parent=bolt)
    box('ShroudSafety', (.0100, .0835, rear_z + .016), (.0040, .0035, .010), key, .0006, bolt)
    z0 = rear_z - .016
    handle = node('BoltHandle', (0, .075, z0), bolt)
    if style == 'military':     # straight, slightly swept handle, round knob
        wire('BoltHandleArm', [(.010, .0770, z0), (.030, .0760, z0 + .003), (.047, .0735, z0 + .007)], key, .0034, handle)
        knob = (.053, .0730, z0 + .008); sphere('BoltKnob', knob, .0085, key, handle)
    else:                       # sporter: swept down and back, pear knob
        wire('BoltHandleArm', [(.010, .0775, z0), (.026, .0720, z0 + .006), (.038, .0625, z0 + .014)], key, .0034, handle)
        knob = (.042, .0585, z0 + .018); sphere('BoltKnob', knob, .0095, key, handle)
    return bolt, handle, knob


def box_mag(p, depth, length, width, key='blued'):
    """Detachable box magazine; p = top centre (inside the stock), only the visible shell."""
    mag = node('Magazine', p); x, y, z = p
    loft('MagBody', [(z - length / 2, y, y - depth + .003, width / 2, 4.5), (z + length / 2, y, y - depth, width / 2, 4.5)], key, n=16, sub=1, parent=mag)
    box('MagFloor', (0, y - depth - .0015, z + .001), (width + .002, .0035, length + .003), key, .0010, mag)
    socket('MagazineHand', (0, y - depth + .012, z), mag)
    return mag


def mag_builder(depth, length, width, key='blued'):
    return lambda p: box_mag(p, depth, length, width, key)


def sockets_common(aim_y, hl, mag_pos, bolthand_pos, bolthand_parent, eject=(.018, .084, -.050)):
    hr = socket('HandR', (.041, -.024, .067)); hl_ = socket('HandL', hl)
    socket('Muzzle', (0, .075, -MUZ3[current.name])); socket('Aim', (0, aim_y, .052)); socket('Ejection', eject)
    socket('MagazineInsert', mag_pos); socket('TriggerFinger', (.021, -.026, .023)); socket('BoltHand', bolthand_pos, bolthand_parent)
    case = node('SpentCase', (eject[0], eject[1], eject[2])); casing('VisualCase', eject, case); case.scale = Vector((.0001,) * 3)
    return hr, hl_, case


def mech_bolt(aim_y, hl, mag_pos, mag_b, rear_z=.062, style='sporter', key='blued', guard_key=None):
    trigger = trigger_guard_v3(guard_key or key)
    for z in (-.031, .059): screw('GuardScrew', (0, .0225, z), 'y', .0026, guard_key or key)
    screw('TangScrew', (0, .0745, rear_z + .036), 'y', .0022, key, sign=1)
    bolt, handle, knob = bolt_parts(rear_z, style, key)
    charge = node('ChargingHandle', (.021, .074, -.070))
    release = node('MagazineRelease', (0, .026, mag_pos[2] - .046))
    box('MagLatch', (0, .027, mag_pos[2] - .046), (.010, .004, .006), guard_key or key, .0008, release)
    mag = mag_b(mag_pos)
    hr, hl_, case = sockets_common(aim_y, hl, mag_pos, knob, handle, eject=(.017, .084, rear_z - .110))
    return {'bolt': bolt, 'handle': handle, 'charge': charge, 'trigger': trigger, 'release': release, 'mag': mag, 'hr': hr, 'hl': hl_, 'case': case}


def mag_well(mag_z, length, width, y=.0290, key='blued'):
    box('MagWellPlate', (0, y, mag_z), (width + .008, .0030, length + .012), key, .0010)


def swivel_stud(z, y, key='steel_bright'):
    cylinder('SwivelStud', (0, y + .004, z), (0, y - .004, z), .0030, key, 12)
    ring_d('SwivelLoop', -z - .002, .0030, .0046, .004, key, cy=y - .010)


def recoil_pad(z, top, bot, hw, key='rubber', t=.022, spacer=True):
    plate('RecoilPad', [(z, top), (z + t, top - .0008), (z + t, bot + .0010), (z, bot)], -hw, hw, key, edge=.004)
    if spacer: plate('PadSpacer', [(z - .0015, top), (z + .0005, top), (z + .0005, bot), (z - .0015, bot)], -hw + .0004, hw - .0004, 'synthetic_black', edge=.0006)


def band(z, top, bot, hw, key='blued', w=.011, sq=2.4):
    loft('Band', [(z - w / 2, top, bot, hw, sq), (z + w / 2, top, bot, hw, sq)], key, n=26, sub=1)
    screw('BandScrew', (hw + .0002, (top + bot) / 2, z), 'x', .0018, key, sign=1)


def bead_front(m, sight_y, key='blued', ramp_len=.045, hood=False):
    """Ramp + post + brass bead at the muzzle, bead top on the sight line."""
    top_barrel = .075 + .0088
    plate('FrontRamp', [(-(m - ramp_len), top_barrel - .001), (-(m - .012), top_barrel - .001), (-(m - .016), sight_y - .0065), (-(m - .034), sight_y - .0065)], -.0032, .0032, key)
    plate('FrontPost', [(-(m - .022), sight_y - .0070), (-(m - .027), sight_y - .0070), (-(m - .027), sight_y - .0020), (-(m - .022), sight_y - .0020)], -.0009, .0009, key, edge=.0003)
    sphere('FrontBead', (0, sight_y - .0015, -(m - .025)), .0014, 'brass')
    if hood:
        lathe_d('FrontHood', [(m - .036, .0068), (m - .012, .0068), (m - .012, .0058), (m - .036, .0058)], key, cy=sight_y - .0020, n=20, cap=False)


def leaf_rear(z, sight_y, key='blued', wide=False):
    """Folding leaf rear sight on the barrel: U notch bottom on the sight line."""
    top_barrel = .075 + .0100
    hw = .0075 if wide else .0062
    plate('RearSightBase', [(z + .016, top_barrel - .001), (z - .016, top_barrel - .001), (z - .016, top_barrel + .003), (z + .016, top_barrel + .003)], -.0050, .0050, key)
    for sx in (-1, 1):
        plate('RearLeaf', [(z + .003, top_barrel + .002), (z - .003, top_barrel + .002), (z - .003, sight_y + .0034), (z + .003, sight_y + .0034)], sx * .0017, sx * hw, key, edge=.0005)
    plate('RearLeafBottom', [(z + .003, top_barrel + .002), (z - .003, top_barrel + .002), (z - .003, sight_y), (z + .003, sight_y)], -.0018, .0018, key, edge=.0004)


# ================================================================ optics (W2)
def _scope(cy, eye_d, eye_r, tube_r, obj_d, obj_r, ring_ds, key='blued', bases=True, power_ring=False, ao=False):
    """Hunting scope on rings: eyepiece at eye_d (<0, toward the eye), objective at obj_d."""
    for d in ring_ds:
        if bases:
            box('ScopeBase', (0, .0040, d), (.0160, .0080, .0180), key, .0010)
            for dz in (-.0055, .0055): screw('BaseScrew', (0, .0080, d + dz), 'y', .0019, 'steel_bright', sign=1)
        loft('RingStand', [(d - .0060, cy - tube_r + .002, .0075, .0064, 3.4), (d + .0060, cy - tube_r + .002, .0075, .0064, 3.4)], key, n=20, sub=1)
        ring_d('ScopeRing', -d - .0060, tube_r, tube_r + .0024, .012, key, cy=cy)
        for sx in (-1, 1): box('RingSplit', (sx * (tube_r + .0016), cy + .0004, d), (.0030, .0005, .0122), 'synthetic_black', .0001)
        for sx in (-1, 1): cylinder('RingScrew', (sx * (tube_r + .0024), cy - .0010, d - .003), (sx * (tube_r + .0040), cy - .0010, d - .003), .0016, 'steel_bright', 8)
    ep = eye_d; ob = obj_d
    body = [(ep + .004, eye_r - .0010), (ep + .010, eye_r), (ep + .044, eye_r - .0006), (ep + .066, tube_r), (ob - .070, tube_r),
            (ob - .036, obj_r - .0010), (ob - .004, obj_r), (ob, obj_r), (ob, obj_r - .0018), (ob - .020, obj_r - .0022)]
    lathe_d('ScopeBody', body, key, cy=cy, n=36, cap=False)
    lathe_d('EyeBell', [(ep + .006, eye_r - .0030), (ep, eye_r - .0030), (ep, eye_r - .0016), (ep + .004, eye_r - .0010)], 'rubber', cy=cy, n=36, cap=False)
    if power_ring:   # knurled power ring on the eyepiece
        for k in range(10):
            box('PowerRib', (math.cos(k * TAU / 10) * (eye_r + .0004), cy + math.sin(k * TAU / 10) * (eye_r + .0004), -(ep + .030)), (.0022, .0022, .010), 'rubber', .0004)
    if ao:           # adjustable objective ring with range marks
        lathe_d('AORing', [(ob - .026, obj_r + .0006), (ob - .012, obj_r + .0006)], key, cy=cy, n=36)
    mid = (ring_ds[0] + ring_ds[1]) / 2
    turret('TurretTop', (0, cy + tube_r + .0020, -mid), 'y', key)
    turret('TurretSide', (tube_r + .0020, cy, -mid), 'x', key)
    lathe_d('TurretSaddle', [(mid - .016, tube_r + .0030), (mid + .016, tube_r + .0030)], key, cy=cy, n=36)
    lens('ScopeEyeLens', ep + .003, eye_r - .0032, cy, 'glass')
    lens('ScopeObjLens', ob - .003, obj_r - .0024, cy, 'glass')
    socket('Mount', (0, 0, 0)); socket('Eye', (0, cy, -ep)); socket('Scope', (0, cy, -ep))


def optic_scope_3_9x():
    """3-9x40 variable hunting scope, power ring on the eyepiece."""
    _scope(.040, -.140, .0195, .0128, .175, .0240, (-.045, .065), power_ring=True)


def optic_scope_4_12x():
    """4-12x50 long-range scope with an adjustable objective; tall rings clear the 50 mm bell."""
    _scope(.046, -.145, .0200, .0128, .200, .0290, (-.050, .075), power_ring=True, ao=True)


def optic_scope_scout_2x():
    """2x long-eye-relief scout scope on rail rings: mounted forward, used with both eyes open."""
    cy = .026
    for d in (-.030, .030):
        box('RailClamp', (0, .0040, d), (.0200, .0080, .0140), 'alloy_black', .0010)
        ring_d('ScoutRing', -d - .0055, .0128, .0150, .011, 'alloy_black', cy=cy)
        cylinder('ClampKnob', (.0100, .0040, d), (.0160, .0040, d), .0040, 'alloy_black', 12)
    lathe_d('ScoutBody', [(-.096, .0150), (-.090, .0160), (-.070, .0156), (-.050, .0128), (.050, .0128), (.070, .0150), (.096, .0158),
                          (.096, .0140), (.086, .0136)], 'alloy_black', cy=cy, n=32, cap=False)
    lathe_d('ScoutEyeRim', [(-.092, .0128), (-.098, .0128), (-.098, .0150), (-.094, .0160)], 'rubber', cy=cy, n=32, cap=False)
    turret('TurretTop', (0, cy + .0140, 0.0), 'y', 'alloy_black', r=.0078, h=.0085)
    turret('TurretSide', (.0140, cy, 0.0), 'x', 'alloy_black', r=.0078, h=.0085)
    lens('ScopeEyeLens', -.095, .0124, cy, 'glass')
    lens('ScopeObjLens', .093, .0132, cy, 'glass')
    socket('Mount', (0, 0, 0)); socket('Eye', (0, cy, .095)); socket('Scope', (0, cy, .095))


def scout_mount_clamp():
    """Clamp-on scout rail for a surplus rifle: replaces the rear sight leaf, no drilling."""
    box('ClampBody', (0, -.0010, .000), (.0230, .0120, .050), 'parkerized', .0012)
    for d in (-.016, .016): cylinder('ClampBolt', (-.0125, -.004, d), (.0125, -.004, d), .0022, 'steel_bright', 10)
    box('ScoutRail', (0, .0090, -.040), (.0175, .0070, .150), 'alloy_black', .0012)
    for k in range(8): box('RailSlot', (0, .0128, .025 - k * .018), (.0185, .0012, .0035), 'synthetic_black', .0003)
    socket('Mount', (0, 0, 0)); socket('OpticMount', (0, .0125, -.040))


def muzzle_moderator():
    """Factory sound moderator: a plain baffled can on the muzzle thread (outer shell only)."""
    lathe_d('CanBody', [(-.004, .0080), (.000, .0105), (.006, .0150), (.168, .0150), (.174, .0130), (.176, .0050), (.172, .0045)], 'alloy_black', cy=0.0, n=32, cap=False)
    lathe_d('CanThread', [(-.010, .0085), (-.004, .0085)], 'steel_bright', cy=0.0, n=24, cap=False)   # device axis = the bore (Socket_Mount)
    socket('Mount', (0, 0, 0)); socket('Muzzle', (0, 0, -.176))


def muzzle_brake():
    """Ported muzzle brake (expedition rifle factory fit)."""
    lathe_d('BrakeBody', [(-.004, .0098), (.000, .0112), (.052, .0112), (.055, .0100), (.055, .0042), (.050, .0040)], 'blued', cy=0.0, n=28, cap=False)
    for k in range(4):
        for sx in (-1, 1): box('BrakePort', (sx * .0105, .0, -(.010 + k * .011)), (.0020, .0080, .0060), 'synthetic_black', .0005)
    socket('Mount', (0, 0, 0)); socket('Muzzle', (0, 0, -.055))


# ================================================================ rifles (W2)
def ranger_box_rifle():
    """Walnut bolt sporter: round blued receiver on scope bases, 22" sporter barrel, pear knob,
    folding leaf + bead irons, detachable 4-round box, rubber pad, sling studs."""
    m = MUZ3[current.name]
    round_receiver(-.125, .062, key='blued')
    barrel3(-.125, m, .0108, .0082, 'blued')
    leaf_rear(-.300, .0975)
    bead_front(m, .0975, hood=False)
    socket('IronAim', (0, .0975, -.300))
    socket('OpticMount', (0, .0915, -.050))
    socket('LightMount', (0, .075, -(m - .150)))
    loft('Stock', [
        (-.440, .0790, .0600, .0105, 2.4), (-.432, .0810, .0510, .0165, 2.6), (-.36, .0820, .0460, .0186, 2.7),
        (-.25, .0830, .0400, .0196, 2.8), (-.14, .0840, .0345, .0202, 2.8), (-.05, .0835, .0300, .0207, 2.8),
        (.020, .0815, .0280, .0202, 2.7), (.052, .0780, .0110, .0178, 2.5), (.082, .0705, -.0320, .0160, 2.3),
        (.106, .0695, -.0620, .0164, 2.3), (.130, .0720, -.0500, .0168, 2.4), (.200, .0790, -0.0430, .0182, 2.5),
        (.280, .0825, -0.0486, .0196, 2.7), (.338, .0840, -0.0560, .0208, 2.9), (.344, .0838, -0.0558, .0208, 3.0)], 'walnut', n=28, sub=3)
    recoil_pad(.344, .0838, -0.0558, .0208)
    mag_well(-.068, .075, .022)
    swivel_stud(-.380, .0440); swivel_stud(.270, -.0560)
    return mech_bolt(.0975, (.014, .050, -.360), (0, .044, -.068), mag_builder(.028, .072, .021, 'blued'))


def timber_bolt_carbine():
    """Scout bolt carbine: 16.5" barrel, camo-dipped synthetic stock, forward scout rail for a
    long-eye-relief 2x, ghost-ring rear on the bridge + protected post, polymer 5-round box."""
    m = MUZ3[current.name]
    round_receiver(-.125, .062, key='parkerized')
    barrel3(-.125, m, .0110, .0090, 'parkerized', thread=False)
    # scout rail over the chamber end of the barrel
    box('ScoutRailBase', (0, .0880, -.205), (.0160, .0060, .150), 'alloy_black', .0010)
    box('ScoutRail', (0, .0945, -.205), (.0175, .0070, .150), 'alloy_black', .0012)
    for k in range(8): box('RailSlot', (0, .0982, -.140 - k * .018), (.0185, .0012, .0035), 'synthetic_black', .0003)
    socket('OpticMount', (0, .0985, -.205))
    # ghost ring on the receiver bridge (eye ~16 cm behind it when aimed)
    sight_y = .1060
    plate('GhostBase', [(.040, .0915), (.010, .0915), (.012, .0990), (.036, .0990)], -.0070, .0070, 'parkerized', edge=.0008)
    for sx in (-1, 1): plate('GhostEar', [(.034, .0985), (.018, .0985), (.020, sight_y + .0100), (.032, sight_y + .0100)], sx * .0082, sx * .0110, 'parkerized', edge=.0006)
    ring_d('GhostRing', -.030, .0042, .0080, .004, 'parkerized', cy=sight_y)
    plate('FrontBlock', [(-(m - .045), .0820), (-(m - .010), .0820), (-(m - .012), .0910), (-(m - .040), .0910)], -.0060, .0060, 'parkerized')
    for sx in (-1, 1): plate('FrontEar', [(-(m - .038), .0905), (-(m - .014), .0905), (-(m - .016), sight_y + .0040), (-(m - .034), sight_y + .0040)], sx * .0040, sx * .0062, 'parkerized', edge=.0006)
    plate('FrontPost', [(-(m - .028), .0905), (-(m - .022), .0905), (-(m - .022), sight_y), (-(m - .028), sight_y)], -.0010, .0010, 'parkerized', edge=.0003)
    socket('IronAim', (0, sight_y, .030))
    socket('LightMount', (0, .075, -(m - .062)))
    loft('Stock', [
        (-.360, .0790, .0600, .0110, 2.4), (-.352, .0810, .0500, .0170, 2.8), (-.29, .0820, .0440, .0190, 3.0),
        (-.20, .0830, .0390, .0198, 3.0), (-.12, .0840, .0340, .0205, 3.0), (-.05, .0835, .0300, .0208, 3.0),
        (.020, .0815, .0280, .0202, 2.8), (.052, .0780, .0100, .0178, 2.6), (.082, .0712, -.0330, .0162, 2.4),
        (.106, .0702, -.0620, .0166, 2.4), (.130, .0730, -.0490, .0170, 2.5), (.200, .0800, -0.0420, .0185, 2.7),
        (.280, .0830, -0.0486, .0198, 2.9), (.330, .0840, -0.0550, .0208, 3.1), (.336, .0838, -0.0548, .0208, 3.2)], 'camo_dip', n=28, sub=3)
    recoil_pad(.336, .0838, -0.0548, .0208, spacer=False)
    mag_well(-.068, .075, .022, key='synthetic_black')
    swivel_stud(-.320, .0430, 'alloy_black'); swivel_stud(.265, -.0550, 'alloy_black')
    return mech_bolt(sight_y, (.014, .049, -.300), (0, .044, -.068), mag_builder(.024, .072, .021, 'synthetic_black'), key='parkerized')


def north_service_rifle():
    """Surplus military bolt rifle: full-length birch with an upper handguard, two bands and a nose
    cap, straight bolt handle, aperture rear on the bridge, protected post, 10-round box.
    Accepts a clamp-on scout mount over the chamber end (Socket_ScoutMount)."""
    m = MUZ3[current.name]
    round_receiver(-.130, .066, key='parkerized')
    barrel3(-.130, m, .0112, .0088, 'parkerized')
    sight_y = .1060
    # aperture on the rear bridge with protecting wings
    plate('ApertureBase', [(.050, .0915), (.016, .0915), (.018, .0985), (.046, .0985)], -.0080, .0080, 'parkerized', edge=.0008)
    for sx in (-1, 1): plate('ApertureWing', [(.044, .0980), (.020, .0980), (.024, sight_y + .0105), (.040, sight_y + .0105)], sx * .0088, sx * .0118, 'parkerized', edge=.0006)
    ring_d('ApertureRing', -.034, .0044, .0086, .004, 'parkerized', cy=sight_y)
    socket('IronAim', (0, sight_y, .034))
    socket('ScoutMount', (0, .0920, -.165))
    # wood: lower stock to the nose cap, upper handguard over the barrel
    loft('Stock', [
        (-.610, .0860, .0610, .0125, 2.6), (-.600, .0870, .0560, .0170, 2.8), (-.50, .0870, .0500, .0186, 2.8),
        (-.30, .0870, .0440, .0196, 2.8), (-.15, .0860, .0360, .0201, 2.8), (-.05, .0845, .0300, .0206, 2.8),
        (.020, .0825, .0280, .0200, 2.7), (.056, .0790, .0100, .0172, 2.4), (.090, .0715, -.0300, .0160, 2.3),
        (.115, .0705, -.0500, .0162, 2.3), (.140, .0725, -.0460, .0168, 2.4), (.220, .0780, -0.0502, .0186, 2.6),
        (.300, .0805, -0.0528, .0198, 2.8), (.338, .0810, -0.0560, .0204, 2.9), (.344, .0808, -0.0558, .0204, 3.0)], 'birch_dark', n=28, sub=3)
    loft('UpperHandguard', [(-.205, .0905, .0820, .0120, 2.2), (-.217, .0975, .0820, .0150, 2.2), (-.30, .0975, .0830, .0152, 2.2),
                            (-.49, .0965, .0830, .0148, 2.2), (-.500, .0945, .0830, .0140, 2.2)], 'birch_dark', n=24, sub=2)
    band(-.320, .0995, .0428, .0210, 'parkerized'); band(-.505, .0985, .0488, .0200, 'parkerized')
    loft('NoseCap', [(-.598, .0930, .0545, .0178, 2.6), (-.630, .0920, .0600, .0150, 2.4), (-.642, .0905, .0640, .0120, 2.2)], 'parkerized', n=24, sub=2)
    # protected front post on the nose cap
    for sx in (-1, 1): plate('FrontEar', [(-.645, .0900), (-.615, .0900), (-.620, sight_y + .0050), (-.640, sight_y + .0050)], sx * .0045, sx * .0068, 'parkerized', edge=.0006)
    plate('FrontPost', [(-.633, .0900), (-.627, .0900), (-.627, sight_y), (-.633, sight_y)], -.0011, .0011, 'parkerized', edge=.0003)
    plate('ButtPlate', [(.344, .0810), (.350, .0806), (.350, -0.0558), (.344, -0.0562)], -.0204, .0204, 'parkerized', edge=.002)
    mag_well(-.075, .088, .026, key='parkerized')
    ring_d('SlingLoopFront', .505, .0030, .0046, .004, 'parkerized', cy=.040)
    swivel_stud(.260, -.0560, 'parkerized')
    socket('LightMount', (0, .075, -(m - .030)))
    return mech_bolt(sight_y, (.014, .052, -.400), (0, .044, -.075), mag_builder(.050, .084, .025, 'parkerized'), rear_z=.066, style='military', key='parkerized')


def frontier_vented_rifle():
    """SKS-type semi carbine: milled receiver, stamped cover with a short rail, gas tube under a
    wooden handguard, tangent rear, hooded post, hardwood stock, detachable 5-round box."""
    m = MUZ3[current.name]
    loft('Receiver', [(.050, .0880, .0480, .0120, 3.6), (.040, .0900, .0450, .0135, 4.2), (-.150, .0900, .0450, .0135, 4.2), (-.158, .0870, .0480, .0125, 3.6)], 'blued', n=24, sub=1)
    loft('DustCover', [(.090, .0920, .0870, .0090, 2.2), (.070, .0990, .0870, .0128, 2.4), (-.120, .1000, .0870, .0130, 2.4), (-.135, .0960, .0870, .0125, 2.2)], 'blued', n=24, sub=1)
    box('CoverRail', (0, .1020, -.050), (.0160, .0050, .120), 'alloy_black', .0010)
    for k in range(6): box('RailSlot', (0, .1045, -.003 - k * .018), (.0170, .0010, .0035), 'synthetic_black', .0003)
    socket('OpticMount', (0, .1045, -.050))
    barrel3(-.158, m, .0110, .0085, 'blued')
    # gas tube + block above the barrel, wooden handguard over the tube
    lathe_d('GasTube', [(.170, .0082), (.420, .0082)], 'blued', cy=.0950, n=20)
    loft('GasBlock', [(-.410, .1040, .0660, .0105, 3.0), (-.440, .1040, .0660, .0105, 3.0)], 'blued', n=20, sub=1)
    loft('Handguard', [(-.172, .1040, .0850, .0120, 2.2), (-.180, .1070, .0850, .0132, 2.4), (-.380, .1060, .0850, .0128, 2.4), (-.392, .1030, .0850, .0118, 2.2)], 'hardwood_red', n=24, sub=2)
    # tangent rear sight on the barrel ahead of the receiver
    sight_y = .1100
    plate('TangentBase', [(-.150, .0870), (-.178, .0870), (-.178, .0980), (-.150, .0980)], -.0080, .0080, 'blued', edge=.0008)
    plate('TangentLeaf', [(-.150, .0980), (-.176, .1000), (-.176, sight_y + .0030), (-.150, sight_y + .0010)], -.0072, .0072, 'blued', edge=.0006)
    plate('TangentNotchFill', [(-.150, .0980), (-.176, .0980), (-.176, sight_y), (-.150, sight_y)], -.0016, .0016, 'blued', edge=.0003)
    socket('IronAim', (0, sight_y, -.163))
    # hooded front post on the muzzle block, bayonet lug stub below
    loft('FrontBlock', [(-(m - .045), .0900, .0640, .0085, 2.4), (-(m - .008), .0900, .0640, .0085, 2.4)], 'blued', n=20, sub=1)
    lathe_d('FrontHood', [(m - .040, .0068), (m - .014, .0068), (m - .014, .0058), (m - .040, .0058)], 'blued', cy=sight_y - .0020, n=20, cap=False)
    plate('FrontPost', [(-(m - .030), .0890), (-(m - .024), .0890), (-(m - .024), sight_y), (-(m - .030), sight_y)], -.0010, .0010, 'blued', edge=.0003)
    box('BayonetLug', (0, .0590, -(m - .060)), (.0090, .0090, .040), 'blued', .0012)
    loft('Stock', [
        (-.400, .0860, .0620, .0115, 2.4), (-.390, .0870, .0560, .0165, 2.6), (-.30, .0870, .0500, .0180, 2.7),
        (-.20, .0870, .0440, .0190, 2.8), (-.10, .0860, .0360, .0196, 2.8), (-.03, .0850, .0300, .0200, 2.8),
        (.030, .0830, .0270, .0195, 2.7), (.070, .0790, .0080, .0170, 2.4), (.110, .0740, -.0150, .0160, 2.3),
        (.170, .0750, -.0280, .0168, 2.4), (.250, .0790, -0.0434, .0185, 2.6), (.330, .0810, -0.0540, .0200, 2.8),
        (.336, .0808, -0.0536, .0200, 2.9)], 'hardwood_red', n=28, sub=3)
    plate('ButtPlate', [(.336, .0810), (.342, .0806), (.342, -0.0536), (.336, -0.0540)], -.0200, .0200, 'blued', edge=.002)
    band(-.330, .1085, .0478, .0190, 'blued', w=.008)
    mag_well(-.060, .070, .022)
    ring_d('SlingLoopFront', .330, .0030, .0046, .004, 'blued', cy=.0400)
    swivel_stud(.250, -.0470, 'blued')
    socket('LightMount', (0, .075, -(m - .090)))
    trigger = trigger_guard_v3('blued')
    bolt = node('Bolt', (0, .079, -.050)); box('BoltCarrierFace', (.0112, .0810, -.040), (.0030, .0120, .060), 'steel_bright', .0005, bolt)
    handle = node('BoltHandle', (.026, .081, -.022), bolt)
    charge = node('ChargingHandle', (.016, .083, -.040))
    cylinder('ChargingRod', (.012, .083, -.040), (.027, .083, -.040), .0030, 'steel_bright', 12, charge)
    lathe_d('ChargingKnob', [(.036, .0001), (.036, .0050), (.044, .0050), (.044, .0001)], 'blued', cy=.083, x=.030, n=16, parent=charge)
    release = node('MagazineRelease', (0, .026, -.108)); box('MagLatch', (0, .027, -.108), (.010, .004, .006), 'blued', .0008, release)
    mag = box_mag((0, .044, -.060), .030, .068, .021, 'blued')
    hr, hl, case = sockets_common(sight_y, (.014, .052, -.320), (0, .044, -.060), (.032, .083, -.040), charge, eject=(.017, .086, -.060))
    return {'bolt': bolt, 'handle': handle, 'charge': charge, 'trigger': trigger, 'release': release, 'mag': mag, 'hr': hr, 'hl': hl, 'case': case}


def brush_lever_rifle():
    """Lever carbine: flat-sided faded case-colour receiver, exposed hammer, 20" barrel over a tube
    magazine, walnut straight-grip stock + fore-end with a cap, buckhorn rear + bead front."""
    m = MUZ3[current.name]
    loft('Receiver', [(.034, .0900, .0440, .0110, 4.0), (.026, .0950, .0400, .0125, 5.0), (-.118, .0950, .0400, .0125, 5.0), (-.126, .0920, .0440, .0118, 4.0)], 'case_colour', n=24, sub=1)
    box('ReceiverTopFlat', (0, .0952, -.050), (.0160, .0016, .110), 'case_colour', .0006)
    for z in (-.030, -.095): cylinder('SidePin', (-.0128, .060, z), (.0128, .060, z), .0018, 'steel_bright', 10)
    barrel3(-.126, m, .0108, .0088, 'blued')
    lathe_d('TubeMag', [(.126, .0078), (m - .030, .0078), (m - .024, .0074), (m - .024, .0001)], 'blued', cy=.0555, n=20)
    loft('TubeHanger', [(-(m - .040), .0855, .0470, .0088, 2.2), (-(m - .052), .0855, .0470, .0088, 2.2)], 'blued', n=20, sub=1)
    hammer = node('Hammer', (0, .0820, .034))
    plate('HammerBody', [(.030, .0820), (.044, .0830), (.049, .0980), (.043, .1000), (.037, .0960)], -.0038, .0038, 'case_colour', hammer, edge=.0008)
    sight_y = .1040
    # buckhorn rear: tall curved horns around a shallow V
    z = -.270; tb = .075 + .0098
    plate('BuckhornBase', [(z + .014, tb - .001), (z - .014, tb - .001), (z - .014, tb + .003), (z + .014, tb + .003)], -.0050, .0050, 'blued')
    for sx in (-1, 1):
        plate('Buckhorn', [(z + .0025, tb + .002), (z - .0025, tb + .002), (z - .0025, sight_y + .0050), (z + .0025, sight_y + .0050)], sx * .0016, sx * .0085, 'blued', edge=.0005)
    plate('BuckhornV', [(z + .0025, tb + .002), (z - .0025, tb + .002), (z - .0025, sight_y), (z + .0025, sight_y)], -.0018, .0018, 'blued', edge=.0003)
    bead_front(m, sight_y)
    socket('IronAim', (0, sight_y, z))
    loft('Stock', [
        (.036, .0880, .0300, .0130, 2.6), (.050, .0840, .0150, .0150, 2.4), (.090, .0745, -.0100, .0158, 2.3),
        (.140, .0760, -.0250, .0168, 2.4), (.220, .0800, -0.0432, .0186, 2.6), (.300, .0825, -0.0518, .0200, 2.8),
        (.330, .0830, -0.0550, .0206, 2.9), (.336, .0828, -0.0546, .0206, 3.0)], 'walnut', n=28, sub=3)
    plate('ButtPlate', [(.336, .0830), (.343, .0826), (.343, -0.0546), (.336, -0.0550)], -.0206, .0206, 'blued', edge=.002)
    loft('ForeEnd', [(-.128, .0880, .0440, .0170, 2.6), (-.140, .0890, .0420, .0172, 2.6), (-.30, .0880, .0430, .0168, 2.6),
                     (-.356, .0875, .0440, .0164, 2.6)], 'walnut', n=26, sub=2)
    loft('ForeEndCap', [(-.356, .0880, .0438, .0168, 2.6), (-.366, .0870, .0452, .0160, 2.6)], 'blued', n=26, sub=1)
    # loading gate on the right side, lever under the receiver (pivots at the front, loop behind the trigger)
    gate = node('LoadingGate', (.0128, .056, -.086))
    plate('GatePlate', [(-.070, .050), (-.102, .050), (-.102, .064), (-.070, .064)], .0122, .0134, 'steel_bright', gate, edge=.0005)
    socket('LoadingGate', (.0140, .057, -.086))
    round_ = node('InsertRound', (.041, .044, -.072)); casing('InsertionRound', (.041, .044, -.072), round_, round_tip=True); round_.scale = Vector((.0001,) * 3)
    lever = node('Lever', (0, .040, -.080))
    wire('LeverArm', [(0, .040, -.080), (0, .036, -.020), (0, .028, .020)], 'blued', .0036, lever)
    strip('LeverLoop', [(.020, .0280), (.044, .0180), (.072, -.0060), (.080, -.0300), (.066, -.0480), (.040, -.0480), (.022, -.0300),
                        (.014, -.0080), (.012, .0120), (.020, .0280)], .0080, .0040, 'blued', lever)
    trigger = node('Trigger', (0, .010, .022))
    wire('CurvedTrigger', [(0, .024, .020), (0, .006, .024), (0, -.006, .018)], 'steel_bright', .0022, trigger)
    bolt = node('Bolt', (0, .086, -.040)); box('BoltTop', (0, .0915, -.010), (.0110, .0060, .040), 'steel_bright', .0006, bolt)
    handle = node('BoltHandle', (0, .086, -.040), bolt)
    charge = node('ChargingHandle', (.021, .074, -.070)); release = node('MagazineRelease', (0, .022, -.072))
    hr, hl, case = sockets_common(sight_y, (.014, .046, -.300), (0, .026, -.100), (0, -.040, .062), lever, eject=(.000, .098, -.040))
    swivel_stud(.270, -.0520)
    socket('LightMount', (0, .075, -(m - .080)))
    return {'bolt': bolt, 'handle': handle, 'charge': charge, 'trigger': trigger, 'release': release, 'mag': None, 'hr': hr, 'hl': hl, 'case': case,
            'lever': lever, 'gate': gate, 'round': round_}


def ridge_scout_rifle():
    """Varmint bolt rifle: grey laminate, high straight comb, near-vertical grip, wide flat
    beavertail fore-end, heavy stainless barrel with a threaded muzzle, no irons, scope bases."""
    m = MUZ3[current.name]
    round_receiver(-.125, .062, key='stainless')
    barrel3(-.125, m, .0128, .0112, 'stainless', thread=True)
    socket('OpticMount', (0, .0915, -.050))
    socket('MuzzleThread', (0, .075, -m))
    socket('IronAim', (0, .0985, -.110))     # no irons: look along the bare receiver
    loft('Stock', [
        (-.450, .0800, .0480, .0180, 3.4), (-.442, .0815, .0400, .0240, 4.2), (-.36, .0825, .0380, .0250, 4.4),
        (-.25, .0835, .0360, .0250, 4.4), (-.14, .0845, .0330, .0236, 3.8), (-.05, .0840, .0300, .0215, 3.0),
        (.020, .0820, .0280, .0205, 2.8), (.050, .0790, .0050, .0175, 2.5), (.075, .0740, -.0400, .0165, 2.4),
        (.096, .0730, -.0700, .0170, 2.4), (.120, .0800, -.0640, .0175, 2.6), (.150, .0880, -.0440, .0180, 2.8),
        (.260, .0900, -0.0425, .0192, 2.9), (.340, .0900, -0.0580, .0208, 3.1), (.346, .0898, -0.0578, .0208, 3.2)], 'laminate', n=28, sub=3)
    recoil_pad(.346, .0898, -0.0578, .0208)
    mag_well(-.068, .075, .022, key='stainless')
    swivel_stud(-.400, .0390, 'stainless'); swivel_stud(-.340, .0385, 'stainless'); swivel_stud(.270, -.0520, 'stainless')
    socket('LightMount', (0, .075, -(m - .120)))
    return mech_bolt(.0985, (.014, .042, -.360), (0, .044, -.068), mag_builder(.026, .072, .021, 'stainless'), key='stainless', guard_key='synthetic_black')


def expedition_rifle():
    """Magnum bolt rifle: black synthetic stock with a thick pad, long barrel with a ported brake,
    express rear on a quarter rib, hooded bead front, scope bases, detachable 4-round box."""
    m = MUZ3[current.name]
    round_receiver(-.130, .066, key='blued')
    barrel3(-.130, m - .055, .0118, .0094, 'blued')
    lathe_d('Brake', [(m - .060, .0101), (m - .056, .0112), (m - .002, .0112), (m, .0100), (m, .0044), (m - .006, .0042)], 'blued', n=28, cap=False)
    for k in range(4):
        for sx in (-1, 1): box('BrakePort', (sx * .0106, .075, -(m - .046 + k * .011)), (.0018, .0080, .0060), 'synthetic_black', .0005)
    sight_y = .0985
    loft('QuarterRib', [(-.250, .0890, .0820, .0050, 3.0), (-.330, .0890, .0820, .0050, 3.0)], 'blued', n=16, sub=1)
    plate('ExpressLeaf', [(-.285, .0885), (-.293, .0885), (-.293, sight_y + .0020), (-.285, sight_y + .0020)], -.0090, .0090, 'blued', edge=.0005)
    plate('ExpressV', [(-.285, .0885), (-.293, .0885), (-.293, sight_y - .0004), (-.285, sight_y - .0004)], -.0006, .0006, 'blued')
    box('ExpressWhiteLine', (0, sight_y - .0010, -.2848), (.0012, .0040, .0004), 'lamp_lens', .0001)
    bead_front(m - .055, sight_y, hood=True)
    socket('IronAim', (0, sight_y, -.289))
    socket('OpticMount', (0, .0915, -.050))
    loft('Stock', [
        (-.450, .0800, .0580, .0120, 2.6), (-.442, .0815, .0480, .0180, 2.8), (-.36, .0825, .0440, .0198, 2.9),
        (-.25, .0835, .0390, .0205, 3.0), (-.14, .0845, .0340, .0210, 3.0), (-.05, .0840, .0300, .0214, 3.0),
        (.020, .0820, .0280, .0208, 2.8), (.052, .0785, .0090, .0182, 2.6), (.082, .0712, -.0340, .0166, 2.4),
        (.106, .0702, -.0640, .0170, 2.4), (.132, .0730, -.0520, .0172, 2.5), (.200, .0805, -0.0440, .0188, 2.7),
        (.280, .0840, -0.0506, .0204, 2.9), (.330, .0850, -0.0580, .0214, 3.1), (.336, .0848, -0.0578, .0214, 3.2)], 'synthetic_black', n=28, sub=3)
    recoil_pad(.336, .0848, -0.0578, .0214, t=.028)
    mag_well(-.075, .088, .025)
    swivel_stud(-.390, .0430, 'blued'); swivel_stud(.268, -.0570, 'blued')
    socket('LightMount', (0, .075, -(m - .160)))
    return mech_bolt(sight_y, (.014, .049, -.360), (0, .044, -.075), mag_builder(.030, .084, .024, 'blued'), rear_z=.066)


def flashlight_hand():
    """Two-cell household flashlight held in the hand (same model family as the taped light):
    grey anodised body with knurl bands, rubber tail switch, flared head, lens. Axis = -Z (beam)."""
    lathe_d('TorchBody', [(-.100, .0118), (-.094, .0130), (.030, .0130), (.044, .0168), (.064, .0178), (.072, .0178),
                          (.072, .0158), (.068, .0154)], 'parkerized', cy=0.0, n=32, cap=False)
    lathe_d('TorchTail', [(-.106, .0001), (-.106, .0100), (-.100, .0118)], 'rubber', cy=0.0, n=24)
    for d in (-.070, -.052, -.034):
        lathe_d('KnurlBand', [(d, .0136), (d + .010, .0136)], 'alloy_black', cy=0.0, n=32)
    box('TorchSwitch', (0, .0136, .012), (.0070, .0030, .0120), 'rubber', .0008)
    lathe_d('Bezel', [(.066, .0180), (.073, .0182), (.073, .0160)], 'steel_bright', cy=0.0, n=32, cap=False)
    lens('LampLens', .0705, .0156, 0.0, 'lamp_lens')
    socket('Mount', (0, 0, 0)); socket('Grip', (0, 0, .040)); socket('Beam', (0, 0, -.074))


MUZ3.update({'ranger_box_rifle': .660, 'timber_bolt_carbine': .500, 'north_service_rifle': .700, 'frontier_vented_rifle': .640,
             'brush_lever_rifle': .560, 'ridge_scout_rifle': .720, 'expedition_rifle': .760})
RIFLES_W2 = [
    ('north_service_rifle', 'bolt', north_service_rifle, 'Surplus military bolt rifle, birch full stock, aperture sight', {'lift': 1.05, 'travel': .098}),
    ('frontier_vented_rifle', 'semi', frontier_vented_rifle, 'SKS-type semi carbine, hardwood, cover rail, tangent rear', None),
    ('ranger_box_rifle', 'bolt', ranger_box_rifle, 'Walnut bolt sporter, scope bases, folding leaf irons', {'lift': 1.05, 'travel': .092}),
    ('timber_bolt_carbine', 'bolt', timber_bolt_carbine, 'Scout bolt carbine, camo-dipped synthetic, forward scout rail', {'lift': 1.05, 'travel': .092}),
    ('brush_lever_rifle', 'lever', brush_lever_rifle, 'Lever carbine, walnut straight grip, tube magazine, buckhorn sights', None),
    ('ridge_scout_rifle', 'bolt', ridge_scout_rifle, 'Varmint bolt rifle, grey laminate, heavy stainless barrel, threaded', {'lift': 1.05, 'travel': .092}),
    ('expedition_rifle', 'bolt', expedition_rifle, 'Magnum bolt rifle, black synthetic, muzzle brake, express sights', {'lift': 1.05, 'travel': .100}),
]
OPTICS_W2 = [('scope_3_9x', optic_scope_3_9x, '3-9x40 variable hunting scope on rings and bases'),
             ('scope_4_12x', optic_scope_4_12x, '4-12x50 adjustable-objective scope on high rings'),
             ('scope_scout_2x', optic_scope_scout_2x, '2x long-eye-relief scout scope on rail rings')]
LIGHTS_W2 = [('flashlight_hand', flashlight_hand, 'Household two-cell flashlight, held in the hand')]
MOUNTS_W2 = [('scout_mount_clamp', scout_mount_clamp, 'Clamp-on scout rail for a surplus rifle (no drilling)')]
MUZZLES_W2 = [('muzzle_moderator', muzzle_moderator, 'Factory sound moderator for threaded barrels'),
              ('muzzle_brake', muzzle_brake, 'Ported muzzle brake')]
