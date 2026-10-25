"""
Run: blender.exe --background --factory-startup --python gen_bear.py -- <out_dir>
Outputs bear.glb: brown (grizzly) bear v2 (X1), ~2.4 m nose to rump, 1.0 m at the hip, shoulder hump ~1.5 m.
Faces Blender +Y. Same parts / pivots as v1: bear_body, bear_tail, bear_leg_fl/fr/bl/br (origin at hip, z = 0.80).
Lofted through anatomical sections (gen_wolf.M): massive rounded rump lower than the shoulder hump, deep chest,
thick neck, broad dished head, short muzzle, small round ears; pillar legs on wide paws with pale claws, front paws
turned in a little. Shaggy silhouette (strong jitter). Colours: dark brown legs and belly, mid brown body, grizzled
light tips on the hump and shoulders, tan muzzle, black nose.
"""
import sys
import os
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_wolf as gw  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
mix = gw.mix

BROWN = (0.19, 0.12, 0.075)
DARK = (0.075, 0.05, 0.035)
GRIZZLE = (0.36, 0.26, 0.17)
MUZZLE = (0.33, 0.24, 0.16)
NOSE = (0.02, 0.018, 0.018)
CLAW = (0.70, 0.65, 0.55)
EYE = (0.02, 0.015, 0.01)

BODY = [
    ((0, -0.98, 0.96), 0.10, 0.10, 0.0),
    ((0, -0.92, 0.97), 0.30, 0.32, 0.6),
    ((0, -0.72, 0.98), 0.42, 0.44, 0.8),    # rump
    ((0, -0.40, 0.98), 0.43, 0.45, 0.8),
    ((0, -0.08, 0.99), 0.44, 0.47, 0.8),
    ((0, 0.22, 1.04), 0.45, 0.48, 0.9),     # chest
    ((0, 0.45, 1.13), 0.40, 0.41, 1.2),     # shoulder hump
    ((0, 0.68, 1.12), 0.31, 0.31, 1.3),     # neck ruff
    ((0, 0.88, 1.13), 0.27, 0.25, 0.9),     # back of the broad head
    ((0, 1.03, 1.11), 0.23, 0.21, 0.4),
    ((0, 1.16, 1.07), 0.15, 0.13, 0.1),     # dished stop
    ((0, 1.30, 1.04), 0.10, 0.09, 0.0),     # muzzle
    ((0, 1.42, 1.03), 0.065, 0.06, 0.0),
    ((0, 1.47, 1.03), 0.03, 0.03, 0.0),     # nose
]


def body_col(u, k, s):
    cs, sn = s
    y = -0.98 + u * 2.45
    if y > 1.2:
        return mix(MUZZLE, NOSE, (y - 1.4) / 0.05)
    c = mix(DARK, BROWN, (sn + 0.7) / 0.8)
    if 0.25 < y < 0.8:   # grizzled hump and shoulders
        c = mix(c, GRIZZLE, max(0.0, sn) * 0.75)
    elif y > 0.8:        # head: lighter brow
        c = mix(c, GRIZZLE, max(0.0, sn) * 0.4)
    return c


def build():
    objs = []
    b = gw.M()
    b.loft(gw.catmull(BODY, 3), 18, body_col, shag=0.07)
    for sx in (-1, 1):
        # small round ears: a short closed loft
        ear = Vector((sx * 0.17, 0.92, 1.33))
        b.loft([(ear + Vector((0, 0.01, -0.04)), 0.05, 0.035, 0.0), (ear, 0.06, 0.035, 0.0), (ear + Vector((0, -0.005, 0.05)), 0.03, 0.02, 0.0)],
               8, lambda u, k, s: DARK)
        e = (sx * 0.10, 1.2, 1.15)
        b.tri([(e[0], e[1] - 0.02, e[2] - 0.006), (e[0] + sx * 0.006, e[1] + 0.016, e[2]), (e[0], e[1], e[2] + 0.014)], EYE)
    objs.append(b.finish("bear_body"))

    t = gw.M(origin=(0, -0.92, 1.0))
    t.loft([((0, -0.95, 1.0), 0.06, 0.06, 0.0), ((0, -1.03, 0.97), 0.06, 0.05, 0.6), ((0, -1.07, 0.93), 0.01, 0.01, 0.0)],
           8, lambda u, k, s: DARK, shag=0.1)
    objs.append(t.finish("bear_tail"))

    def leg_col(u, k, s):
        return mix(BROWN, DARK, u * 1.4)
    for name, x, y in (("fl", -0.26, 0.45), ("fr", 0.26, 0.45), ("bl", -0.26, -0.55), ("br", 0.26, -0.55)):
        hip = Vector((x, y, 0.80))
        if name[0] == "f":
            path = [((0, 0.0, 0.30), 0.12, 0.18, 0.0), ((0, 0.0, 0.08), 0.15, 0.21, 0.6), ((0, -0.03, -0.22), 0.14, 0.16, 0.6),
                    ((0, 0.0, -0.55), 0.11, 0.12, 0.4), ((0, 0.04, -0.70), 0.12, 0.12, 0.3), ((0, 0.10, -0.77), 0.13, 0.08, 0.0),
                    ((0, 0.20, -0.795), 0.11, 0.03, 0.0)]
        else:
            path = [((0, 0.0, 0.30), 0.13, 0.22, 0.0), ((0, 0.0, 0.05), 0.16, 0.25, 0.6), ((0, 0.05, -0.18), 0.16, 0.2, 0.6),
                    ((0, -0.08, -0.50), 0.11, 0.12, 0.3), ((0, -0.04, -0.70), 0.12, 0.11, 0.2), ((0, 0.06, -0.78), 0.12, 0.07, 0.0),
                    ((0, 0.20, -0.795), 0.11, 0.03, 0.0)]
        parts = gw.leg_parts("bear_leg_" + name, hip, path, 2, leg_col, 12, 0.06)
        objs.extend(parts)
        claws = gw.M(origin=tuple(hip + Vector(path[2][0])))   # claws ride on the lower leg (paw)
        for cx in (-0.06, -0.03, 0.0, 0.03, 0.06):   # pale hooks off the front of the paw
            c0 = hip + Vector((cx, 0.20, -0.785))
            claws.tri([tuple(c0 + Vector((-0.01, 0, 0.01))), tuple(c0 + Vector((0.01, 0, 0.01))), tuple(c0 + Vector((0, 0.07, -0.012)))], CLAW)
            claws.tri([tuple(c0 + Vector((0.01, 0, 0.01))), tuple(c0 + Vector((-0.01, 0, 0.01))), tuple(c0 + Vector((0, 0.07, -0.012)))], CLAW)
        co = claws.finish("bear_claws_" + name)
        co.parent = parts[1]
        co.location = Vector((0, 0, 0))
        objs.append(co)
    return objs


if __name__ == "__main__":
    gw.clear()
    objs = build()
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    gw.export(objs, f"{OUT}/bear.glb")
    print("BEAR tris", tris)
