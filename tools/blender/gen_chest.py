"""
Run: blender.exe --background --factory-startup --python gen_chest.py -- <out_dir>
Outputs chest.glb: a plank storage chest 0.90 x 0.55 x 0.50 m, front (latch) = Blender -Y = Godot +Z, floor at z=0.
Two nodes: chest_base, and chest_lid whose ORIGIN IS THE HINGE (back top edge) so Godot just rotates it about X.
Vertex coloured like the other props.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from gen_cabin import Mesh, export, clear, rng, SNOW, IRON

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.getcwd()

PLANK = (0.34, 0.235, 0.15)
PLANK2 = (0.27, 0.19, 0.12)
POST = (0.22, 0.155, 0.10)
INNER = (0.16, 0.115, 0.08)
BAND = (0.075, 0.07, 0.07)
RUST = (0.17, 0.10, 0.07)

W, D, H = 0.90, 0.55, 0.50
T = 0.035          # wall thickness
BOARD = 0.095
LID_H = 0.11


def pick():
    return PLANK if rng.random() < 0.65 else PLANK2


def build_base():
    m = Mesh()
    # floor + inner floor
    m.box(0, 0, T / 2, W, D, T, POST, j=0.1)
    # front and back walls: horizontal boards
    n = int((H - T) / BOARD)
    for k in range(n):
        z = T + (k + 0.5) * BOARD
        m.box(0, -D / 2 + T / 2, z, W - 0.02, T, BOARD - 0.008, pick(), j=0.1)
        m.box(0, D / 2 - T / 2, z, W - 0.02, T, BOARD - 0.008, pick(), j=0.1)
        for sx in (-1, 1):
            m.box(sx * (W / 2 - T / 2), 0, z, T, D - 2 * T, BOARD - 0.008, pick(), j=0.1)
    # inner dark floor so it reads hollow when the lid is up
    m.box(0, 0, T + 0.004, W - 2 * T - 0.01, D - 2 * T - 0.01, 0.006, INNER, j=0.05)
    # corner posts
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box(sx * (W / 2 - 0.022), sy * (D / 2 - 0.022), H / 2, 0.05, 0.05, H, POST, j=0.08)
    # iron straps around the body
    for sx in (-0.28, 0.28):
        m.box(sx, -D / 2 - 0.004, H / 2, 0.065, 0.012, H - 0.02, BAND, j=0.1)
        m.box(sx, D / 2 + 0.004, H / 2, 0.065, 0.012, H - 0.02, BAND, j=0.1)
        m.box(sx, 0, 0.012, 0.065, D + 0.02, 0.024, BAND, j=0.1)
    # hasp plate + lock on the front
    m.box(0, -D / 2 - 0.008, H - 0.06, 0.12, 0.014, 0.1, BAND)
    m.box(0, -D / 2 - 0.02, H - 0.1, 0.05, 0.02, 0.06, RUST)
    # rivets
    for sx in (-0.28, 0.28):
        for z in (0.1, 0.25, 0.4):
            m.box(sx, -D / 2 - 0.012, z, 0.018, 0.01, 0.018, IRON, j=0.1)
    return m.finish("chest_base")


def build_lid():
    """Origin at the hinge: back edge, top of the body. Lid extends toward -Y (the front)."""
    m = Mesh()
    ly = -D / 2 - 0.012
    n = 6
    span = D + 0.025
    for k in range(n):
        y = -(k + 0.5) * span / n
        m.box(0, y, LID_H * 0.5 + 0.0, W + 0.025, span / n - 0.006, LID_H * 0.35, pick(), top=PLANK, j=0.1)
    # side cleats
    for sx in (-1, 1):
        m.box(sx * (W / 2 + 0.008), -D / 2, LID_H * 0.5, 0.03, D + 0.03, LID_H, POST, j=0.08)
    # front/back lips
    m.box(0, 0.012, LID_H * 0.5, W + 0.03, 0.03, LID_H, POST, j=0.08)
    m.box(0, -D - 0.005, LID_H * 0.5, W + 0.03, 0.03, LID_H, POST, j=0.08)
    # lid straps
    for sx in (-0.28, 0.28):
        m.box(sx, -D / 2, LID_H * 0.5 + LID_H * 0.18 + 0.004, 0.065, D + 0.045, 0.014, BAND, j=0.1)
        m.box(sx, -D - 0.018, LID_H * 0.5, 0.065, 0.014, LID_H, BAND, j=0.1)
    # snow on the lid
    m.box(0, -D / 2, LID_H * 0.5 + LID_H * 0.18 + 0.02, W * 0.8, D * 0.78, 0.035, SNOW, top=SNOW, j=0.02)
    lid = m.finish("chest_lid")
    lid.location = (0.0, D / 2, H)
    return lid


if __name__ == "__main__":
    clear()
    b = build_base()
    l = build_lid()
    export([b, l], os.path.join(OUT, "chest.glb"))
    print("CHEST tris", sum(len(p.vertices) - 2 for p in b.data.polygons), sum(len(p.vertices) - 2 for p in l.data.polygons))
