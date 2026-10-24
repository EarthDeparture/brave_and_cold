"""Greenhouse crop models, one per crop x growth stage (farming v2, 2026-10-22).

blender --background --factory-startup --python tools/blender/gen_crops.py

Replaces the box-blade plants built in code. Crops: potato, carrot, kale, shallot, beet, radish.
Stages: s0 sprout (cotyledons), s1 young, s2 mature, s3 ready (the real ripeness cues: potato haulm dying
back yellow, carrot / beet / radish shoulders showing at the soil, shallot tops flopping over), dead
(frost-blackened, collapsed). Radish also has `bolt` (flower stalk, seed pods: the seed-saving stage).
Leaves are built as folded strips (midrib V, ovate / lanceolate width profile, curl, wavy edges for kale,
lobes for radish), petioles as thin tubes, roots as lathe shoulders. Vertex colours carry the colour
(base -> tip gradient, lighter midrib, red petioles on beet); the game shades them with a translucent leaf
shader. Under ~1.3k tris for a mature plant. Output: assets/greenhouse/crops.glb (objects crop_<id>_<stage>).
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "brave-and-cold", "assets", "greenhouse", "crops.glb")
TAU = math.tau


class Builder:
    def __init__(self, name):
        self.name = name; self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")   # leaves only: u across the blade (0.5 = midrib), v base->tip

    def _face(self, vs, cols, uvs=None):
        f = self.bm.faces.new(vs)
        for lp, c in zip(f.loops, cols): lp[self.col] = (c[0], c[1], c[2], 1.0)
        if uvs is not None:
            for lp, uv in zip(f.loops, uvs): lp[self.uv].uv = uv
        return f

    def leaf(self, base, yaw, pitch, length, width, c0, c1, segs=7, curl=0.6, fold=0.25, profile="ovate",
             wave=0.0, wave_n=6, lobes=0, mid=None, twist=0.0, cols=1, ruffle=0.0):
        """Folded leaf strip from `base`, heading `yaw` around Z, rising at `pitch` and curling down by `curl`."""
        rows = []
        d = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        side = Vector((-d.y, d.x, 0.0))
        p = Vector(base); ang = pitch
        step = length / segs
        for i in range(segs + 1):
            t = i / segs
            if profile == "ovate": w = width * math.sin(math.pi * min(1.0, t * 1.08)) ** 0.75
            elif profile == "lance": w = width * math.sin(math.pi * t) ** 1.2
            elif profile == "spoon": w = width * (math.sin(math.pi * t * 0.92) ** 0.6) * (0.35 + 0.65 * t)
            else: w = width * (1.0 - t * 0.85)
            if lobes: w *= 0.7 + 0.3 * abs(math.sin(t * lobes * math.pi))
            w = max(w, 0.0004)
            dirv = d * math.cos(ang) + Vector((0, 0, 1)) * math.sin(ang)
            up = dirv.cross(side).normalized()
            s2 = (side * math.cos(twist * t) + up * math.sin(twist * t))
            wv = math.sin(t * wave_n * math.pi) * wave * w
            cm = [a + (b - a) * t for a, b in zip(c0, c1)]
            cmid = mid if mid is not None else [min(1.0, x * 1.25) for x in cm]
            vs = []; cs = []
            for k in range(-cols, cols + 1):   # across the blade: midrib at k = 0
                u = k / cols; au = abs(u)
                # edge ruffle (kale): a faster wave whose phase runs along the margin, growing toward the edge
                rf = math.sin(t * wave_n * 1.5 * math.pi + u * 2.0) * ruffle * w * au * au
                q = p + s2 * (w * u) + up * (fold * w * au + wv * (1 if u >= 0 else -1) * au * au + rf)
                vs.append(self.bm.verts.new(q))
                cs.append([m_ + (e - m_) * min(1.0, au * 1.4) for m_, e in zip(cmid, cm)])
            rows.append((vs, cs))
            p = p + dirv * step
            ang -= curl / segs
        for i in range(segs):
            a, ca = rows[i]; b, cb = rows[i + 1]
            v0 = 0.01 + 0.99 * i / segs; v1 = 0.01 + 0.99 * (i + 1) / segs   # v > 0 marks a leaf for the vein shader
            for k in range(2 * cols):
                u0 = k / (2 * cols); u1 = (k + 1) / (2 * cols)
                self._face([a[k], a[k + 1], b[k + 1], b[k]], [ca[k], ca[k + 1], cb[k + 1], cb[k]],
                           [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
        return p

    def tube(self, a, b, r0, r1, c0, c1, n=5, bend=None):
        """Thin tapered tube (stem, petiole, shallot leaf) a -> b, optional quadratic bend control point."""
        segs = 5 if bend else 1
        pts = []
        for i in range(segs + 1):
            t = i / segs
            if bend: q = (1 - t) ** 2 * Vector(a) + 2 * (1 - t) * t * Vector(bend) + t * t * Vector(b)
            else: q = Vector(a).lerp(Vector(b), t)
            pts.append(q)
        rings = []
        for i, q in enumerate(pts):
            t = i / segs
            dirv = (pts[min(i + 1, segs)] - pts[max(i - 1, 0)]).normalized()
            ax = dirv.cross(Vector((0, 0, 1)) if abs(dirv.z) < 0.95 else Vector((1, 0, 0))).normalized()
            ay = dirv.cross(ax).normalized()
            r = r0 + (r1 - r0) * t
            c = [x0 + (x1 - x0) * t for x0, x1 in zip(c0, c1)]
            rings.append(([self.bm.verts.new(q + (ax * math.cos(k * TAU / n) + ay * math.sin(k * TAU / n)) * r) for k in range(n)], c))
        for i in range(segs):
            ra, ca = rings[i]; rb, cb = rings[i + 1]
            for k in range(n):
                self._face([ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k]], [ca, ca, cb, cb])
        return pts[-1]

    def shoulder(self, top_z, r, h, c, n=10):
        """Root shoulder showing above the soil (carrot / beet / radish): a short lathe dome."""
        prof = [(r * 0.98, top_z - h), (r, top_z - h * 0.4), (r * 0.85, top_z - h * 0.1), (r * 0.45, top_z), (0.0, top_z + 0.002)]
        rings = []
        for rr, z in prof:
            rings.append([self.bm.verts.new((rr * math.cos(k * TAU / n), rr * math.sin(k * TAU / n), z)) for k in range(n)])
        for i in range(len(rings) - 1):
            for k in range(n):
                self._face([rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]], [c, c, c, c])

    def bulb(self, p, r, c, n=8):
        ret = bmesh.ops.create_icosphere(self.bm, subdivisions=2, radius=r, matrix=Matrix.Translation(p))
        new = set(ret["verts"])
        for f in self.bm.faces:   # colour only the bulb's own faces (new loops default to white)
            if all(v in new for v in f.verts):
                for lp in f.loops:
                    top = max(0.0, (lp.vert.co.z - p.z) / r)   # papery skin: paler toward the neck
                    lp[self.col] = (c[0] + 0.12 * top, c[1] + 0.10 * top, c[2] + 0.06 * top, 1.0)

    def done(self):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.00005)
        self.bm.to_mesh(me); self.bm.free()
        for poly in me.polygons: poly.use_smooth = True
        if 'Col' in me.color_attributes:   # the exporter only writes the ACTIVE colour attribute
            me.color_attributes.active_color = me.color_attributes['Col']
            me.color_attributes.render_color_index = me.color_attributes.find('Col')
        o = bpy.data.objects.new(self.name, me); bpy.context.collection.objects.link(o)
        return o


# ---------------------------------------------------------------- palettes (linear-ish vertex colours)
G_DARK = (0.08, 0.17, 0.05); G_MID = (0.16, 0.32, 0.08); G_LIGHT = (0.32, 0.50, 0.14)
KALE0 = (0.10, 0.20, 0.17); KALE1 = (0.22, 0.36, 0.30)
BEET0 = (0.08, 0.15, 0.06); BEET1 = (0.17, 0.27, 0.10); BEET_RED = (0.40, 0.04, 0.08)
YEL0 = (0.40, 0.36, 0.10); YEL1 = (0.55, 0.47, 0.16)
DEAD0 = (0.16, 0.11, 0.06); DEAD1 = (0.34, 0.26, 0.15)   # frost-killed: brown-black, not black plastic
STEM = (0.18, 0.30, 0.09)


def cots(b, size):
    """Sprout: two seed leaves on a short stem."""
    top = b.tube((0, 0, 0), (0, 0, size * 0.9), 0.0016, 0.0012, STEM, STEM, n=4)
    for s in (0, math.pi):
        b.leaf(top, s, 0.25, size * 0.9, size * 0.35, G_MID, G_LIGHT, segs=3, curl=0.4, profile="spoon")


def potato(stage, rng):
    b = Builder("crop_potato_" + stage)
    if stage == "s0": cots(b, 0.035); return b.done()
    k = {"s1": 0.45, "s2": 1.0, "s3": 1.0, "dead": 0.95}[stage]
    c0, c1 = {"s3": (YEL0, YEL1), "dead": (DEAD0, DEAD1)}.get(stage, (G_DARK, G_MID))
    lean = {"s3": 0.55, "dead": 1.15}.get(stage, 0.15)          # a ripe haulm falls open, a dead one collapses
    stems = 3 if stage == "s1" else 5
    for i in range(stems):
        yaw = i * TAU / stems + rng.uniform(-0.3, 0.3)
        tip = Vector((math.cos(yaw) * 0.16 * k * (0.6 + lean), math.sin(yaw) * 0.16 * k * (0.6 + lean), 0.30 * k * (1.0 - 0.5 * lean)))
        mid = tip * 0.5 + Vector((0, 0, 0.06 * k))
        if stage == "dead":   # frost-killed: stems lie on the soil, kinked at the base
            tip = Vector((math.cos(yaw) * 0.27 * k, math.sin(yaw) * 0.27 * k, 0.025))
            mid = Vector((math.cos(yaw) * 0.08 * k, math.sin(yaw) * 0.08 * k, 0.06))
        end = b.tube((0, 0, 0), tip, 0.0035 * k + 0.001, 0.002, STEM if stage not in ("dead",) else DEAD1, c1, n=5, bend=mid)
        # pinnate compound leaf: pairs of leaflets along the stem's upper half, and a terminal one
        for j in range(3):
            t = 0.45 + 0.17 * j
            q = Vector((0, 0, 0)).lerp(tip, t) + Vector((0, 0, 0.03 * k))
            for s in (-1, 1):
                if stage == "dead":   # shrivelled, hanging limp onto the soil
                    q = Vector((0, 0, 0)).lerp(tip, t) + Vector((0, 0, 0.01))
                    b.leaf(q, yaw + s * 1.4 + rng.uniform(-0.3, 0.3), -0.15, 0.05 * k, 0.012 * k, c0, c1, segs=4, curl=0.5, profile="lance", twist=0.8)
                else:
                    b.leaf(q, yaw + s * 1.25 + rng.uniform(-0.2, 0.2), 0.35 - lean * 0.6, 0.07 * k, 0.03 * k, c0, c1, segs=4, curl=0.5 + lean, profile="ovate")
        if stage == "dead":
            b.leaf(end, yaw, -0.1, 0.05 * k, 0.014 * k, c0, c1, segs=4, curl=0.4, profile="lance", twist=0.6)
        else:
            b.leaf(end, yaw, 0.2 - lean * 0.5, 0.075 * k, 0.034 * k, c0, c1, segs=4, curl=0.6 + lean, profile="ovate")
    return b.done()


def carrot(stage, rng):
    b = Builder("crop_carrot_" + stage)
    if stage == "s0": cots(b, 0.03); return b.done()
    k = {"s1": 0.45, "s2": 1.0, "s3": 1.0, "dead": 0.9}[stage]
    c0, c1 = {"dead": (DEAD0, DEAD1)}.get(stage, (G_DARK, G_LIGHT))
    droop = 1.2 if stage == "dead" else 0.0
    n = 6 if stage == "s1" else 11
    for i in range(n):
        yaw = i * TAU / n + rng.uniform(-0.25, 0.25)
        pitch = rng.uniform(1.0, 1.35) - droop
        L = 0.24 * k * rng.uniform(0.8, 1.1)
        top = Vector((math.cos(yaw) * L * 0.45, math.sin(yaw) * L * 0.45, L * math.sin(pitch) * 0.8))
        b.tube((0, 0, 0.004), top, 0.0018, 0.0010, STEM, c1, n=4, bend=top * 0.5 + Vector((0, 0, 0.03 * k)))
        # finely divided frond: tiers of narrow segments
        for j in range(4):
            t = 0.35 + 0.2 * j
            q = Vector((0, 0, 0.004)).lerp(top, t)
            for s in (-1, 1):
                b.leaf(q, yaw + s * 0.9, pitch - 0.6 - droop * 0.3, 0.05 * k * (1.1 - 0.2 * j), 0.006 * k, c0, c1, segs=3, curl=0.5, profile="lance")
    if stage in ("s3", "dead"):
        b.shoulder(0.012, 0.016, 0.03, (0.75, 0.30, 0.05) if stage == "s3" else (0.35, 0.16, 0.05))
    return b.done()


def kale(stage, rng):
    b = Builder("crop_kale_" + stage)
    if stage == "s0": cots(b, 0.035); return b.done()
    k = {"s1": 0.5, "s2": 1.0, "s3": 1.1, "dead": 1.0}[stage]
    c0, c1 = {"dead": (DEAD0, DEAD1)}.get(stage, (KALE0, KALE1))
    stalk = 0.10 * k if stage in ("s2", "s3", "dead") else 0.02
    b.tube((0, 0, 0), (0, 0, stalk), 0.008 * k, 0.006 * k, (0.25, 0.32, 0.22), (0.25, 0.32, 0.22), n=6)
    n = 5 if stage == "s1" else 9
    for i in range(n):
        yaw = i * 2.4 + rng.uniform(-0.15, 0.15)                 # golden-angle-ish spiral up the stalk
        z = stalk * (0.3 + 0.7 * i / n)
        pitch = (0.9 - 0.5 * i / n) - (1.3 if stage == "dead" else 0.0)
        b.leaf((0, 0, z), yaw, pitch, 0.22 * k * (1.0 - 0.25 * i / n), 0.07 * k, c0, c1, segs=22, curl=0.9,
               profile="ovate", wave=0.22, wave_n=4, mid=(0.32, 0.42, 0.36), cols=3, ruffle=0.24)
    return b.done()


def shallot(stage, rng):
    b = Builder("crop_shallot_" + stage)
    if stage == "s0":
        b.tube((0, 0, 0), (0, 0, 0.045), 0.0025, 0.0012, G_MID, G_LIGHT, n=5); return b.done()
    k = {"s1": 0.5, "s2": 1.0, "s3": 1.0, "dead": 0.9}[stage]
    c0, c1 = {"s3": (G_MID, YEL1), "dead": (DEAD0, DEAD1)}.get(stage, (G_MID, G_LIGHT))
    flop = {"s3": 0.85, "dead": 1.4}.get(stage, 0.0)            # ripe shallot tops fall over
    for cl in range(3 if stage != "s1" else 1):
        cp = Vector((math.cos(cl * 2.1) * 0.03, math.sin(cl * 2.1) * 0.03, 0)) if stage != "s1" else Vector((0, 0, 0))
        for i in range(4):
            yaw = i * TAU / 4 + cl + rng.uniform(-0.3, 0.3)
            h = 0.26 * k * rng.uniform(0.8, 1.05)
            tip = cp + Vector((math.cos(yaw) * (0.03 + flop * 0.16), math.sin(yaw) * (0.03 + flop * 0.16), h * (1.0 - 0.75 * flop)))
            ctrl = cp + Vector((0, 0, h * (0.65 - 0.25 * flop)))
            b.tube(cp + Vector((0, 0, 0.005)), tip, 0.0035 * k + 0.001, 0.0008, c0, c1, n=5, bend=ctrl)
        if stage in ("s2", "s3", "dead"):
            b.bulb(cp + Vector((0, 0, 0.010 if stage == "s3" else 0.004)), (0.021 if stage == "s3" else 0.016) * k,
                   (0.46, 0.24, 0.16) if stage != "dead" else (0.18, 0.12, 0.08))
    return b.done()


def beet(stage, rng):
    b = Builder("crop_beet_" + stage)
    if stage == "s0": cots(b, 0.03); return b.done()
    k = {"s1": 0.5, "s2": 1.0, "s3": 1.0, "dead": 0.9}[stage]
    c0, c1 = {"dead": (DEAD0, DEAD1)}.get(stage, (BEET0, BEET1))
    n = 5 if stage == "s1" else 9
    for i in range(n):
        yaw = i * TAU / n + rng.uniform(-0.2, 0.2)
        pitch = rng.uniform(1.0, 1.3) - (1.2 if stage == "dead" else 0.0)
        L = 0.08 * k
        top = Vector((math.cos(yaw) * L * 0.4, math.sin(yaw) * L * 0.4, L * math.sin(pitch)))
        b.tube((0, 0, 0.006), top, 0.0025 * k + 0.0008, 0.0015, BEET_RED, BEET_RED if stage != "dead" else DEAD1, n=4)
        b.leaf(top, yaw, pitch - 0.7, 0.13 * k, 0.045 * k, c0, c1, segs=6, curl=0.8, profile="ovate", wave=0.12, wave_n=5,
               mid=tuple(a * 0.6 + b * 0.4 for a, b in zip(BEET1, BEET_RED)) if stage != "dead" else DEAD1)   # a red vein, not a red leaf
    if stage in ("s3", "dead"):
        b.shoulder(0.018, 0.028, 0.03, (0.30, 0.03, 0.07) if stage == "s3" else (0.14, 0.04, 0.05))
    return b.done()


def radish(stage, rng):
    b = Builder("crop_radish_" + stage)
    if stage == "s0": cots(b, 0.028); return b.done()
    k = {"s1": 0.5, "s2": 1.0, "s3": 1.0, "dead": 0.9, "bolt": 1.0}[stage]
    c0, c1 = {"dead": (DEAD0, DEAD1), "bolt": (YEL0, G_MID)}.get(stage, (G_DARK, G_MID))
    n = 4 if stage == "s1" else 7
    for i in range(n):
        yaw = i * TAU / n + rng.uniform(-0.25, 0.25)
        b.leaf((0, 0, 0.006), yaw, rng.uniform(0.6, 0.9) - (1.0 if stage == "dead" else 0.0), 0.11 * k, 0.032 * k, c0, c1,
               segs=6, curl=0.7, profile="spoon", lobes=3)
    if stage in ("s3", "dead", "bolt"):
        b.shoulder(0.010, 0.015, 0.02, (0.70, 0.08, 0.10) if stage != "dead" else (0.25, 0.06, 0.06))
    if stage == "bolt":   # the seed-saving stage: a branching flower stalk with white-pink flowers and green pods
        top = b.tube((0, 0, 0.01), (0.01, 0.0, 0.42), 0.004, 0.0018, STEM, STEM, n=5, bend=(0.0, 0.01, 0.2))
        for j in range(6):
            q = Vector((0.005, 0.003, 0.18 + 0.04 * j)); yaw = j * 2.3
            tip = q + Vector((math.cos(yaw) * 0.07, math.sin(yaw) * 0.07, 0.06))
            b.tube(q, tip, 0.0018, 0.0010, STEM, STEM, n=4)
            for m in range(3):
                pod = q.lerp(tip, 0.4 + 0.3 * m)
                b.tube(pod, pod + Vector((math.cos(yaw + 1.2) * 0.025, math.sin(yaw + 1.2) * 0.025, 0.012)), 0.0022, 0.0008, (0.22, 0.36, 0.12), (0.30, 0.42, 0.16), n=4)
            for s in range(4):
                b.leaf(tip, yaw + s * TAU / 4, 0.3, 0.009, 0.006, (0.85, 0.80, 0.86), (0.90, 0.70, 0.82), segs=2, curl=0.2, profile="spoon")
    return b.done()


bpy.ops.wm.read_factory_settings(use_empty=True)
CROPS = {"potato": potato, "carrot": carrot, "kale": kale, "shallot": shallot, "beet": beet, "radish": radish}
made = []
for cid, fn in CROPS.items():
    stages = ["s0", "s1", "s2", "s3", "dead"] + (["bolt"] if cid == "radish" else [])
    for st in stages:
        o = fn(st, random.Random(hash(cid) % 1000 if False else len(cid) * 31 + len(st)))
        made.append(o)
        print("CROP", o.name, len(o.data.polygons), "faces")
mat = bpy.data.materials.new("crop_leaf")
for o in made: o.data.materials.append(mat)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_vertex_color='ACTIVE')
print("CROPS_EXPORT", OUT, len(made))
