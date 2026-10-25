# North Ridge / Weapon Art Kit v1

Eight original fictional firearms inspired by the supplied visual sheet, plus seven matching spare magazines, one visual round, one spent case and one loading strip. Created locally with Blender 5.2.2 and Python; no downloaded meshes, paid services or addons. All dimensions below are final vertex measurements at a 1 metre unit scale. The reference image supplies appearance guidance, not reliable absolute dimensions.

## Open and edit

Open **north_ridge_weapon_library.blend** for the actual-scale library. Individual **source/*.blend** are normal editable scenes with packed original textures. **godot/*.glb** embed their textures, named component nodes and animations. The isolated **godot/project.godot** and **gallery.gd** exercise imports and render review images. The live game is unchanged.

In Blender, select **Preview_Clips.py** in the Text Editor, set ASSET and CLIP at the top, then Run Script and play the timeline. The helper binds the matching component actions and their Blender 5.2 action slots directly; it restores the saved resting transforms on every selection. Named NLA tracks remain the export grouping. Their native export sampling state is not used as the preview mixer. Spare props have no animation clips.

## Scale and attachments

Godot uses +Y up and -Z muzzle forward. Blender uses Z up, with +Y muzzle forward. Weapon origin is a trigger-hand reference rather than a ground-resting pivot. Socket_HandR and Socket_HandL are animated wrist reference targets. Socket_TriggerFinger, Socket_BoltHand, Socket_MagazineHand, Socket_MagazineInsert, Socket_Aim, Socket_Muzzle and Socket_Ejection identify handling and effects locations; the lever rifle also has Socket_LoadingGate. Asset IDs prefix every node. Attachment records include parent-local transforms and composed rest positions in weapon-root space.

Rigid components use Pivot nodes with attached meshes, not one merged static weapon. Bolts, charging handles, triggers, magazine releases, safeties and magazines stay independent; the carbine includes a bolt handle, the lever gun its lever/loading gate, and the compact rifle its folding stock. Safety controls are editable pivots, with no safety-toggle animation authored. No collision is exported. Use simple pickup collision shapes for world weapons and no player-blocking collision for held copies.

## Contents

| Asset | Width x height x length (m) | Triangles | Clips |
|---|---:|---:|---:|
| ridge_scout_rifle | 0.079 x 0.236 x 1.094 | 6758 | 8 |
| timber_bolt_carbine | 0.094 x 0.217 x 0.964 | 6786 | 8 |
| ranger_box_rifle | 0.079 x 0.253 x 1.024 | 6606 | 8 |
| brush_lever_rifle | 0.072 x 0.269 x 0.974 | 7050 | 9 |
| frontier_vented_rifle | 0.080 x 0.234 x 1.054 | 7462 | 8 |
| north_service_rifle | 0.079 x 0.282 x 1.064 | 7422 | 8 |
| compact_patrol_rifle | 0.082 x 0.292 x 0.877 | 6982 | 10 |
| expedition_rifle | 0.079 x 0.282 x 1.114 | 7838 | 8 |
| ridge_scout_rifle_spare_magazine | 0.039 x 0.114 x 0.084 | 972 | 0 |
| timber_bolt_carbine_spare_magazine | 0.039 x 0.099 x 0.084 | 972 | 0 |
| ranger_box_rifle_spare_magazine | 0.039 x 0.144 x 0.084 | 972 | 0 |
| frontier_vented_rifle_spare_magazine | 0.039 x 0.114 x 0.084 | 972 | 0 |
| north_service_rifle_spare_magazine | 0.039 x 0.134 x 0.094 | 972 | 0 |
| compact_patrol_rifle_spare_magazine | 0.039 x 0.164 x 0.094 | 972 | 0 |
| expedition_rifle_spare_magazine | 0.039 x 0.164 x 0.094 | 972 | 0 |
| visual_rifle_round | 0.011 x 0.011 x 0.050 | 264 | 0 |
| visual_spent_case | 0.011 x 0.011 x 0.035 | 204 | 0 |
| round_loading_strip | 0.057 x 0.011 x 0.054 | 1428 | 0 |

## Animation contract

67 exported clips in total. Every weapon has idle, fire, cycle, inspect, equip and unequip. Seven detachable-magazine weapons have reload_tactical and reload_empty. The lever weapon instead has reload_start, reload_insert and reload_end; reload_insert can repeat, retaining the tilt and matching the preceding/following wrist targets. The compact rifle also has stock_fold and stock_unfold. Durations and events are quantised to the actual 30 fps keyframes and recorded separately in manifest.json.

Tactical reloads detach a magazine, carry it out of the view area, return and reseat. The magazine_exchange_out_of_view marker permits a future runtime magazine resource swap; the art reuses the same mesh. Empty reloads also operate the action. The lever insertion exposes a temporary visual round and moves the loading gate. Self-loading fire clips include action movement and case ejection; bolt/lever rifles use a separate manual cycle. Ejection and insertion props hide using a tiny nonzero scale, preserving invertible transforms and their geometry through export.

Events are metadata rather than gameplay callbacks. magazine_seated, round_inserted and reload_complete must be connected to the existing inventory/ammo state machine deliberately. Reload cancellation must preserve already completed resource transfers and restore or persist the current magazine/action state. Avoid awarding ammunition when a clip merely starts or an inspect action plays. Held props and ejection display meshes are visual state, not duplicate inventory items.

## Surface and geometry policy

Original 1024px albedo, roughness and OpenGL +Y normal maps for three woods, blued steel, lighter steel, brass and rubber, plus eight original receiver markings. Textures are packed in Blender and embedded in GLB exports. Static surfaces share meshes by material within each rigid component. Each weapon is under 8,000 triangles; the full 18-asset kit totals 65604 triangles. Barrel muzzles are recessed openings, the vented shields have actual holes and wall thickness, and the receiver shells have bounded action recesses.

## Verification and review

validation.json independently checks the GLB binary structure, exact hashes, actual vertex dimensions and bounds, finite unit normals/UVs, embedded textures, non-degenerate triangles, component names, all clip names, key times, nonempty movement and duration/event contracts. native_validation.json records reopening all 18 normal Blender scenes, packed textures and exercising all component action clips with the shipped preview helper. godot/engine_validation.json records actual Godot 4.7.2 import and motion for all 67 clips, magazine detachment/reseating and visible uncollapsed case geometry. Forward+ Vulkan GPU renders ran on the GTX 1080 Ti.

previews/contact_sheet.png shows Blender output; godot_contact_sheet.png and left/right close-ups show actual Godot rendering. Three storyboards show reload phases; reload_extras.png shows the detachable props. Panels preserve proportions but normalise display size. Iterations corrected stock/trigger gaps, overlarge ports, repeated action controls, hidden-prop geometry collapse, native rest-pose export side effects, Blender action preview bindings, stock variety and receiver identities.

## Gameplay integration still required

These assets are prepared and validated separately from the player viewmodel. Animated wrist targets are not skinned hand animations. Each design still needs palm/finger fitting, magazine and bolt hand contact, wrist/elbow reach checks, ADS camera alignment and player-camera clipping review with the existing hand system. Reload/firing sounds, muzzle/impact effects, runtime ammo transfers and interruptible weapon state are not implemented by this pack. The current single-rifle offsets cannot be assumed to fit all eight designs.

Review first-person lighting and texture density at the real gameplay field of view before selecting final weapon offsets. Decide which firearms belong in the Canadian survival setting and their loot/ammo balance before admission. Use a smaller world-pickup representation/LOD when many are visible; this pack supplies the editable near-view geometry, with no separately authored world LOD tiers. No gameplay performance result or human playtest is claimed by the isolated GPU check.

## Rebuild

Use the repository scripts in tools/blender: gen_weapon_kit_textures.py with the existing Python environment; gen_north_ridge_weapons.py in Blender with --render; finalize_weapon_kit_sources.py; verify_weapon_kit_native.py; validate_weapon_kit.py and prepare_weapon_kit_review.py with Python. Import the isolated Godot project to completion, then run gallery.gd with --rendering-method forward_plus. Finally run package_weapon_kit.py. Included build_scripts copies record the pipeline; root resolution expects their original repository locations. The mesh/PBR helper prefix and GLB binary reader come from our preceding original survival-kit tools.

## Integrity and rollback

All new geometry, surfaces and printwork are original project work; the user image is recorded by hash and excluded from distribution. package_hashes.json lists exactly the delivered package files. The ZIP contains that roster and the hash list. Disposable import caches, extracted PNGs, logs, local iteration sheets and Blender backups are excluded. Reverting the scoped asset commit removes this package and its tools; live gameplay and map files are not part of the change. No push is made.
