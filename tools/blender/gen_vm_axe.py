"""
Run: blender.exe --background --factory-startup --python gen_vm_axe.py -- <out_dir>
vm_axe.glb: hatchet, 0.46 m. Origin = grip point on the handle (z up along handle, blade faces +Y = forward). Budget <= 300 tris.
Part: vm_axe (single mesh, vertex colours).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

WOOD = (0.36, 0.23, 0.11)
WOOD_D = (0.22, 0.14, 0.07)
STEEL = (0.30, 0.31, 0.33)
STEEL_D = (0.14, 0.14, 0.16)
EDGE = (0.62, 0.63, 0.65)
TAPE = (0.09, 0.09, 0.08)

# (y, z, half thickness x, colour) outline of head seen from the side
OUTLINE = [(-0.040, 0.280, 0.016, STEEL_D), (-0.040, 0.340, 0.016, STEEL_D), (0.010, 0.352, 0.016, STEEL),
           (0.068, 0.392, 0.003, EDGE), (0.102, 0.326, 0.002, EDGE), (0.074, 0.246, 0.003, EDGE), (0.010, 0.268, 0.016, STEEL)]


def head(a):
    n = len(OUTLINE)
    for sx in (-1, 1):
        vs = [a.vert((sx * t, y, z), c) for (y, z, t, c) in OUTLINE]
        if sx > 0:
            vs.reverse()
        a.face(vs)
    # edge strips with their own verts (hard crease)
    for i in range(n):
        j = (i + 1) % n
        y0, z0, t0, c0 = OUTLINE[i]
        y1, z1, t1, c1 = OUTLINE[j]
        q = [a.vert((-t0, y0, z0), c0), a.vert((t0, y0, z0), c0), a.vert((t1, y1, z1), c1), a.vert((-t1, y1, z1), c1)]
        a.face(q)


def build():
    a = Part("vm_axe")
    Z = Vector
    # handle: slight forward belly, knob at the butt, tape grip around the hand
    zs = [-0.15, -0.13, -0.08, 0.0, 0.10, 0.20, 0.29, 0.345]
    ys = [-0.005, -0.004, -0.002, 0.0, 0.002, 0.006, 0.01, 0.01]
    rx = [0.020, 0.016, 0.0145, 0.0145, 0.0135, 0.0125, 0.0125, 0.0125]
    ry = [0.017, 0.0135, 0.0125, 0.0125, 0.0115, 0.0105, 0.0105, 0.0105]
    cols = [WOOD_D, WOOD, TAPE, TAPE, WOOD, WOOD, WOOD, WOOD]
    limb(a, [Z((0, ys[i], zs[i])) for i in range(len(zs))], list(zip(rx, ry)), cols, sides=8, ref=Z((0, 1, 0)), cap0=True, cap1=True)
    head(a)
    stain(a, mix=0.0, scale=5.0, thresh=2.0, seed=4.0)
    return a.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    o = build()
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/vm_axe.glb", export_format="GLB", use_selection=True, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("VMAXE tris", tris)
