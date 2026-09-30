"""
Run: blender.exe --background --factory-startup --python gen_wolf.py -- <out_dir>
Outputs wolf.glb: low-poly timber wolf, ~1.1 m body length, 0.8 m shoulder height, facing Blender +Y (-> Godot -Z).
Separate objects so Godot can animate: wolf_body (torso+neck+head), wolf_tail, wolf_leg_fl/fr/bl/br (origin at hip).
Vertex colours only (grey fur, pale belly, dark muzzle).
"""
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

FUR = (0.30, 0.30, 0.33)
FUR_DARK = (0.16, 0.16, 0.18)
BELLY = (0.52, 0.50, 0.48)
MUZZLE = (0.05, 0.045, 0.05)
EYE = (0.6, 0.45, 0.1)
rng = random.Random(3)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


class M:
    def __init__(self, origin=(0, 0, 0)):
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.color.new("Col")
        self.origin = Vector(origin)

    def poly(self, pts, c):
        vs = [self.bm.verts.new(Vector(p) - self.origin) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return
        for l in f.loops:
            l[self.layer] = (c[0], c[1], c[2], 1.0)

    def blob(self, cx, cy, cz, rx, ry, rz, c, belly=None, sides=8, rings=5, tilt=0.0):
        """Ellipsoid; lower hemisphere optionally belly-coloured. tilt pitches the long axis (rad)."""
        ct, st = math.cos(tilt), math.sin(tilt)

        def P(i, j):
            th = math.pi * j / rings            # 0..pi (top to bottom)
            ph = 2 * math.pi * i / sides
            x = math.sin(th) * math.cos(ph) * rx
            y = math.sin(th) * math.sin(ph) * ry
            z = math.cos(th) * rz
            jit = 1.0 + (rng.random() - 0.5) * 0.06
            y2 = y * ct - z * st
            z2 = y * st + z * ct
            return (cx + x * jit, cy + y2, cz + z2)

        for j in range(rings):
            for i in range(sides):
                i2 = (i + 1) % sides
                a, b, c2, d = P(i, j), P(i2, j), P(i2, j + 1), P(i, j + 1)
                col = belly if (belly and j >= rings - 1) else c
                if j == 0:
                    self.poly([a, c2, d] if False else [P(0, 0), c2, d] if False else [b, c2, d], col)
                    self.poly([a, b, d], col)
                elif j == rings - 1:
                    self.poly([a, b, c2], col)
                    self.poly([a, c2, d], col)
                else:
                    self.poly([a, b, c2, d], col)

    def box(self, cx, cy, cz, sx, sy, sz, c, taper=1.0):
        """Box with bottom scaled by taper (leg segments)."""
        x0, x1, y0, y1, z0, z1 = cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2
        tx, ty = sx * taper / 2, sy * taper / 2
        b = [(cx - tx, cy - ty, z0), (cx + tx, cy - ty, z0), (cx + tx, cy + ty, z0), (cx - tx, cy + ty, z0)]
        t = [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        for k in range(4):
            k2 = (k + 1) % 4
            self.poly([b[k], b[k2], t[k2], t[k]], c)
        self.poly(list(reversed(b)), c)
        self.poly(t, c)

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
        obj.location = self.origin
        bpy.context.collection.objects.link(obj)
        return obj


def build():
    objs = []
    # torso: chest, belly, hips, neck, head
    b = M()
    b.blob(0, 0.10, 0.74, 0.20, 0.30, 0.26, FUR, belly=BELLY)           # chest
    b.blob(0, -0.22, 0.71, 0.18, 0.28, 0.23, FUR, belly=BELLY)          # hips/belly
    b.blob(0, 0.36, 0.86, 0.12, 0.17, 0.15, FUR_DARK, tilt=-0.7)        # neck/ruff
    b.blob(0, 0.56, 0.86, 0.10, 0.16, 0.10, FUR)                        # head
    b.blob(0, 0.72, 0.82, 0.055, 0.12, 0.055, MUZZLE)                   # snout
    for sx in (-1, 1):
        # ears
        b.poly([(sx * 0.06, 0.52, 0.95), (sx * 0.12, 0.50, 0.95), (sx * 0.09, 0.50, 1.08)], FUR_DARK)
        b.poly([(sx * 0.09, 0.50, 1.08), (sx * 0.12, 0.50, 0.95), (sx * 0.06, 0.52, 0.95)], FUR_DARK)
        # eyes
        b.box(sx * 0.085, 0.64, 0.88, 0.02, 0.02, 0.02, EYE)
    # mane ridge
    b.blob(0, 0.05, 0.92, 0.07, 0.38, 0.09, FUR_DARK)
    objs.append(b.finish("wolf_body"))
    # tail: hangs down/back, origin at its root
    t = M(origin=(0, -0.46, 0.76))
    t.blob(0, -0.56, 0.64, 0.07, 0.09, 0.20, FUR, tilt=0.7)
    t.blob(0, -0.64, 0.50, 0.055, 0.07, 0.12, FUR_DARK, tilt=0.5)
    objs.append(t.finish("wolf_tail"))
    # legs: origin at hip
    for name, x, y in (("fl", -0.13, 0.22), ("fr", 0.13, 0.22), ("bl", -0.13, -0.30), ("br", 0.13, -0.30)):
        hip = (x, y, 0.56)
        l = M(origin=hip)
        l.box(x, y, 0.41, 0.125, 0.15, 0.30, FUR, taper=0.75)     # upper
        l.box(x, y + (0.02 if name[0] == "b" else 0.0), 0.14, 0.075, 0.085, 0.28, FUR_DARK, taper=0.85)   # lower
        l.box(x, y + 0.03, 0.02, 0.09, 0.15, 0.04, FUR_DARK)     # paw
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
