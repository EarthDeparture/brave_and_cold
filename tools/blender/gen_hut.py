"""
Run: blender.exe --background --factory-startup --python gen_hut.py -- <out_dir>
Outputs hut.glb: small weathered fishing hut 3.2 x 2.6 m (door on -Y wall -> Godot +Z), vertical board walls,
tin gable roof with snow, stone piers, bunk + tackle box inside, barrel + drying rack outside.
Vertex coloured, one object "hut". Interior floor top at z=0.3 (matches Hut.FLOOR_LOCAL_Y).
"""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from gen_cabin import Mesh, col, export, clear, rng, SNOW, IRON

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()

HX, HY = 1.6, 1.3
FT = 0.3
WH = 2.1
WALL_TOP = FT + WH
BOARD = 0.16
DOOR = (-0.5, 0.5, 2.0)
WIN = (-0.1, 0.65, 1.05, 1.75)   # side window on x=+HX wall: y0,y1,zlo,zhi

SIDING = (0.22, 0.30, 0.27)       # weathered grey-green
SIDING2 = (0.28, 0.27, 0.22)      # faded
TRIM = (0.14, 0.12, 0.10)
TIN = (0.30, 0.22, 0.18)          # rusty roof
STONE = (0.17, 0.17, 0.19)
WOODL = (0.40, 0.30, 0.20)
FABRIC = (0.28, 0.09, 0.08)
BLUE = (0.10, 0.20, 0.36)
FISH = (0.62, 0.66, 0.70)


def slab(m, a, b, c, d, th, color, j=0.05):
    """Quad a,b,c,d (ccw seen from the +normal side) extruded by th along its normal."""
    import mathutils
    A, B, C = mathutils.Vector(a), mathutils.Vector(b), mathutils.Vector(c)
    n = (B - A).cross(C - B).normalized() * th
    pts = [mathutils.Vector(p) for p in (a, b, c, d)]
    top = [tuple(p + n) for p in pts]
    bot = [tuple(p) for p in pts]
    cc = col(color, j)
    m.poly(top, cc)
    m.poly(list(reversed(bot)), cc)
    for i in range(4):
        j2 = (i + 1) % 4
        m.poly([bot[i], bot[j2], top[j2], top[i]], cc)


def build():
    m = Mesh()
    # --- foundation piers + floor
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            m.box(sx * (HX - 0.1), sy * (HY - 0.1), FT * 0.5 - 0.05, 0.4, 0.4, FT + 0.1, STONE, j=0.2)
    m.box(0, 0, FT - 0.06, 2 * HX + 0.2, 2 * HY + 0.2, 0.12, TRIM, top=WOODL, j=0.1)
    # --- vertical board walls
    def wall_x(sign):
        # wall along Y at x = sign*HX
        n = int(2 * HY / BOARD)
        for k in range(n):
            y = -HY + (k + 0.5) * BOARD
            c = SIDING if rng.random() < 0.7 else SIDING2
            if sign > 0 and WIN[0] < y < WIN[1]:
                m.box(sign * HX, y, FT + WIN[2] / 2 - 0.02, 0.07, BOARD - 0.012, WIN[2] - 0.02, c)
                m.box(sign * HX, y, WIN[3] + (WALL_TOP - WIN[3]) / 2, 0.07, BOARD - 0.012, WALL_TOP - WIN[3], c)
            else:
                m.box(sign * HX, y, FT + WH / 2, 0.07, BOARD - 0.012, WH + rng.uniform(-0.03, 0.03), c)
        if sign > 0:  # window frame
            y0, y1, zlo, zhi = WIN
            m.box(sign * HX, (y0 + y1) / 2, zlo, 0.1, y1 - y0 + 0.08, 0.06, TRIM)
            m.box(sign * HX, (y0 + y1) / 2, zhi, 0.1, y1 - y0 + 0.08, 0.06, TRIM)
            for yy in (y0, y1):
                m.box(sign * HX, yy, (zlo + zhi) / 2, 0.1, 0.06, zhi - zlo, TRIM)

    wall_x(-1)
    wall_x(1)
    # back wall (y=+HY) and front wall (y=-HY, door gap)
    n = int(2 * HX / BOARD)
    for k in range(n):
        x = -HX + (k + 0.5) * BOARD
        c = SIDING if rng.random() < 0.7 else SIDING2
        m.box(x, HY, FT + WH / 2, BOARD - 0.012, 0.07, WH + rng.uniform(-0.03, 0.03), c)
        if DOOR[0] < x < DOOR[1]:
            m.box(x, -HY, FT + DOOR[2] + (WH - DOOR[2]) / 2, BOARD - 0.012, 0.07, WH - DOOR[2], c)
        else:
            m.box(x, -HY, FT + WH / 2, BOARD - 0.012, 0.07, WH + rng.uniform(-0.03, 0.03), c)
    # door frame
    for sx in (DOOR[0] - 0.05, DOOR[1] + 0.05):
        m.box(sx, -HY - 0.02, FT + DOOR[2] / 2, 0.09, 0.1, DOOR[2], TRIM)
    m.box(0, -HY - 0.02, FT + DOOR[2] + 0.03, 1.2, 0.1, 0.08, TRIM)
    # corner posts + top plate
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box(sx * HX, sy * HY, FT + WH / 2, 0.14, 0.14, WH, TRIM)
    m.box(0, 0, WALL_TOP + 0.04, 2 * HX + 0.14, 2 * HY + 0.14, 0.08, TRIM)
    # --- gable roof (ridge along X)
    ov = 0.45
    rz = WALL_TOP + 0.08
    ridge = rz + 0.95
    ey = HY + ov
    xe = HX + 0.4
    slab(m, (-xe, -ey, rz), (xe, -ey, rz), (xe, 0.0, ridge), (-xe, 0.0, ridge), 0.05, TIN, j=0.12)
    slab(m, (-xe, ey, rz), (-xe, 0.0, ridge), (xe, 0.0, ridge), (xe, ey, rz), 0.05, TIN, j=0.12)
    # snow on roof
    sn = 0.07
    slab(m, (-xe + 0.1, -ey + 0.1, rz + 0.06), (xe - 0.1, -ey + 0.1, rz + 0.06), (xe - 0.1, 0.02, ridge + 0.05), (-xe + 0.1, 0.02, ridge + 0.05), sn, SNOW, j=0.02)
    slab(m, (-xe + 0.1, ey - 0.1, rz + 0.06), (-xe + 0.1, -0.02, ridge + 0.05), (xe - 0.1, -0.02, ridge + 0.05), (xe - 0.1, ey - 0.1, rz + 0.06), sn, SNOW, j=0.02)
    # gable end boards (triangles filled with narrow boxes)
    for sx in (-HX, HX):
        for k in range(int(2 * HY / BOARD)):
            y = -HY + (k + 0.5) * BOARD
            h = (ridge - rz - 0.1) * (1.0 - abs(y) / HY) + 0.02
            if h > 0.05:
                m.box(sx, y, WALL_TOP + 0.08 + h / 2, 0.07, BOARD - 0.012, h, SIDING2)
    # --- chimney pipe
    m.pipe(-0.8, 0.55, WALL_TOP, ridge + 0.55, 0.07, IRON)
    m.pipe(-0.8, 0.55, ridge + 0.5, ridge + 0.62, 0.11, IRON)
    # --- interior: bunk on back wall, tackle box, bench
    m.box(-HX + 0.55, HY - 0.5, FT + 0.45, 1.0, 0.9, 0.08, WOODL)
    m.box(-HX + 0.55, HY - 0.5, FT + 0.55, 0.95, 0.85, 0.12, FABRIC)
    for sx in (-HX + 0.1, -HX + 1.0):
        m.box(sx, HY - 0.08, FT + 0.22, 0.08, 0.08, 0.45, TRIM)
        m.box(sx, HY - 0.92, FT + 0.22, 0.08, 0.08, 0.45, TRIM)
    m.box(HX - 0.45, HY - 0.4, FT + 0.18, 0.62, 0.34, 0.36, BLUE, top=WOODL, j=0.1)   # tackle box
    m.box(HX - 0.45, HY - 0.4, FT + 0.37, 0.64, 0.36, 0.04, TRIM)
    m.box(0.3, HY - 0.25, FT + 0.2, 1.1, 0.3, 0.05, WOODL)                              # bench
    m.box(-0.2, HY - 0.25, FT + 0.1, 0.06, 0.26, 0.2, TRIM)
    m.box(0.8, HY - 0.25, FT + 0.1, 0.06, 0.26, 0.2, TRIM)
    # --- outside: step, barrel, drying rack, leaning rods
    m.box(0, -HY - 0.4, FT - 0.12, 1.2, 0.5, 0.18, WOODL, j=0.1)
    m.pipe(-1.25, -HY - 0.6, 0.0, 0.85, 0.28, (0.12, 0.2, 0.3), sides=10)
    m.pipe(-1.25, -HY - 0.6, 0.84, 0.88, 0.29, TRIM, sides=10)
    for sy in (-1, 1):
        m.box(HX + 1.2, 0.3 + sy * 0.9, 0.7, 0.08, 0.08, 1.4, TRIM)
    m.box(HX + 1.2, 0.3, 1.38, 0.08, 2.0, 0.06, TRIM)
    for k in range(5):
        m.box(HX + 1.2, -0.3 + k * 0.28, 1.12, 0.05, 0.06, 0.52, FISH, j=0.15)
    for k in range(3):
        a = 0.32 + k * 0.1
        z1 = 2.1
        m.poly([(HX * 0 + 1.0 + k * 0.13, -HY - 0.08, FT), (1.0 + k * 0.13 + 0.02, -HY - 0.08, FT), (1.0 + k * 0.13 + 0.02 + a * 0.3, -HY - 0.08, z1), (1.0 + k * 0.13 + a * 0.3, -HY - 0.08, z1)], col(TRIM))
    # --- snow drifts at the base
    m.box(0, -HY - 0.35, FT - 0.18, 2 * HX + 0.8, 0.5, 0.3, SNOW, top=SNOW, j=0.02)
    m.box(HX + 0.3, 0, FT - 0.18, 0.5, 2 * HY, 0.3, SNOW, top=SNOW, j=0.02)
    m.box(-HX - 0.3, 0, FT - 0.18, 0.5, 2 * HY, 0.3, SNOW, top=SNOW, j=0.02)
    return m.finish("hut")


if __name__ == "__main__":
    clear()
    h = build()
    n = sum(len(p.vertices) - 2 for p in h.data.polygons)
    export([h], os.path.join(OUT, "hut.glb"))
    print("HUT tris", n)
