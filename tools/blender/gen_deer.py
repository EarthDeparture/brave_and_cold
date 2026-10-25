"""
Run: blender.exe --background --factory-startup --python gen_deer.py -- <out_dir>
Outputs deer.glb: white-tailed deer (stag) v2 (X1), ~1.45 m nose to tail, ~1.0 m at the withers, faces Blender +Y.
Same parts / pivots as v1 so deer.gd and the hit zones are unchanged:
  deer_body (torso, neck, head, ears, antlers), deer_tail (origin at its root), deer_leg_fl/fr/bl/br (origin at the
  hip / shoulder joint, z = 0.80).
Lofted through anatomical sections (gen_wolf.M): slim barrel, sloping back, long upright neck, narrow wedge head,
big oval ears; legs bend at the knee (front) and hock (hind) on thin cannon bones down to dark hooves; antlers are
lofted beams with three tines a side. Winter coat colours: grey-brown, darker along the back, white throat patch,
belly, eye ring and muzzle band, dark nose, tail brown above / white below.
"""
import sys
import os
import math
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_wolf as gw  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
mix = gw.mix

COAT = (0.34, 0.28, 0.22)
BACK = (0.22, 0.18, 0.14)
TAN = (0.44, 0.37, 0.29)
WHITE = (0.80, 0.78, 0.74)
NOSE = (0.03, 0.03, 0.03)
HOOF = (0.05, 0.045, 0.04)
ANTLER = (0.52, 0.45, 0.36)
EYE = (0.03, 0.025, 0.02)

BODY = [
    ((0, -0.56, 1.04), 0.04, 0.05, 0.0),
    ((0, -0.51, 1.04), 0.12, 0.15, 0.2),
    ((0, -0.38, 1.02), 0.165, 0.19, 0.3),    # haunch
    ((0, -0.20, 1.00), 0.155, 0.18, 0.3),
    ((0, -0.02, 0.99), 0.165, 0.205, 0.3),   # barrel
    ((0, 0.15, 0.99), 0.17, 0.22, 0.3),      # chest
    ((0, 0.29, 1.04), 0.15, 0.20, 0.3),      # withers
    ((0, 0.40, 1.16), 0.105, 0.13, 0.4),     # neck base
    ((0, 0.48, 1.30), 0.08, 0.095, 0.4),
    ((0, 0.55, 1.41), 0.07, 0.08, 0.3),
    ((0, 0.61, 1.47), 0.07, 0.072, 0.1),     # poll
    ((0, 0.68, 1.47), 0.066, 0.062, 0.0),    # head
    ((0, 0.76, 1.44), 0.048, 0.05, 0.0),
    ((0, 0.83, 1.41), 0.034, 0.04, 0.0),     # muzzle
    ((0, 0.87, 1.40), 0.018, 0.024, 0.0),    # nose
]


def body_col(u, k, s):
    cs, sn = s
    y = -0.56 + u * 1.43
    if y > 0.79:   # muzzle: white band, dark nose
        return mix(WHITE, NOSE, (y - 0.82) / 0.04)
    if y > 0.6:    # head: grey-brown, white eye ring area and chin
        return mix(WHITE, mix(TAN, BACK, max(0.0, sn - 0.5)), (sn + 0.6) / 0.6)
    if y > 0.36:   # neck: darker mane line, white throat patch high on the neck
        throat = WHITE if (y > 0.5 and sn < -0.3) else TAN
        return mix(throat, mix(COAT, BACK, (sn - 0.4) / 0.5), (sn + 0.7) / 0.9)
    top = mix(COAT, BACK, (sn - 0.3) / 0.5)
    return mix(WHITE, top, (sn + 0.85) / 0.3)   # white only on the belly strip


def antler(m, sx):
    """Main beam up from the pedicle, sweeping back then forward, with three tines rising from it."""
    beam = [((sx * 0.05, 0.60, 1.52), 0.016, 0.016, 0.0), ((sx * 0.11, 0.57, 1.62), 0.015, 0.015, 0.0),
            ((sx * 0.17, 0.58, 1.72), 0.013, 0.013, 0.0), ((sx * 0.18, 0.66, 1.80), 0.011, 0.011, 0.0),
            ((sx * 0.14, 0.76, 1.84), 0.008, 0.008, 0.0), ((sx * 0.10, 0.82, 1.83), 0.003, 0.003, 0.0)]
    m.loft(gw.catmull([(Vector(p), w, h, sk) for p, w, h, sk in beam], 2), 6, lambda u, k, s: ANTLER)
    for base, tip in (((sx * 0.13, 0.575, 1.65), (sx * 0.14, 0.62, 1.78)),
                      ((sx * 0.175, 0.62, 1.76), (sx * 0.18, 0.66, 1.92)),
                      ((sx * 0.16, 0.72, 1.82), (sx * 0.15, 0.76, 1.94))):
        b, t = Vector(base), Vector(tip)
        m.loft([(b, 0.01, 0.01, 0.0), ((b + t) * 0.5, 0.007, 0.007, 0.0), (t, 0.002, 0.002, 0.0)], 5, lambda u, k, s: ANTLER)


def build():
    objs = []
    b = gw.M()
    b.loft(gw.catmull(BODY, 3), 16, body_col, shag=0.03)
    for sx in (-1, 1):
        # big oval ears, set wide and angled out: a fan of triangles, dark rim outside, pale inside
        base = Vector((sx * 0.055, 0.60, 1.51))
        out = Vector((sx * 0.6, -0.25, 0.75)).normalized()
        side = Vector((0, 1, 0)).cross(out).normalized() * (1 if sx > 0 else -1)
        pts = [base + out * (0.14 * math.sin(math.pi * t)) * 0 + out * 0.15 * t + side * 0.05 * math.sin(math.pi * t) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        pts2 = [base + out * 0.15 * t - side * 0.035 * math.sin(math.pi * t) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        for i in range(4):
            b.tri([tuple(pts[i]), tuple(pts[i + 1]), tuple(pts2[i + 1])], COAT)
            b.tri([tuple(pts[i]), tuple(pts2[i + 1]), tuple(pts2[i])], COAT)
            b.tri([tuple(pts2[i + 1]), tuple(pts[i + 1]), tuple(pts[i])], WHITE)
            b.tri([tuple(pts2[i]), tuple(pts2[i + 1]), tuple(pts[i])], WHITE)
        e = (sx * 0.062, 0.71, 1.485)
        b.tri([(e[0], e[1] - 0.014, e[2] - 0.004), (e[0] + sx * 0.004, e[1] + 0.012, e[2]), (e[0], e[1], e[2] + 0.01)], EYE)
        antler(b, sx)
    objs.append(b.finish("deer_body"))

    t = gw.M(origin=(0, -0.54, 1.08))
    t.loft(gw.catmull([((0, -0.53, 1.08), 0.03, 0.03, 0.0), ((0, -0.58, 1.06), 0.055, 0.045, 0.5),
                       ((0, -0.63, 1.0), 0.06, 0.04, 0.6), ((0, -0.66, 0.93), 0.035, 0.025, 0.3),
                       ((0, -0.67, 0.89), 0.005, 0.005, 0.0)], 2),
           8, lambda u, k, s: COAT if s[1] > 0.1 else WHITE, shag=0.1)
    objs.append(t.finish("deer_tail"))

    def leg_col(u, k, s):
        if u > 0.9:
            return HOOF
        c = mix(mix(COAT, TAN, 0.3), TAN, (u - 0.2) * 2.0)
        return mix(c, WHITE, max(0.0, -s[1]) * 0.35 * max(0.0, 1.0 - abs(u - 0.35) * 4.0))   # pale inner thigh / forearm
    for name, x, y in (("fl", -0.105, 0.30), ("fr", 0.105, 0.30), ("bl", -0.10, -0.36), ("br", 0.10, -0.36)):
        hip = Vector((x, y, 0.80))
        if name[0] == "f":
            path = [((0, 0.0, 0.19), 0.045, 0.10, 0.0), ((0, 0.0, 0.08), 0.055, 0.11, 0.2), ((0, -0.02, -0.06), 0.055, 0.075, 0.2),
                    ((0, -0.01, -0.22), 0.035, 0.045, 0.0), ((0, 0.0, -0.40), 0.026, 0.03, 0.0), ((0, 0.005, -0.44), 0.028, 0.032, 0.0),
                    ((0, 0.01, -0.70), 0.018, 0.022, 0.0), ((0, 0.02, -0.74), 0.022, 0.026, 0.0), ((0, 0.035, -0.785), 0.024, 0.03, 0.0),
                    ((0, 0.06, -0.8), 0.016, 0.01, 0.0)]
        else:
            path = [((0, 0.0, 0.19), 0.05, 0.12, 0.0), ((0, 0.0, 0.08), 0.06, 0.14, 0.2), ((0, 0.06, -0.08), 0.075, 0.1, 0.2),
                    ((0, 0.03, -0.2), 0.045, 0.06, 0.0), ((0, -0.08, -0.36), 0.026, 0.034, 0.0), ((0, -0.085, -0.4), 0.025, 0.03, 0.0),
                    ((0, -0.04, -0.70), 0.018, 0.022, 0.0), ((0, -0.02, -0.74), 0.022, 0.026, 0.0), ((0, 0.0, -0.785), 0.024, 0.03, 0.0),
                    ((0, 0.025, -0.8), 0.016, 0.01, 0.0)]
        objs.extend(gw.leg_parts("deer_leg_" + name, hip, path, 4, leg_col, 10, 0.03))
    return objs


if __name__ == "__main__":
    gw.clear()
    objs = build()
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    gw.export(objs, f"{OUT}/deer.glb")
    print("DEER tris", tris)
