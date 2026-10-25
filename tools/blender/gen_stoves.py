"""Original procedural wood stoves for the fire standard (F5), vertex-coloured like the
building generators. Blender Z-up; the front (door) faces Blender -Y (= Godot +Z).
  box_stove.glb : small sheet-iron box stove for fishing huts, pipe to 2.40 m
  pot_belly.glb : cast-iron pot-belly stove for the general store, pipe to 2.90 m
Origin at floor level under the stove centre. Usage:
  blender --background --factory-startup --python gen_stoves.py -- <out_dir>
"""
import bpy, bmesh, math, os, random, sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
IRON = (0.045, 0.045, 0.05)
IRON_RUST = (0.11, 0.07, 0.05)
IRON_EDGE = (0.09, 0.09, 0.095)
DOOR = (0.02, 0.02, 0.022)
rng = random.Random(11)


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

    def box(self, cx, cy, cz, sx, sy, sz, c, j=0.05):
        x0, x1, y0, y1, z0, z1 = cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2
        cc = col(c, j)
        self.poly([(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)], cc)
        self.poly([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], cc)
        self.poly([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], cc)
        self.poly([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], cc)
        self.poly([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], cc)
        self.poly([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], cc)

    def lathe(self, x, y, profile, c, sides=14, cap_top=True, cap_bottom=True):
        """profile: [(radius, z), ...] bottom to top."""
        cc = col(c, 0.04)
        rings = [[(x + math.cos(2 * math.pi * i / sides) * r, y + math.sin(2 * math.pi * i / sides) * r, z) for i in range(sides)] for r, z in profile]
        for a, b in zip(rings, rings[1:]):
            for i in range(sides):
                i2 = (i + 1) % sides
                self.poly([a[i], a[i2], b[i2], b[i]], cc)
        if cap_bottom:
            self.poly(list(reversed(rings[0])), cc)
        if cap_top:
            self.poly(rings[-1], cc)

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


def pipe(m, x, y, z0, z1, r=0.06):
    m.lathe(x, y, [(r, z0), (r, z1)], IRON, sides=10, cap_bottom=False)
    for z in (z0 + 0.35, z0 + 0.95, z1 - 0.3):  # crimped section joints
        if z < z1:
            m.lathe(x, y, [(r + 0.008, z), (r + 0.008, z + 0.03)], IRON_EDGE, sides=10)


def box_stove():
    m = Mesh()
    for lx in (-0.18, 0.18):              # legs
        for ly in (-0.14, 0.14):
            m.box(lx, ly, 0.06, 0.04, 0.04, 0.12, IRON)
    m.box(0, 0, 0.33, 0.46, 0.38, 0.42, IRON_RUST, j=0.08)        # firebox
    m.box(0, 0, 0.55, 0.50, 0.42, 0.03, IRON_EDGE)                # top plate (cooking surface)
    m.box(0, 0, 0.13, 0.48, 0.40, 0.025, IRON_EDGE)               # base rim
    m.box(0, -0.195, 0.31, 0.26, 0.012, 0.20, DOOR)               # door frame (ember window sits on it)
    m.box(0.15, -0.205, 0.31, 0.03, 0.02, 0.05, IRON_EDGE)        # latch
    m.lathe(0, 0.10, [(0.075, 0.565), (0.075, 0.62)], IRON_EDGE, sides=10)   # flue collar
    pipe(m, 0, 0.10, 0.62, 2.40)
    return m.finish("box_stove")


def pot_belly():
    m = Mesh()
    for k in range(3):                    # three cast legs
        a = math.pi / 2 + k * 2 * math.pi / 3
        m.box(math.cos(a) * 0.20, math.sin(a) * 0.20, 0.07, 0.05, 0.05, 0.14, IRON)
    m.lathe(0, 0, [(0.21, 0.14), (0.25, 0.20), (0.29, 0.34), (0.29, 0.50), (0.24, 0.66), (0.20, 0.72)], IRON, sides=16)
    m.lathe(0, 0, [(0.30, 0.335), (0.30, 0.355)], IRON_EDGE, sides=16, cap_top=False, cap_bottom=False)  # belly band
    m.lathe(0, 0, [(0.25, 0.72), (0.25, 0.75)], IRON_EDGE, sides=16)                                    # top plate
    m.box(0, -0.27, 0.40, 0.20, 0.03, 0.16, DOOR)                  # door (ember window sits on it)
    m.box(0.12, -0.29, 0.40, 0.025, 0.02, 0.05, IRON_EDGE)         # latch
    m.lathe(0, 0, [(0.075, 0.75), (0.075, 0.82)], IRON_EDGE, sides=10)
    pipe(m, 0, 0, 0.82, 2.90)
    return m.finish("pot_belly")


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    os.makedirs(OUT, exist_ok=True)
    for build in (box_stove, pot_belly):
        o = build()
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        export(o, os.path.join(OUT, o.name + ".glb"))
        print("STOVE", o.name, "tris", tris)
