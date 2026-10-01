"""Shared loft helpers for first-person viewmodel generators."""
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '.'


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




