"""
Run: blender.exe --background --factory-startup --python gen_wood.py -- <out_dir>
Outputs stump.glb and log.glb (vertex coloured, one object each).
 stump: unit tree stump, radius 0.25 m, height 0.45 m, pale cut top with snow dust, root flare. Godot scales xz by trunk radius / 0.25.
 log:   unit felled trunk along +X, length 1.0 (x -0.5..0.5), radius 0.25, resting on y=0. Godot scales x by length, yz by radius / 0.25.
"""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from gen_cabin import Mesh, col, export, clear, rng, SNOW

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()

BARK = (0.20, 0.14, 0.10)
BARK2 = (0.14, 0.10, 0.07)
CUT = (0.64, 0.52, 0.36)
CUT2 = (0.55, 0.43, 0.29)


def ring_pts(r, z, n, off=0.0):
    return [(math.cos(2 * math.pi * i / n + off) * r, math.sin(2 * math.pi * i / n + off) * r, z) for i in range(n)]


def build_stump():
    m = Mesh()
    n = 10
    h = 0.45
    # trunk sides, slightly flared at the base
    lo = ring_pts(0.30, 0.0, n, 0.2)
    hi = ring_pts(0.25, h, n, 0.2)
    for k in range(n):
        k2 = (k + 1) % n
        m.poly([lo[k], lo[k2], hi[k2], hi[k]], col(BARK if k % 2 == 0 else BARK2, 0.15))
    # pale cut face (axe-chopped, slightly uneven)
    top = [(p[0], p[1], p[2] + (0.02 if i % 3 == 0 else 0.0)) for i, p in enumerate(ring_pts(0.25, h, n, 0.2))]
    m.poly(top, col(CUT, 0.08))
    # growth rings hint: inner darker disc
    m.poly(ring_pts(0.12, h + 0.012, 8, 0.1), col(CUT2, 0.05))
    # snow dust on the cut
    m.box(0.02, -0.02, h + 0.035, 0.3, 0.26, 0.04, SNOW, j=0.02)
    # root flare
    for a in (0.3, 1.7, 3.2, 4.6):
        m.box(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.06, 0.18, 0.1, 0.12, BARK2, j=0.1)
    return m.finish("stump")


def build_log():
    m = Mesh()
    r = 0.25
    # main trunk: Mesh.log builds a cylinder along X with pale end caps
    m.log("x", -0.5, 0.5, 0.0, r, r=r, c=BARK, sides=10)
    # broken branch stubs
    for x, ang, ln in ((-0.3, 0.9, 0.22), (-0.05, 2.4, 0.18), (0.22, 4.1, 0.25), (0.38, 5.4, 0.16)):
        cy, cz = math.cos(ang) * (r + ln * 0.4), r + math.sin(ang) * (r + ln * 0.4)
        m.box(x, cy, cz, 0.05, 0.05 + abs(math.cos(ang)) * ln, 0.05 + abs(math.sin(ang)) * ln, BARK2, j=0.1)
    # snow strip on top + a little on the ends
    m.box(0.0, 0.0, 2 * r + 0.01, 0.92, 0.2, 0.05, SNOW, j=0.02)
    return m.finish("log")


if __name__ == "__main__":
    clear()
    s = build_stump()
    export([s], os.path.join(OUT, "stump.glb"))
    clear()
    l = build_log()
    export([l], os.path.join(OUT, "log.glb"))
    print("WOOD stump tris", sum(len(p.vertices) - 2 for p in s.data.polygons) if s.data else 0)
