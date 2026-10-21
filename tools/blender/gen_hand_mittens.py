"""Mitten shells for the anatomical hand rig (weapons W8).

blender --background --factory-startup --python tools/blender/gen_hand_mittens.py

The approved anatomical_hand_rig.glb is NOT modified. Its LeatherGlove shells (right + left) are copied; the four
finger sleeves (index / middle / ring / little) are cut away and replaced by one lofted mitten bag: as wide as the
knuckle line, rounded at the end, flattened like a real leather mitten, skinned hand -> middle_01 -> 02 -> 03 along
its length so it curls as one finger. Palm, back, cuff and the thumb stay the glove's own (thumb free, as in a
real mitten). (A first try that morphed the finger sleeves together read as lumpy overlapping fingers.)
Exported with both armatures (same bone names/order) as assets/models/viewmodel/hand_mittens.glb; the game
re-parents the MittenShell meshes onto the live rig skeletons (SurvivorHandRig._attach_mitten).
"""
import bpy, bmesh, os, math
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "brave-and-cold", "assets", "models", "viewmodel", "anatomical_hand_rig.glb")
OUT = os.path.join(ROOT, "brave-and-cold", "assets", "models", "viewmodel", "hand_mittens.glb")
FINGERS = ["index", "middle", "ring", "little"]
CUT = 0.40          # finger weight above which the glove's finger sleeve is removed
N = 28              # ring resolution of the bag
HALF_T = 0.0145     # half thickness (palm-back), metres
WIDTH_K = 1.38      # bag half width vs half the knuckle span (leather + lining)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
keep = []
for arm_name, out_name in (("HandRig", "MittenShell"), ("LeftHandRig", "MittenShellLeft")):
    arm = bpy.data.objects[arm_name]
    glove = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == arm and o.data.materials and o.data.materials[0].name.startswith("survivor_leather"))
    m = glove.copy(); m.data = glove.data.copy(); m.name = out_name; m.data.name = out_name
    bpy.context.collection.objects.link(m)
    bones = arm.data.bones; aw = arm.matrix_world
    head = lambda b: aw @ bones[b].head_local
    tail = lambda b: aw @ bones[b].tail_local
    mw = m.matrix_world; inv = mw.inverted()
    gi = {g.name: g.index for g in m.vertex_groups}
    fgroups = {gi["%s_0%d" % (f, k)] for f in FINGERS for k in (1, 2, 3)}
    # ---- frame of the bag: from the knuckle line along the middle finger, flattened palm-normal
    k_in, k_out = head("index_01"), head("little_01")
    base = k_in * 0.56 + k_out * 0.44   # the index side of the glove sticks out further than its knuckle
    tip = tail("middle_03")
    fdir = (tip - head("middle_01")).normalized()
    lat = (k_in - k_out); lat = (lat - fdir * lat.dot(fdir)).normalized()
    up = fdir.cross(lat).normalized()
    half_w = (k_in - k_out).length / 2 * WIDTH_K
    L = (tip - base).dot(fdir) + 0.006
    # palm side: the side the fingers curl toward = away from the back of the hand. Use the vertex mass of the
    # glove's finger region to find which way `up` points relative to the hand centre line (keeps it symmetric).
    # ---- cut the finger sleeves, remembering their UV box (the bag reuses that patch of leather)
    me = m.data
    bm = bmesh.new(); bm.from_mesh(me)
    dl = bm.verts.layers.deform.active
    uvl = bm.loops.layers.uv.active
    cut = [v for v in bm.verts if sum(w for g, w in v[dl].items() if g in fgroups) > CUT]
    # UV patch for the bag: a small square of the leather on the back of the hand (one continuous island;
    # the finger islands sit among atlas gaps and rendered black)
    # two patches - the palm leather and the back leather are painted differently - picked by which way the
    # glove's own hand-weighted surface faces relative to the bag's `up`
    hg = gi["hand"]; best = {1: (9.0, None), -1: (9.0, None)}
    nm = mw.to_3x3()
    for v in bm.verts:   # the UV of the glove point in the middle of the palm / the back: deep inside its island
        if v[dl].get(hg, 0.0) > 0.9 and v.link_loops:
            d = (nm @ v.normal).normalized().dot(up)
            if abs(d) < 0.7: continue
            sd = 1 if d > 0 else -1
            dist = ((mw @ v.co) - (base - fdir * 0.035 + up * sd * HALF_T)).length
            if dist < best[sd][0]: best[sd] = (dist, v.link_loops[0][uvl].uv.copy())
    patch = {}
    for sd, (_, mid) in best.items():
        patch[sd] = (mid.x - 0.010, mid.x + 0.010, mid.y - 0.010, mid.y + 0.010)
    bmesh.ops.delete(bm, geom=cut, context='VERTS')
    # ---- the bag: superellipse rings along the frame, rounded tip, open base sunk 2 cm into the palm
    j1, j2, j3 = head("middle_02"), head("middle_03"), tip
    t_j = [(p - base).dot(fdir) for p in (head("middle_01"), j1, j2, j3)]
    ts = [-0.030 + (L + 0.030) * i / 30 for i in range(31)]
    rings = []
    for ti, t in enumerate(ts):
        e = max(0.0, (t - (L - 0.030)) / 0.030)                 # last 30 mm: round off
        r = math.sqrt(max(0.0, 1.0 - e * e)) if e < 1.0 else 0.0
        w = half_w * (1.0 - 0.10 * max(0.0, t) / L) * ((0.30 + 0.70 * r) if e > 0 else 1.0)
        h = HALF_T * (0.35 + 0.65 * r) if e > 0 else HALF_T
        if ti == len(ts) - 1: w, h = half_w * 0.12, HALF_T * 0.15
        ring = []
        for k in range(N):
            a = k * 2 * math.pi / N; c, s = math.cos(a), math.sin(a)
            ex = 0.7 + 0.3 * min(1.0, e)            # squarer along the bag, round at the tip
            x = math.copysign(abs(c) ** ex, c) * w; y = math.copysign(abs(s) ** 0.85, s) * h
            p = base + fdir * t + lat * x + up * y
            bv = bm.verts.new(inv @ p)
            ring.append((bv, k / N, (t + 0.03) / (L + 0.03), t, 1 if s >= 0 else -1))
        rings.append(ring)
    bm.verts.ensure_lookup_table()
    tip_v = bm.verts.new(inv @ (base + fdir * (L + 0.002)))
    # the glove's corrective shape keys: new verts must sit at their own position in every key (else they snap to 0)
    for sl in bm.verts.layers.shape.values():
        for ring in rings:
            for bv, _, _, _, _ in ring: bv[sl] = bv.co.copy()
        tip_v[sl] = tip_v.co.copy()
    faces = []
    for i in range(len(rings) - 1):
        for k in range(N):
            a, b = rings[i][k], rings[i][(k + 1) % N]; c_, d = rings[i + 1][(k + 1) % N], rings[i + 1][k]
            faces.append((bm.faces.new((a[0], b[0], c_[0], d[0])), (a, b, c_, d)))
    for k in range(N):
        a, b = rings[-1][k], rings[-1][(k + 1) % N]
        faces.append((bm.faces.new((a[0], b[0], tip_v)), (a, b, (tip_v, a[1], 1.0, L, a[4]))))
    for f, parts in faces:
        sd = 1 if sum(pt[4] for pt in parts) >= 0 else -1          # whole face on one side's patch
        u0, u1, v0, v1 = patch[sd]
        for lp, pt in zip(f.loops, parts): lp[uvl].uv = (u0 + (u1 - u0) * (0.5 + 0.5 * math.cos(pt[1] * 2 * math.pi)), v0 + (v1 - v0) * pt[2])
    bmesh.ops.recalc_face_normals(bm, faces=[f for f, _ in faces])
    # ---- skin the bag: hand at the base, then middle_01/02/03 by position along it (soft 8 mm joints)
    def wts(t):
        out = {}
        segs = [("hand", -1.0, t_j[0]), ("middle_01", t_j[0], t_j[1]), ("middle_02", t_j[1], t_j[2]), ("middle_03", t_j[2], 9.0)]
        for name, a, b in segs:
            x = min(t - a, b - t)
            out[name] = max(0.0, min(1.0, 0.5 + x / 0.008))
        s = sum(out.values()) or 1.0
        return {k: v / s for k, v in out.items() if v > 1e-3}
    for ring in rings:
        for bv, _, _, t, _ in ring:
            for name, w in wts(t).items(): bv[dl][gi[name]] = w
    for name, w in wts(L).items(): tip_v[dl][gi[name]] = w
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.update()
    print("MITTEN", out_name, "cut", len(cut), "bag rings", len(rings), "verts", len(me.vertices))
    keep += [arm, m]
for o in list(bpy.data.objects):
    if o not in keep: bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_skins=True, export_animations=False, export_apply=False)
print("MITTEN_EXPORT", OUT)
