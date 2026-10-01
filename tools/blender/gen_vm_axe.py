"""
Run: blender.exe --background --factory-startup --python gen_vm_axe.py -- <out_dir>
vm_axe.glb v2: forged hatchet, ~0.52 m. Origin = grip point on the handle (z up along handle, bit faces +Y = forward).
Ash handle (oval section, belly, flared pommel), leather grip wrap, steel head with eye lugs and curved bit. Budget <= 900 tris.
Part: vm_axe.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

Z = Vector((0, 0, 1))
Y = Vector((0, 1, 0))


def T(k):
    return (k, k, k)


# head outline in the side view (y, z, half thickness x, tint): poll, top, toe, curved bit, heel, neck
OUT_PTS = [
    (-0.052, 0.286, 0.0150, 0.80), (-0.052, 0.342, 0.0150, 0.80), (-0.030, 0.351, 0.0160, 0.85), (0.000, 0.355, 0.0150, 0.9),
    (0.040, 0.372, 0.0100, 0.95), (0.076, 0.395, 0.0040, 1.0), (0.100, 0.366, 0.0016, 1.0), (0.108, 0.330, 0.0012, 1.0),
    (0.107, 0.298, 0.0012, 1.0), (0.099, 0.266, 0.0016, 1.0), (0.084, 0.240, 0.0030, 1.0), (0.046, 0.256, 0.0080, 0.95),
    (0.010, 0.268, 0.0130, 0.9), (-0.026, 0.282, 0.0150, 0.85),
]


def head(a):
    a.mat = "steel"
    n = len(OUT_PTS)
    cL = a.vert((-0.0185, 0.010, 0.318), T(0.85))
    cR = a.vert((0.0185, 0.010, 0.318), T(0.85))
    L = [a.vert((-t, y, z), T(k)) for (y, z, t, k) in OUT_PTS]
    R = [a.vert((t, y, z), T(k)) for (y, z, t, k) in OUT_PTS]
    for i in range(n):
        j = (i + 1) % n
        a.face([cL, L[i], L[j]])
        a.face([cR, R[j], R[i]])
        # bevel strip between cheeks along the outline
        a.face([L[i], R[i], R[j], L[j]])
    # eye lugs around the handle
    limb(a, [Vector((0, 0.010, 0.272)), Vector((0, 0.010, 0.300)), Vector((0, 0.010, 0.332)), Vector((0, 0.010, 0.358))],
         [(0.0215, 0.0235), (0.0230, 0.0250), (0.0230, 0.0250), (0.0205, 0.0225)], [T(0.8), T(0.95), T(0.95), T(0.85)],
         sides=12, ref=Y, cap0=False, cap1=True, n=2.2)


def build():
    a = Part("vm_axe")
    a.mat = "ash"
    st = [(-0.170, 0.0, 0.0105, 0.0185), (-0.150, -0.002, 0.0100, 0.0160), (-0.120, -0.003, 0.0095, 0.0148), (-0.060, -0.002, 0.0098, 0.0145),
          (0.000, 0.000, 0.0100, 0.0146), (0.080, 0.002, 0.0098, 0.0140), (0.160, 0.005, 0.0096, 0.0136), (0.240, 0.008, 0.0098, 0.0136),
          (0.300, 0.010, 0.0100, 0.0138), (0.345, 0.010, 0.0100, 0.0140)]
    shade = [0.75, 0.85, 0.9, 0.95, 1.0, 1.0, 1.0, 1.0, 0.95, 0.9]
    limb(a, [Vector((0, y, z)) for (z, y, _, _) in st], [(w, h) for (_, _, w, h) in st], [T(s) for s in shade], sides=12, ref=Y,
         cap0=True, cap1=True, n=2.4)
    # leather grip wrap
    a.mat = "leather"
    gz = [-0.115, -0.085, -0.04, 0.0, 0.04, 0.075]
    limb(a, [Vector((0, -0.002, z)) for z in gz], [(0.0112, 0.0158), (0.0120, 0.0166), (0.0122, 0.0168), (0.0122, 0.0168), (0.0120, 0.0166), (0.0112, 0.0158)],
         [T(0.7), T(0.9), T(1.0), T(1.0), T(0.9), T(0.7)], sides=12, ref=Y, cap0=True, cap1=True, n=2.4)
    head(a)
    a.tint_noise(0.15, 12.0, 4.0)
    return a.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    o = build()
    export_glb([o], os.path.join(OUT, "vm_axe.glb"))
    print("VMAXE tris", tris(o))
