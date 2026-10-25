"""Reopen the delivered editable Blender file and verify its real contents."""
from pathlib import Path
import json, hashlib, math
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/blender/generated/winter_tree_diversity_v1"
path = OUT / "winter_tree_library.blend"
bpy.ops.wm.open_mainfile(filepath=str(path))
manifest = json.loads((OUT / "manifest.json").read_text())
assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest["native_sha256"]
objects = bpy.data.collections["Export_UnitHeight"].objects
previews = bpy.data.collections["Preview_18m_RealScale"].objects
assert len(objects) == 10 and len(previews) == 5
checked = []
for entry in manifest["models"]:
    obj = objects[entry["name"]]
    assert obj.type == "MESH" and len(obj.data.materials) == 1
    assert tuple(obj.location) == (0, 0, 0) and tuple(obj.scale) == (1, 1, 1)
    assert obj.data.color_attributes.active_color.name == "Surface"
    assert obj.data.uv_layers.active.name == "SurfaceUV"
    assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles) == entry["triangles"]
    checked.append(obj.name)
images = [image for image in bpy.data.images if image.name.startswith("winter_")]
assert len(images) == 4 and all(image.packed_file and image.size[:] == (1024, 1024) for image in images)
assert all(tuple(obj.scale) == (18, 18, 18) and obj.data == objects[obj.name.replace("_18m_preview", "")].data for obj in previews)
report = {"schema": 1, "native_reopen": "passed", "blender_version": bpy.app.version_string, "editable_export_meshes": checked, "actual_scale_linked_previews": 5, "packed_original_images": [image.name for image in images], "native_sha256": manifest["native_sha256"]}
(OUT / "native_validation.json").write_text(json.dumps(report, indent=2) + "\n", newline="\n")
print("WINTER_TREE_NATIVE_PASS", len(checked), "editable meshes, 4 packed textures")
