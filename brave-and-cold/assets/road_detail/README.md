# Original winter roadside asset bank

Original project-authored procedural fields, sign artwork and Blender assemblies. No downloaded/copied images or meshes, paid providers or new third-party asset licences. The system font is rasterized into sign artwork; no font file is redistributed. Godot/Blender may extract additional original sign image files during import/export; these remain derived from the authored PNGs.

The reusable source is tools/blender/generated/road_detail/winter_road_signs.blend. Run tools/roads/generate_road_fields.py with the existing terrain Python environment, then tools/blender/gen_road_signs.py using Blender --background --factory-startup --python. Output is this namespace. Regeneration replaces these generated outputs; source provenance and SHA256 hashes live beside textures and models.

All sizes are metres, +Y up in Godot, sign front +Z, origin at ground/post base. Warning plates are 0.88×0.88 m; speed plate is 0.60×0.78 m. Posts reach 2.67 m. Each sign has four draw surfaces and 474–482 triangles. UVs are explicitly authored for graphics. Textures are 1024 px with mipmaps; packed material data preserves alpha. Budget and import tests: tests/test_road_detail.gd.

Road routing, map heights, bridge geometry and signs' placement anchors are preserved by this bank. Appearance fallback: road_detail=baseline. See docs/design/ROADS_JUMP_REVIEW.md for verification, rejected iterations, remaining geometry work and recovery.
