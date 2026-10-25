"""
Run: blender.exe --background --factory-startup --python gen_zombie.py -- <out_dir>
zombie.glb v2: ~1.8 m infected survivor in a puffer jacket, jeans, boots, small backpack. Hunched, head dropped.
Built from lofted rings (smooth, tapered limbs) instead of boxes. Budget: <= 2500 tris total.
Parts (names are the contract with entities/zombies/zombie.gd): zombie_body, zombie_arm_l/r (origin at shoulder,
arm points forward along +Y = Godot -Z), zombie_leg_l/r (origin at hip). Vertex colours only; smooth shading.
"""
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

COAT = (0.14, 0.17, 0.22)
COAT_DARK = (0.08, 0.095, 0.12)
COAT_PATCH = (0.22, 0.20, 0.16)
SKIN = (0.50, 0.57, 0.48)
SKIN_DARK = (0.22, 0.26, 0.23)
PANTS = (0.15, 0.16, 0.20)
BOOT = (0.05, 0.045, 0.045)
BLOOD = (0.20, 0.025, 0.025)
HAIR = (0.05, 0.045, 0.04)
PACK = (0.20, 0.16, 0.09)
EYE = (0.85, 0.82, 0.55)
rng = random.Random(8)


def noise3(p, s=1.0):
    """Cheap deterministic value noise in 0..1."""
    x, y, z = p[0] * s, p[1] * s, p[2] * s
    n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
    n2 = math.sin(x * 4.1 + y * 6.3 + z * 5.2 + 1.7) * 0.5 + 0.5
    return (n - math.floor(n)) * 0.35 + n2 * 0.65


class Part:
    def __init__(self, name, origin=(0, 0, 0)):
        self.name = name
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.color.new("Col")
        self.origin = Vector(origin)
        self._cols = {}

    def vert(self, p, col):
        v = self.bm.verts.new(Vector(p) - self.origin)
        self._cols[v] = col
        return v

    def face(self, vs):
        try:
            return self.bm.faces.new(vs)
        except ValueError:
            return None

    def tube(self, rings, sides=8, cap0=True, cap1=True):
        """rings: dicts c(Vector) u v (unit axes) ru rv col. Quads between rings, optional fan caps."""
        rows = []
        for r in rings:
            row = []
            for k in range(sides):
                a = 2 * math.pi * k / sides
                p = r["c"] + r["u"] * (math.cos(a) * r["ru"]) + r["v"] * (math.sin(a) * r["rv"])
                row.append(self.vert(p, r["col"]))
            rows.append(row)
        for i in range(len(rows) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                self.face([rows[i][k], rows[i][k2], rows[i + 1][k2], rows[i + 1][k]])
        if cap0:
            cv = self.vert(rings[0]["c"], rings[0]["col"])
            for k in range(sides):
                self.face([cv, rows[0][(k + 1) % sides], rows[0][k]])
        if cap1:
            cv = self.vert(rings[-1]["c"], rings[-1]["col"])
            for k in range(sides):
                self.face([cv, rows[-1][k], rows[-1][(k + 1) % sides]])
        return rows

    def finish(self):
        bm = self.bm
        bm.normal_update()
        for f in bm.faces:
            for loop in f.loops:
                c = self._cols[loop.vert]
                loop[self.layer] = (c[0], c[1], c[2], 1.0)
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        if mesh.color_attributes:
            mesh.color_attributes.active_color = mesh.color_attributes[0]
            mesh.color_attributes.render_color_index = 0
        for p in mesh.polygons:
            p.use_smooth = True
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = self.origin
        bpy.context.collection.objects.link(obj)
        return obj


def frame(w, ref=Vector((0, 0, 1))):
    w = Vector(w).normalized()
    if abs(w.dot(ref)) > 0.95:
        ref = Vector((0, 1, 0))
    u = w.cross(ref).normalized()
    v = w.cross(u)
    return u, v, w


def ring(c, u, v, ru, rv, col):
    return {"c": Vector(c), "u": u, "v": v, "ru": ru, "rv": rv, "col": col}


def limb(part, pts, radii, cols, sides=8, ref=Vector((0, 0, 1)), flat=1.0, cap0=True, cap1=True):
    """Tube through points; per-point radius (rx, ry) or scalar; cross-section frames follow the path."""
    rings = []
    for i, p in enumerate(pts):
        w = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        u, v, _ = frame(w, ref)
        r = radii[i]
        ru, rv = (r, r * flat) if not isinstance(r, tuple) else r
        rings.append(ring(p, u, v, ru, rv, cols[i]))
    return part.tube(rings, sides, cap0, cap1)


def blob(part, c, rx, ry, rz, col, sides=10, nrings=6, col2=None):
    """Ellipsoid as a stack of rings along Z (poles are tiny capped rings)."""
    rings = []
    ex = Vector((1, 0, 0))
    ey = Vector((0, 1, 0))
    for j in range(nrings + 1):
        th = math.pi * j / nrings
        s = max(math.sin(th), 0.04)
        z = c[2] + math.cos(th) * rz
        cc = col if col2 is None else tuple(col[k] * (1 - j / nrings) + col2[k] * (j / nrings) for k in range(3))
        rings.append(ring((c[0], c[1], z), ex, ey, rx * s, ry * s, cc))
    part.tube(rings, sides, False, False)


def stain(part, mix=0.55, scale=3.2, thresh=0.62, seed=0.0):
    """Blood / dirt: perturb vertex colours by 3D noise after the mesh is built."""
    for v, c in list(part._cols.items()):
        if c == HAIR:
            continue
        p = v.co + part.origin
        n = noise3((p.x + seed, p.y, p.z), scale)
        k = 0.88 + 0.24 * noise3((p.x, p.y + seed, p.z), 9.0)
        c = (c[0] * k, c[1] * k, c[2] * k)
        if n > thresh:
            t = min(1.0, (n - thresh) / 0.2) * mix
            c = tuple(c[i] * (1 - t) + BLOOD[i] * t for i in range(3))
        part._cols[v] = c


def build_body():
    b = Part("zombie_body")
    Z = Vector
    # torso: puffer jacket lofted hem -> shoulders; leans forward (y grows with height)
    zs = [0.90, 0.99, 1.07, 1.15, 1.23, 1.31, 1.39, 1.47, 1.54, 1.59]
    ys = [-0.02, -0.01, 0.00, 0.02, 0.045, 0.075, 0.11, 0.15, 0.19, 0.21]
    base_rx = [0.275, 0.26, 0.245, 0.265, 0.25, 0.275, 0.26, 0.285, 0.26, 0.15]
    base_ry = [0.195, 0.185, 0.17, 0.19, 0.175, 0.195, 0.18, 0.195, 0.17, 0.11]
    rxs = base_rx
    rys = base_ry
    cols = [COAT_DARK, COAT, COAT, COAT, COAT, COAT, COAT, COAT, COAT, COAT]
    rows = limb(b, [Z((0, ys[i], zs[i])) for i in range(len(zs))], list(zip(rxs, rys)), cols, sides=12, ref=Z((0, 1, 0)), cap0=True, cap1=False)
    # puffer baffles: pinch rings are implicit in the ring spacing; jagged torn hem hangs below the first ring
    for k in range(12):
        k2 = (k + 1) % 12
        a, c = rows[0][k], rows[0][k2]
        mid = (a.co + c.co) * 0.5 + b.origin
        drop = rng.uniform(0.04, 0.15)
        tip = b.vert(mid + Z((0, 0, -drop)), COAT_DARK)
        b.face([a, tip, c])
    # neck + hood bunched at the collar
    limb(b, [Z((0, 0.20, 1.58)), Z((0, 0.25, 1.66)), Z((0, 0.28, 1.70))], [0.115, 0.078, 0.065], [COAT, SKIN_DARK, SKIN_DARK], sides=8, cap0=False, cap1=False)
    limb(b, [Z((0, 0.19, 1.57)), Z((0, 0.22, 1.65))], [(0.17, 0.15), (0.13, 0.12)], [COAT, COAT_DARK], sides=10, cap0=False, cap1=False)
    # head: skull + jaw + nose, dropped forward
    hx, hy, hz = 0.0, 0.34, 1.78
    blob(b, (hx, hy, hz), 0.108, 0.122, 0.135, SKIN, sides=10, nrings=6, col2=SKIN)
    blob(b, (hx, hy + 0.012, hz + 0.045), 0.104, 0.118, 0.085, HAIR, sides=10, nrings=4)          # hair cap
    blob(b, (hx, hy + 0.045, hz - 0.095), 0.074, 0.075, 0.055, SKIN_DARK, sides=8, nrings=4)      # jaw
    blob(b, (hx, hy + 0.115, hz - 0.01), 0.022, 0.03, 0.04, SKIN, sides=6, nrings=3)              # nose
    blob(b, (hx, hy + 0.092, hz - 0.082), 0.040, 0.022, 0.016, BLOOD, sides=6, nrings=3)          # open mouth
    for sx in (-1, 1):
        blob(b, (sx * 0.05, hy + 0.092, hz + 0.018), 0.032, 0.022, 0.026, SKIN_DARK, sides=6, nrings=3)   # sunken sockets
        blob(b, (sx * 0.05, hy + 0.105, hz + 0.018), 0.012, 0.010, 0.012, EYE, sides=6, nrings=3)         # eyes
        blob(b, (sx * 0.102, hy - 0.01, hz - 0.01), 0.014, 0.022, 0.034, SKIN_DARK, sides=6, nrings=3)    # ears
    # backpack on the back (small, askew strap shapes skipped for tri budget)
    limb(b, [Z((0, -0.195, 1.12)), Z((0, -0.19, 1.50))], [(0.15, 0.085), (0.13, 0.075)], [PACK, PACK], sides=8, ref=Z((0, 1, 0)))
    b.tube([ring(Z((0, -0.20, 1.52)), Z((1, 0, 0)), Z((0, 1, 0)), 0.095, 0.055, COAT_PATCH),
            ring(Z((0, -0.20, 1.42)), Z((1, 0, 0)), Z((0, 1, 0)), 0.115, 0.065, COAT_PATCH)], 8, True, False)
    stain(b, mix=0.7, scale=2.6, thresh=0.60, seed=0.0)
    return b.finish()


def build_arm(sx, name):
    sh = Vector((sx * 0.30, 0.13, 1.47))
    a = Part(name, origin=sh)
    # points relative to the world: reach forward (+Y), slightly down, elbow bent a touch inward
    p = [sh + Vector((0, 0, 0)), sh + Vector((sx * 0.01, 0.14, -0.045)), sh + Vector((sx * 0.0, 0.30, -0.08)),
         sh + Vector((-sx * 0.015, 0.45, -0.075)), sh + Vector((-sx * 0.02, 0.57, -0.06))]
    r = [0.078, 0.07, 0.062, 0.050, 0.040]
    cols = [COAT, COAT, COAT_DARK, SKIN_DARK, SKIN]
    limb(a, p, r, cols, sides=8, ref=Vector((0, 0, 1)), cap0=True, cap1=False)
    # hand: flat palm + three curled fingers + thumb
    wrist = p[-1]
    palm = [wrist, wrist + Vector((-sx * 0.005, 0.07, -0.015))]
    limb(a, palm, [(0.045, 0.02), (0.05, 0.02)], [SKIN, SKIN_DARK], sides=6, ref=Vector((0, 0, 1)), cap0=False, cap1=True)
    for i, off in enumerate((-0.028, 0.0, 0.028)):
        base = palm[1] + Vector((off, 0.0, 0.0))
        f = [base, base + Vector((0, 0.045, -0.012)), base + Vector((0, 0.075, -0.05))]
        limb(a, f, [0.011, 0.009, 0.006], [SKIN_DARK, SKIN_DARK, SKIN_DARK], sides=5, ref=Vector((0, 0, 1)), cap0=False, cap1=True)
    t = [wrist + Vector((sx * 0.03, 0.03, 0.0)), wrist + Vector((sx * 0.055, 0.075, -0.01))]
    limb(a, t, [0.012, 0.008], [SKIN_DARK, SKIN_DARK], sides=5, cap0=False, cap1=True)
    stain(a, mix=0.6, scale=3.0, thresh=0.60, seed=1.0 + sx)
    return a.finish()


def build_leg(sx, name):
    hip = Vector((sx * 0.105, 0.0, 1.0))
    l = Part(name, origin=hip)
    pts = [hip + Vector((0, 0, -0.02)), hip + Vector((0, 0.01, -0.22)), hip + Vector((0, 0.085, -0.45)),
           hip + Vector((0, 0.01, -0.62)), hip + Vector((0, -0.01, -0.82)), hip + Vector((0, 0.0, -0.9))]
    r = [(0.115, 0.125), (0.105, 0.110), (0.080, 0.085), (0.072, 0.076), (0.054, 0.058), (0.050, 0.054)]
    cols = [PANTS, PANTS, PANTS, PANTS, PANTS, BOOT]
    limb(l, pts, r, cols, sides=8, ref=Vector((0, 1, 0)), cap0=True, cap1=False)
    # boot: shaft + toe box, sole darker
    foot = [hip + Vector((0, -0.01, -0.86)), hip + Vector((0, 0.02, -0.935)), hip + Vector((0, 0.10, -0.95)), hip + Vector((0, 0.19, -0.96))]
    limb(l, foot, [(0.058, 0.062), (0.060, 0.060), (0.062, 0.050), (0.050, 0.030)], [BOOT, BOOT, BOOT, BOOT], sides=8, ref=Vector((0, 0, 1)), cap0=False, cap1=True)
    stain(l, mix=0.35, scale=2.5, thresh=0.66, seed=2.0 + sx)
    return l.finish()


def build():
    objs = [build_body()]
    for nm, sx in (("l", -1), ("r", 1)):
        objs.append(build_arm(sx, "zombie_arm_" + nm))
    for nm, sx in (("l", -1), ("r", 1)):
        objs.append(build_leg(sx, "zombie_leg_" + nm))
    return objs


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    objs = build()
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
    export(objs, f"{OUT}/zombie.glb")
    print("ZOMBIE tris", sum(tris.values()), tris)
