# North Ridge / Field Survival Kit v1

32 original props and state variants, created with local Blender 5.2.2/Python from the user-provided visual reference. Includes its survival-equipment categories plus two matching removable pot lids.

## Open and edit

Open **field_survival_library.blend** for the complete collection at actual metre scale on a spaced grid. Each asset also has an opening-ready individual scene under **source/**, with original textures packed. **godot/*.glb** are independent portable Y-up exports with embedded PBR textures. **previews/contact_sheet.png** normalises panel size for comparison; it does not show relative physical scale.

Front is +Z, height is +Y in Godot; tools are upright along +Y. Blender uses its normal Z-up coordinates and a 1 metre unit scale. Resting geometry stays within 2 mm of Y=0. Dimensions below are measured from the actual final vertices, including handles, caps and the extended radio antenna. Physical sizes were selected for plausible use; the sheet cannot establish absolute scale.

Each moving component keeps an asset-prefixed Pivot node. Socket nodes mark grip, carry, mouth, beam, back attachment or working contact locations. Use the exact names and local transforms in the GLB, rather than relying on mesh order. These are rigid component pivots and attachment markers; character hand skinning is a separate system.

## Contents and dimensions

| Asset | Width x height x depth (m) | Triangles |
|---|---:|---:|
| propane_cylinder | 0.324 x 0.502 x 0.324 | 3092 |
| canvas_backpack | 0.566 x 0.681 x 0.328 | 10124 |
| jaw_trap_open | 0.465 x 0.062 x 0.308 | 6988 |
| jaw_trap_closed | 0.465 x 0.149 x 0.308 | 6988 |
| camp_pot_large | 0.378 x 0.178 x 0.284 | 2300 |
| camp_pot_small | 0.270 x 0.070 x 0.176 | 2300 |
| skillet_large | 0.270 x 0.048 x 0.440 | 816 |
| skillet_small | 0.172 x 0.048 x 0.302 | 816 |
| water_bottle_tall | 0.068 x 0.260 x 0.068 | 840 |
| water_bottle_short | 0.075 x 0.205 x 0.075 | 1080 |
| fuel_jerrycan | 0.255 x 0.449 x 0.149 | 1730 |
| first_aid_case | 0.255 x 0.254 x 0.102 | 1620 |
| portable_radio | 0.300 x 0.470 x 0.107 | 3430 |
| matchbox_closed | 0.056 x 0.019 x 0.075 | 326 |
| matchbox_open | 0.056 x 0.019 x 0.098 | 1034 |
| field_flashlight | 0.050 x 0.204 x 0.050 | 3440 |
| battery_aa | 0.015 x 0.051 x 0.015 | 396 |
| battery_d | 0.034 x 0.062 x 0.035 | 396 |
| field_compass_closed | 0.058 x 0.018 x 0.072 | 1764 |
| field_compass_open | 0.058 x 0.068 x 0.090 | 1764 |
| food_can_beans | 0.075 x 0.111 x 0.075 | 1544 |
| food_can_soup | 0.075 x 0.111 x 0.075 | 1544 |
| food_can_fish | 0.075 x 0.111 x 0.075 | 1544 |
| food_can_fruit | 0.075 x 0.111 x 0.075 | 1544 |
| rolled_bandage | 0.058 x 0.050 x 0.058 | 1816 |
| field_shovel | 0.214 x 1.049 x 0.044 | 840 |
| hunting_knife | 0.037 x 0.270 x 0.021 | 516 |
| woodcutting_hatchet | 0.211 x 0.556 x 0.043 | 524 |
| improvised_stone_axe | 0.164 x 0.580 x 0.052 | 3444 |
| rescue_hatchet | 0.211 x 0.446 x 0.043 | 524 |
| camp_pot_lid_large | 0.284 x 0.043 x 0.284 | 812 |
| camp_pot_lid_small | 0.176 x 0.043 x 0.176 | 812 |

## Surface and geometry policy

Original shared 512px surface maps for cloth, cotton, leather, wood, stone, enamel, rubber and metal; readable original 1024px packaging and a 1536x256 radio strip. Normal maps use OpenGL +Y. Images are embedded in the GLBs and packed into native scenes. Geometry budgets: at most 24,000 triangles and eight materials per prop. Final total: 66708 triangles. The largest model is the 10,124-triangle backpack. Meshes remain separate only where materials or moving components need that separation.

Cooking vessels have continuous thick walls and open cavities. The first-aid case has a hollow body and front-bottom lid hinge. Trap jaws share the same mechanical hinge axis between open/closed variants. Compass lid and needle remain independent; closed lid hides the needle. Match tray slides; bottle caps detach; radio antenna and tuning knob remain adjustable.

No rigid-body mass, collision meshes, interaction scripts, fuel functionality or inventory entries are added by this asset package. World placement should use simple engine collision shapes; hollow vessels/cases need compound shapes if their cavities matter. Held/inventory copies should have no player-blocking collision. Existing maps, held models, saves and gameplay code are unchanged.

## Validation and review

validation.json independently checks GLB structure, exact hashes, vertex dimensions, finite unit normals, UVs, embedded textures, non-degenerate triangles and named pivots. native_validation.json records reopening all 32 individual Blender scenes and checking metre scale, packed textures and dimensions. godot/engine_validation.json records actual Godot 4.7.2 import, metre dimensions, named sockets and moving each Pivot with its attached vertices. Forward+ D3D12 previews were rendered on a GTX 1080 Ti; this is an isolated art/import review, not a gameplay performance benchmark.

Reviewed iterations corrected the tank collar, backpack body, curved labels and mirrored tin print, closed-compass overlap, trap hinge placement, excess small-prop triangles, radio label aspect, and the medical case cavity. Final Blender contact sheet and Godot close-ups show the shipped shapes. Live held-item integration still requires fitting each tool to the existing hand poses and confirming reach/contact in player-camera views. Mass and resource balancing should continue to use the existing gameplay definitions.

## Rebuild

Run the original scripts under tools/blender from the repository root: generate textures; run gen_field_survival_kit.py in Blender with --render; run finalize_field_kit_sources.py; refresh_field_kit_radio.py; refine_field_kit_case.py; verify_field_kit_native.py; run validate_field_survival_kit.py and prepare_field_kit_review.py with the existing Python environment. Import the isolated godot/ project and run gallery.gd for GPU checks, then package_field_survival_kit.py. The included build_scripts/ copies are provenance copies; the original repository paths preserve root resolution. No downloaded addons or asset services are required.

## Provenance and package integrity

All new geometry, printwork and surfaces were authored locally for this project. The user reference image is recorded by hash and is not included. package_hashes.json binds the delivered Blender, GLB, source, texture, metadata and preview files. It excludes disposable Blender backups, import caches and logs. The ZIP contains precisely that roster plus the hash file. No push was made.
