"""
Run: blender.exe --background --factory-startup --python gen_plants.py -- <out_dir>
Outputs grass_tuft.glb, cattail.glb, stick_pile.glb, lichen.glb (vertex coloured, origin at ground).
"""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import gen_cabin
from gen_cabin import Mesh, col, export, clear, SNOW
import random

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()
R = random.Random(7)

STRAW = (0.66, 0.56, 0.32)
STRAW2 = (0.52, 0.42, 0.24)
REED = (0.40, 0.36, 0.20)
HEAD = (0.27, 0.15, 0.08)
STICK = (0.30, 0.22, 0.15)
STICK2 = (0.22, 0.16, 0.11)
LICHEN = (0.62, 0.68, 0.50)
LICHEN2 = (0.50, 0.58, 0.42)
GREY = (0.34, 0.31, 0.28)


def blade(m, x, y, h, w, lean, ang, c):
    """Thin tapered blade: base width w, tip leaning by `lean` in direction ang."""
    ca, sa = math.cos(ang), math.sin(ang)
    px, py = -sa * w / 2, ca * w / 2
    tx, ty = x + ca * lean, y + sa * lean
    m.poly([(x - px, y - py, 0.0), (x + px, y + py, 0.0), (tx + px * 0.2, ty + py * 0.2, h), (tx - px * 0.2, ty - py * 0.2, h)], col(c, 0.12))
    m.poly([(x + px, y + py, 0.0), (x - px, y - py, 0.0), (tx - px * 0.2, ty - py * 0.2, h), (tx + px * 0.2, ty + py * 0.2, h)], col(c, 0.12))


def build_grass():
    m = Mesh()
    for i in range(30):
        a = R.random() * math.tau
        r = R.random() * 0.18
        h = 0.5 + R.random() * 0.45
        blade(m, math.cos(a) * r, math.sin(a) * r, h, 0.06, 0.08 + R.random() * 0.22, a + R.uniform(-0.6, 0.6), STRAW if i % 3 else STRAW2)
    return m.finish("grass_tuft")


def build_cattail():
    m = Mesh()
    for i in range(6):
        a = i * 1.05 + 0.3
        r = 0.05 + R.random() * 0.07
        x, y = math.cos(a) * r, math.sin(a) * r
        h = 1.0 + R.random() * 0.45
        m.pipe(x, y, 0.0, h, 0.011, REED, sides=4)
        if i % 2 == 0:
            m.pipe(x, y, h * 0.72, h * 0.72 + 0.17, 0.034, HEAD, sides=6)
        blade(m, x, y, h * 0.8, 0.05, 0.2, a + 0.5, REED)
    return m.finish("cattail")


def build_sticks():
    m = Mesh()
    n = 0
    for z, ax in ((0.03, "x"), (0.03, "y"), (0.075, "x"), (0.075, "y"), (0.12, "x")):
        for k in range(2):
            ln = 0.55 + R.random() * 0.4
            off = (k - 0.5) * 0.17 + R.uniform(-0.03, 0.03)
            a0 = -ln / 2 + R.uniform(-0.1, 0.1)
            m.log(ax, a0, a0 + ln, off, z, r=0.03 + R.random() * 0.012, c=STICK if n % 2 else STICK2, sides=5)
            n += 1
    m.box(0.0, 0.0, 0.165, 0.7, 0.28, 0.035, SNOW, j=0.02)
    return m.finish("stick_pile")


def strand(m, x, y, z, h, w, c):
    for ang in (0.0, math.pi / 2):
        ca, sa = math.cos(ang), math.sin(ang)
        m.poly([(x - ca * w, y - sa * w, z), (x + ca * w, y + sa * w, z), (x + ca * w * 0.25, y + sa * w * 0.25, z - h), (x - ca * w * 0.25, y - sa * w * 0.25, z - h)], col(c, 0.1))


def build_lichen():
    m = Mesh()
    m.pipe(0.0, 0.0, 0.0, 1.3, 0.035, GREY, sides=6)
    for z, ang, ln in ((0.55, 0.0, 0.5), (0.85, 1.5708, 0.45), (1.1, 3.1416, 0.4), (0.7, 4.7124, 0.35)):
        ex, ey = math.cos(ang) * ln, math.sin(ang) * ln
        m.box(ex / 2, ey / 2, z, max(abs(ex), 0.035), max(abs(ey), 0.035), 0.035, GREY, j=0.08)
        for s in range(5):
            t = (s + 0.5) / 5
            strand(m, ex * t, ey * t, z - 0.015, 0.16 + R.random() * 0.22, 0.05, LICHEN if s % 2 else LICHEN2)
    for k in range(5):
        strand(m, math.cos(k * 1.3) * 0.05, math.sin(k * 1.3) * 0.05, 1.25 - k * 0.12, 0.25, 0.05, LICHEN2)
    return m.finish("lichen")


if __name__ == "__main__":
    for fn, name in ((build_grass, "grass_tuft"), (build_cattail, "cattail"), (build_sticks, "stick_pile"), (build_lichen, "lichen")):
        clear()
        o = fn()
        export([o], os.path.join(OUT, name + ".glb"))
    print("PLANTS ok")
