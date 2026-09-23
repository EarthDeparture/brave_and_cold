"""
Generic .blend -> .glb exporter, driven by export_assets.ps1.

Run headless:
  blender.exe --background --python tools/blender_export_glb.py -- <input.blend> <output.glb>

Modeling conventions every .blend must follow (enforced by review, not by this script):
  - Metric units, real-world scale (1 BU = 1 m).
  - Base of the object at Z=0, front facing -Y in Blender (= -Z in Godot).
  - Transforms applied (Ctrl+A) before saving.
"""
import os
import sys

import bpy


def main():
    argv = sys.argv
    if "--" not in argv:
        raise SystemExit(
            "Usage: blender --background --python blender_export_glb.py -- <input.blend> <output.glb>"
        )
    tail = argv[argv.index("--") + 1:]
    if len(tail) != 2:
        raise SystemExit("Expected exactly 2 args after '--': <input.blend> <output.glb>")

    src, dst = os.path.abspath(tail[0]), os.path.abspath(tail[1])
    os.makedirs(os.path.dirname(dst), exist_ok=True)

    bpy.ops.wm.open_mainfile(filepath=src)
    bpy.ops.export_scene.gltf(
        filepath=dst,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
    )
    print(f"[export_glb] {src} -> {dst}")


main()
