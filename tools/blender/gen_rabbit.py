"""Original low-poly snowshoe hare (winter white with grey-brown ear tips) and a wire
snare, vertex-coloured. Blender Z-up, the hare faces Blender -Y (= Godot +Z... the game
turns it); origin on the ground under the body. Separate nodes the game animates:
  rabbit.glb : rabbit_body, rabbit_ears, rabbit_hind (hind legs pivot at the hip)
  snare.glb  : snare (stake, cord, wire loop on a stick frame)
Usage: blender --background --factory-startup --python gen_rabbit.py -- <out_dir>
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
FUR = (0.86, 0.85, 0.82)
FUR_SHADE = (0.70, 0.68, 0.64)
TIP = (0.30, 0.25, 0.20)
EYE = (0.03, 0.03, 0.03)
NOSE = (0.55, 0.38, 0.36)
WOOD = (0.33, 0.24, 0.16)
WIRE = (0.55, 0.55, 0.57)
rng = random.Random(7)


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

    def blob(self, p, rx, ry, rz, c, seg=8, rings=5, j=0.05, shade=None):
        pts = []
        for k in range(rings + 1):
            t = math.pi * k / rings
            pts.append([Vector((p[0] + math.sin(t) * math.cos(2 * math.pi * i / seg) * rx, p[1] + math.sin(t) * math.sin(2 * math.pi * i / seg) * ry, p[2] - math.cos(t) * rz)) for i in range(seg)])
        for k in range(rings):
            cc = col(shade if shade is not None and k < rings / 2 else c, j)
            for i in range(seg):
                i2 = (i + 1) % seg
                self.poly([pts[k][i], pts[k + 1][i], pts[k + 1][i2], pts[k][i2]], cc)

    def tube(self, a, b, r0, r1, c, sides=5):
        a, b = Vector(a), Vector(b)
        n = (b - a).normalized()
        u = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        v = n.cross(u)
        cc = col(c, 0.05)
        A = [a + (u * math.cos(2 * math.pi * i / sides) + v * math.sin(2 * math.pi * i / sides)) * r0 for i in range(sides)]
        B = [b + (u * math.cos(2 * math.pi * i / sides) + v * math.sin(2 * math.pi * i / sides)) * r1 for i in range(sides)]
        for i in range(sides):
            i2 = (i + 1) % sides
            self.poly([A[i], A[i2], B[i2], B[i]], cc)

    def finish(self, name, origin=(0, 0, 0)):
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=Vector(origin) * -1)
        self.bm.to_mesh(mesh)
        self.bm.free()
        if mesh.color_attributes:
            mesh.color_attributes.active_color = mesh.color_attributes[0]
            mesh.color_attributes.render_color_index = 0
        for p in mesh.polygons:
            p.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        obj.location = origin
        bpy.context.collection.objects.link(obj)
        return obj


def rabbit():
    body, ears, hind = Mesh(), Mesh(), Mesh()
    body.blob((0, 0.02, 0.15), 0.09, 0.15, 0.10, FUR, shade=FUR_SHADE)          # haunch-heavy body
    body.blob((0, -0.13, 0.22), 0.065, 0.075, 0.065, FUR, shade=FUR_SHADE)      # head
    body.blob((0, -0.20, 0.215), 0.022, 0.02, 0.018, NOSE, seg=5, rings=3)
    for sx in (-1, 1):
        body.blob((sx * 0.052, -0.16, 0.24), 0.012, 0.012, 0.012, EYE, seg=5, rings=3)
        body.tube((sx * 0.03, -0.09, 0.07), (sx * 0.035, -0.11, 0.0), 0.015, 0.012, FUR)  # forelegs
    body.blob((0, 0.17, 0.17), 0.035, 0.03, 0.035, (0.95, 0.95, 0.94), seg=6, rings=3)  # tail puff
    for sx in (-1, 1):                                                                 # ears from the crown
        base = Vector((sx * 0.025, -0.11, 0.27))
        tip = base + Vector((sx * 0.03, 0.06, 0.13))
        ears.tube(base, tip - (tip - base) * 0.25, 0.018, 0.016, FUR, sides=5)
        ears.tube(tip - (tip - base) * 0.25, tip, 0.016, 0.006, TIP, sides=5)
    for sx in (-1, 1):                                                                 # big snowshoe feet
        hind.tube((sx * 0.06, 0.08, 0.12), (sx * 0.065, 0.05, 0.03), 0.03, 0.022, FUR)
        hind.blob((sx * 0.065, 0.0, 0.018), 0.028, 0.08, 0.016, FUR_SHADE, seg=6, rings=3)
    return [body.finish("rabbit_body"), ears.finish("rabbit_ears", (0, -0.11, 0.27)), hind.finish("rabbit_hind", (0, 0.08, 0.12))]


def snare():
    m = Mesh()
    m.tube((0, 0.25, -0.05), (0.02, 0.25, 0.32), 0.018, 0.012, WOOD)                 # stake
    m.tube((-0.12, 0, 0.0), (-0.12, 0, 0.30), 0.012, 0.009, WOOD)                  # loop frame sticks
    m.tube((0.12, 0, 0.0), (0.12, 0, 0.30), 0.012, 0.009, WOOD)
    m.tube((-0.14, 0, 0.30), (0.14, 0, 0.30), 0.01, 0.01, WOOD)
    pts = [Vector((math.cos(2 * math.pi * i / 12) * 0.08, 0, 0.15 + math.sin(2 * math.pi * i / 12) * 0.08)) for i in range(12)]
    for a, b in zip(pts, pts[1:] + pts[:1]):
        m.tube(a, b, 0.004, 0.004, WIRE, sides=3)                                    # wire loop
    m.tube((0, 0, 0.30), (0.02, 0.25, 0.30), 0.004, 0.004, WIRE, sides=3)           # tether to the stake
    return [m.finish("snare")]


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
    for name, build in (("rabbit", rabbit), ("snare", snare)):
        objs = build()
        tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
        export(objs, os.path.join(OUT, name + ".glb"))
        print("SMALLGAME", name, "tris", tris)
