"""
Run: blender.exe --background --factory-startup --python gen_vm_rifle.py -- <out_dir>
vm_rifle.glb v3 (TLD hunting-rifle proportions: Lee-Enfield pattern): chunky orange beech stock, straight wrist (no pistol grip),
full-length handguard to a steel nose cap, boxy receiver with rear-sight ladder, big magazine box, black barrel bands, swept bolt
handle with round knob. ~1.1 m. Origin = wrist of the stock. Muzzle toward +Y (Godot -Z).
Parts: vm_rifle, vm_bolt (origin on bolt axis at (0,-0.06,BZ+0.006), slides along Y). Budget <= 3500 tris.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

Z = Vector((0, 0, 1))
X = Vector((1, 0, 0))
BZ = 0.040  # bore axis height


def T(k):
    return (k, k, k)


def V(y, z, x=0.0):
    return Vector((x, y, z))


def build_rifle():
    r = Part("vm_rifle")
    # ---- stock + handguard (beech). station = (y, zc, half width, half height)
    r.mat = "beech"
    st = [(-0.402, -0.044, 0.0165, 0.066), (-0.380, -0.043, 0.0185, 0.064), (-0.320, -0.037, 0.0195, 0.056), (-0.260, -0.028, 0.0195, 0.048),
          (-0.200, -0.018, 0.0190, 0.042), (-0.140, -0.011, 0.0185, 0.039), (-0.080, -0.007, 0.0180, 0.037), (-0.020, -0.004, 0.0185, 0.038),
          (0.050, 0.000, 0.0190, 0.040), (0.120, 0.004, 0.0195, 0.040), (0.220, 0.008, 0.0195, 0.036), (0.340, 0.012, 0.0190, 0.032),
          (0.460, 0.016, 0.0185, 0.029), (0.560, 0.018, 0.0180, 0.026), (0.600, 0.019, 0.0165, 0.0235)]
    shade = [0.8, 0.9, 0.95, 1.0, 1.0, 1.0, 0.95, 0.9, 0.95, 1.0, 1.0, 1.0, 0.98, 0.95, 0.85]
    limb(r, [V(y, z) for (y, z, _, _) in st], [(w, h) for (_, _, w, h) in st], [T(s) for s in shade], sides=16, ref=Z,
         cap0=False, cap1=False, n=2.8)
    blob(r, (0, -0.030, -0.040), 0.019, 0.034, 0.022, T(0.9), sides=10, nrings=4)           # wrist swell under the hand
    # butt pad
    r.mat = "rubber"
    limb(r, [V(-0.404, -0.044), V(-0.4135, -0.044)], [(0.0170, 0.0670), (0.0170, 0.0670)], [T(0.9), T(1.0)], sides=16, ref=Z, cap0=True, cap1=True, n=2.8)
    # ---- steel: nose cap, barrel muzzle section, receiver, bands, mag box, guard
    r.mat = "blued"
    limb(r, [V(0.598, 0.019), V(0.640, 0.0215)], [(0.0170, 0.0240), (0.0150, 0.0215)], [T(0.9), T(1.0)], sides=14, ref=Z, cap0=True, cap1=True, n=2.8)  # nose cap
    bp = [(0.636, 0.0108), (0.700, 0.0098), (0.735, 0.0096), (0.748, 0.0105)]
    limb(r, [V(y, BZ) for (y, _) in bp], [rad for (_, rad) in bp], [T(1.0)] * 4, sides=14, ref=Z, cap0=False, cap1=True)
    rc = [(-0.125, 0.0150, 0.020), (-0.108, 0.0182, 0.0245), (-0.040, 0.0186, 0.0255), (0.050, 0.0186, 0.0255), (0.105, 0.0182, 0.0245),
          (0.120, 0.0160, 0.0210)]
    limb(r, [V(y, BZ + 0.006) for (y, _, _) in rc], [(a, b) for (_, a, b) in rc], [T(0.95)] * 6, sides=14, ref=Z, cap0=True, cap1=True, n=3.6)
    # rear sight ladder block on the barrel ahead of the receiver
    limb(r, [V(0.125, BZ + 0.006), V(0.215, BZ + 0.006)], [(0.0150, 0.0200), (0.0140, 0.0170)], [T(1.0)] * 2, sides=10, ref=Z, cap0=True, cap1=True, n=3.2)
    # ejection port + bolt slot decals
    r.mat = "rubber"
    xr = 0.0190
    r.smooth = False
    r.face([r.vert((xr, -0.060, BZ + 0.024), T(0.5)), r.vert((xr, 0.045, BZ + 0.024), T(0.5)), r.vert((xr, 0.045, BZ + 0.002), T(0.5)),
            r.vert((xr, -0.060, BZ + 0.002), T(0.5))])
    r.smooth = True
    # magazine box, trigger guard, trigger
    r.mat = "blued"
    limb(r, [V(-0.068, -0.026), V(-0.015, -0.028), V(0.048, -0.026)], [(0.0175, 0.0260)] * 3, [T(0.9)] * 3, sides=12, ref=Z, cap0=True, cap1=True, n=4.0)
    tg = [V(-0.086, -0.020), V(-0.082, -0.048), V(-0.052, -0.066), V(-0.004, -0.064), V(0.030, -0.050), V(0.044, -0.022)]
    limb(r, tg, [0.0046] * 6, [T(1.0)] * 6, sides=6, ref=X, cap0=True, cap1=True)
    limb(r, [V(-0.040, 0.006), V(-0.034, -0.020), V(-0.028, -0.042)], [0.0040, 0.0034, 0.0030], [T(1.0)] * 3, sides=5, ref=X, cap0=False, cap1=True)
    # barrel bands (black) + swivel
    r.mat = "rubber"
    for yb in (0.300, 0.455):
        limb(r, [V(yb, st_z) for st_z in [0.0]], [(0.0205, 0.0400)], [T(1.0)], sides=16, ref=Z, cap0=True, cap1=True, n=2.8) if False else None
    for yb, zc, hh in ((0.300, 0.010, 0.0335), (0.455, 0.016, 0.0295)):
        limb(r, [V(yb, zc), V(yb + 0.014, zc)], [(0.0198, hh + 0.001), (0.0198, hh + 0.001)], [T(0.9)] * 2, sides=16, ref=Z, cap0=True, cap1=True, n=2.8)
    r.mat = "steel"
    limb(r, [V(0.350, -0.022), V(0.350, -0.014)], [0.0038, 0.0032], [T(1.0)] * 2, sides=6, ref=X, cap0=True, cap1=True)
    # front sight ears + blade
    limb(r, [V(0.700, BZ + 0.0095), V(0.700, BZ + 0.0255)], [(0.0016, 0.0050), (0.0010, 0.0045)], [T(1.0)] * 2, sides=6, ref=Z, cap0=False, cap1=True, n=3.0)
    for sx in (-1, 1):
        limb(r, [V(0.690, BZ + 0.010, sx * 0.0075), V(0.690, BZ + 0.0225, sx * 0.0075)], [(0.0014, 0.0060), (0.0012, 0.0060)], [T(1.0)] * 2, sides=6, ref=Z, cap0=False, cap1=True, n=3.0)
    # rear sight leaf
    limb(r, [V(0.170, BZ + 0.0260), V(0.196, BZ + 0.0420)], [(0.0090, 0.0020), (0.0085, 0.0016)], [T(1.0)] * 2, sides=6, ref=X, cap0=True, cap1=True, n=3.0)
    r.tint_noise(0.12, 10.0, 2.0)
    return r.finish()


def build_bolt():
    o = Vector((0.0, -0.06, BZ + 0.006))
    b = Part("vm_bolt", origin=o)
    b.mat = "blued"
    limb(b, [o + Vector((0, -0.062, 0)), o + Vector((0, -0.078, 0)), o + Vector((0, -0.105, 0)), o + Vector((0, -0.120, 0))],
         [0.0072, 0.0078, 0.0072, 0.0055], [T(0.95), T(1.0), T(1.0), T(0.9)], sides=10, ref=Z, cap0=False, cap1=True)
    b.mat = "steel"
    limb(b, [o + Vector((0.012, 0.0, 0.0)), o + Vector((0.034, 0.0, -0.002)), o + Vector((0.054, -0.004, -0.018)), o + Vector((0.061, -0.014, -0.034))],
         [0.0052, 0.0046, 0.0042, 0.0040], [T(1.0)] * 4, sides=8, ref=Vector((0, 1, 0)), cap0=False, cap1=False)
    blob(b, o + Vector((0.063, -0.018, -0.042)), 0.0125, 0.0125, 0.0115, T(1.0), sides=10, nrings=5)
    b.tint_noise(0.1, 10.0, 6.0)
    return b.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    objs = [build_rifle(), build_bolt()]
    export_glb(objs, os.path.join(OUT, "vm_rifle.glb"))
    print("VMRIFLE tris", sum(tris(o) for o in objs), {o.name: tris(o) for o in objs})
