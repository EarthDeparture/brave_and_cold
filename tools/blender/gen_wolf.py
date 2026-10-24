"""
Run: blender.exe --background --factory-startup --python gen_wolf.py -- <out_dir>
Outputs wolf.glb: timber wolf v2 (W7), ~1.3 m nose to tail root, 0.8 m at the shoulder, facing Blender +Y (-> Godot -Z).
Same parts and pivots as v1 so wolf.gd animates it unchanged:
  wolf_body (torso + neck + head, one lofted surface), wolf_tail (origin at its root),
  wolf_leg_fl / fr / bl / br (origin at the hip / shoulder joint, z = 0.56).
v1 was ellipsoid blobs and box legs. v2 lofts the body through anatomical cross-sections (deep chest, tucked
waist, narrow hips, ruffed neck, wedge head, long muzzle), legs bend at elbow / wrist and stifle / hock, the tail
is a bushy taper. Clumped fur silhouette from per-vertex jitter (stronger on the ruff, cheeks and tail).
Vertex colours: TLD timber-wolf countershading - dark saddle and tail tip, grey-tan flanks, cream belly, legs,
cheeks and throat, grey muzzle with a black nose, amber eyes. Smooth shaded.
"""
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

SADDLE = (0.11, 0.10, 0.095)
FLANK = (0.34, 0.30, 0.25)
GREY = (0.44, 0.42, 0.39)
CREAM = (0.64, 0.59, 0.51)
MUZ = (0.30, 0.28, 0.26)
NOSE = (0.03, 0.03, 0.03)
EYE = (0.55, 0.38, 0.08)
rng = random.Random(7)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


class M:
    def __init__(self, origin=(0, 0, 0)):
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.color.new("Col")
        self.origin = Vector(origin)

    def vert(self, p):
        return self.bm.verts.new(Vector(p) - self.origin)

    def face(self, vs, cols):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return
        for l, c in zip(f.loops, cols):
            l[self.layer] = (c[0], c[1], c[2], 1.0)

    def loft(self, stations, sides, colfn, shag=0.0, cap0=True, cap1=True):
        """stations: [(centre Vector, w, h, shag_k)]. Rings perpendicular to the path. colfn(u, ring_k, s) -> rgb,
        u = 0..1 along the path, s = (cos, sin) around the ring (sin > 0 is up)."""
        n = len(stations)
        rings, cols = [], []
        for k, (c, w, h, sk) in enumerate(stations):
            c = Vector(c)
            t = (Vector(stations[min(k + 1, n - 1)][0]) - Vector(stations[max(k - 1, 0)][0])).normalized()
            a = Vector((1, 0, 0))
            if abs(t.dot(a)) > 0.9:
                a = Vector((0, 1, 0))
            b = a.cross(t).normalized()
            a = t.cross(b).normalized()
            if b.z < 0:
                b = -b
            ring, rc = [], []
            u = k / (n - 1)
            for i in range(sides):
                th = 2 * math.pi * i / sides
                cs, sn = math.cos(th), math.sin(th)
                j = 1.0 + (rng.random() - 0.5) * 2.0 * shag * sk
                p = c + a * cs * w * j + b * sn * h * j
                ring.append(self.vert(p))
                rc.append(colfn(u, k, (cs, sn)))
            rings.append(ring)
            cols.append(rc)
        for k in range(n - 1):
            for i in range(sides):
                i2 = (i + 1) % sides
                self.face([rings[k][i], rings[k + 1][i], rings[k + 1][i2], rings[k][i2]],
                          [cols[k][i], cols[k + 1][i], cols[k + 1][i2], cols[k][i2]])
        for cap, k in ((cap0, 0), (cap1, n - 1)):
            if not cap:
                continue
            c = Vector(stations[k][0])
            cv = self.vert(c)
            cc = cols[k][0]
            for i in range(sides):
                i2 = (i + 1) % sides
                vs = [cv, rings[k][i2], rings[k][i]] if k == 0 else [cv, rings[k][i], rings[k][i2]]
                self.face(vs, [cc, cols[k][i2], cols[k][i]] if k == 0 else [cc, cols[k][i], cols[k][i2]])

    def tri(self, pts, c):
        self.face([self.vert(p) for p in pts], [c] * len(pts))

    def finish(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        if mesh.color_attributes:
            mesh.color_attributes.active_color = mesh.color_attributes[0]
            mesh.color_attributes.render_color_index = 0
        for p in mesh.polygons:
            p.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        obj.location = self.origin
        bpy.context.collection.objects.link(obj)
        return obj


def catmull(pts, per=3):
    """Densify a station list (centre, w, h, shag) with Catmull-Rom on every component."""
    out = []
    n = len(pts)
    for k in range(n - 1):
        p0, p1, p2, p3 = pts[max(k - 1, 0)], pts[k], pts[k + 1], pts[min(k + 2, n - 1)]
        for s in range(per):
            t = s / per
            def cr(a, b, c, d):
                return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
            cen = Vector([cr(p0[0][i], p1[0][i], p2[0][i], p3[0][i]) for i in range(3)])
            out.append((cen, cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2]), cr(p0[3], p1[3], p2[3], p3[3])))
    out.append(pts[-1])
    return out


# body stations: (centre (x, y, z), half width, half height, shag)
BODY = [
    ((0, -0.47, 0.75), 0.05, 0.05, 0.0),
    ((0, -0.42, 0.75), 0.12, 0.13, 0.3),
    ((0, -0.30, 0.74), 0.155, 0.17, 0.4),    # hips / haunch
    ((0, -0.15, 0.745), 0.15, 0.165, 0.4),
    ((0, -0.02, 0.75), 0.14, 0.15, 0.4),     # tucked waist
    ((0, 0.10, 0.715), 0.165, 0.215, 0.5),   # deep chest
    ((0, 0.22, 0.74), 0.165, 0.22, 0.7),     # shoulders
    ((0, 0.33, 0.83), 0.135, 0.165, 1.2),    # neck base: ruff
    ((0, 0.43, 0.90), 0.115, 0.125, 1.3),    # neck / ruff
    ((0, 0.515, 0.94), 0.095, 0.092, 0.9),   # back of skull, cheek ruff
    ((0, 0.58, 0.935), 0.085, 0.078, 0.4),   # head
    ((0, 0.645, 0.915), 0.06, 0.058, 0.1),   # stop
    ((0, 0.72, 0.895), 0.038, 0.042, 0.0),   # muzzle
    ((0, 0.785, 0.885), 0.026, 0.03, 0.0),
    ((0, 0.81, 0.882), 0.012, 0.016, 0.0),   # nose tip
]


def body_col(u, k, s):
    cs, sn = s
    y = -0.47 + u * 1.28
    if y > 0.62:    # muzzle: grey above, cream jaw, black nose
        c = mix(CREAM, MUZ, (sn + 0.3) / 1.0)
        return mix(c, NOSE, (y - 0.765) / 0.03) if y > 0.765 else c
    if y > 0.47:    # head: grey crown, cream cheeks / throat, darker brow
        return mix(CREAM, mix(GREY, SADDLE, max(0.0, sn - 0.6)), (sn + 0.5) / 1.1)
    top = mix(FLANK, SADDLE, (sn - 0.25) / 0.4)
    if 0.25 < y < 0.47:   # neck: darker cape over the shoulders, pale throat
        top = mix(FLANK, SADDLE, (sn - 0.1) / 0.6)
    return mix(CREAM, top, (sn + 0.55) / 0.75)


def build():
    objs = []
    b = M()
    b.loft(catmull(BODY, 3), 16, body_col, shag=0.06)
    for sx in (-1, 1):   # ears: two-sided triangles, pointed, set back on the skull
        base0 = (sx * 0.035, 0.545, 0.99)
        base1 = (sx * 0.085, 0.53, 0.975)
        tip = (sx * 0.075, 0.505, 1.085)
        b.tri([base0, base1, tip], SADDLE)
        b.tri([tip, base1, base0], GREY)
        b.tri([(sx * 0.06, 0.55, 0.985), (sx * 0.075, 0.51, 1.07), (sx * 0.05, 0.535, 0.99)], CREAM)   # pale inner ear
        # eyes: small amber almond facing forward-out
        e = (sx * 0.058, 0.628, 0.948)
        b.tri([(e[0], e[1] - 0.012, e[2] - 0.004), (e[0] + sx * 0.004, e[1] + 0.012, e[2]), (e[0], e[1], e[2] + 0.008)], EYE)
    objs.append(b.finish("wolf_body"))

    def tail_col(u, k, s):
        return mix(mix(FLANK, SADDLE, (s[1] + 0.2) / 0.8), SADDLE, (u - 0.7) / 0.3)
    t = M(origin=(0, -0.46, 0.76))
    t.loft(catmull([((0, -0.45, 0.77), 0.035, 0.035, 0.0), ((0, -0.53, 0.72), 0.06, 0.06, 0.8),
                    ((0, -0.60, 0.61), 0.072, 0.07, 1.4), ((0, -0.645, 0.48), 0.062, 0.06, 1.4),
                    ((0, -0.665, 0.37), 0.035, 0.035, 0.8), ((0, -0.67, 0.32), 0.008, 0.008, 0.0)], 2),
           10, tail_col, shag=0.12)
    objs.append(t.finish("wolf_tail"))

    def leg_col_f(u, k, s):   # flank colour where it meets the body, tan-cream lower down, a darker front stripe
        c = mix(mix(FLANK, CREAM, 0.45), mix(CREAM, FLANK, 0.3), (u - 0.25) * 1.8)   # matches the lit flank where it leaves the body
        return mix(c, SADDLE, max(0.0, s[1]) * 0.3 * max(0.0, 1.0 - abs(u - 0.55) * 3.0))   # stripe down the foreleg only
    # legs: origin at the joint (x, y, 0.56). Front: shoulder -> elbow -> wrist -> paw. Hind: hip -> stifle -> hock -> paw.
    for name, x, y in (("fl", -0.105, 0.22), ("fr", 0.105, 0.22), ("bl", -0.10, -0.30), ("br", 0.10, -0.30)):
        hip = Vector((x, y, 0.56))
        l = M(origin=tuple(hip))
        if name[0] == "f":
            path = [((0, 0.0, 0.19), 0.06, 0.09, 0.0), ((0, 0.0, 0.1), 0.08, 0.115, 0.4), ((0, -0.02, 0.0), 0.066, 0.085, 0.3), ((0, -0.035, -0.12), 0.044, 0.055, 0.2),
                    ((0, -0.005, -0.40), 0.026, 0.03, 0.0), ((0, 0.01, -0.49), 0.024, 0.028, 0.0), ((0, 0.03, -0.535), 0.03, 0.022, 0.0),
                    ((0, 0.075, -0.548), 0.026, 0.014, 0.0)]
        else:
            path = [((0, 0.0, 0.19), 0.075, 0.1, 0.0), ((0, 0.0, 0.1), 0.095, 0.13, 0.4), ((0, 0.03, -0.02), 0.085, 0.1, 0.4), ((0, 0.075, -0.13), 0.052, 0.065, 0.2),
                    ((0, -0.03, -0.33), 0.03, 0.034, 0.0), ((0, -0.055, -0.38), 0.027, 0.03, 0.0), ((0, -0.03, -0.52), 0.024, 0.026, 0.0),
                    ((0, 0.0, -0.538), 0.03, 0.02, 0.0), ((0, 0.045, -0.548), 0.026, 0.013, 0.0)]
        st = [(hip + Vector(p), w, h, sk) for p, w, h, sk in path]
        l.loft(catmull(st, 2), 10, leg_col_f, shag=0.04, cap0=False)
        objs.append(l.finish("wolf_leg_" + name))
    return objs


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)


if __name__ == "__main__":
    clear()
    objs = build()
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    export(objs, f"{OUT}/wolf.glb")
    print("WOLF tris", tris)
