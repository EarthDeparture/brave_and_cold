"""
Run: blender.exe --background --factory-startup --python gen_vm_hands.py -- <out_dir>
vm_hands.glb v3 (TLD-style): BARE pale hands (slim fingers, knuckles, nails), thin wrist, loose ribbed wool cuff, big parka sleeve.
Hand = fist whose grip axis is local Z (handle passes through origin). Palm on -Y (toward camera), fingers wrap round via -X
(right hand), thumb over +X side. Wrist at (sx*0.075,-0.05,-0.005). Sleeve parts: origin at the wrist, extend along
d = (sx*0.25,-1,-0.12) (Blender) = Godot (sx*.25,-.12,+1).
Parts: vm_hand_r, vm_hand_l, vm_sleeve_r, vm_sleeve_l. Budget <= 4000 tris.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vmlib import *

Z = Vector((0, 0, 1))


_ROT = [0.0]  # degrees; hand geometry rotated about the wrist (about Z) so the palm lines up with the forearm (relaxed fists)


def _rz(v, a):
    c, s = math.cos(a), math.sin(a)
    return Vector((v.x * c - v.y * s, v.x * s + v.y * c, v.z))


def P(sx, x, y, z):
    v = Vector((sx * x, y, z))
    if _ROT[0] != 0.0:
        W0 = Vector((sx * 0.075, -0.05, 0.0))
        a = math.radians(-_ROT[0] * sx)
        r = _rz(v - W0, a)
        v = Vector((W0.x + r.x, W0.y + r.y, v.z))
    return v


def RV(sx, x, y, z):
    v = Vector((sx * x, y, z))
    if _ROT[0] != 0.0:
        v = _rz(v, math.radians(-_ROT[0] * sx))
    return v


def T(k):
    return (k, k, k)


def build_hand(sx, name, rot=0.0):
    _ROT[0] = rot
    h = Part(name)
    W = Vector((sx * 0.075, -0.05, -0.005))
    d = Vector((sx * 0.25, -1, -0.12)).normalized()
    h.mat = "skin"
    # back of hand / palm slab, wrist -> knuckle line (slim, flat)
    pp = [P(sx, 0.080, -0.052, 0.0), P(sx, 0.058, -0.045, 0.0), P(sx, 0.034, -0.038, 0.0), P(sx, 0.010, -0.032, 0.0)]
    pr = [(0.0155, 0.026), (0.0175, 0.031), (0.0185, 0.0345), (0.0165, 0.0355)]
    limb(h, pp, pr, [T(0.85), T(0.95), T(1.0), T(1.0)], sides=12, ref=Z, cap0=True, cap1=False, n=2.5)
    # slim wrist running out of the cuff
    limb(h, [W - d * 0.012, W + d * 0.02, W + d * 0.05, W + d * 0.075], [(0.0185, 0.0255), (0.0185, 0.0250), (0.0190, 0.0250), (0.0195, 0.0255)],
         [T(0.88), T(0.95), T(0.95), T(0.9)], sides=12, ref=Z, cap0=False, cap1=False)
    # four slim fingers, three phalanges each, wrapping ~165deg round the handle
    R0 = 0.0262
    FZ = [0.0250, 0.0085, -0.0085, -0.0250]
    FL = [165, 178, 168, 145]
    FS = [1.08, 1.12, 1.06, 0.92]
    # proximal fat -> tip; swell at each joint (idx 1,4 knuckle, 3 PIP, 5 DIP) with dark crease rings between
    prof = [0.0098, 0.0096, 0.0104, 0.0088, 0.0092, 0.0080, 0.0076, 0.0064]
    crease = {2: 0.74, 4: 0.72, 6: 0.78}
    nails = []
    for z0, L, s in zip(FZ, FL, FS):
        pts, rad, cols = [], [], []
        for i in range(8):
            t = i / 7.0
            th = math.radians(-72 - L * t)
            R = R0 * (1 - 0.16 * t)
            pts.append(P(sx, R * math.cos(th), R * math.sin(th), z0 * (1 - 0.06 * t)))
            rad.append(prof[i] * s * (0.90 if i in crease else 1.0))
            k = crease.get(i, 1.0) * (0.98 - 0.08 * t)
            warm = 1.0 if i not in (1, 3, 5) else 0.96  # cold-reddened knuckles
            cols.append((k, k * warm * 0.98 if warm < 1 else k, k * (0.93 if warm < 1 else 1.0)))
        limb(h, pts, rad, cols, sides=8, ref=Z, cap0=False, cap1=True)
        # nail on the back (outer) side near the tip
        tipc = pts[6] * 0.35 + pts[7] * 0.65
        ctr = P(sx, 0.0, 0.0, 0.0)
        rad_dir = Vector((tipc.x - ctr.x, tipc.y - ctr.y, 0.0)).normalized()
        nails.append((tipc + rad_dir * 0.0058 * s + Vector((0, 0, 0)), s, rad_dir))
    # knuckle bumps on the back of the hand + extensor tendons running to the wrist
    for z0 in FZ:
        blob(h, P(sx, 0.011, -0.045, z0), 0.0098, 0.0080, 0.0105, (1.0, 0.94, 0.92), sides=8, nrings=3)
        limb(h, [P(sx, 0.014, -0.047, z0 * 0.9), P(sx, 0.040, -0.052, z0 * 0.7), P(sx, 0.070, -0.060, z0 * 0.55)],
             [0.0042, 0.0046, 0.0040], [T(1.0), T(0.97), T(0.93)], sides=6, ref=Z, cap0=False, cap1=True)
    # thumb (two phalanges + thenar pad)
    th = [P(sx, 0.032, -0.034, 0.036), P(sx, 0.037, -0.016, 0.045), P(sx, 0.031, 0.009, 0.049), P(sx, 0.018, 0.028, 0.048), P(sx, 0.006, 0.037, 0.045)]
    limb(h, th, [0.0125, 0.0112, 0.0102, 0.0092, 0.0078], [T(0.95), T(1.0), T(0.95), T(0.92), T(0.88)], sides=8, ref=Z, cap0=False, cap1=True)
    blob(h, P(sx, 0.040, -0.034, 0.030), 0.021, 0.016, 0.026, T(0.95), sides=8, nrings=4)
    # thumb joint crease
    blob(h, P(sx, 0.031, 0.009, 0.0495), 0.0120, 0.0115, 0.0070, (0.80, 0.74, 0.72), sides=8, nrings=3)
    # nails
    h.mat = "nail"
    for c, s, rd in nails:
        blob(h, c, 0.0036 * s, 0.0036 * s, 0.0052 * s, T(1.0), sides=6, nrings=3)
    blob(h, P(sx, 0.006, 0.0372, 0.0485) + RV(sx, 0, 0.0055, 0) * 1.0, 0.0048, 0.0030, 0.0058, T(1.0), sides=6, nrings=3)
    # loose ribbed wool cuff
    h.mat = "wool"
    ts = [0.040, 0.058, 0.076, 0.094, 0.112, 0.130]
    cr = [0.0405, 0.0445, 0.0420, 0.0460, 0.0430, 0.0475]
    ct = [0.7, 0.9, 0.78, 0.95, 0.84, 0.9]
    limb(h, [W + d * t for t in ts], cr, [T(c) for c in ct], sides=14, ref=Z, cap0=False, cap1=False)
    h.tint_noise(0.08, 18.0, 3.0 + sx)
    return h.finish()


def build_sleeve(sx, name):
    W = Vector((sx * 0.075, -0.05, -0.005))
    s = Part(name, origin=W)
    d = Vector((sx * 0.25, -1, -0.12)).normalized()
    s.mat = "fabric"
    ts = [0.11, 0.13, 0.16, 0.20, 0.25, 0.31, 0.38, 0.46, 0.55, 0.65, 0.75, 0.85]
    mod = [1.0, 1.12, 1.06, 1.14, 1.0, 1.10, 0.98, 1.08, 0.97, 1.06, 0.98, 1.04]
    pts, rad, cols = [], [], []
    for t, m in zip(ts, mod):
        base = 0.040 + 0.034 * (t - 0.11) / 0.74
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
        objs.append(build_hand(sx, "vm_fist_" + nm, 60.0))
    export_glb(objs, os.path.join(OUT, "vm_hands.glb"))
    print("VMHANDS tris", sum(tris(o) for o in objs), {o.name: tris(o) for o in objs})
