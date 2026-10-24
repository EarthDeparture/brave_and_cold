"""
Run: blender.exe --background --factory-startup --python gen_cabin_burned.py -- <out_dir>
Outputs cabin_burned.glb: the shell of a log cabin after a fire (A4 E2), same footprint and origin as cabin.glb so it
swaps in place. Charred log courses burned down unevenly (corner notches survive tallest, mid-walls and the door wall
lowest), broken log ends, no roof or gables; fallen rafters, the ridge log and a tie beam lying across the room at
angles; floor planks charred with burned-through holes, ash drifts and charred debris; the iron stove left standing
with a stub of pipe and the fallen pipe on the floor; the bed frame as low charred boards. One object "cabin_burned"
(vertex-coloured; Godot adds char grain + ember cracks).
"""
import os
import sys
import math
import random
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_cabin as gc  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

CHAR = (0.022, 0.021, 0.020)        # charcoal: near-black, neutral (not brown wood)
CHAR2 = (0.048, 0.044, 0.041)
CHAR_BROWN = (0.075, 0.052, 0.038)
gc.WOOD_LIGHT = (0.055, 0.045, 0.038)   # gen_cabin's log end caps use this global: charred ends, not fresh-cut wood
ASH = (0.30, 0.29, 0.28)
ASH_DARK = (0.16, 0.155, 0.15)
STONE_SOOT = (0.075, 0.073, 0.078)
IRON = gc.IRON

rng = random.Random(41)
gc.rng = random.Random(42)   # gen_cabin's colour jitter stream


def c(cc, j=0.15):
    k = 1.0 + (rng.random() * 2 - 1) * j
    return (min(cc[0] * k, 1), min(cc[1] * k, 1), min(cc[2] * k, 1))


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def beam(m, p0, p1, r, cc, sides=8, end_c=None):
    """A cylinder between two arbitrary points (fallen rafters, pipe)."""
    ax = [p1[i] - p0[i] for i in range(3)]
    L = math.sqrt(sum(a * a for a in ax))
    d = [a / L for a in ax]
    up = (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)
    u = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
    ul = math.sqrt(sum(a * a for a in u)); u = [a / ul for a in u]
    v = (d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0])
    col = gc.col(c(cc), 0.1)
    def pt(p, k, rr):
        a = 2 * math.pi * k / sides + 0.3
        return tuple(p[i] + (u[i] * math.cos(a) + v[i] * math.sin(a)) * rr for i in range(3))
    r0 = r * (0.95 + rng.random() * 0.1); r1 = r * (0.7 + rng.random() * 0.3)   # burned thinner toward one end
    for k in range(sides):
        k2 = (k + 1) % sides
        m.poly([pt(p0, k, r0), pt(p1, k, r1), pt(p1, k2, r1), pt(p0, k2, r0)], col)
    ec = gc.col(end_c or CHAR_BROWN, 0.1)
    m.poly([pt(p0, k, r0) for k in reversed(range(sides))], ec)
    m.poly([pt(p1, k, r1) for k in range(sides)], ec)


def profile(t, L, base, peak, seed):
    """Surviving course count along a wall: tall at the notched corners, ragged low in the middle."""
    r = random.Random(seed)
    ph = [r.uniform(0, 6.28) for _ in range(3)]
    edge = 1.0 - smooth(0.0, 1.5, min(t + L / 2, L / 2 - t))
    n = 0.9 * math.sin(t * 1.7 + ph[0]) + 0.6 * math.sin(t * 3.9 + ph[1]) + 0.4 * math.sin(t * 7.3 + ph[2])
    return base + (peak - base) * edge + n


def wall(m, axis, fixed, lo, hi, opening, base, peak, seed, half_step=False):
    step = 0.2
    L = hi - lo
    for i in range(gc.COURSES - (1 if half_step else 0)):
        z = gc.Z0 + i * gc.STEP + (gc.STEP * 0.5 if half_step else 0.0)
        t = lo
        run_start = None
        while t <= hi + 1e-6:
            alive = profile(t - (lo + hi) / 2, L, base, peak, seed) > i
            if opening is not None:
                a0, a1, zlo, zhi = opening
                if a0 < t < a1 and zlo - gc.LOG_R * 0.5 <= z <= zhi + gc.LOG_R * 0.5:
                    alive = False
            if alive and run_start is None:
                run_start = t
            if (not alive or t + step > hi + 1e-6) and run_start is not None:
                end = t if not alive else hi
                if end - run_start > 0.35:
                    a = run_start + (rng.uniform(0, 0.12) if run_start > lo + 0.01 else 0)
                    b = end - (rng.uniform(0, 0.12) if end < hi - 0.01 else 0)
                    top = profile((a + b) / 2 - (lo + hi) / 2, L, base, peak, seed) < i + 1.6
                    cc = CHAR if top or rng.random() < 0.6 else CHAR2
                    r = gc.WALL_R * (0.82 if top else 0.97)
                    m.log(axis, a, b, fixed, z, r=r, c=c(cc), sides=10)
                run_start = None
            t += step


def build():
    m = gc.Mesh()
    HX, HY, FT = gc.HX, gc.HY, gc.FLOOR_TOP
    # foundation, sooted
    m.box(0, 0, (FT - 1.4) / 2, 6.4, 5.4, FT + 1.4, STONE_SOOT, j=0.2)
    # floor: charred planks, burned through in the middle of the room
    for i in range(12):
        y = -2.3 + i * 0.4 + 0.2
        x = -2.9
        while x < 2.9:
            seg = rng.uniform(0.6, 1.8)
            x1 = min(2.9, x + seg)
            hole = math.hypot((x + x1) / 2 + 0.3, y - 0.2) < 1.5 and rng.random() < 0.55
            if not hole:
                m.box((x + x1) / 2, y, FT - 0.015 - rng.uniform(0, 0.02), x1 - x - 0.03, 0.37, 0.05,
                      c(CHAR2 if rng.random() < 0.5 else CHAR_BROWN), top=c(CHAR2, 0.3), j=0.2)
            x = x1
    m.box(0, 0, FT - 0.09, 5.8, 4.8, 0.03, (0.02, 0.018, 0.017), top=(0.02, 0.018, 0.017), j=0.0)   # cavity below
    # walls burned down: front (door) lowest, the back and corners tallest
    wall(m, "x", -HY, -HX - 0.35, HX + 0.35, gc.DOOR, base=0.6, peak=6.0, seed=1)
    wall(m, "x", HY, -HX - 0.35, HX + 0.35, gc.WIN_BACK, base=3.0, peak=8.5, seed=2)
    wall(m, "y", -HX, -HY - 0.35, HY + 0.35, gc.WIN_SIDE, base=1.8, peak=7.5, seed=3, half_step=True)
    wall(m, "y", HX, -HY - 0.35, HY + 0.35, gc.WIN_SIDE, base=1.2, peak=6.5, seed=4, half_step=True)
    # charred door posts, one still standing
    m.box(gc.DOOR[0] - 0.06, -HY, FT + 0.75, 0.11, 0.38, 1.5, c(CHAR))
    # fallen roof: rafters from the wall tops down across the room, the ridge log, a tie beam
    eave = gc.WALL_TOP
    for k in range(7):
        x = rng.uniform(-HX + 0.4, HX - 0.4)
        side = -1 if rng.random() < 0.5 else 1
        top = (x + rng.uniform(-0.4, 0.4), side * (HY - 0.1), rng.uniform(1.2, 2.3))
        bot = (x + rng.uniform(-1.0, 1.0), -side * rng.uniform(0.0, 1.6), FT + rng.uniform(0.05, 0.25))
        beam(m, top, bot, rng.uniform(0.06, 0.09), CHAR if rng.random() < 0.7 else CHAR2)
    beam(m, (-HX + 0.2, 0.4, FT + 0.12), (HX - 0.6, -0.5, FT + 0.9), 0.12, CHAR)            # ridge log
    beam(m, (-2.4, HY - 0.2, 1.75), (-2.1, -0.8, FT + 0.1), 0.08, CHAR2)                    # a tie beam
    beam(m, (2.2, -HY + 0.3, FT + 0.08), (0.9, HY - 0.4, FT + 0.35), 0.075, CHAR)
    # ash drifts and charred chunks
    for k in range(26):
        x, y = rng.uniform(-2.6, 2.6), rng.uniform(-2.1, 2.1)
        w, d = rng.uniform(0.3, 1.1), rng.uniform(0.3, 0.9)
        m.box(x, y, FT + 0.01, w, d, rng.uniform(0.015, 0.05), c(ASH if rng.random() < 0.6 else ASH_DARK, 0.2), top=c(ASH, 0.25))
    for k in range(18):
        x, y = rng.uniform(-2.7, 2.7), rng.uniform(-2.2, 2.2)
        a = rng.uniform(0, math.pi)
        L = rng.uniform(0.25, 0.8)
        beam(m, (x, y, FT + 0.05), (x + math.cos(a) * L, y + math.sin(a) * L, FT + 0.05 + rng.uniform(0, 0.08)), rng.uniform(0.03, 0.06), CHAR, sides=6)
    # stove survives; pipe stub + the fallen pipe; stone hearth
    sx, sy = -2.35, 1.75
    m.box(sx, sy, FT + 0.5, 0.7, 0.5, 0.7, IRON, top=(0.05, 0.045, 0.045), j=0.05)
    m.box(sx, sy - 0.26, FT + 0.4, 0.3, 0.02, 0.25, (0.02, 0.02, 0.02))
    m.box(sx, sy + 0.05, FT + 0.1, 0.9, 0.7, 0.06, STONE_SOOT)
    m.pipe(sx, sy, FT + 0.85, FT + 1.45, 0.075, IRON)
    beam(m, (sx + 0.2, sy - 0.3, FT + 0.08), (sx + 1.9, sy - 1.6, FT + 0.12), 0.075, IRON, end_c=(0.02, 0.02, 0.02))
    # bed frame: low charred boards, a bed spring rectangle (iron) sagging
    bx, by = 2.0, 1.65
    m.box(bx, by, FT + 0.08, 1.85, 0.9, 0.05, c(CHAR))
    for lx in (-0.88, 0.88):
        m.box(bx + lx, by, FT + 0.12, 0.08, 0.9, 0.16, c(CHAR2))
    for k in range(6):
        y = by - 0.38 + k * 0.15
        beam(m, (bx - 0.85, y, FT + 0.16), (bx + 0.85, y, FT + 0.14 + rng.uniform(-0.03, 0.03)), 0.008, (0.10, 0.08, 0.07), sides=5)
    return m.finish("cabin_burned")


if __name__ == "__main__":
    gc.clear()
    o = build()
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    gc.export([o], os.path.join(OUT, "cabin_burned.glb"))
    print("CABIN_BURNED tris", tris)
