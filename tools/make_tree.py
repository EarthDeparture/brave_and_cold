"""
M2 look-dev: parametric bare-winter tree generator.

Recursive cone-segment branching (trunk -> primary branches -> twigs), no
leaves — dead winter silhouettes are both thematically right and cheap.
All geometry is baked into a single mesh with a flat dark bark material
(trees read as fog-silhouettes; texture is unnecessary at M2 range).

Run headless:
  blender.exe --background --python tools/make_tree.py -- <blend_out> <glb_out> <seed>
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector


SIDES = 7  # radial segments per cone (chunky low-poly reads as stylized)


def parse_args():
    argv = sys.argv
    if "--" not in argv or len(argv[argv.index("--") + 1:]) != 3:
        raise SystemExit(
            "Usage: blender --background --python tools/make_tree.py -- <blend_out> <glb_out> <seed>")
    tail = argv[argv.index("--") + 1:]
    return os.path.abspath(tail[0]), os.path.abspath(tail[1]), int(tail[2])


class MeshBuilder:
    def __init__(self):
        self.verts = []
        self.faces = []

    def cone(self, p0, p1, r0, r1):
        """Append a tapered cone segment from p0 to p1."""
        axis = (p1 - p0).normalized()
        # perpendicular frame
        helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(helper).normalized()
        v = axis.cross(u).normalized()

        base = len(self.verts)
        for k in range(SIDES):
            a = 2 * math.pi * k / SIDES
            off = u * math.cos(a) + v * math.sin(a)
            self.verts.append(tuple(p0 + off * r0))
        for k in range(SIDES):
            a = 2 * math.pi * k / SIDES
            off = u * math.cos(a) + v * math.sin(a)
            self.verts.append(tuple(p1 + off * r1))
        for k in range(SIDES):
            k2 = (k + 1) % SIDES
            self.faces.append((base + k, base + k2, base + SIDES + k2, base + SIDES + k))


def grow(builder, rng, p0, direction, length, radius, depth, max_depth):
    tip = p0 + direction * length
    builder.cone(p0, tip, radius, radius * 0.55)

    if depth >= max_depth:
        return

    children = rng.randint(2, 3)
    for _ in range(children):
        t = rng.uniform(0.45, 1.0)
        start = p0 + direction * (length * t)
        # tilt away from parent direction; winter branches sweep upward
        tilt = math.radians(rng.uniform(25.0, 55.0))
        roll = rng.uniform(0.0, 2 * math.pi)
        helper = direction.orthogonal().normalized()
        new_dir = (direction * math.cos(tilt)
                   + helper * math.sin(tilt) * math.cos(roll)
                   + direction.cross(helper).normalized() * math.sin(tilt) * math.sin(roll))
        new_dir = (new_dir + Vector((0, 0, 0.25))).normalized()
        grow(builder, rng, start, new_dir,
             length * rng.uniform(0.55, 0.7), radius * 0.5, depth + 1, max_depth)


def main():
    blend_out, glb_out, seed = parse_args()
    os.makedirs(os.path.dirname(blend_out), exist_ok=True)
    os.makedirs(os.path.dirname(glb_out), exist_ok=True)
    rng = random.Random(seed)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    builder = MeshBuilder()

    height = rng.uniform(3.8, 5.5)
    lean = Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 1.0)).normalized()
    grow(builder, rng, Vector((0, 0, 0)), lean, height * 0.45,
         rng.uniform(0.16, 0.24), depth=0, max_depth=3)

    mesh = bpy.data.meshes.new("TreeMesh")
    mesh.from_pydata(builder.verts, [], builder.faces)
    mesh.update()
    tree = bpy.data.objects.new("BareTree", mesh)
    bpy.context.scene.collection.objects.link(tree)

    bark = bpy.data.materials.new("Bark")
    bsdf = bark.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.14, 0.115, 0.10, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    mesh.materials.append(bark)

    for poly in mesh.polygons:
        poly.use_smooth = True

    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    bpy.ops.export_scene.gltf(filepath=glb_out, export_format="GLB",
                              export_yup=True, export_apply=True)
    print(f"[make_tree] wrote {blend_out}")
    print(f"[make_tree] wrote {glb_out}")


main()
