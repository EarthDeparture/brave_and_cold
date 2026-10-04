# Original winter presentation assets

Production sources live under tools/blender and tools/atmosphere. This bank contains project-authored geometry, procedural textures and synthesized material audio. It uses no extracted game assets or external provider output.

- Trees: three spruce families, each with a near model and a matching distant crown. 2548–2860 near triangles, 306 distant triangles. Trunk roots, scatter transforms, felling and collision remain owned by ForestScatter.
- Textures: periodic powder snow, bedrock, forest snow, timber and irregular ice fields. Botanical spruce atlas has fine needles and accumulated snow. Terrain packing is RGB albedo + A height, RGB normal + A roughness. Ice channels are R fractures, G cloudiness, B drift, A bubbles.
- Sleeves: original Blender cloth geometry, 1720 triangles per sleeve, preserving cuff origin and 0.52 m forearm length. Existing hand anatomy/skeletons remain in use.
- Audio: wood and ice footsteps, sparse timber creaks and window rattles. These are original synthesized material events; existing recorded ambience and creature audio remain in use.

Each folder has a provenance receipt with hashes. Keep mipmap generation enabled for all material textures. Packed data textures must preserve their alpha channels and disable alpha-border colour fixing. The botanical atlas uses alpha-border fixing and shader cutouts.

From the repository root, regeneration uses:
1. Python with numpy, scipy and Pillow: tools/atmosphere/generate_environment_fields.py and generate_detail_audio.py.
2. Blender 5.2 background mode: tools/blender/gen_boreal_detail.py and gen_winter_sleeves.py.
3. Godot 4.7.2 editor import, then the documented capture/test scripts.

Source Blender files are in tools/blender/generated/environment_detail. Numbered Blender backup files are ignored.

The normal game enables this bank. The developer argument detail=baseline selects the accepted pre-detail foreground while retaining the winter atmosphere. atmosphere=baseline retains the earlier complete presentation option.

See docs/design/ENVIRONMENT_DETAIL_REVIEW.md for measured acceptance, review evidence and recovery instructions.
