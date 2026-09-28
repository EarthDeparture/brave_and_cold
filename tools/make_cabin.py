"""
M2 look-dev: parametric log cabin generator (v2 — correct Blender axes).

Blender is Z-up: X = east, Y = north, Z = up. With export_yup=True the glTF
map is Blender (x, y, z) -> Godot (x, z, -y), so the door/window face is built
on the -Y side, which arrives in Godot facing +Z (toward the player spawn).

Produces: stacked-log walls (door + window gaps), gabled roof with snow caps,
floor, fireplace blockout + chimney, recessed emissive window glow.
UVs are cube-projected so the generated wood texture tiles sensibly.

Run headless:
  blender.exe --background --python tools/make_cabin.py -- <blend_out> <glb_out> <tex_dir>
"""
import math
import os
import sys

import bpy


W, D = 6.0, 5.0          # footprint: X (east-west) x Y (north-south)
WALL_H = 2.7
LOG_H = 0.16
LOG_T = 0.14
RIDGE_H = 1.5
ROOF_T = 0.12
OVERHANG = 0.35

DOOR_W, DOOR_H = 1.0, 2.05
DOOR_X = 0.0
WIN_W, WIN_H = 0.9, 0.7
WIN_X, WIN_Z = 1.8, 1.55

FRONT_Y = -(D / 2 - LOG_T / 2)   # Blender -Y == Godot +Z (faces the spawn)
BACK_Y = +(D / 2 - LOG_T / 2)


def parse_args():
    argv = sys.argv
    if "--" not in argv or len(argv[argv.index("--") + 1:]) != 3:
        raise SystemExit(
            "Usage: blender --background --python make_cabin.py -- <blend_out> <glb_out> <tex_dir>")
    tail = argv[argv.index("--") + 1:]
    return os.path.abspath(tail[0]), os.path.abspath(tail[1]), os.path.abspath(tail[2])


def cube_obj(name, location, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def cube_project_uv(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=1.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def make_materials(tex_dir):
    mats = {}

    wood_img = bpy.data.images.load(os.path.join(tex_dir, "wood.png"))
    wood = bpy.data.materials.new("Wood")
    bsdf = wood.node_tree.nodes["Principled BSDF"]
    tex = wood.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = wood_img
    wood.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    mats["wood"] = wood

    def flat(name, color, rough=0.9):
        m = bpy.data.materials.new(name)
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*color, 1.0)
        b.inputs["Roughness"].default_value = rough
        return m

    mats["roof"] = flat("RoofDark", (0.10, 0.09, 0.09))
    mats["snow"] = flat("SnowCap", (0.92, 0.94, 0.98), rough=0.85)
    mats["stone"] = flat("Stone", (0.30, 0.29, 0.28))
    mats["floor"] = flat("FloorWood", (0.38, 0.26, 0.15))

    glow = bpy.data.materials.new("WindowGlow")
    gb = glow.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (1.0, 0.55, 0.20, 1.0)
    gb.inputs["Emission Color"].default_value = (1.0, 0.50, 0.16, 1.0)
    gb.inputs["Emission Strength"].default_value = 10.0
    mats["glow"] = glow
    return mats


def build_walls(mats):
    rows = math.ceil(WALL_H / LOG_H)  # run slightly past wall top: sealed joint
    hw = W / 2
    door = (DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2, 0.0, DOOR_H)
    win = (WIN_X - WIN_W / 2, WIN_X + WIN_W / 2, WIN_Z - WIN_H / 2, WIN_Z + WIN_H / 2)

    def segments_x(z0, z1):
        """X spans for a front-wall log row at heights z0..z1, minus gaps."""
        spans = [(-hw, hw)]
        for gx0, gx1, gz0, gz1 in (door, win):
            if z1 <= gz0 or z0 >= gz1:
                continue
            new = []
            for a, b in spans:
                if b <= gx0 or a >= gx1:
                    new.append((a, b))
                else:
                    if a < gx0:
                        new.append((a, gx0))
                    if b > gx1:
                        new.append((gx1, b))
            spans = new
        return spans

    for r in range(rows):
        z = r * LOG_H + LOG_H / 2
        z0, z1 = r * LOG_H, (r + 1) * LOG_H
        stagger = 0.10 if r % 2 else 0.0

        # front (-Y, door+window) and back (+Y, solid) walls, logs run along X
        for yc, gaps in ((FRONT_Y, True), (BACK_Y, False)):
            spans = segments_x(z0, z1) if gaps else [(-hw, hw)]
            for a, b in spans:
                if b - a < 0.02:
                    continue
                cube_obj("LogFB", ((a + b) / 2, yc, z),
                         ((b - a) / 2 + stagger, LOG_T / 2, LOG_H / 2), mats["wood"])

        # side walls at x = +/-, logs run along Y between front and back
        inner = D / 2 - LOG_T
        for xc in (W / 2 - LOG_T / 2, -(W / 2 - LOG_T / 2)):
            cube_obj("LogS", (xc, 0.0, z),
                     (LOG_T / 2, inner, LOG_H / 2), mats["wood"])


def build_roof(mats):
    half_span = D / 2 + OVERHANG
    slope_len = math.sqrt(half_span ** 2 + RIDGE_H ** 2)
    angle = math.atan2(RIDGE_H, half_span)
    ridge_z = WALL_H + RIDGE_H

    # ridge runs along X; slabs slope toward +/-Y
    for side in (1, -1):
        slab = cube_obj("RoofSlab", (0, side * half_span / 2, WALL_H + RIDGE_H / 2),
                        (W / 2 + OVERHANG, slope_len / 2, ROOF_T / 2), mats["roof"])
        slab.rotation_euler[0] = -side * angle
        snow = cube_obj("RoofSnow", (0, side * half_span / 2, WALL_H + RIDGE_H / 2 + 0.09),
                        (W / 2 + OVERHANG + 0.03, slope_len / 2 + 0.03, 0.05), mats["snow"])
        snow.rotation_euler[0] = -side * angle

    # gables: triangles in the Y-Z plane at both X ends, base sunk into the wall
    for gx, flip in ((W / 2 - LOG_T, False), (-(W / 2 - LOG_T), True)):
        verts = [(gx, -D / 2 + LOG_T, WALL_H - 0.06),
                 (gx, D / 2 - LOG_T, WALL_H - 0.06),
                 (gx, 0, ridge_z)]
        mesh = bpy.data.meshes.new("GableMesh")
        mesh.from_pydata(verts, [], [(2, 1, 0)] if flip else [(0, 1, 2)])
        gable = bpy.data.objects.new("Gable", mesh)
        bpy.context.scene.collection.objects.link(gable)
        mesh.materials.append(mats["wood"])
        sol = gable.modifiers.new("Solidify", "SOLIDIFY")
        sol.thickness = LOG_T


def build_interior(mats):
    cube_obj("Floor", (0, 0, 0.05), (W / 2 - LOG_T, D / 2 - LOG_T, 0.05), mats["floor"])
    # fireplace against the back wall (+Y) with a chimney through the roof
    cube_obj("Fireplace", (-1.2, D / 2 - LOG_T - 0.3, 0.75), (0.45, 0.3, 0.75), mats["stone"])
    cube_obj("Chimney", (-1.2, D / 2 - LOG_T - 0.3, WALL_H + 1.05),
             (0.35, 0.35, 1.05), mats["stone"])


def build_window_glow(mats):
    # recessed just inside the front wall hole: reads as a lit room, no z-fight
    cube_obj("WindowGlow", (WIN_X, FRONT_Y - 0.01 + LOG_T, WIN_Z),
             (WIN_W / 2 - 0.04, 0.02, WIN_H / 2 - 0.04), mats["glow"])


def main():
    blend_out, glb_out, tex_dir = parse_args()
    os.makedirs(os.path.dirname(blend_out), exist_ok=True)
    os.makedirs(os.path.dirname(glb_out), exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials(tex_dir)
    build_walls(mats)
    build_roof(mats)
    build_interior(mats)
    build_window_glow(mats)

    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            cube_project_uv(obj)

    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    bpy.ops.export_scene.gltf(filepath=glb_out, export_format="GLB",
                              export_yup=True, export_apply=True)
    print(f"[make_cabin] wrote {blend_out}")
    print(f"[make_cabin] wrote {glb_out}")


main()
