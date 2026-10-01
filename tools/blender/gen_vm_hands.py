"""
Run: blender.exe --background --factory-startup --python gen_vm_hands.py -- <out_dir>
vm_hands.glb v2: first-person leather gloves with ribbed wool cuffs + quilted parka sleeves. Textured (UV), budget <= 3200 tris.
Hand = fist whose grip axis is local Z (handle passes through origin). Palm on -Y (toward camera), fingers wrap round via -X
(right hand), thumb over +X side. Wrist at (sx*0.075,-0.05,-0.005). Sleeve parts have their origin at the wrist and extend along
d = (sx*0.25,-1,-0.12) (Blender) = Godot (sx*.25,-.12,+1).
Parts: vm_hand_r, vm_hand_l, vm_sleeve_r, vm_sleeve_l.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

Z = Vector((0, 0, 1))


def P(sx, x, y, z):
    return Vector((sx * x, y, z))


def T(k):
    return (k, k, k)


def build_hand(sx, name):
    h = Part(name)
    W = Vector((sx * 0.075, -0.05, -0.005))
    d = Vector((sx * 0.25, -1, -0.12)).normalized()
    h.mat = "leather"
    # back of hand / palm slab, wrist -> knuckle line
    pp = [P(sx, 0.080, -0.052, 0.0), P(sx, 0.058, -0.045, 0.0), P(sx, 0.034, -0.038, 0.0), P(sx, 0.010, -0.032, 0.0)]
    pr = [(0.020, 0.031), (0.0225, 0.037), (0.0235, 0.041), (0.0205, 0.0425)]
    limb(h, pp, pr, [T(0.8), T(0.92), T(1.0), T(1.0)], sides=12, ref=Z, cap0=True, cap1=False, n=2.6)
    # four fingers, three phalanges each, wrapping ~165deg round the handle
    R0 = 0.0285
    FZ = [0.0295, 0.0100, -0.0100, -0.0295]
    FL = [163, 175, 165, 140]
    FS = [1.0, 1.04, 0.98, 0.82]
    prof = [0.0100, 0.0098, 0.0108, 0.0096, 0.0101, 0.0092, 0.0088, 0.0072]
    for z0, L, s in zip(FZ, FL, FS):
        pts, rad, cols = [], [], []
        for i in range(8):
            t = i / 7.0
            th = math.radians(-72 - L * t)
            R = R0 * (1 - 0.16 * t)
            pts.append(P(sx, R * math.cos(th), R * math.sin(th), z0 * (1 - 0.06 * t)))
            rad.append(prof[i] * s)
            cols.append(T(0.98 - 0.16 * t))
        limb(h, pts, rad, cols, sides=8, ref=Z, cap0=False, cap1=True)
    # knuckle bumps on the back of the hand
    for z0 in FZ:
        blob(h, P(sx, 0.011, -0.045, z0), 0.0105, 0.0085, 0.0108, T(1.0), sides=8, nrings=3)
    # thumb (two phalanges + thenar pad)
    th = [P(sx, 0.034, -0.036, 0.040), P(sx, 0.039, -0.016, 0.050), P(sx, 0.032, 0.010, 0.055), P(sx, 0.018, 0.030, 0.054), P(sx, 0.005, 0.040, 0.050)]
    limb(h, th, [0.0150, 0.0138, 0.0126, 0.0112, 0.0094], [T(0.95), T(1.0), T(0.95), T(0.9), T(0.82)], sides=8, ref=Z, cap0=False, cap1=True)
    blob(h, P(sx, 0.036, -0.034, 0.036), 0.020, 0.015, 0.024, T(0.95), sides=8, nrings=4)
    # ribbed wool cuff pulled over the sleeve end
    h.mat = "wool"
    ts = [-0.012, 0.012, 0.030, 0.048, 0.066, 0.086]
    cr = [0.0345, 0.0380, 0.0360, 0.0392, 0.0368, 0.0402]
    ct = [0.7, 0.9, 0.78, 0.95, 0.84, 0.9]
    limb(h, [W + d * t for t in ts], cr, [T(c) for c in ct], sides=14, ref=Z, cap0=False, cap1=False)
    h.tint_noise(0.10, 18.0, 3.0 + sx)
    return h.finish()


def build_sleeve(sx, name):
    W = Vector((sx * 0.075, -0.05, -0.005))
    s = Part(name, origin=W)
    d = Vector((sx * 0.25, -1, -0.12)).normalized()
    s.mat = "fabric"
    ts = [0.07, 0.09, 0.12, 0.15, 0.19, 0.24, 0.30, 0.37, 0.45, 0.54, 0.64, 0.75, 0.85]
    mod = [1.0, 1.16, 1.10, 1.0, 1.12, 0.96, 1.10, 0.96, 1.08, 0.96, 1.07, 0.97, 1.04]
    pts, rad, cols = [], [], []
    for t, m in zip(ts, mod):
        base = 0.036 + 0.026 * (t - 0.07) / 0.78
        pts.append(W + d * t)
        rad.append(base * m)
        cols.append(T(0.72 + 0.28 * (m - 0.95) / 0.21))
    limb(s, pts, rad, cols, sides=12, ref=Z, cap0=False, cap1=True, n=2.2)
    s.tint_noise(0.12, 9.0, 5.0 + sx)
    return s.finish()


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    objs = []
    for nm, sx in (("r", 1), ("l", -1)):
        objs.append(build_hand(sx, "vm_hand_" + nm))
        objs.append(build_sleeve(sx, "vm_sleeve_" + nm))
    export_glb(objs, os.path.join(OUT, "vm_hands.glb"))
    print("VMHANDS tris", sum(tris(o) for o in objs), {o.name: tris(o) for o in objs})
