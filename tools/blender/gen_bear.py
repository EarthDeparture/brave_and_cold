"""
Run: blender.exe --background --factory-startup --python gen_bear.py -- <out_dir>
Outputs bear.glb: low-poly brown bear, ~2.0 m long, 1.0 m at the hip, shoulder hump ~1.45 m. Faces Blender +Y.
Separate objects: bear_body, bear_tail, bear_leg_fl/fr/bl/br (origin at hip). Vertex colours only.
"""
import sys
import os
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_wolf as gw  # noqa: E402  (reuse M mesh helper; its __main__ block does not run on import)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

FUR = (0.17, 0.105, 0.065)
FUR_DARK = (0.085, 0.055, 0.04)
FUR_LIGHT = (0.26, 0.17, 0.10)
BELLY = (0.14, 0.095, 0.065)
MUZZLE = (0.30, 0.215, 0.15)
NOSE = (0.03, 0.025, 0.025)
EYE = (0.05, 0.03, 0.02)
CLAW = (0.75, 0.70, 0.60)


def build():
    M = gw.M
    objs = []
    b = M()
    b.blob(0, 0.30, 1.00, 0.44, 0.58, 0.46, FUR, belly=BELLY, sides=10, rings=6)     # chest
    b.blob(0, -0.45, 0.96, 0.42, 0.52, 0.43, FUR, belly=BELLY, sides=10, rings=6)    # hips
    b.blob(0, 0.15, 1.36, 0.30, 0.42, 0.26, FUR_LIGHT, sides=8, rings=5)             # shoulder hump
    b.blob(0, 0.80, 1.14, 0.27, 0.32, 0.28, FUR, sides=8, rings=5, tilt=-0.3)        # neck
    b.blob(0, 1.06, 1.10, 0.22, 0.27, 0.21, FUR, sides=8, rings=5)                   # head
    b.blob(0, 1.30, 1.04, 0.105, 0.17, 0.09, MUZZLE, sides=8, rings=4)               # snout
    b.blob(0, 1.46, 1.04, 0.04, 0.03, 0.03, NOSE, sides=6, rings=3)                  # nose
    for sx in (-1, 1):
        b.blob(sx * 0.15, 0.98, 1.29, 0.065, 0.045, 0.065, FUR_DARK, sides=6, rings=3)  # ears
        b.box(sx * 0.10, 1.27, 1.16, 0.03, 0.03, 0.03, EYE)
    objs.append(b.finish("bear_body"))
    t = M(origin=(0, -0.92, 1.0))
    t.blob(0, -0.98, 0.98, 0.06, 0.07, 0.07, FUR_DARK, sides=6, rings=3)
    objs.append(t.finish("bear_tail"))
    for name, x, y in (("fl", -0.27, 0.45), ("fr", 0.27, 0.45), ("bl", -0.27, -0.55), ("br", 0.27, -0.55)):
        hip = (x, y, 0.80)
        l = M(origin=hip)
        l.box(x, y, 0.58, 0.26, 0.30, 0.44, FUR, taper=0.80)
        l.box(x, y + (0.02 if name[0] == "b" else 0.0), 0.22, 0.19, 0.21, 0.36, FUR_DARK, taper=0.9)
        l.box(x, y + 0.05, 0.03, 0.21, 0.32, 0.06, FUR_DARK)
        l.box(x, y + 0.22, 0.03, 0.15, 0.04, 0.03, CLAW)
        objs.append(l.finish("bear_leg_" + name))
    return objs


if __name__ == "__main__":
    gw.clear()
    objs = build()
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    gw.export(objs, f"{OUT}/bear.glb")
    print("BEAR tris", tris)
