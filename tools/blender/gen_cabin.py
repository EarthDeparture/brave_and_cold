"""
Run: blender.exe --background --factory-startup --python gen_cabin.py -- <out_dir>
Outputs cabin.glb: log cabin 6.6 x 5.6 m (x by y in Blender; door on -Y wall), notched log corners,
gabled roof with snow, stone foundation, stove + bed + table + shelf interior.
Two objects: "cabin" (vertex-coloured, opaque) and "cabin_glass" (window panes; Godot swaps an emissive material).
Blender +Z up -> glTF +Y up; Blender -Y (door) -> Godot +Z.
"""
import sys
import math
import random
import bpy
import bmesh

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

HX, HY = 3.0, 2.5           # wall centre-line half extents
LOG_R = 0.15
FLOOR_TOP = 0.3
COURSES = 9
STEP = 0.29
Z0 = FLOOR_TOP + LOG_R      # first log centre
WALL_TOP = Z0 + (COURSES - 1) * STEP + LOG_R
DOOR = (-0.55, 0.55, FLOOR_TOP, FLOOR_TOP + 2.05)                # x0, x1, zlo, zhi (front wall, y=-HY)
WIN_SIDE = (-0.3, 0.9, FLOOR_TOP + 1.05, FLOOR_TOP + 1.85)      # y0, y1, zlo, zhi (walls x=+-HX)
WIN_BACK = (-1.7, -0.6, FLOOR_TOP + 1.05, FLOOR_TOP + 1.85)     # x0, x1 (back wall y=+HY)

WOOD = (0.30, 0.215, 0.15)
WOOD_DARK = (0.19, 0.135, 0.095)
WOOD_LIGHT = (0.40, 0.29, 0.19)
STONE = (0.16, 0.16, 0.18)
SNOW = (0.86, 0.90, 0.97)
IRON = (0.04, 0.04, 0.045)
FABRIC = (0.30, 0.10, 0.09)
FABRIC2 = (0.10, 0.14, 0.22)
GLASS = (0.30, 0.42, 0.55)

rng = random.Random(5)


def col(c, j=0.0):
    k = 1.0 + (rng.random() * 2 - 1) * j
    return (min(c[0] * k, 1), min(c[1] * k, 1), min(c[2] * k, 1), 1.0)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


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

    def box(self, cx, cy, cz, sx, sy, sz, c, top=None, j=0.06):
        x0, x1, y0, y1, z0, z1 = cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2
        cc = col(c, j)
        tc = col(top, 0.02) if top else cc
        self.poly([(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)], cc)
        self.poly([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], tc)
        self.poly([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], cc)
        self.poly([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], cc)
        self.poly([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], cc)
        self.poly([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], cc)

    def log(self, axis, a0, a1, fixed, z, r=LOG_R, c=WOOD, sides=8):
        """Cylinder along X (axis='x', at y=fixed) or Y (axis='y', at x=fixed) from a0 to a1."""
        r = r * (0.94 + rng.random() * 0.12)
        cc = col(c, 0.18)
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides + 0.39
            ring.append((math.cos(a) * r, math.sin(a) * r))

        def pt(t, k):
            u, v = ring[k]
            if axis == "x":
                return (t, fixed + u, z + v)
            return (fixed + u, t, z + v)

        for k in range(sides):
            k2 = (k + 1) % sides
            self.poly([pt(a0, k), pt(a1, k), pt(a1, k2), pt(a0, k2)], cc)
        self.poly([pt(a0, k) for k in reversed(range(sides))], col(WOOD_LIGHT, 0.1))
        self.poly([pt(a1, k) for k in range(sides)], col(WOOD_LIGHT, 0.1))

    def pipe(self, x, y, z0, z1, r, c, sides=8):
        ring = [(math.cos(2 * math.pi * i / sides) * r, math.sin(2 * math.pi * i / sides) * r) for i in range(sides)]
        cc = col(c)
        for k in range(sides):
            k2 = (k + 1) % sides
            self.poly([(x + ring[k][0], y + ring[k][1], z0), (x + ring[k2][0], y + ring[k2][1], z0),
                       (x + ring[k2][0], y + ring[k2][1], z1), (x + ring[k][0], y + ring[k][1], z1)], cc)
        self.poly([(x + ring[k][0], y + ring[k][1], z1) for k in range(sides)], cc)

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


def split_log(m, axis, fixed, z, lo, hi, opening):
    """Add a wall log from lo..hi, cut by an opening (a0, a1, zlo, zhi)."""
    if opening is not None:
        a0, a1, zlo, zhi = opening
        if zlo - LOG_R * 0.5 <= z <= zhi + LOG_R * 0.5:
            if lo < a0:
                m.log(axis, lo, a0, fixed, z)
            if a1 < hi:
                m.log(axis, a1, hi, fixed, z)
            return
    m.log(axis, lo, hi, fixed, z)


def build_cabin():
    m = Mesh()
    # foundation
    m.box(0, 0, (FLOOR_TOP - 1.4) / 2 + 0.0, 6.4, 5.4, FLOOR_TOP + 1.4, STONE, top=None, j=0.15)
    # floor planks (interior)
    for i in range(12):
        y = -2.3 + i * 0.4 + 0.2
        m.box(0, y, FLOOR_TOP - 0.03, 5.8, 0.38, 0.06, WOOD_LIGHT, top=WOOD_LIGHT, j=0.12)
    # walls
    for i in range(COURSES):
        z = Z0 + i * STEP
        # front/back walls run along X (overhang 0.35 for notched corners)
        split_log(m, "x", -HY, z, -HX - 0.35, HX + 0.35, (DOOR[0], DOOR[1], DOOR[2], DOOR[3]))
        split_log(m, "x", HY, z, -HX - 0.35, HX + 0.35, (WIN_BACK[0], WIN_BACK[1], WIN_BACK[2], WIN_BACK[3]))
        zz = z + STEP * 0.5
        if i < COURSES - 1:
            split_log(m, "y", -HX, zz, -HY - 0.35, HY + 0.35, WIN_SIDE)
            split_log(m, "y", HX, zz, -HY - 0.35, HY + 0.35, WIN_SIDE)
    # window trim + sill
    for sx in (-HX, HX):
        y0, y1, zlo, zhi = WIN_SIDE
        m.box(sx, (y0 + y1) / 2, zlo - 0.04, 0.42, y1 - y0 + 0.2, 0.08, WOOD_DARK)
        m.box(sx, (y0 + y1) / 2, zhi + 0.04, 0.42, y1 - y0 + 0.2, 0.08, WOOD_DARK)
        m.box(sx, y0 - 0.04, (zlo + zhi) / 2, 0.42, 0.08, zhi - zlo, WOOD_DARK)
        m.box(sx, y1 + 0.04, (zlo + zhi) / 2, 0.42, 0.08, zhi - zlo, WOOD_DARK)
        m.box(sx, (y0 + y1) / 2, (zlo + zhi) / 2, 0.06, 0.05, zhi - zlo, WOOD_DARK)   # mullion
    x0, x1, zlo, zhi = WIN_BACK
    m.box((x0 + x1) / 2, HY, zlo - 0.04, x1 - x0 + 0.2, 0.42, 0.08, WOOD_DARK)
    m.box((x0 + x1) / 2, HY, zhi + 0.04, x1 - x0 + 0.2, 0.42, 0.08, WOOD_DARK)
    m.box(x0 - 0.04, HY, (zlo + zhi) / 2, 0.08, 0.42, zhi - zlo, WOOD_DARK)
    m.box(x1 + 0.04, HY, (zlo + zhi) / 2, 0.08, 0.42, zhi - zlo, WOOD_DARK)
    # door frame + lintel + step
    m.box(DOOR[0] - 0.06, -HY, (DOOR[2] + DOOR[3]) / 2, 0.12, 0.42, DOOR[3] - DOOR[2], WOOD_DARK)
    m.box(DOOR[1] + 0.06, -HY, (DOOR[2] + DOOR[3]) / 2, 0.12, 0.42, DOOR[3] - DOOR[2], WOOD_DARK)
    m.box(0, -HY, DOOR[3] + 0.06, DOOR[1] - DOOR[0] + 0.24, 0.42, 0.12, WOOD_DARK)
    m.box(0, -HY - 0.55, FLOOR_TOP - 0.12, 1.4, 0.7, 0.18, WOOD_LIGHT)
    # gable end fill (upper triangles above top log) + roof
    eave = WALL_TOP
    ridge = eave + 1.35
    for sx in (-HX - 0.02, HX + 0.02):
        m.poly([(sx, -HY - 0.15, eave - 0.3), (sx, HY + 0.15, eave - 0.3), (sx, HY + 0.15, eave), (sx, 0, ridge), (sx, -HY - 0.15, eave)], col(WOOD, 0.05))
        m.poly([(sx, -HY - 0.15, eave), (sx, 0, ridge), (sx, HY + 0.15, eave), (sx, HY + 0.15, eave - 0.3), (sx, -HY - 0.15, eave - 0.3)], col(WOOD_DARK, 0.05))
    for sy in (-HY, HY):  # top plate closes the slit between the last log course and the roof slab
        m.box(0, sy, eave + 0.02, 2 * HX + 0.7, 0.42, 0.16, WOOD_DARK)
    ov = 0.75
    half = HY + ov
    slope_len = math.hypot(half, ridge - (eave - 0.15))
    for side in (-1, 1):
        # roof slab: quad from eave edge to ridge with thickness
        yE = side * half
        zE = eave - 0.15
        t = 0.14
        xL, xR = -HX - 0.6, HX + 0.6
        top_pts = [(xL, yE, zE), (xR, yE, zE), (xR, 0, ridge + 0.05), (xL, 0, ridge + 0.05)]
        nz = t
        under = [(x, y, z - nz) for (x, y, z) in top_pts]
        m.poly(top_pts if side > 0 else list(reversed(top_pts)), col(WOOD_DARK, 0.05))
        m.poly(list(reversed(under)) if side > 0 else under, col(WOOD_LIGHT, 0.08))
        m.poly([top_pts[0], under[0], under[1], top_pts[1]] if side > 0 else [top_pts[1], under[1], under[0], top_pts[0]], col(WOOD_DARK))
        # snow blanket on top
        sn = 0.16
        s_pts = [(xL - 0.05, yE * 0.985, zE + 0.02), (xR + 0.05, yE * 0.985, zE + 0.02),
                 (xR + 0.05, 0, ridge + 0.05 + sn), (xL - 0.05, 0, ridge + 0.05 + sn)]
        m.poly(s_pts if side > 0 else list(reversed(s_pts)), col(SNOW, 0.02))
        edge = [(xL - 0.05, yE * 0.985, zE + 0.02), (xL - 0.05, yE * 0.985, zE - 0.1), (xR + 0.05, yE * 0.985, zE - 0.1), (xR + 0.05, yE * 0.985, zE + 0.02)]
        m.poly(edge if side > 0 else list(reversed(edge)), col(SNOW, 0.02))
    m.log("x", -HX - 0.7, HX + 0.7, 0, ridge + 0.02, r=0.13, c=WOOD)
    # ceiling tie beams
    for x in (-2.4, 0, 2.4):
        m.box(x, 0, eave - 0.05, 0.16, 5.4, 0.16, WOOD_DARK)
    # stove + pipe (back-left)
    sx, sy = -2.35, 1.75
    m.box(sx, sy, FLOOR_TOP + 0.5, 0.7, 0.5, 0.7, IRON, top=(0.06, 0.06, 0.07), j=0.05)
    m.box(sx, sy - 0.26, FLOOR_TOP + 0.4, 0.3, 0.02, 0.25, (0.02, 0.02, 0.02))
    m.box(sx, sy + 0.05, FLOOR_TOP + 0.1, 0.9, 0.7, 0.06, STONE)
    m.pipe(sx, sy, FLOOR_TOP + 0.85, ridge + 1.0, 0.075, IRON)
    m.box(sx, sy, ridge + 1.0, 0.24, 0.24, 0.1, SNOW)
    # bed (back-right corner)
    bx, by = 2.0, 1.65
    m.box(bx, by, FLOOR_TOP + 0.3, 1.9, 0.95, 0.12, WOOD_DARK)
    for lx in (-0.9, 0.9):
        for ly in (-0.42, 0.42):
            m.box(bx + lx, by + ly, FLOOR_TOP + 0.13, 0.1, 0.1, 0.26, WOOD_DARK)
    m.box(bx, by, FLOOR_TOP + 0.4, 1.8, 0.88, 0.12, FABRIC, top=FABRIC, j=0.1)
    m.box(bx + 0.72, by, FLOOR_TOP + 0.51, 0.4, 0.6, 0.1, (0.55, 0.53, 0.5))
    m.box(bx - 0.35, by, FLOOR_TOP + 0.48, 0.9, 0.86, 0.05, FABRIC2)
    # table + two stools (front-left)
    tx, ty = -1.6, -0.9
    m.box(tx, ty, FLOOR_TOP + 0.74, 1.2, 0.75, 0.06, WOOD_LIGHT)
    for lx in (-0.53, 0.53):
        for ly in (-0.3, 0.3):
            m.box(tx + lx, ty + ly, FLOOR_TOP + 0.36, 0.07, 0.07, 0.72, WOOD)
    for sxx, syy in ((tx - 0.3, ty - 0.7), (tx + 0.4, ty + 0.72)):
        m.box(sxx, syy, FLOOR_TOP + 0.42, 0.34, 0.34, 0.05, WOOD_LIGHT)
        for lx in (-0.12, 0.12):
            for ly in (-0.12, 0.12):
                m.box(sxx + lx, syy + ly, FLOOR_TOP + 0.2, 0.05, 0.05, 0.4, WOOD)
    # tin cup + lantern on table
    m.pipe(tx + 0.3, ty, FLOOR_TOP + 0.77, FLOOR_TOP + 0.87, 0.04, (0.30, 0.30, 0.32))
    m.box(tx - 0.3, ty + 0.1, FLOOR_TOP + 0.87, 0.14, 0.14, 0.2, (0.22, 0.05, 0.04))
    # shelf + crate (right wall)
    m.box(HX - 0.35, -0.9, FLOOR_TOP + 1.55, 0.3, 1.5, 0.05, WOOD_LIGHT)
    for k in range(4):
        m.box(HX - 0.35, -1.4 + k * 0.32, FLOOR_TOP + 1.7, 0.16, 0.14, 0.2, col(WOOD_DARK, 0.5)[:3], j=0.2)
    m.box(HX - 0.5, -1.6, FLOOR_TOP + 0.3, 0.7, 0.7, 0.55, WOOD)
    m.box(HX - 0.5, -1.6, FLOOR_TOP + 0.6, 0.72, 0.72, 0.05, WOOD_DARK)
    # firewood stack outside, right of the door
    for row in range(3):
        for k in range(6 - row):
            m.log("y", -HY - 0.9, -HY - 0.15, 1.05 + k * 0.28 + row * 0.14 + 0.75, FLOOR_TOP + 0.15 + row * 0.25, r=0.12, c=WOOD, sides=6)
    # snow drift piles at foundation
    m.box(0, -HY - 0.2, FLOOR_TOP - 0.1, 5.8, 0.5, 0.35, SNOW, top=SNOW, j=0.02)
    m.box(HX + 0.3, 0.5, FLOOR_TOP - 0.1, 0.5, 4.4, 0.35, SNOW, top=SNOW, j=0.02)
    return m.finish("cabin")


def build_glass():
    m = Mesh()
    g = col(GLASS)
    for sx in (-HX, HX):
        y0, y1, zlo, zhi = WIN_SIDE
        m.poly([(sx, y0, zlo), (sx, y1, zlo), (sx, y1, zhi), (sx, y0, zhi)], g)
        m.poly([(sx, y0, zhi), (sx, y1, zhi), (sx, y1, zlo), (sx, y0, zlo)], g)
    x0, x1, zlo, zhi = WIN_BACK
    m.poly([(x0, HY, zlo), (x1, HY, zlo), (x1, HY, zhi), (x0, HY, zhi)], g)
    m.poly([(x0, HY, zhi), (x1, HY, zhi), (x1, HY, zlo), (x0, HY, zlo)], g)
    return m.finish("cabin_glass")


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)


if __name__ == "__main__":
    clear()
    cab = build_cabin()
    gl = build_glass()
    tris = sum(len(p.vertices) - 2 for p in cab.data.polygons)
    export([cab, gl], f"{OUT}/cabin.glb")
    print("CABIN tris", tris, "wall_top", WALL_TOP)
