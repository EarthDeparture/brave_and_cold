"""
M0 pipeline proof: generates a wooden supply crate procedurally,
saves the .blend source, and exports a .glb for Godot.

Run headless:
  blender.exe --background --python tools/make_test_prop.py -- <blend_out> <glb_out>
"""
import os
import sys

import bpy


def parse_args():
    argv = sys.argv
    if "--" not in argv:
        raise SystemExit(
            "Usage: blender --background --python make_test_prop.py -- <blend_out> <glb_out>"
        )
    tail = argv[argv.index("--") + 1:]
    if len(tail) != 2:
        raise SystemExit("Expected exactly 2 args after '--': <blend_out> <glb_out>")
    return os.path.abspath(tail[0]), os.path.abspath(tail[1])


def build_crate():
    # Start from an empty scene (no default cube/light/camera).
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 0.5 m cube, resting on the ground plane (base at Z=0; Blender is Z-up,
    # the glTF exporter converts to Godot's Y-up with export_yup=True).
    bpy.ops.mesh.primitive_cube_add(size=0.5, location=(0.0, 0.0, 0.25))
    crate = bpy.context.active_object
    crate.name = "Crate"

    # Slight bevel so edges catch light instead of looking like a raw cube.
    bevel = crate.modifiers.new(name="EdgeBevel", type="BEVEL")
    bevel.width = 0.015
    bevel.segments = 2

    # Simple flat-wood material (placeholder until hand-painted textures in M2).
    # Note: new materials are node-based by default in Blender 4.x+.
    mat = bpy.data.materials.new(name="CrateWood")
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.30, 0.19, 0.10, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    crate.data.materials.append(mat)


def main():
    blend_out, glb_out = parse_args()
    os.makedirs(os.path.dirname(blend_out), exist_ok=True)
    os.makedirs(os.path.dirname(glb_out), exist_ok=True)

    build_crate()

    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    bpy.ops.export_scene.gltf(
        filepath=glb_out,
        export_format="GLB",
        export_yup=True,
        export_apply=True,  # bakes the bevel modifier into the exported mesh
    )
    print(f"[make_test_prop] Wrote {blend_out}")
    print(f"[make_test_prop] Wrote {glb_out}")


main()
