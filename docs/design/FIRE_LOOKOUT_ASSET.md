# Additive mountain fire lookout

## Delivered scope

An original, Python-generated Blender asset is now present in the playable Godot world at **x528, z−764**, yaw **30°**. It sits on a naturally open mountain shoulder at approximately **472.75m above sea level**, near the upper end of the existing 169–497m terrain range. Its glazed living room is **8.64m above the structure origin**; the roof reaches **12.77m**.

The timber tower has cross bracing, four continuous switchback stair flights, guarded landings, a connecting deck, a wraparound balcony, a snow-covered roof, and a furnished room. Bed, stove, desk lamp, radio, logbook and provisions are visual props. They do not yet provide sleep, heating, broadcasting, maintenance jobs or starting inventory.

Existing terrain, roads, trees, trails, buildings and default player spawn remain unchanged. The only existing script changes are optional height-aware player surface hooks and the world hook for the new structure, indoor fog, roof cover and elevated save restoration. The ground beneath the cabin remains outdoors and never snaps actors upstairs.

## Access and placement

The new **2m-wide maintenance footpath** joins the existing road at **x549.0067, z−259.44** and ends immediately in front of the stairs at **x533.0538, z−764.1465**. It follows a ridge already reached by the road. It is a surface overlay on unchanged terrain, added after the existing forest has finished generating.

| Survey result | Value |
|---|---:|
| Path length | 570.55m |
| Cumulative ascent | 55.81m |
| Maximum grade | 29.38% |
| 95th percentile grade | 22.53% |
| Minimum clearance from path centre to a trunk surface | 1.209m |
| Water crossings | 0 |
| Terrain relief beneath tower footprint | 1.193m |
| Existing trees removed | 0 |

This is credible walking access for a remote maintenance site. It is steep and narrow; it is not a vehicle logging road. Vehicle access would need a separate route assessment, wider bends and likely terrain/tree changes, which are outside this addition. Nearby trees remain, so some approaches obscure the tower. The room has an elevated valley view, rather than an artificially cleared panorama.

The runtime samples the existing Godot terrain beneath the first stair and sets the tower origin to that height plus 3cm (**world Y303.7298** in the verified run). The raster survey gives Y303.7542; the small difference comes from terrain sampling. Short added foundation piers accommodate the hillside instead of flattening it.

## Asset files and efficiency

- Generator: `tools/blender/gen_fire_lookout.py`
- Editable native source: `tools/blender/generated/fire_lookout.blend`
- Game model: `brave-and-cold/assets/models/buildings/fire_lookout.glb`
- Geometry and provenance receipt: `brave-and-cold/data/fire_lookout_geometry.json`
- Survey and route: `brave-and-cold/data/lookout_site.json`
- Godot traversal/placement adapter: `brave-and-cold/world/fire_lookout.gd`

Generated with Blender **5.2.2 LTS**, deterministic seed **2103**, in metres. Blender +Z is converted to Godot +Y during GLB export. The native source stays outside the Godot project so the editor imports the GLB rather than invoking Blender.

The GLB contains **6,790 triangles**, **13,524 exported vertices**, **seven mesh/material batches**, and **534,172 bytes**. Flat face colours account for the duplicated vertices. It uses no external textures or downloaded meshes. The path and hillside piers each use one additional mesh; the visual desk light has no shadow map. These are bounded asset costs, not a measured FPS improvement.

The Godot adapter duplicates only the tower's imported materials to enable vertex-colour albedo, matching the project's other generated buildings. It preserves linear colours and the imported glass alpha/depth-prepass settings. In-game renders caught and corrected the initial white-material import result.

## Verification

The final GLB validation confirms its receipt digest, bounds, finite positions, normals, vertex colours, 6,790-triangle budget and zero degenerate triangles.

**28 Godot checks passed**, including actual player movement up all four flights, landing turns, the upper connector and doorway, return to unchanged terrain, shelter at the room's elevation, rail/wall bounds, and JSON round-trip restoration through the actual world save-application routine. A crouched save restores the same floor while standing. Upstairs footsteps do not trample ground snow. The real user save slot was untouched.

A separate full-route check walked the actual player controller through **all 256 path waypoints**, from the existing road to the staircase entrance, with **zero movement blocks**. This exercised terrain grades, snow movement and the existing forest-trunk resolution, with hostiles disabled only for the diagnostic.

The runtime map survey before and after the addition matched all **1,024 road points**, **114,022 forest trunks**, **15 existing trails**, and **18 existing buildings** exactly. Only the lookout was appended to the building list. The default spawn remained **x−120.4435, z133.7661**. Terrain/map source hashes are recorded in the site receipt.

Blender exterior, rear and interior previews were inspected across multiple iterations, including landing guardrails and interior lighting. Actual Godot exterior, room and road-junction renders were also inspected. Local diagnostics are under ignored `shots/lookout/` and `brave-and-cold/shots/lookout/` directories. Godot runs completed with exit code zero; current Terrain3D deprecation and shutdown resource warnings remain in their logs.

## Reproduce and inspect

Use the installed Blender executable in background mode, without altering an open Blender session:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/blender/gen_fire_lookout.py -- --output-dir shots/lookout/source --preview-dir shots/lookout/previews --render
& tools/terrain/.venv/Scripts/python.exe tools/blender/validate_fire_lookout.py brave-and-cold/assets/models/buildings/fire_lookout.glb brave-and-cold/data/fire_lookout_geometry.json
```

Generation writes to the selected output directory. Copy the generated GLB, geometry receipt and `.blend` to their canonical paths together if intentionally updating the asset, then let Godot reimport it. The receipt includes the generator and model SHA-256 hashes.

Use your installed Godot console executable as `$lookoutGodot`:

```powershell
& $lookoutGodot --path brave-and-cold res://world/game_world.tscn -- lookoutpos=room
& $lookoutGodot --path brave-and-cold res://world/game_world.tscn -- lookoutpos=1 lookoutdist=8
& $lookoutGodot --headless --path brave-and-cold --script res://tests/test_fire_lookout.gd -- integration=1 zombies=0 wolves=0 bears=0 deer=0
```

The default game adds the tower without relocating the player. `lookoutpos=deck` is another inspection option. `lookout=0` disables the addition for comparison.

For a fresh read-only map survey, run `tools/terrain/export_lookout_baseline.gd` as an absolute `--script` path, with `--path brave-and-cold` and user arguments `lookout=0 zombies=0 wolves=0 bears=0 deer=0`. It writes the ignored baseline needed by `tools/terrain/plan_lookout_site.py`. Use `report=after` with the lookout enabled for the comparison survey. Re-running the planner deliberately rewrites the site manifest; it is not required to play or import the existing asset.

## Remaining gameplay work

This addition establishes a traversable elevated shelter. It does not establish a completed safe-zone system. Enemy navigation currently remains on the ground and does not follow the stairs or collide with the new support posts. The current bullet/world-hit code does not yet use the lookout walls as occluders. Those gaps must be resolved before relying on the structure for finished combat encounters.

Radio-tower maintenance, power supply, radio story progression, functional bed/stove/storage, safety-aware rest, a fenced refuge, and a new opening spawn remain separate work in `LOOKOUT_RADIO_IMPLEMENTATION_PLAN.md`. The constant desk light is a visual preview fixture; future power gameplay must own its availability. The path also needs a deliberate navigation cue if playtesting shows players missing its snow-covered entrance.
