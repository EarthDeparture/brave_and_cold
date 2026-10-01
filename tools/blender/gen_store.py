"""
Run: blender.exe --background --factory-startup --python gen_store.py -- <out_dir>
Outputs store.glb: roadside general store 6.4 x 4.6 m. Clapboard walls, false-front facade, covered porch, tin roof + snow.
Door on -Y wall (Godot +Z), two front windows flanking it, one window on each side wall.
Interior: counter, back-wall shelves, barrels, crates. Floor top at z=0.3 (Store.FLOOR_LOCAL_Y).
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from gen_cabin import Mesh, col, export, clear, rng, SNOW, IRON
from gen_hut import slab, TRIM, TIN, STONE, WOODL

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()

HX, HY = 3.2, 2.3
FT = 0.3
ROW = 0.2
NROWS = 13
WH = ROW * NROWS
WALL_TOP = FT + WH
CLAP = (0.30, 0.24, 0.17)
CLAP2 = (0.25, 0.20, 0.14)
FADED = (0.34, 0.20, 0.15)     # barn-red facade accent, weathered
DOOR_W = 1.0
FRONT_WIN = [(-2.0, 0.9)]      # placeholder, real list below
# window cutouts in WALL coordinates: (centre u, half width, rel z0, rel z1) -- rows are 0.2 so keep on 0.2 steps
WIN_Z = (0.8, 1.6)
DOOR_Z = (0.0, 2.0)


def wall_rows(m, fixed, axis, u0, u1, cuts, thick=0.08):
    """Horizontal clapboard along `axis` ('x': wall at y=fixed running in x; 'y': wall at x=fixed running in y).
    cuts: list of (a, b, rel_z0, rel_z1) openings in wall coordinate."""
    for r in range(NROWS):
        z0 = r * ROW
        z1 = z0 + ROW
        blocked = []
        for a, b, cz0, cz1 in cuts:
            if z1 > cz0 + 1e-6 and z0 < cz1 - 1e-6:
                blocked.append((a, b))
        blocked.sort()
        cur = u0
        segs = []
        for a, b in blocked:
            if a > cur:
                segs.append((cur, a))
            cur = max(cur, b)
        if cur < u1:
            segs.append((cur, u1))
        c = CLAP if (r % 2 == 0) else CLAP2
        for s0, s1 in segs:
            uc = (s0 + s1) / 2
            ln = s1 - s0
            zc = FT + z0 + ROW / 2
            if axis == "x":
                m.box(uc, fixed, zc, ln, thick, ROW + 0.012, c)
            else:
                m.box(fixed, uc, zc, thick, ln, ROW + 0.012, c)


def frame(m, axis, fixed, a, b, rz0, rz1):
    z0 = FT + rz0
    z1 = FT + rz1
    t = 0.06
    for u in (a, b):
        if axis == "x":
            m.box(u, fixed, (z0 + z1) / 2, t, 0.12, z1 - z0, TRIM)
        else:
            m.box(fixed, u, (z0 + z1) / 2, 0.12, t, z1 - z0, TRIM)
    for z in (z0, z1):
        if axis == "x":
            m.box((a + b) / 2, fixed, z, b - a + t, 0.12, t, TRIM)
        else:
            m.box(fixed, (a + b) / 2, z, 0.12, b - a + t, t, TRIM)


def build():
    m = Mesh()
    # foundation piers + floor
    for sx in (-1, -0.33, 0.33, 1):
        for sy in (-1, 1):
            m.box(sx * (HX - 0.15), sy * (HY - 0.15), FT * 0.5 - 0.05, 0.4, 0.4, FT + 0.1, STONE, j=0.2)
    m.box(0, 0, FT - 0.06, 2 * HX + 0.2, 2 * HY + 0.2, 0.12, TRIM, top=WOODL, j=0.1)
    # walls. front wall y=-HY: door gap + 2 windows
    fcuts = [(-DOOR_W / 2, DOOR_W / 2, *DOOR_Z), (-2.4, -1.4, *WIN_Z), (1.4, 2.4, *WIN_Z)]
    wall_rows(m, -HY, "x", -HX, HX, fcuts)
    wall_rows(m, HY, "x", -HX, HX, [])
    wall_rows(m, -HX, "y", -HY, HY, [(-0.5, 0.5, *WIN_Z)])
    wall_rows(m, HX, "y", -HY, HY, [(-0.5, 0.5, *WIN_Z)])
    # door + window frames
    frame(m, "x", -HY - 0.02, -DOOR_W / 2 - 0.05, DOOR_W / 2 + 0.05, 0.0, 2.05)
    frame(m, "x", -HY - 0.02, -2.4, -1.4, *WIN_Z)
    frame(m, "x", -HY - 0.02, 1.4, 2.4, *WIN_Z)
    frame(m, "y", -HX - 0.02, -0.5, 0.5, *WIN_Z)
    frame(m, "y", HX + 0.02, -0.5, 0.5, *WIN_Z)
    # corner posts + plate
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box(sx * HX, sy * HY, FT + WH / 2, 0.16, 0.16, WH, TRIM)
    m.box(0, 0, WALL_TOP + 0.04, 2 * HX + 0.16, 2 * HY + 0.16, 0.08, TRIM)
    # false front: tall flat facade above the front wall with a sign board
    FF_H = 1.1
    m.box(0, -HY - 0.12, WALL_TOP + 0.08 + FF_H / 2, 2 * HX + 0.3, 0.1, FF_H, FADED, j=0.1)
    m.box(0, -HY - 0.2, WALL_TOP + 0.08 + FF_H / 2, 3.2, 0.05, 0.6, (0.62, 0.55, 0.40), j=0.15)   # sign board
    m.box(0, -HY - 0.24, WALL_TOP + 0.08 + FF_H / 2, 3.0, 0.03, 0.08, (0.15, 0.10, 0.08))
    # gable roof (ridge along X) behind the facade
    ov = 0.35
    rz = WALL_TOP + 0.1
    ridge = rz + 1.2
    ey = HY + ov
    xe = HX + 0.3
    slab(m, (-xe, -ey + 0.3, rz), (xe, -ey + 0.3, rz), (xe, 0.0, ridge), (-xe, 0.0, ridge), 0.05, TIN, j=0.12)
    slab(m, (-xe, ey, rz), (-xe, 0.0, ridge), (xe, 0.0, ridge), (xe, ey, rz), 0.05, TIN, j=0.12)
    slab(m, (-xe + 0.1, -ey + 0.4, rz + 0.06), (xe - 0.1, -ey + 0.4, rz + 0.06), (xe - 0.1, 0.02, ridge + 0.05), (-xe + 0.1, 0.02, ridge + 0.05), 0.08, SNOW, j=0.02)
    slab(m, (-xe + 0.1, ey - 0.1, rz + 0.06), (-xe + 0.1, -0.02, ridge + 0.05), (xe - 0.1, -0.02, ridge + 0.05), (xe - 0.1, ey - 0.1, rz + 0.06), 0.08, SNOW, j=0.02)
    for sx in (-HX, HX):
        for k in range(int(2 * HY / 0.16)):
            y = -HY + (k + 0.5) * 0.16
            h = (ridge - rz) * (1.0 - abs(y) / HY) + 0.02
            if h > 0.05:
                m.box(sx, y, rz + h / 2, 0.07, 0.148, h, CLAP2)
    # chimney
    m.pipe(-1.8, 1.0, WALL_TOP, ridge + 0.6, 0.09, IRON)
    # covered porch: deck, two posts, shed roof
    PD = 1.5
    m.box(0, -HY - PD / 2, FT - 0.06, 2 * HX - 0.4, PD, 0.12, WOODL, j=0.1)
    for sx in (-HX + 0.4, HX - 0.4):
        m.box(sx, -HY - PD + 0.15, FT + 1.3, 0.14, 0.14, 2.6, TRIM)
    slab(m, (-HX, -HY - PD - 0.2, FT + 2.7), (HX, -HY - PD - 0.2, FT + 2.7), (HX, -HY - 0.1, WALL_TOP - 0.15), (-HX, -HY - 0.1, WALL_TOP - 0.15), 0.05, TIN, j=0.12)
    slab(m, (-HX + 0.1, -HY - PD - 0.1, FT + 2.76), (HX - 0.1, -HY - PD - 0.1, FT + 2.76), (HX - 0.1, -HY - 0.2, WALL_TOP - 0.1), (-HX + 0.1, -HY - 0.2, WALL_TOP - 0.1), 0.07, SNOW, j=0.02)
    # porch bench + crates + barrel
    m.box(-HX + 1.2, -HY - 0.45, FT + 0.2, 1.2, 0.3, 0.05, WOODL)
    m.box(-HX + 0.7, -HY - 0.45, FT + 0.1, 0.06, 0.26, 0.2, TRIM)
    m.box(-HX + 1.7, -HY - 0.45, FT + 0.1, 0.06, 0.26, 0.2, TRIM)
    m.box(HX - 1.0, -HY - 0.6, FT + 0.2, 0.7, 0.5, 0.4, WOODL, top=WOODL, j=0.12)
    m.pipe(HX - 1.9, -HY - 0.6, FT, FT + 0.8, 0.27, (0.12, 0.2, 0.3), sides=10)
    # interior: counter along the right, shelves on the back wall, barrels + crates
    m.box(1.6, 0.0, FT + 0.55, 0.7, 2.6, 1.1, WOODL, top=(0.45, 0.34, 0.22), j=0.1)
    for k in range(3):
        for sz in (0.5, 1.1, 1.7):
            m.box(-HX + 0.35 + k * 1.4 + 0.4, HY - 0.3, FT + sz, 1.2, 0.35, 0.05, WOODL)
    for sx in (-2.5, -1.1, 0.3):
        m.box(sx, HY - 0.3, FT + 1.0, 0.07, 0.34, 2.0, TRIM)
    m.box(-2.5, 1.8, FT + 2.05, 0.1, 0.1, 0.1, TRIM)
    for k in range(6):   # tins on shelves
        m.box(-2.4 + k * 0.45, HY - 0.3, FT + 0.58, 0.14, 0.14, 0.18, (0.55, 0.50, 0.38), j=0.2)
        m.box(-2.4 + k * 0.45 + 0.15, HY - 0.3, FT + 1.18, 0.14, 0.14, 0.18, (0.28, 0.32, 0.22), j=0.2)
    m.pipe(-HX + 0.6, -0.4, FT, FT + 0.85, 0.28, (0.16, 0.12, 0.09), sides=10)
    m.pipe(-HX + 1.2, -0.9, FT, FT + 0.85, 0.28, (0.16, 0.12, 0.09), sides=10)
    m.box(-HX + 0.7, 0.9, FT + 0.2, 0.8, 0.6, 0.4, WOODL, top=WOODL, j=0.12)
    m.box(-HX + 0.7, 0.9, FT + 0.6, 0.6, 0.5, 0.4, (0.40, 0.31, 0.20), top=WOODL, j=0.12)
    # snow drifts
    m.box(0, -HY - PD - 0.1, FT - 0.2, 2 * HX + 1.2, 0.5, 0.3, SNOW, top=SNOW, j=0.02)
    m.box(HX + 0.3, 0, FT - 0.2, 0.5, 2 * HY, 0.3, SNOW, top=SNOW, j=0.02)
    m.box(-HX - 0.3, 0, FT - 0.2, 0.5, 2 * HY, 0.3, SNOW, top=SNOW, j=0.02)
    return m.finish("store")


if __name__ == "__main__":
    clear()
    s = build()
    export([s], os.path.join(OUT, "store.glb"))
    print("STORE tris", sum(len(p.vertices) - 2 for p in s.data.polygons))
