# Frozen basin coverage and walking support

Two distinct faults caused the exposed stepped slab: the rendered mask stopped before the carved bank ended, and 9,574 border pixels were marked as water while their level was zero. Those zero values also created false walking walls when the player crossed between bed height and real ice height.

`tools/terrain/repair_ice_surface.py` derives a surface from valid nonzero authored levels. It reproduces Terrain3D's two 7-pixel terrain smoothing passes, fills missing levels from valid samples, smooths the level field by 1.5 m, and finds the connected below-level basin. The connected basin grows from 135,623 to 207,740 one-metre pixels. A 218,650-pixel support mask adds 1 m at the shore to cover partial grid cells smoothly. A separate 242,477-pixel render mask overlaps the bank by 3 m, burying the slab edge without extending gameplay eligibility across that wider dry overlap.

The original terrain, water mask and water levels stay unchanged. World planning uses those original files, then activates the repaired surface after building/camp placement and forest planning. Existing hut, camp, hamlet, store and lookout positions are preserved.

## Shared surface

`IceField` reads `ice_mask.png`, `ice_render_mask.png` and `ice_level.r16`. Walking and rendering use the same 2 m triangle height interpolation. Terrain support remains the maximum of terrain and ice. There are no nearest-pixel height steps or zero-level slabs. `WaterSurfaces` adds a clockwise top, underside 32 cm below it and closed bank walls, including cells at the map boundary. Flat patches are merged without changing coverage.

The final mesh has 64,560 cells, 44,312 top patches and 7,752 edge quads, or 192,256 triangles in one material/mesh. The stable integer-hash shader supplies blue ice, restrained fine fractures, windblown snow and a darker underside. Fishing holes retain their existing dark water disc/rim; they do not geometrically cut this ice mesh.

## Walking changes

The custom Node3D player controller now uses the same filtered support for its slope gate and camera height. Small terrain ripples no longer produce a steep invisible wall while the eye follows a different floor. Vertical following uses exponential smoothing, and long frames are split into bounded movement steps for collision and stair queries. Tree, wall, chest and lookout push-out logic, plus the steep-slope limit, remain in place.

## Verification

- `test_frozen_water.gd`: finite mesh, clockwise top/underside, closed thickness pairs, projected coverage and triangle height agreement with the walking field.
- `test_shore_walking.gd`: 14 former river/lake shoreline routes, both directions, at 30/60/120 FPS. It also drives the real controller up and down all ten lookout stair flights.
- `test_fire_lookout.gd`: elevated floors, stair/landing selection, walls, doorway, guardrail and save restoration.
- Existing `walktest=1` and `fishtest=1`: complete-world terrain/door walking and fishing/ice-camp behavior.

The verified 84 shoreline crossings have zero blocked movement frames. Maximum frame-to-frame vertical displacement is 18.2 mm at 30 FPS, 16.3 mm at 60 FPS and 8 mm at 120 FPS. The real controller climbs and descends all ten lookout flights without blocking. Complete-world walking, the cabin doorway, fishing, and the 24 lookout contracts also pass. GPU captures confirm the repaired shore reaches all four lake banks without exposed slab walls. These routes cover the diagnosed floor failures; they do not remove intentional collision with trees, buildings or steep terrain.

`ice_surface.json` records input hashes, generation parameters and coverage. Regenerate with `tools/terrain/.venv/Scripts/python.exe tools/terrain/repair_ice_surface.py`. New raw map files are covered by the existing export include filter. GPU captures are kept under ignored `brave-and-cold/shots`.
