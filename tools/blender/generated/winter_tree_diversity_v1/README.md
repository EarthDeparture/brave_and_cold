# Winter Tree Diversity v1

Five original winter tree families augment the existing three spruce models. The supplied image guides silhouette, age and snow treatment; no reference pixels, downloaded trees, paid generation or external meshes are included. This uses the project's existing local Blender/Python pipeline. Hash verification and project admission are local receipts, not a claim that the unavailable game-dev CLI ran.

## Edit and reuse

Open **winter_tree_library.blend**. **Export_UnitHeight** contains ten editable single-mesh near/far objects at a 1 metre upright export height and identity transforms. **Preview_18m_RealScale** contains five linked near-mesh instances at actual 18 metre display height. Editing those linked meshes updates the corresponding export geometry. Four original 1024px textures and the preview material are packed into the Blender file. No plugins or downloads are needed.

The live forest scales these unit meshes to the existing lidar canopy heights, retaining every root, height, girth, yaw and trunk circle. The image does not establish absolute dimensions; the existing canopy scale supplies them. Blender is Z-up; GLB is Godot Y-up, rooted at the ground plane. Meshes export without collision or a glTF material because the live MultiMesh applies the shared boreal shader. A generic GLB viewer will not reproduce the foliage automatically.

Vertex alpha is a surface tag: .10 dark bark, .18 pale birch bark, .65 near needle atlas, .72 distant full-bough atlas, 1 solid snow. These are not material opacity values. The provided project shader uses UVs and the four texture bindings to supply cutout foliage, rough bark, tangent normal detail and solid snow. Native Blender materials implement the same tags for editing previews.

## Geometry

| Tree family | Near triangles | Far triangles |
|---|---:|---:|
| snow_pine_open | 3298 | 342 |
| snow_fir_full | 3730 | 418 |
| snow_spruce_wind | 3170 | 302 |
| snow_snag | 2120 | 700 |
| winter_birch | 1814 | 808 |

Near crowns use irregular primary branches, secondary sprays and closed resting snow caps. Distant conifers use an original composed full-bough atlas to preserve coverage on fewer planes; only the larger snow caps retain physical thickness. Deadwood and birch retain geometric branches. Source files, binary GLB validation and native reopening are independently checked.

## Live forest behavior

Pine and fir form smoothly varying stands. Wind-worn spruce favours upper slopes; leafless birch favours sheltered low patches; deadwood appears in pockets. Original spruce variants remain the majority. The habitat mask is derived independently from the same map seed, consuming no extra placement RNG calls. This is visual habitat selection, not a new ecological simulation or species-specific wood system.

Road, trail, building, water and lookout clearings remain governed by the existing exclusions. No new foliage/twig collision is introduced. Both detail levels disappear when chopped. Existing falling-tree, log, fuel, plank and saved-cut behavior stays intact. Tests compare all 115,845 potential map trees by coordinate and transform, all collision radii, all five new-family falls, duplicate cuts and fresh generation/save replay. The complete world has fewer trees after existing exclusions.

## Review and rendering cost

**previews/family-near.png**, **family-far.png**, **family-back.png** and branch close-ups are actual Godot renders. **world_comparison.png** compares matched lookout, route and weather views. The full corresponding images and capture manifests are preserved. Clear, overcast and dusk use matching camera/weather inputs.

Iterations corrected overly sparse tiered crowns, inadequate far birch spread, coarse snow stitching, missing bark detail, excess crown width and excessive distant conifer geometry. Far coverage uses its own atlas rather than a heavily thinned copy of near foliage. The shared shader avoids sampling an unused old twig texture on new foliage or any twig texture on opaque bark/snow.

The richer crowns and additional species groups still cost more to render than the original bank. These measured observations use a frozen 1600x900 world, AI disabled, Vulkan Forward+ on the GTX 1080 Ti; they do not establish full gameplay frame rates.

| View | Original median ms | Diverse median ms | Diverse p99 ms |
|---|---:|---:|---:|
| clear-lookout | 9.90 | 13.43 | 14.55 |
| clear-forest | 8.01 | 10.33 | 10.83 |
| clear-bough | 7.32 | 10.57 | 11.25 |
| overcast-forest | 8.13 | 10.46 | 11.02 |
| dusk-forest | 6.80 | 8.15 | 9.15 |

The existing near/far visibility overlap is retained. This package does not claim to solve all forest LOD transitions, terrain presentation or whole-game performance. Tests use the real Vulkan renderer: Godot's dummy headless renderer cannot supply the MultiMesh transform storage required by this contract. Existing editor/runtime shutdown RID leak diagnostics remain in the project; no gameplay script error is accepted in the contract reports.

## Rebuild and rollback

Use the existing Python environment for gen_winter_tree_atlas.py, Blender 5.2 for gen_winter_tree_diversity.py with --python-exit-code 1, then validate_winter_trees.py --admit. Reopen with verify_winter_tree_native.py. Import the Godot project; run tests/visual/tree_diversity_review.gd, test_tree_diversity.gd, test_environment_detail.gd and test_lookout_radio_logs.gd with the real renderer. Capture matching worlds with forest_diversity=baseline and default diversity using capture_atmosphere.gd, then package_winter_tree_review.py.

The live launch option **forest_diversity=baseline** selects the previous three-spruce presentation without changing terrain or saves. The scoped tree-diversity commit can be reverted independently; the parent checkpoint is **42f6b97**. Original tree mesh hashes are retained and verified in admission_receipt.json. No push is made.

package_hashes.json records every delivered source/package file except itself and disposable logs/Blender backups. Live copied-byte integrity is separately recorded in the project admission receipt. Engine rendering, geometry validation and artistic approval are separate evidence stages; user playtest/art approval remains the next review.
