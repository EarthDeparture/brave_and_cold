"""
Run: blender.exe --background --factory-startup --python gen_deer.py -- <out_dir>
Outputs deer.glb: low-poly white-tailed deer (stag), ~1.1 m body length, 0.8 m shoulder height, facing Blender +Y (-> Godot -Z).
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

FUR = (0.36, 0.26, 0.18)
FUR_DARK = (0.20, 0.14, 0.10)
BELLY = (0.62, 0.56, 0.48)
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


ANTLER = (0.55, 0.48, 0.38)
WHITE = (0.85, 0.85, 0.85)


def build():
    objs = []
    b = M()
    b.blob(0, 0.05, 0.98, 0.21, 0.36, 0.26, FUR, belly=BELLY)            # barrel
    b.blob(0, -0.30, 0.96, 0.20, 0.26, 0.25, FUR, belly=BELLY)           # haunch
    b.blob(0, 0.46, 1.22, 0.10, 0.14, 0.26, FUR, tilt=-0.5)              # neck
    b.blob(0, 0.62, 1.42, 0.085, 0.17, 0.09, FUR)                        # head
    b.blob(0, 0.78, 1.38, 0.05, 0.11, 0.05, FUR_DARK)                    # muzzle
    for sx in (-1, 1):
        b.poly([(sx * 0.06, 0.58, 1.48), (sx * 0.15, 0.56, 1.50), (sx * 0.09, 0.57, 1.60)], FUR)
        b.poly([(sx * 0.09, 0.57, 1.60), (sx * 0.15, 0.56, 1.50), (sx * 0.06, 0.58, 1.48)], FUR)
        b.box(sx * 0.075, 0.68, 1.45, 0.02, 0.02, 0.02, (0.05, 0.04, 0.03))
        # antlers: main beam + two tines
        b.box(sx * 0.10, 0.55, 1.64, 0.02, 0.02, 0.22, ANTLER, taper=0.7)
        b.box(sx * 0.14, 0.52, 1.80, 0.02, 0.02, 0.18, ANTLER, taper=0.7)
        b.box(sx * 0.16, 0.60, 1.70, 0.02, 0.10, 0.02, ANTLER)
        b.box(sx * 0.12, 0.47, 1.72, 0.02, 0.10, 0.02, ANTLER)
    objs.append(b.finish("deer_body"))
    t = M(origin=(0, -0.54, 1.08))
    t.blob(0, -0.60, 1.04, 0.06, 0.05, 0.11, WHITE, tilt=0.4)
    objs.append(t.finish("deer_tail"))
    for name, x, y in (("fl", -0.12, 0.30), ("fr", 0.12, 0.30), ("bl", -0.12, -0.36), ("br", 0.12, -0.36)):
        hip = (x, y, 0.80)
        l = M(origin=hip)
        l.box(x, y, 0.60, 0.10, 0.13, 0.36, FUR, taper=0.7)
        l.box(x, y, 0.22, 0.055, 0.065, 0.42, FUR_DARK, taper=0.8)
        l.box(x, y + 0.02, 0.02, 0.07, 0.11, 0.04, (0.06, 0.05, 0.05))
        objs.append(l.finish("deer_leg_" + name))
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
    export(objs, f"{OUT}/deer.glb")
    print("DEER tris", tris)