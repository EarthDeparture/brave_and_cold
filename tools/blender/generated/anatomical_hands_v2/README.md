# North Ridge / Anatomical Hands v2

Original bare right and left hands built in Blender from the supplied anatomical topology reference. The source image guides proportions, thumb-web topology and finger joint loops; its pixels and any third-party mesh are not used in the assets. This is a standalone replacement candidate. The live game hands, gloves and weapons are unchanged.

## Open and inspect

Open **anatomical_hands.blend**. Both hands are separated for inspection in the native scene, with original hidden **EditableQuadCage_Right / Left** objects. These are editable base cages, not live modifier drivers of the final baked skins. The skin meshes retain UVs, weights and corrective shape keys. The three original 2048px maps are packed in the source and embedded in **godot/anatomical_hands.glb**.

In Blender's Text Editor select **Preview_Hand_Poses.py**, set CLIP to one of the names below, Run Script and play the timeline. The helper selects the matching bone and corrective actions with their Blender 5.2 action slots. Named NLA tracks retain the export grouping. The helper is also shipped in the source folder. Turn viewport overlays on to inspect/select bones, then enter Pose Mode.

## Anatomy and scale

Godot uses metres, wrist origin (0,0,0), fingers toward -Z, dorsum +Y and forearm +Z. Each GLB rig is independently wrist-local at the origin. Native rigs are offset +/-0.11m on Blender X for inspection. Skin spans 182.9mm from wrist to middle fingertip and 94.1mm from wrist toward forearm. The open-hand span including thumb is 134.1mm; maximum dorsum-to-palm thickness is 32.9mm. These are authored adult-scale proportions, not measurements recoverable from the reference image.

Each hand has continuous connected skin through the palm, finger webs and thumb saddle. Palm pads, staggered knuckles, tapered phalanges, rounded fingertips and a wrist transition are modeled. Nails are five separate curved, closed plates fitted to the actual skin surface and weighted to the distal bones. Finger joint loops and the thumb web remain visible in the retained cages.

| Part | Triangles per hand | Skinning |
|---|---:|---|
| Bare skin | 29,792 | Maximum four normalized bone influences per vertex |
| Five curved nail plates | 590 | Distal finger/thumb bones |
| Editable base cage | 943 vertices / 922 faces | Authoring geometry, excluded from GLB |

Both visible hands total 60,764 triangles. This is a close-up viewmodel asset; world and distant character versions should use a separate reduced mesh. This package has no world LODs or collision.

## Rig and animation contract

Two 17-bone armatures: forearm, hand/wrist, three joints for each of four fingers and three thumb joints. Left geometry, normals and bone axes are mirrored explicitly without negative root scale. Eight corrective shapes per skin preserve volume under linear skinning.

Nine one-second pose clips: **Open, Relaxed, Fist, Shaft, Trigger, Support, Bolt, PinchReady, Magazine**. **FlexCycle** is a 2.6-second open–relaxed–fist–open motion. Trigger keeps the index finger extended away from the trigger; a deliberate trigger press needs a separate fitted pose. PinchReady is a preparatory shape, not a claim that the pads touch. These are generic pose foundations. Each weapon/tool still needs wrist placement, contact fitting and synchronized manipulation/reload animation.

The GLB includes bone and matching corrective animation channels. Blender 5.2's NLA exporter cached the FlexCycle morph values as a constant; **export_hand_morph_tracks_v2.py** explicitly samples the authored shape-key curves at the same 30fps frame times as the bone export. Static and animated morph tracks are checked independently and exercised in Godot. Import/re-export of this file from another tool should be revalidated.

## Surfaces

Original 2048px albedo, roughness and OpenGL +Y tangent-space normal maps. Atlas islands are separated by anatomical regions with extended mip gutters. Skin pigment, palm/wrist/joint creases, slight dorsal veins, knuckle colour and fine pores are authored in model space and rasterized into the UV atlas. Normal-map slopes use physical UV derivatives. Nails use a separate muted pink, rough material. Blender adds shallow subsurface scattering; Godot receives the exported PBR maps and should be judged under the actual game lighting during later integration.

## Validation

**validation.json** checks the final binary GLB, source/export hashes, closed geometry, connected skin, positive winding, UV bounds, normals, four-weight limits, inverse bind matrices, embedded maps, mirror dimensions and all ten bone/morph clips. FlexCycle must carry changing morph values with zero corrections at its endpoints and full fist corrections during its hold.

**pose_audit.json** reopens the native file and checks nine static poses per hand plus 40 samples per hand through FlexCycle. No non-neighbour skin triangle intersections were detected in those tested poses/samples. This is bounded validation, not a guarantee for arbitrary future bone rotations or weapon contact.

**native_validation.json** exercises all ten clips using the embedded Blender preview helper and checks packed maps and both editable cages. **godot/engine_validation.json** records actual Godot 4.7.2 import, two skeletons, bind paths, bone movement and corrective playback. The isolated fixture produces actual Forward+ Vulkan GPU captures on the GTX 1080 Ti. Blender and Godot previews depict the asset itself; none are image-generation mockups.

## Rebuild and next fitting step

The source folder preserves the new authoring, export, render, validation and preview scripts plus exact reused project helpers. The supported rebuild layout is the repository's **tools/blender** directory, with output at **tools/blender/generated/anatomical_hands_v2**. Run Blender in background with **gen_anatomical_hands_v2.py -- --render**, then **finalize_anatomical_hands_v2.py**, the native audits and Python GLB validator. The original user reference path is used only to hash provenance; if rebuilding elsewhere, update it to the same local reference or retain the recorded provenance hash. No paid provider, downloaded model or Blender addon is required. Python binary validation/package review uses numpy and Pillow from the existing terrain virtual environment.

For engine review, import **godot/project.godot**, then run Godot with **--path [that folder] --rendering-method forward_plus --script res://review.gd**. This is an automated capture/validation fixture, not a gameplay scene.

Before live replacement: fit wrist/cuff alignment and first-person framing; rebuild the glove variant on this anatomy; fit each item's finger pads and thumb contact; author trigger press, bolt, magazine and support-hand transitions against the actual moving weapon parts; then check clipping during reload cancellation and viewmodel movement. Existing live grips use a 16-bone rig; this candidate adds an independent forearm bone and requires an explicit integration review.

The package hash roster verifies its exact contents. The ZIP excludes engine caches, temporary import textures, build logs and Blender backups. This is a local offline Blender asset package, not a game-dev CLI canonical seal or admission receipt.
