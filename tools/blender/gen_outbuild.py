"""
Run: blender.exe --background --factory-startup --python gen_outbuild.py -- <out_dir>
Outputs woodshed.glb (3.4 x 2.2 m, open front stacked with cordwood, mono-pitch tin roof + snow) and
outhouse.glb (1.2 x 1.2 m, door on -Y). Both: floor/ground at z=0, front = -Y (Godot +Z). Vertex coloured, solid props.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from gen_cabin import Mesh, col, export, clear, rng, SNOW, IRON
from gen_hut import slab, TRIM, TIN, STONE, WOODL
SIDING = (0.27, 0.21, 0.15)    # weathered brown boards, matches the cabin logs
SIDING2 = (0.22, 0.17, 0.12)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()

LOGC = (0.30, 0.20, 0.12)
BARK = (0.20, 0.15, 0.11)
BOARD = 0.16


def boards_x(m, x, y0, y1, z0, z1, cols=(SIDING, SIDING2)):
    n = int(abs(y1 - y0) / BOARD)
    for k in range(n):
        y = y0 + (k + 0.5) * BOARD
        c = cols[0] if rng.random() < 0.7 else cols[1]
        m.box(x, y, (z0 + z1) / 2, 0.07, BOARD - 0.012, (z1 - z0) + rng.uniform(-0.03, 0.03), c)


def boards_y(m, y, x0, x1, z0, z1, cols=(SIDING, SIDING2)):
    n = int(abs(x1 - x0) / BOARD)
    for k in range(n):
        x = x0 + (k + 0.5) * BOARD
        c = cols[0] if rng.random() < 0.7 else cols[1]
        m.box(x, y, (z0 + z1) / 2, BOARD - 0.012, 0.07, (z1 - z0) + rng.uniform(-0.03, 0.03), c)


def woodshed():
    m = Mesh()
    HX, HY = 1.7, 1.1
    hb, hf = 2.1, 1.6            # back / front wall heights
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box(sx * (HX - 0.1), sy * (HY - 0.1), 0.05, 0.3, 0.3, 0.2, STONE, j=0.2)
            m.box(sx * HX, sy * HY, (hb if sy > 0 else hf) / 2, 0.14, 0.14, hb if sy > 0 else hf, TRIM)
    m.box(0, 0, 0.12, 2 * HX, 2 * HY, 0.1, WOODL, j=0.1)
    boards_y(m, HY, -HX, HX, 0.1, hb)
    # side walls: slope with the roof
    for sx in (-HX, HX):
        n = int(2 * HY / BOARD)
        for k in range(n):
            y = -HY + (k + 0.5) * BOARD
            h = hf + (hb - hf) * (y + HY) / (2 * HY)
            m.box(sx, y, 0.1 + (h - 0.1) / 2, 0.07, BOARD - 0.012, h - 0.1, SIDING if rng.random() < 0.7 else SIDING2)
    # cordwood stacked against the back and one side, ends facing the front
    for row in range(7):
        for k in range(int((2 * HX - 0.5) / 0.2)):
            if row >= 3 and k < 6:
                continue
            x = -HX + 0.3 + k * 0.2 + (0.1 if row % 2 else 0.0)
            if x > HX - 0.25:
                continue
            m.log("y", -0.2, HY - 0.15, x, 0.25 + row * 0.19, r=0.085, c=LOGC if rng.random() < 0.7 else BARK, sides=6)
    # roof
    ov = 0.4
    ex = HX + ov
    zb, zf = hb + 0.12, hf + 0.12
    slab(m, (-ex, -HY - ov, zf), (ex, -HY - ov, zf), (ex, HY + 0.2, zb), (-ex, HY + 0.2, zb), 0.05, TIN, j=0.12)
    slab(m, (-ex + 0.1, -HY - ov + 0.1, zf + 0.06), (ex - 0.1, -HY - ov + 0.1, zf + 0.06), (ex - 0.1, HY + 0.1, zb + 0.06), (-ex + 0.1, HY + 0.1, zb + 0.06), 0.09, SNOW, j=0.02)
    # chopping block + axe-scarred stump out front, snow drifts
    m.log("x", 0.0, 0.0, 0.0, 0.0, r=0.01)
    m.pipe(1.0, -HY - 0.7, 0.0, 0.42, 0.26, LOGC, sides=9)
    m.box(0, -HY - 0.3, -0.1, 2 * HX + 0.8, 0.6, 0.3, SNOW, top=SNOW, j=0.02)
    m.box(HX + 0.3, 0, -0.1, 0.5, 2 * HY, 0.3, SNOW, top=SNOW, j=0.02)
    return m.finish("woodshed")


def outhouse():
    m = Mesh()
    H = 0.6
    hb, hf = 2.3, 2.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box(sx * 0.5, sy * 0.5, 0.05, 0.25, 0.25, 0.2, STONE, j=0.2)
            m.box(sx * H, sy * H, (hb if sy > 0 else hf) / 2, 0.1, 0.1, hb if sy > 0 else hf, TRIM)
    m.box(0, 0, 0.12, 1.3, 1.3, 0.1, WOODL, j=0.1)
    boards_y(m, H, -H, H, 0.1, hb)
    for sx in (-H, H):
        n = int(2 * H / BOARD)
        for k in range(n):
            y = -H + (k + 0.5) * BOARD
            h = hf + (hb - hf) * (y + H) / (2 * H)
            m.box(sx, y, 0.1 + (h - 0.1) / 2, 0.07, BOARD - 0.012, h - 0.1, SIDING if rng.random() < 0.7 else SIDING2)
    # front: boards with a door gap-less (closed door slab, darker + frame) and a vent
    boards_y(m, -H, -H, H, 0.1, hf)
    m.box(0, -H - 0.04, 1.0, 0.7, 0.05, 1.8, (0.20, 0.17, 0.13))
    m.box(0, -H - 0.07, 1.95, 0.8, 0.05, 0.08, TRIM)
    m.box(0.22, -H - 0.09, 1.0, 0.06, 0.04, 0.2, IRON)       # latch
    m.box(0, -H - 0.07, 1.78, 0.14, 0.04, 0.14, IRON)        # vent hole
    ex = H + 0.25
    slab(m, (-ex, -H - 0.3, hf + 0.1), (ex, -H - 0.3, hf + 0.1), (ex, H + 0.15, hb + 0.1), (-ex, H + 0.15, hb + 0.1), 0.05, TIN, j=0.12)
    slab(m, (-ex + 0.08, -H - 0.22, hf + 0.16), (ex - 0.08, -H - 0.22, hf + 0.16), (ex - 0.08, H + 0.08, hb + 0.16), (-ex + 0.08, H + 0.08, hb + 0.16), 0.08, SNOW, j=0.02)
    m.box(0, -H - 0.3, -0.1, 2.0, 0.5, 0.3, SNOW, top=SNOW, j=0.02)
    return m.finish("outhouse")


if __name__ == "__main__":
    clear()
    w = woodshed()
    export([w], os.path.join(OUT, "woodshed.glb"))
    print("WOODSHED tris", sum(len(p.vertices) - 2 for p in w.data.polygons))
    clear()
    o = outhouse()
    export([o], os.path.join(OUT, "outhouse.glb"))
    print("OUTHOUSE tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
