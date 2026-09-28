"""
M2 look-dev: rolling snow terrain generator.

Creates a gentle midwinter landscape: layered value-noise hills with a
flattened clearing (radius ~22 m, smoothstep blend) at the origin so the
cabin, crate, spawn point and nearby trees all sit at y = 0.

Run headless:
  blender.exe --background --python tools/make_terrain.py -- <blend_out> <glb_out>
"""
import math
import os
import sys

import bpy
import numpy as np


SIZE = 140.0          # metres, square
GRID = 128            # verts per side (16k verts — cheap)
AMPLITUDE = 2.4       # metres of relief outside the clearing
FLAT_RADIUS = 18.0    # fully flat radius around origin
BLEND_RADIUS = 26.0   # smoothstep edge of the clearing


def parse_args():
    argv = sys.argv
    if "--" not in argv or len(argv[argv.index("--") + 1:]) != 2:
        raise SystemExit("Usage: blender --background --python make_terrain.py -- <blend_out> <glb_out>")
    tail = argv[argv.index("--") + 1:]
    return os.path.abspath(tail[0]), os.path.abspath(tail[1])


def box_blur(a, iters):
    for _ in range(iters):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0)
               + np.roll(a, 1, 1) + np.roll(a, -1, 1)) * 0.2
    return a


def fbm(n, base_cells, octaves, rng, persistence=0.5):
    total = np.zeros((n, n), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cells = base_cells * (2 ** o)
        g = rng.random((cells, cells)).astype(np.float32)
        fy = -(-n // cells)  # ceil so upsampling covers full extent
        up = np.kron(g, np.ones((fy, fy), np.float32))[:n, :n]
        total += amp * box_blur(up, max(1, fy // 2))
        norm += amp
        amp *= persistence
    return total / norm


def build_heightfield():
    rng = np.random.default_rng(777)
    n = GRID
    # base_cells=2: broad rolling drifts first, finer noise on top — reads as
    # wind-shaped snow rather than uniform bumpiness (iter 1 was too flat+even)
    h = fbm(n, 2, 4, rng) * AMPLITUDE

    # Flatten the clearing (cabin + spawn + trees all live at y=0 there).
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    scale = SIZE / (n - 1)
    x = (xx - (n - 1) / 2) * scale
    z = (yy - (n - 1) / 2) * scale
    dist = np.sqrt(x * x + z * z)
    mask = np.clip((dist - FLAT_RADIUS) / (BLEND_RADIUS - FLAT_RADIUS), 0.0, 1.0)
    mask = mask * mask * (3.0 - 2.0 * mask)  # smoothstep
    return h * mask


def build_mesh(heights, blend_out, glb_out):
    n = GRID
    scale = SIZE / (n - 1)
    verts = []
    faces = []
    for j in range(n):
        for i in range(n):
            x = (i - (n - 1) / 2) * scale
            z = (j - (n - 1) / 2) * scale
            verts.append((x, z, float(heights[j, i])))
    for j in range(n - 1):
        for i in range(n - 1):
            a = j * n + i
            faces.append((a, a + 1, a + n + 1, a + n))

    mesh = bpy.data.meshes.new("TerrainMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    terrain = bpy.data.objects.new("Terrain", mesh)
    bpy.context.scene.collection.objects.link(terrain)

    # Simple snow material (overridden in Godot by the sparkle shader anyway).
    mat = bpy.data.materials.new("Snow")
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.90, 0.93, 0.97, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    mesh.materials.append(mat)

    # Smooth shading so hills read as drifts, not facets.
    for poly in mesh.polygons:
        poly.use_smooth = True

    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    bpy.ops.export_scene.gltf(filepath=glb_out, export_format="GLB",
                              export_yup=True, export_apply=True)
    print(f"[make_terrain] wrote {blend_out}")
    print(f"[make_terrain] wrote {glb_out}")


def main():
    blend_out, glb_out = parse_args()
    os.makedirs(os.path.dirname(blend_out), exist_ok=True)
    os.makedirs(os.path.dirname(glb_out), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_mesh(build_heightfield(), blend_out, glb_out)


main()
