"""
Run: blender.exe --background --factory-startup --python gen_zombie.py -- <out_dir>
Outputs zombie.glb: low-poly shambler, 1.8 m tall, hunched, arms reaching forward; faces Blender +Y (-> Godot -Z).
Segmented for animation: zombie_body (torso+head), zombie_arm_l/r (origin at shoulder), zombie_leg_l/r (origin at hip).
Vertex colours: winter coat, pale grey-green skin, dried blood.
"""
import sys
import math
import random
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

COAT = (0.17, 0.18, 0.23)
COAT_LIGHT = (0.26, 0.24, 0.21)
SKIN = (0.58, 0.63, 0.54)
SKIN_DARK = (0.26, 0.29, 0.26)
PANTS = (0.16, 0.15, 0.17)
BOOT = (0.05, 0.045, 0.045)
BLOOD = (0.22, 0.03, 0.03)
HAIR = (0.06, 0.055, 0.05)
rng = random.Random(8)


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
        j = 1.0 + (rng.random() - 0.5) * 0.12
        for l in f.loops:
            l[self.layer] = (min(c[0] * j, 1), min(c[1] * j, 1), min(c[2] * j, 1), 1.0)

    def blob(self, cx, cy, cz, rx, ry, rz, c, sides=8, rings=5):
        def P(i, j):
            th = math.pi * j / rings
            ph = 2 * math.pi * i / sides
            return (cx + math.sin(th) * math.cos(ph) * rx, cy + math.sin(th) * math.sin(ph) * ry, cz + math.cos(th) * rz)
        for j in range(rings):
            for i in range(sides):
                i2 = (i + 1) % sides
                a, b, c2, d = P(i, j), P(i2, j), P(i2, j + 1), P(i, j + 1)
                if j == 0:
                    self.poly([b, c2, d], c)
                    self.poly([a, b, d], c)
                elif j == rings - 1:
                    self.poly([a, b, c2], c)
                    self.poly([a, c2, d], c)
                else:
                    self.poly([a, b, c2, d], c)

    def box(self, cx, cy, cz, sx, sy, sz, c, top_scale=(1.0, 1.0), bot_scale=(1.0, 1.0), colors=None):
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        b = [(cx - hx * bot_scale[0], cy - hy * bot_scale[1], cz - hz), (cx + hx * bot_scale[0], cy - hy * bot_scale[1], cz - hz),
             (cx + hx * bot_scale[0], cy + hy * bot_scale[1], cz - hz), (cx - hx * bot_scale[0], cy + hy * bot_scale[1], cz - hz)]
        t = [(cx - hx * top_scale[0], cy - hy * top_scale[1], cz + hz), (cx + hx * top_scale[0], cy - hy * top_scale[1], cz + hz),
             (cx + hx * top_scale[0], cy + hy * top_scale[1], cz + hz), (cx - hx * top_scale[0], cy + hy * top_scale[1], cz + hz)]
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
    b = M()
    # torso (coat), hunched forward
    b.box(0, 0.03, 1.36, 0.44, 0.26, 0.62, COAT, top_scale=(1.05, 1.0), bot_scale=(0.9, 0.95))
    b.box(0, 0.05, 1.05, 0.40, 0.25, 0.20, COAT_LIGHT)                     # coat hem
    b.box(0, 0.13, 1.42, 0.20, 0.03, 0.22, BLOOD)                          # blood on chest
    b.blob(0, 0.14, 1.72, 0.08, 0.08, 0.10, SKIN_DARK)                     # neck
    b.blob(0, 0.22, 1.83, 0.115, 0.13, 0.14, SKIN)                         # head (forward)
    b.blob(0, 0.19, 1.93, 0.12, 0.13, 0.07, HAIR)                          # hair/hat
    b.box(0.0, 0.33, 1.79, 0.10, 0.03, 0.06, BLOOD)                        # mouth
    for sx in (-1, 1):
        b.box(sx * 0.055, 0.34, 1.86, 0.025, 0.02, 0.025, (0.9, 0.9, 0.7))  # eyes
    objs.append(b.finish("zombie_body"))
    # arms: origin at shoulder, reaching forward
    for name, sx in (("l", -1), ("r", 1)):
        sh = (sx * 0.27, 0.06, 1.55)
        a = M(origin=sh)
        a.box(sx * 0.27, 0.22, 1.50, 0.10, 0.34, 0.10, COAT, top_scale=(1, 1))
        a.box(sx * 0.27, 0.50, 1.44, 0.085, 0.30, 0.085, SKIN, top_scale=(1, 1))
        a.box(sx * 0.27, 0.68, 1.42, 0.09, 0.10, 0.06, SKIN_DARK)
        objs.append(a.finish("zombie_arm_" + name))
    # legs: origin at hip
    for name, sx in (("l", -1), ("r", 1)):
        hip = (sx * 0.11, 0.0, 1.0)
        l = M(origin=hip)
        l.box(sx * 0.11, 0.0, 0.76, 0.17, 0.19, 0.46, PANTS, bot_scale=(0.85, 0.85))
        l.box(sx * 0.11, 0.0, 0.32, 0.13, 0.15, 0.44, PANTS)
        l.box(sx * 0.11, 0.05, 0.06, 0.14, 0.27, 0.12, BOOT)
        objs.append(l.finish("zombie_leg_" + name))
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
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    export(objs, f"{OUT}/zombie.glb")
    print("ZOMBIE tris", tris)
