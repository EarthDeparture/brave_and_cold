"""Original winter greenhouse for N-farming (phase F), vertex-coloured like the cabins.
A 3.2 x 4.4 m timber-framed lean-to style gable house with corrugated poly panels, a plank
door on the -Y gable (Godot +Z), two raised planting beds and a gravel path, snow on the
roof ridge and drifted against the walls. Blender Z-up, origin at ground under the centre,
floor top at z = FT. Objects:
  greenhouse        : frame, sill, beds, door frame, snow (opaque)
  greenhouse_panels : poly glazing (game gives it a translucent material)
  greenhouse_soil   : the two bed soil surfaces (game tints them dry / wet / frozen)
Usage: blender --background --factory-startup --python gen_greenhouse.py -- <out_dir>
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
HX, HY = 1.6, 2.2
FT = 0.15
WALL_TOP = FT + 1.9
RIDGE = FT + 2.75
TIMBER = (0.42, 0.31, 0.20)
TIMBER_DARK = (0.24, 0.17, 0.11)
SILL = (0.30, 0.30, 0.31)
PANEL = (0.78, 0.83, 0.84)
SOIL = (0.17, 0.12, 0.08)
BED = (0.33, 0.24, 0.16)
GRAVEL = (0.40, 0.39, 0.37)
SNOW = (0.86, 0.90, 0.97)
rng = random.Random(41)


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

    def box(self, cx, cy, cz, sx, sy, sz, c, j=0.06):
        x0, x1, y0, y1, z0, z1 = cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2
        cc = col(c, j)
        for q in ([(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)], [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
                  [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
                  [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)]):
            self.poly(q, cc)

    def beam(self, a, b, w, c):
        """Square timber from point a to b (Vectors), w thick."""
        d = b - a
        n = d.normalized()
        u = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized() * w / 2
        v = n.cross(u).normalized() * w / 2
        cc = col(c, 0.08)
        A = [a + u + v, a - u + v, a - u - v, a + u - v]
        B = [p + d for p in A]
        for i in range(4):
            i2 = (i + 1) % 4
            self.poly([A[i], A[i2], B[i2], B[i]], cc)
        self.poly(list(reversed(A)), cc)
        self.poly(B, cc)

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


def roof_z(x):
    return WALL_TOP + (RIDGE - WALL_TOP) * (1.0 - abs(x) / HX)


DOOR_HALF = 0.45
DOOR_TOP = FT + 1.95


def build():
    m, glass, soil, door = Mesh(), Mesh(), Mesh(), Mesh()
    # concrete sill + gravel floor
    for sx in (-HX, HX):
        m.box(sx, 0, FT / 2, 0.16, 2 * HY + 0.16, FT, SILL, j=0.05)
    for sy in (-HY, HY):
        m.box(0, sy, FT / 2, 2 * HX + 0.16, 0.16, FT, SILL, j=0.05)
    m.box(0, 0, FT - 0.02, 2 * HX - 0.1, 2 * HY - 0.1, 0.04, GRAVEL, j=0.04)
    # knee wall (planks, 0.45 high) all round except the doorway
    KW = FT + 0.45
    for sx in (-HX, HX):
        m.box(sx, 0, (FT + KW) / 2, 0.08, 2 * HY, KW - FT, TIMBER_DARK, j=0.08)
    m.box(0, HY, (FT + KW) / 2, 2 * HX, 0.08, KW - FT, TIMBER_DARK, j=0.08)
    for sx in (-1, 1):
        w = HX - DOOR_HALF
        m.box(sx * (DOOR_HALF + w / 2), -HY, (FT + KW) / 2, w, 0.08, KW - FT, TIMBER_DARK, j=0.08)
    # frame: posts every ~1.1 m on the long walls, rafters to the ridge
    ys = [-HY + i * (2 * HY) / 4 for i in range(5)]
    for y in ys:
        for sx in (-HX, HX):
            m.beam(Vector((sx, y, FT)), Vector((sx, y, WALL_TOP)), 0.09, TIMBER)
            m.beam(Vector((sx, y, WALL_TOP)), Vector((0, y, RIDGE)), 0.08, TIMBER)
    for sx in (-HX, HX):
        m.beam(Vector((sx, -HY, WALL_TOP)), Vector((sx, HY, WALL_TOP)), 0.09, TIMBER)   # top plates
    m.beam(Vector((0, -HY - 0.08, RIDGE)), Vector((0, HY + 0.08, RIDGE)), 0.1, TIMBER)  # ridge
    for sy in (-HY, HY):                                                               # gable studs
        for x in (-0.8, 0.8):
            m.beam(Vector((x, sy, FT)), Vector((x, sy, roof_z(x))), 0.07, TIMBER)
    # door frame on the -Y gable
    for sx in (-DOOR_HALF, DOOR_HALF):
        m.beam(Vector((sx, -HY, FT)), Vector((sx, -HY, DOOR_TOP)), 0.09, TIMBER)
    m.beam(Vector((-DOOR_HALF - 0.05, -HY, DOOR_TOP)), Vector((DOOR_HALF + 0.05, -HY, DOOR_TOP)), 0.09, TIMBER)
    # raised beds + soil
    for sx in (-1.0, 1.0):
        bx, bw, by0, by1, bh = sx, 0.95, -1.75, 1.95, FT + 0.42
        for xx in (bx - bw / 2, bx + bw / 2):
            m.box(xx, (by0 + by1) / 2, (FT + bh) / 2, 0.06, by1 - by0, bh - FT, BED, j=0.1)
        for yy in (by0, by1):
            m.box(bx, yy, (FT + bh) / 2, bw, 0.06, bh - FT, BED, j=0.1)
        soil.box(bx, (by0 + by1) / 2, bh - 0.05, bw - 0.06, by1 - by0 - 0.06, 0.04, SOIL, j=0.05)
    # glazing: long walls, gables (around the door), roof
    for sx in (-HX, HX):
        glass.poly([(sx, -HY, KW), (sx, HY, KW), (sx, HY, WALL_TOP), (sx, -HY, WALL_TOP)], col(PANEL, 0.02))
        r = [Vector((sx * 1.0, -HY - 0.12, WALL_TOP - 0.05)), Vector((sx * 1.0, HY + 0.12, WALL_TOP - 0.05)),
             Vector((0, HY + 0.12, RIDGE + 0.02)), Vector((0, -HY - 0.12, RIDGE + 0.02))]
        glass.poly([tuple(p * Vector((1.06, 1, 1))) for p in r], col(PANEL, 0.02))
    glass.poly([(-HX, HY, KW), (HX, HY, KW), (HX, HY, WALL_TOP), (0, HY, RIDGE), (-HX, HY, WALL_TOP)], col(PANEL, 0.02))
    for sx in (-1, 1):
        xo, xi = sx * HX, sx * DOOR_HALF
        glass.poly([(xi, -HY, KW), (xo, -HY, KW), (xo, -HY, WALL_TOP), (xi, -HY, roof_z(xi))][::(1 if sx < 0 else -1)], col(PANEL, 0.02))
    glass.poly([(-DOOR_HALF, -HY, DOOR_TOP), (DOOR_HALF, -HY, DOOR_TOP), (DOOR_HALF, -HY, roof_z(DOOR_HALF)), (0, -HY, RIDGE), (-DOOR_HALF, -HY, roof_z(DOOR_HALF))], col(PANEL, 0.02))
    # snow: along the eaves and ridge, drifted against the walls
    for sx in (-1, 1):
        xa, xb = sx * 0.95, sx * (HX + 0.1)   # snow lying on the lower roof, on the slope
        za, zb = roof_z(0.95) + 0.06, roof_z(HX) - 0.05
        cs = col(SNOW, 0.02)
        m.poly([(xa, -HY - 0.1, za), (xb, -HY - 0.1, zb), (xb, HY + 0.1, zb), (xa, HY + 0.1, za)], cs)
        m.poly([(xa, -HY - 0.1, za - 0.04), (xa, HY + 0.1, za - 0.04), (xb, HY + 0.1, zb - 0.04), (xb, -HY - 0.1, zb - 0.04)], col((0.55, 0.60, 0.68)))
        m.box(sx * (HX + 0.35), 0, 0.12, 0.6, 2 * HY + 0.6, 0.3, SNOW, j=0.02)
    m.box(0, HY + 0.35, 0.1, 2 * HX + 0.6, 0.6, 0.26, SNOW, j=0.02)
    # door: planks with a poly window, hinged at x = -DOOR_HALF (object origin)
    dw = 2 * DOOR_HALF - 0.04
    door.box(dw / 2, 0, (DOOR_TOP - FT) / 2, dw, 0.05, DOOR_TOP - FT - 0.02, TIMBER_DARK, j=0.05)
    door.box(dw / 2, -0.03, (DOOR_TOP - FT) * 0.68, dw - 0.25, 0.01, 0.55, PANEL, j=0.02)
    door.box(dw - 0.1, -0.05, (DOOR_TOP - FT) * 0.48, 0.03, 0.04, 0.12, (0.05, 0.05, 0.05))
    objs = [m.finish("greenhouse"), glass.finish("greenhouse_panels"), soil.finish("greenhouse_soil"), door.finish("greenhouse_door")]
    objs[3].location = (-DOOR_HALF + 0.02, -HY, FT)
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
    os.makedirs(OUT, exist_ok=True)
    objs = build()
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    export(objs, os.path.join(OUT, "greenhouse.glb"))
    print("GREENHOUSE tris", tris)
