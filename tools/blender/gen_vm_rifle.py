"""
Run: blender.exe --background --factory-startup --python gen_vm_rifle.py -- <out_dir>
vm_rifle.glb v2: bolt-action hunting rifle (Winchester/Mauser pattern, iron sights), ~1.08 m. Origin = wrist of the stock.
Muzzle toward +Y (Godot -Z). Walnut stock with comb, curved pistol grip, rubber pad; blued receiver/barrel, magazine floorplate,
guard, trigger, iron sights, swivel. Parts: vm_rifle, vm_bolt (origin on bolt axis at (0,-0.06,BZ), slides along Y).
Budget <= 3000 tris.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

Z = Vector((0, 0, 1))
X = Vector((1, 0, 0))
BZ = 0.034  # bore axis height


def T(k):
    return (k, k, k)


def V(y, z, x=0.0):
    return Vector((x, y, z))


def build_rifle():
    r = Part("vm_rifle")
    # ---- stock (walnut): butt -> wrist -> forend tip. station = (y, zc, half width, half height)
    r.mat = "walnut"
    st = [(-0.402, -0.040, 0.0150, 0.059), (-0.380, -0.039, 0.0165, 0.057), (-0.320, -0.034, 0.0170, 0.050), (-0.260, -0.026, 0.0170, 0.043),
          (-0.200, -0.016, 0.0165, 0.037), (-0.150, -0.010, 0.0160, 0.034), (-0.100, -0.006, 0.0155, 0.031), (-0.050, -0.006, 0.0150, 0.030),
          (0.000, -0.004, 0.0155, 0.031), (0.060, 0.002, 0.0160, 0.030), (0.120, 0.006, 0.0160, 0.026), (0.200, 0.010, 0.0158, 0.0235),
          (0.300, 0.013, 0.0155, 0.021), (0.380, 0.015, 0.0150, 0.0195), (0.440, 0.016, 0.0145, 0.0185), (0.448, 0.016, 0.0125, 0.0160)]
    shade = [0.8, 0.9, 0.95, 1.0, 1.0, 1.0, 0.95, 0.9, 0.95, 1.0, 1.0, 1.0, 1.0, 0.95, 0.85, 0.7]
    limb(r, [V(y, z) for (y, z, _, _) in st], [(w, h) for (_, _, w, h) in st], [T(s) for s in shade], sides=14, ref=Z,
         cap0=False, cap1=True, n=2.8)
    # pistol grip dropping from the wrist
    gp = [V(0.006, -0.012), V(-0.006, -0.040), V(-0.022, -0.072), V(-0.038, -0.094)]
    limb(r, gp, [(0.0155, 0.020), (0.0152, 0.019), (0.0150, 0.0175), (0.0148, 0.016)], [T(0.95), T(1.0), T(1.0), T(0.85)],
         sides=12, ref=X, cap0=False, cap1=True, n=2.6)
    r.mat = "rubber"
    limb(r, [V(-0.404, -0.040), V(-0.4125, -0.040)], [(0.0166, 0.0600), (0.0166, 0.0600)], [T(0.9), T(1.0)], sides=14, ref=Z, cap0=True, cap1=True, n=2.8)
    limb(r, [V(-0.0425, -0.0955), V(-0.0475, -0.1010)], [(0.0150, 0.0165), (0.0145, 0.0160)], [T(1.0), T(1.0)], sides=12, ref=X, cap0=True, cap1=True, n=2.6)
    # ---- receiver + barrel (blued)
    r.mat = "blued"
    rc = [(-0.115, 0.0124, 0.0136), (-0.100, 0.0137, 0.0151), (-0.030, 0.0140, 0.0153), (0.040, 0.0140, 0.0153), (0.090, 0.0134, 0.0144),
          (0.108, 0.0155, 0.0166), (0.122, 0.0135, 0.0144)]
    limb(r, [V(y, BZ) for (y, _, _) in rc], [(a, b) for (_, a, b) in rc], [T(0.95)] * 7, sides=14, ref=Z, cap0=True, cap1=False, n=2.4)
    bp = [(0.118, 0.0120), (0.200, 0.0113), (0.300, 0.0105), (0.450, 0.0098), (0.600, 0.0091), (0.655, 0.0090), (0.667, 0.0096)]
    limb(r, [V(y, BZ) for (y, _) in bp], [rad for (_, rad) in bp], [T(1.0)] * 7, sides=14, ref=Z, cap0=False, cap1=True)
    # ejection port + bolt-handle slot decals (flat dark quads just proud of the right wall)
    r.mat = "rubber"
    xr = 0.0143
    r.smooth = False
    r.face([r.vert((xr, -0.050, BZ + 0.011), T(0.5)), r.vert((xr, 0.040, BZ + 0.011), T(0.5)), r.vert((xr, 0.040, BZ - 0.007), T(0.5)),
            r.vert((xr, -0.050, BZ - 0.007), T(0.5))])
    r.face([r.vert((xr, -0.090, BZ + 0.004), T(0.5)), r.vert((xr, -0.060, BZ + 0.004), T(0.5)), r.vert((xr, -0.060, BZ - 0.003), T(0.5)),
            r.vert((xr, -0.090, BZ - 0.003), T(0.5))])
    r.smooth = True
    # trigger guard loop + floorplate / magazine box + trigger (blued)
    r.mat = "blued"
    tg = [V(-0.078, -0.004), V(-0.074, -0.030), V(-0.046, -0.046), V(-0.004, -0.044), V(0.026, -0.030), V(0.036, -0.004)]
    limb(r, tg, [0.0042] * 6, [T(1.0)] * 6, sides=6, ref=X, cap0=True, cap1=True)
    limb(r, [V(-0.062, -0.014), V(-0.020, -0.016), V(0.030, -0.015)], [(0.0135, 0.0105)] * 3, [T(0.9)] * 3, sides=10, ref=Z, cap0=True, cap1=True, n=4.0)
    limb(r, [V(-0.034, 0.018), V(-0.029, -0.002), V(-0.024, -0.016)], [0.0036, 0.0030, 0.0026], [T(1.0)] * 3, sides=5, ref=X, cap0=False, cap1=True)
    # ---- iron sights + barrel band + swivel (steel)
    r.mat = "steel"
    limb(r, [V(0.372, BZ), V(0.388, BZ)], [0.0125, 0.0125], [T(1.0)] * 2, sides=14, ref=Z, cap0=True, cap1=True)
    limb(r, [V(0.350, 0.004), V(0.350, 0.012)], [0.0035, 0.0030], [T(1.0)] * 2, sides=6, ref=X, cap0=True, cap1=True)   # swivel stud
    blob(r, (0, 0.618, BZ + 0.0105), 0.0050, 0.0170, 0.0042, T(1.0), sides=8, nrings=3)                                 # front ramp
    limb(r, [V(0.628, BZ + 0.011), V(0.628, BZ + 0.0235)], [(0.0016, 0.0032), (0.0010, 0.0026)], [T(1.0)] * 2, sides=6, ref=Z, cap0=False, cap1=True, n=3.0)  # blade
    limb(r, [V(0.150, BZ + 0.0095), V(0.185, BZ + 0.0095)], [(0.0075, 0.0045), (0.0075, 0.0045)], [T(1.0)] * 2, sides=8, ref=Z, cap0=True, cap1=True, n=3.5)  # base
    limb(r, [V(0.158, BZ + 0.013), V(0.176, BZ + 0.026)], [(0.0060, 0.0016), (0.0058, 0.0014)], [T(1.0)] * 2, sides=6, ref=X, cap0=True, cap1=True, n=3.0)   # leaf
    r.tint_noise(0.12, 10.0, 2.0)
    return r.finish()


def build_bolt():
    o = Vector((0.0, -0.06, BZ))
    b = Part("vm_bolt", origin=o)
    b.mat = "blued"
    # cocking piece / shroud sticking out of the rear of the receiver
    limb(b, [o + Vector((0, -0.060, 0)), o + Vector((0, -0.075, 0)), o + Vector((0, -0.100, 0)), o + Vector((0, -0.112, 0))],
         [0.0062, 0.0068, 0.0062, 0.0048], [T(0.95), T(1.0), T(1.0), T(0.9)], sides=10, ref=Z, cap0=False, cap1=True)
    # bolt handle: stem + oval knob
    limb(b, [o + Vector((0.010, 0.0, 0.0)), o + Vector((0.028, 0.0, -0.004)), o + Vector((0.046, 0.0, -0.020))],
         [0.0048, 0.0042, 0.0038], [T(1.0)] * 3, sides=8, ref=Vector((0, 1, 0)), cap0=False, cap1=False)
    b.mat = "steel"
    blob(b, o + Vector((0.056, 0.0, -0.028)), 0.0108, 0.0108, 0.0098, T(1.0), sides=10, nrings=5)
    b.tint_noise(0.1, 10.0, 6.0)
    return b.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    objs = [build_rifle(), build_bolt()]
    export_glb(objs, os.path.join(OUT, "vm_rifle.glb"))
    print("VMRIFLE tris", sum(tris(o) for o in objs), {o.name: tris(o) for o in objs})
