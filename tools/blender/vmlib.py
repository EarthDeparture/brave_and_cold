"""Shared loft + material helpers for the first-person viewmodel generators (v2: UV-mapped, textured, superellipse sections).
Vertex colours here are TINTS (AO / wear, ~0.6..1.0); albedo comes from the textures in <out>/tex (see gen_vm_tex.py)."""
import sys
import os
import math
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.path.abspath(".")
TEX = os.path.join(OUT, "tex")

# name: (texture, tile metres per repeat, roughness, metallic)
MATS = {
    "walnut": ("vm_walnut.png", 0.30, 0.42, 0.0),
    "ash": ("vm_ash.png", 0.30, 0.55, 0.0),
    "wool": ("vm_wool.png", 0.07, 0.95, 0.0),
    "leather": ("vm_leather.png", 0.12, 0.70, 0.0),
    "fabric": ("vm_fabric.png", 0.14, 0.85, 0.0),
    "blued": ("vm_blued.png", 0.25, 0.38, 0.55),
    "steel": ("vm_steel.png", 0.25, 0.40, 0.60),
    "rubber": ("vm_rubber.png", 0.10, 0.90, 0.0),
    "skin": ("vm_skin.png", 0.10, 0.62, 0.0),
    "nail": ("vm_nail.png", 0.05, 0.35, 0.0),
    "beech": ("vm_beech.png", 0.30, 0.38, 0.0),
}
_MC = {}


def get_material(name):
    if name in _MC:
        return _MC[name]
    tex, tile, rough, metal = MATS[name]
    m = bpy.data.materials.new("vm_" + name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    img = bpy.data.images.load(os.path.join(TEX, tex))
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    _MC[name] = m
    return m


def se(c, n):
    """Superellipse helper: n=2 circle/ellipse, larger = squarer."""
    return math.copysign(abs(c) ** (2.0 / n), c)


class Part:
    def __init__(self, name, origin=(0, 0, 0)):
        self.name = name
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.color.new("Col")
        self.uvl = self.bm.loops.layers.uv.new("UV")
        self.origin = Vector(origin)
        self._cols = {}
        self._uvs = {}
        self.mat = "leather"
        self.smooth = True
        self.slots = []

    def _slot(self):
        if self.mat not in self.slots:
            self.slots.append(self.mat)
        return self.slots.index(self.mat)

    def vert(self, p, col=(1.0, 1.0, 1.0)):
        v = self.bm.verts.new(Vector(p) - self.origin)
        self._cols[v] = col
        return v

    def face(self, vs, uvs=None, smooth=None):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self._slot()
        f.smooth = self.smooth if smooth is None else smooth
        if uvs is None:
            tile = MATS[self.mat][1]
            p = [v.co for v in vs]
            n = (p[1] - p[0]).cross(p[2] - p[0])
            ax = max(range(3), key=lambda i: abs(n[i]))
            a, b = [i for i in range(3) if i != ax]
            uvs = [(q[a] / tile, q[b] / tile) for q in p]
        self._uvs[f] = uvs
        return f

    def tube(self, rings, sides=8, cap0=True, cap1=True):
        """rings: dicts c u v ru rv col [n]. Quads between rings (UV: u along path, v around), fan caps."""
        tile = MATS[self.mat][1]
        rows, accs, circs = [], [], []
        acc = 0.0
        for i, r in enumerate(rings):
            if i > 0:
                acc += (r["c"] - rings[i - 1]["c"]).length
            n = r.get("n", 2.0)
            row = []
            for k in range(sides):
                a = 2 * math.pi * k / sides
                p = r["c"] + r["u"] * (se(math.cos(a), n) * r["ru"]) + r["v"] * (se(math.sin(a), n) * r["rv"])
                row.append(self.vert(p, r["col"]))
            rows.append(row)
            accs.append(acc / tile)
            a_, b_ = r["ru"], r["rv"]
            circs.append(math.pi * (3 * (a_ + b_) - math.sqrt((3 * a_ + b_) * (a_ + 3 * b_))) / tile)
        for i in range(len(rows) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                uv = [(accs[i], circs[i] * k / sides), (accs[i], circs[i] * (k + 1) / sides),
                      (accs[i + 1], circs[i + 1] * (k + 1) / sides), (accs[i + 1], circs[i + 1] * k / sides)]
                self.face([rows[i][k], rows[i][k2], rows[i + 1][k2], rows[i + 1][k]], uv)
        for do, idx, flip in ((cap0, 0, False), (cap1, len(rings) - 1, True)):
            if not do:
                continue
            r = rings[idx]
            cv = self.vert(r["c"], r["col"])
            for k in range(sides):
                k2 = (k + 1) % sides
                ang0 = 2 * math.pi * k / sides
                ang1 = 2 * math.pi * k2 / sides
                uv = [(0.5, 0.5), (0.5 + math.cos(ang1) * r["ru"] / tile, 0.5 + math.sin(ang1) * r["rv"] / tile),
                      (0.5 + math.cos(ang0) * r["ru"] / tile, 0.5 + math.sin(ang0) * r["rv"] / tile)]
                if not flip:
                    self.face([cv, rows[idx][k2], rows[idx][k]], uv)
                else:
                    self.face([cv, rows[idx][k], rows[idx][k2]], [uv[0], uv[2], uv[1]])
        return rows

    def tint_noise(self, amt=0.2, scale=14.0, seed=0.0):
        for v, c in list(self._cols.items()):
            p = v.co + self.origin
            n = noise3((p.x + seed, p.y, p.z), scale)
            k = 1.0 - amt + amt * n
            self._cols[v] = (c[0] * k, c[1] * k, c[2] * k)

    def finish(self):
        bm = self.bm
        bm.normal_update()
        for f in bm.faces:
            uvs = self._uvs.get(f)
            for i, loop in enumerate(f.loops):
                c = self._cols[loop.vert]
                loop[self.layer] = (min(c[0], 1.0), min(c[1], 1.0), min(c[2], 1.0), 1.0)
                if uvs:
                    loop[self.uvl].uv = uvs[i]
        mesh = bpy.data.meshes.new(self.name)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        if mesh.color_attributes:
            mesh.color_attributes.active_color = mesh.color_attributes[0]
            mesh.color_attributes.render_color_index = 0
        for nm in self.slots:
            mesh.materials.append(get_material(nm))
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = self.origin
        bpy.context.collection.objects.link(obj)
        return obj


def noise3(p, s=1.0):
    x, y, z = p[0] * s, p[1] * s, p[2] * s
    n = math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
    n2 = math.sin(x * 4.1 + y * 6.3 + z * 5.2 + 1.7) * 0.5 + 0.5
    return (n - math.floor(n)) * 0.35 + n2 * 0.65


def frame(w, ref=Vector((0, 0, 1))):
    w = Vector(w).normalized()
    if abs(w.dot(ref)) > 0.95:
        ref = Vector((0, 1, 0))
    u = w.cross(ref).normalized()
    v = w.cross(u)
    return u, v, w


def ring(c, u, v, ru, rv, col, n=2.0):
    return {"c": Vector(c), "u": u, "v": v, "ru": ru, "rv": rv, "col": col, "n": n}


def limb(part, pts, radii, cols=None, sides=8, ref=Vector((0, 0, 1)), cap0=True, cap1=True, n=2.0):
    """Tube through points; radius scalar or (ru, rv); cols = tint per point (default white)."""
    rings = []
    for i, p in enumerate(pts):
        w = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        u, v, _ = frame(w, ref)
        r = radii[i]
        ru, rv = (r, r) if not isinstance(r, tuple) else r
        col = (1.0, 1.0, 1.0) if cols is None else cols[i]
        rings.append(ring(p, u, v, ru, rv, col, n))
    return part.tube(rings, sides, cap0, cap1)


def blob(part, c, rx, ry, rz, col=(1.0, 1.0, 1.0), sides=10, nrings=6):
    rings = []
    ex = Vector((1, 0, 0))
    ey = Vector((0, 1, 0))
    for j in range(nrings + 1):
        th = math.pi * j / nrings
        s = max(math.sin(th), 0.04)
        z = c[2] + math.cos(th) * rz
        rings.append(ring((c[0], c[1], z), ex, ey, rx * s, ry * s, col))
    part.tube(rings, sides, False, False)


def export_glb(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_materials="EXPORT", export_image_format="AUTO")


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)
