# Articulated first-person hands

The live renderer now uses `survivor_hand_rig.glb`. The earlier six fixed-pose meshes are legacy references and are no longer loaded by the viewmodel.

The Blender source has a continuous quad palm, shared finger webs, an integrated thenar/thumb opening, tapered phalanges, rounded pads, a rounded metacarpal arch, individual dorsal tendon ridges, staggered knuckles and skinning loops around the bend joints. The fist thumb rests across the curled fingers. Each hand has a wrist/palm bone and three bones per digit: 16 bones per hand. Both sides have their own correctly oriented mesh, outward winding and skeleton; runtime uses no negative scales. Skin and glove variants share the same weighted anatomy.

## Runtime integration

`SurvivorHandRig` imports the Blender grip clips and retains rest rotations for constant tracks Godot removes. This is essential for the wrist's orientation. `Viewmodel` blends bone rotations and wrist transforms during the rifle bolt reach and return instead of swapping rigid hand shapes. Cuffs stay anchored at the active wrist, with sleeves aimed toward hidden elbows.

The six reusable poses are Open, Fist, Shaft, Trigger, Support and Bolt. They cover every current persistent viewmodel: fists/jab, hatchet/chopping, rifle carry/aim/recoil and bolt cycling. Shaft is reusable for another similarly sized handle, and Support for another long gun. New items still require fitting their wrist transform and grip against their actual mesh. Knife, hammer, flare and other inventory items currently have no persistent equipped viewmodel; this change does not add those gameplay modes. There is no general finger IK solver.

The current inventory hands slot selects bare skin or the shared two-tone leather glove for `hide_mitts` and `wolf_mitts`. Skin paint includes palm and joint creases, knuckle tint, nail tint and restrained grain. Glove paint includes cream backs, brown palms/tips, weathering and seams. Four embedded 2048-square albedo/normal textures are shared across both hands. Sleeves retain olive cloth, wool cuffs and the existing neutral fabric texture. All geometry and paint are original; the supplied references guide the style without supplying asset data.

Damage, ammunition, action costs and combat timing remain unchanged. The previously requested faster work swing is retained. Rifle carry framing was adjusted to expose the grips; fully aimed sight alignment remains the same.

## Sources

- Generator: `tools/blender/gen_hand_rig.py`
- Material generator: `tools/blender/hand_materials.py`
- Native editable file: `tools/blender/generated/hand_refinement/survivor_hand_rig.blend`
- Runtime export and provenance: `brave-and-cold/assets/models/viewmodel/survivor_hand_rig.glb` and adjacent JSON
- Exported-byte validation: `tools/blender/validate_hand_rig.py`
- Runtime verification: `brave-and-cold/tests/test_viewmodel.gd`

Generate with Blender 5.2 using `--background --factory-startup --python-exit-code 1 --python tools/blender/gen_hand_rig.py -- --output-dir tools/blender/generated/hand_refinement`. Run the validator against the exported GLB and JSON, copy both into the runtime folder, then import in Godot. The native file opens with one readable bare right hand; hidden variants remain available for editing.

## Validation and limits

Each skin/glove hand has 27,872 triangles. At most two hand skins and two sleeves draw: 56,496 triangles, excluding tools. The asset stores four skins and two sleeves, with two 16-bone skeletons. The GLB validator checks real exported bytes, embedded textures, finite/unit normals, normalised weights with at most four influences, joint indices, inverse bind matrices, closed welded topology, connectivity, nonzero triangle area and outward winding.

The Godot test checks bind-pose fidelity, actual CPU skin deformation for all grips, native mirrored joint motion, thumb contact targets, joined cuffs throughout swings and the bolt cycle, clothing appearance, dry firing, death/revival and work/combat timing. Captures review bare and gloved variants under both studio and game lighting, including aiming, recoil, bolt cycling, sprint and zoom.

The final export passes the byte/topology validator and all 16 runtime checks. Bind geometry error is below 3 micrometres; fitted thumb-target error is below 0.24 mm. These are numerical rig checks, not proof of physically correct contact with every point on each item.

These are original stylised hands, not an exact reproduction of The Long Dark's production assets. Human playtesting remains the final judgement of anatomy, sleeve transitions and screen coverage. The geometry and integration tests establish functional correctness; they do not establish equivalent commercial art quality.

## October 4 refinement

The current version 6 source widens the wrist, reduces the inflated dorsal palm, refines finger pad profiles and gives the glove a gathered cuff and stitched reinforcement. Thumb rings now follow the palm opening in the correct order; the previous half-twist caused visible thumb-web inversions. Five pose-specific corrective morphs preserve bent joint volume under Godot linear skinning, with native left/right mirroring and the existing grip bones/contact targets retained. The runtime blends both skeleton rotations and corrective weights. See WALK_SURFACE_REVIEW.md and the adjacent validation receipt for the current 14 rendered item poses, motion evidence and tests. The old native source is retained in hand_rig for historical recovery.
