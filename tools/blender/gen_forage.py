"""Original low-poly forage plants for teas (N3), vertex-coloured like the other generators.
Blender Z-up, origin at ground level. Each GLB holds the plant plus a separate harvest node
the game hides once picked:
  rose_bush.glb    : wild rose cane clump in snow; node "rose_hips" = the red hips
  reishi_stump.glb : cut birch stump; node "reishi_caps" = lacquered bracket fungi
  birch_log.glb    : fallen white birch log half buried in snow; node "birch_bark" = loose curls
Usage: blender --background --factory-startup --python gen_forage.py -- <out_dir>
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
CANE = (0.36, 0.15, 0.10)
CANE_OLD = (0.27, 0.16, 0.11)
HIP = (0.62, 0.08, 0.05)
SNOW = (0.86, 0.90, 0.97)
BARK = (0.36, 0.27, 0.19)
CUT = (0.55, 0.45, 0.32)
REISHI = (0.42, 0.10, 0.05)
REISHI_RIM = (0.80, 0.62, 0.38)
BIRCH = (0.82, 0.80, 0.74)
BIRCH_DARK = (0.12, 0.11, 0.10)
rng = random.Random(23)


def col(c, j=0.0):
    k = 1.0 + (rng.random() * 2 - 1) * j
    return (min(c[0] * k, 1), min(c[1] * k, 1), min(c[2] * k, 1), 1.0)


class Mesh:
    def __init__(self):
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.color.new("Col")

    def poly(self, pts, c):
        vs = [self.bm.verts.new(p) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return
        for l in f.loops:
            l[self.layer] = c

    def tube(self, p0, p1, r0, r1, c, sides=5, cap=False):
        """Tapered prism from p0 to p1 (Vectors)."""
        d = (p1 - p0)
        if d.length < 1e-5:
            return
        n = d.normalized()
        a = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(a)
        cc = col(c, 0.08)
        ring = lambda p, r: [p + (a * math.cos(2 * math.pi * i / sides) + b * math.sin(2 * math.pi * i / sides)) * r for i in range(sides)]
        A, B = ring(p0, r0), ring(p1, r1)
        for i in range(sides):
            i2 = (i + 1) % sides
            self.poly([A[i], A[i2], B[i2], B[i]], cc)
        if cap:
            self.poly(list(B), cc)

    def blob(self, p, rx, ry, rz, c, j=0.06, seg=6, rings=4):
        """Squashed low-poly sphere (berries, fungus, snow lumps)."""
        cc = col(c, j)
        pts = []
        for k in range(rings + 1):
            t = math.pi * k / rings
            pts.append([Vector((p.x + math.sin(t) * math.cos(2 * math.pi * i / seg) * rx, p.y + math.sin(t) * math.sin(2 * math.pi * i / seg) * ry, p.z - math.cos(t) * rz)) for i in range(seg)])
        for k in range(rings):
            for i in range(seg):
                i2 = (i + 1) % seg
                self.poly([pts[k][i], pts[k + 1][i], pts[k + 1][i2], pts[k][i2]], cc)

    def lathe_x(self, x0, x1, y, z, r, c, sides=10, bands=None):
        """Horizontal log along X with optional dark bark bands [(x, width)]."""
        xs = [x0, x1]
        for bx, bw in (bands or []):
            xs += [bx - bw / 2, bx + bw / 2]
        xs = sorted(set(round(v, 4) for v in xs if x0 <= v <= x1))
        ring = lambda x, rr: [Vector((x, y + math.cos(2 * math.pi * i / sides) * rr, z + math.sin(2 * math.pi * i / sides) * rr)) for i in range(sides)]
        for xa, xb in zip(xs, xs[1:]):
            mid = (xa + xb) / 2
            band = any(abs(mid - bx) < bw / 2 for bx, bw in (bands or []))
            A, B = ring(xa, r * (1 + 0.04 * math.sin(xa * 7))), ring(xb, r * (1 + 0.04 * math.sin(xb * 7)))
            for i in range(sides):
                i2 = (i + 1) % sides
                dark = band and rng.random() < 0.38   # lenticels: short broken dashes, never full rings
                self.poly([A[i], A[i2], B[i2], B[i]], col(BIRCH_DARK if dark else c, 0.06))
        self.poly(list(reversed(ring(x0, r))), col(CUT, 0.05))
        self.poly(ring(x1, r), col(CUT, 0.05))

    def finish(self, name):
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        if mesh.color_attributes:
            mesh.color_attributes.active_color = mesh.color_attributes[0]
            mesh.color_attributes.render_color_index = 0
        for p in mesh.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def rose_bush():
    m, hips = Mesh(), Mesh()
    m.blob(Vector((0, 0, 0.0)), 0.45, 0.42, 0.10, SNOW, j=0.02, seg=8, rings=3)   # drift at the base
    for k in range(10):
        a = 2 * math.pi * k / 10 + rng.uniform(-0.3, 0.3)
        base = Vector((math.cos(a) * rng.uniform(0.02, 0.12), math.sin(a) * rng.uniform(0.02, 0.12), 0.0))
        h = rng.uniform(0.55, 1.05)
        out = rng.uniform(0.25, 0.55)
        pts = []
        for s in range(6):                        # arching cane: up, then out and over
            t = s / 5
            r = out * t ** 1.4
            z = h * math.sin(t * math.pi * 0.62) / math.sin(math.pi * 0.62) - 0.12 * t ** 3
            pts.append(base + Vector((math.cos(a) * r, math.sin(a) * r, z)))
        c = CANE_OLD if k % 3 == 0 else CANE
        for s in range(5):
            m.tube(pts[s], pts[s + 1], 0.012 * (1 - s / 6), 0.012 * (1 - (s + 1) / 6), c, sides=4)
        for s in (2, 3, 4):                       # side twigs
            if rng.random() < 0.75:
                b = a + rng.choice((-1, 1)) * rng.uniform(0.6, 1.2)
                tip = pts[s] + Vector((math.cos(b) * 0.14, math.sin(b) * 0.14, rng.uniform(-0.02, 0.08)))
                m.tube(pts[s], tip, 0.006, 0.003, c, sides=3)
                if rng.random() < 0.6:
                    hips.blob(tip + Vector((0, 0, -0.012)), 0.016, 0.016, 0.022, HIP, j=0.15, seg=5, rings=3)
        hips.blob(pts[-1] + Vector((0, 0, -0.015)), 0.018, 0.018, 0.024, HIP, j=0.15, seg=5, rings=3)
        if rng.random() < 0.5:
            hips.blob(pts[-2] + Vector((0.02, 0, -0.02)), 0.016, 0.016, 0.02, HIP, j=0.15, seg=5, rings=3)
    return [m.finish("rose_bush"), hips.finish("rose_hips")]


def reishi_stump():
    m, caps = Mesh(), Mesh()
    sides = 9
    prof = [(0.30, -0.05), (0.27, 0.06), (0.24, 0.30), (0.23, 0.44)]
    rings = [[Vector((math.cos(2 * math.pi * i / sides) * r * rng.uniform(0.95, 1.05), math.sin(2 * math.pi * i / sides) * r * rng.uniform(0.95, 1.05), z)) for i in range(sides)] for r, z in prof]
    for A, B in zip(rings, rings[1:]):
        for i in range(sides):
            i2 = (i + 1) % sides
            m.poly([A[i], A[i2], B[i2], B[i]], col(BARK, 0.12))
    top = rings[-1]
    m.poly(top, col(CUT, 0.04))
    m.blob(Vector((0.03, 0.02, 0.45)), 0.19, 0.18, 0.05, SNOW, j=0.02, seg=8, rings=3)      # snow cap on the cut
    m.blob(Vector((0, 0, 0.0)), 0.48, 0.46, 0.09, SNOW, j=0.02, seg=8, rings=3)
    for k, (ang, z, s) in enumerate([(-1.75, 0.24, 1.0), (-1.30, 0.33, 0.75), (-2.15, 0.15, 0.85), (0.9, 0.28, 0.7)]):
        cx, cy = math.cos(ang) * 0.25, math.sin(ang) * 0.25
        p = Vector((cx * 1.25, cy * 1.25, z))
        caps.blob(p, 0.10 * s, 0.10 * s, 0.022 * s, REISHI, j=0.1, seg=7, rings=3)              # kidney cap
        caps.blob(p + Vector((cx, cy, 0)).normalized() * 0.07 * s + Vector((0, 0, -0.004)), 0.035 * s, 0.035 * s, 0.014 * s, REISHI_RIM, j=0.05, seg=5, rings=2)
    return [m.finish("reishi_stump"), caps.finish("reishi_caps")]


def birch_log():
    m, bark = Mesh(), Mesh()
    bands = [(x, rng.uniform(0.02, 0.05)) for x in [-1.05 + 0.09 * i + rng.uniform(-0.03, 0.03) for i in range(24)] if rng.random() < 0.7]
    m.lathe_x(-1.1, 1.1, 0, 0.11, 0.15, BIRCH, sides=14, bands=bands)
    m.tube(Vector((0.55, 0, 0.18)), Vector((0.75, 0.22, 0.45)), 0.04, 0.015, BIRCH, sides=5)  # broken limb
    for x in (-0.7, -0.1, 0.5):
        m.blob(Vector((x, 0, 0.26)), 0.32, 0.10, 0.035, SNOW, j=0.02, seg=6, rings=3)        # snow line on top
    m.blob(Vector((0, 0.05, 0.0)), 1.35, 0.42, 0.10, SNOW, j=0.02, seg=10, rings=3)          # drift it lies in
    for x in (-0.45, 0.2, 0.85):                                                          # peeling curls
        bark.blob(Vector((x, -0.15, 0.16)), 0.07, 0.015, 0.05, (0.88, 0.84, 0.78), j=0.04, seg=5, rings=2)
    return [m.finish("birch_log"), bark.finish("birch_bark")]


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
    os.makedirs(OUT, exist_ok=True)
    for build in (rose_bush, reishi_stump, birch_log):
        objs = build()
        tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
        export(objs, os.path.join(OUT, objs[0].name + ".glb"))
        print("FORAGE", objs[0].name, "tris", tris)
