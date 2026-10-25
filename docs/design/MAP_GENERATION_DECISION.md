# Map generation decision (M1 input)

Status: proposed, awaiting owner sign-off on region. Date: 2026-09-30.

## Options evaluated
| Option | Macro realism | Gameplay control | Look match (TLD) | Effort | Main risk |
| --- | --- | --- | --- | --- | --- |
| A. From scratch (noise + erosion in Gaea/Python) | Medium; drainage and ridges often look generic | Total | Easy to make smooth | Medium-High art time to make it feel natural | "Procedural" look; Gaea free build limited to 1024 px per build, tiled builds are paid |
| B. Raw real DEM, unedited | Highest | Very low | Poor: lidar micro-roughness fights the painterly look; steep, unwalkable, wrong pacing | Low | Unplayable slopes, no town site, no shelter spacing, open edges |
| C. Hybrid: real lidar base + stylize filter + authored gameplay overlay | High macro and meso realism | High | Good after smoothing | Medium | Region choice and data quality |
| D. Copernicus 30 m only | Medium | Medium | Faceted at 30 m posts | Low | Too coarse for first-person ground; fine only as far backdrop |

## Recommendation: C (hybrid)
Real lidar bare-earth DTM as the base layer (natural ridges, drainage, lake basins, glacial valleys), then:
1. Stylize: low-pass and snow-fill filter to remove micro-roughness (roots, boulders, strip noise) so forms read soft like The Long Dark.
2. Gameplay pass: slope walkability audit, nonlinear vertical compression where too steep, flatten and terrace the town site, carve rivers and lake bathymetry (lidar has no underwater data), raise map edges into natural barrier cliffs.
3. Authored overlay: POI layout, roads, shelter spacing (5-7 min walk), landmarks visible from open spots.
4. Derive masks from the same data: slope, curvature, aspect, wind exposure, flow accumulation, snow accumulation, and canopy height (DSM minus DTM) for real forest density.
5. Far terrain: Copernicus 30 m (or similar) for a real horizon out to 20-30 km, low-res mesh, fog-blended.
Scratch generation stays as the greybox and fallback (the existing noise generator moves to legacy).

## Verified facts
- Terrain3D imports EXR (real heights, 16/32-bit float, RGB) or R16; max 1,024 regions in a 32x32 grid; 8-bit heightmaps terrace. A 2048x2048 map at 1 m is trivially within limits. Installed: Terrain3D 1.0.2 (gdextension minimum Godot 4.4).
- NRCan HRDEM: 1 m or 2 m lidar DTM and DSM in southern Canada (coverage is per project, not edge-matched); north of the productive forest line only 2 m satellite-derived DSM. License OGL-Canada 2.0 (attribution required). STAC: datacube.services.geo.ca.
- USGS 3DEP 1 m: US coverage, public domain.
- Copernicus GLO-30: global 30 m surface model (includes trees and buildings), free with mandatory attribution.
- Gaea: commercial use allowed on all editions; free edition single build capped at 1024x1024; Indie $99.
- STAC test (2026-09-30) found 1 m DTM+DSM for: BC East Kootenay 2015 (Rockies), BC Squamish 2016, Quebec Gaspesie 2018 and 2020-21, Ontario Muskoka 2018/2019/2023. None found for a Yukon (Kluane) test box.

## Candidate regions (score before choosing)
| Region | Relief | Snow feel | Water | Notes |
| --- | --- | --- | --- | --- |
| Gaspesie, QC (Chic-Chocs) | Real mountains, rounded plateaus | Very deep snow, boreal | Rivers, sea inlet nearby | Best match to deep-snow pillar; unverified tile fit |
| Rockies, BC East Kootenay | Big relief, steep | Alpine | Lakes, rivers | Risk: too steep, footprint may not cover chosen window |
| Squamish/Whistler, BC | Big relief, coastal | Wet snow, coastal forest | Fjord, rivers | Different vegetation |
| Muskoka, ON | Low relief | Lakes and forest | Many lakes | Not mountainous; fails the peaks requirement, useful for lake/forest set pieces |

## Critical issues and mitigations
- Footprints are project bounding boxes: confirm real tile coverage and voids for the exact 2x2 km window before committing.
- Lidar water returns are unreliable: lakes come out flat or noisy; rebuild water surfaces and bathymetry by script.
- Real terrain can be unwalkable: run a slope audit (target most playable ground under 30 degrees) and remap heights.
- Buildings and structures appear in DSM: use DTM for ground; use DSM-DTM only for canopy and mask out buildings by height and area.
- Licensing: keep raw downloads out of git, record STAC item IDs and hashes, ship required attribution in credits. Do not use OpenStreetMap roads/buildings (ODbL share-alike risk); derive hydrology from the DEM and design roads ourselves.
- Reproducibility: the whole pipeline is a scripted, parameterized tool in tools/terrain (uv, Python 3.12 environment, rasterio, numpy, scipy), re-runnable end to end.
- The plugin's Windows debug DLL failed to load in one headless run (file-copy error, likely locked by an open editor). Re-test with the editor closed.

## Pipeline (tools/terrain)
fetch (STAC, cache) -> window select and score -> reproject to metric grid -> fill voids -> resample 1 m -> stylize filter -> water rebuild -> slope audit and remap -> edge barrier -> export EXR heightmap + masks -> Terrain3D import script -> sector streaming.
Acceptance: 2048x2048 EXR imports into Terrain3D, walks at 60 fps, hillshade reads as Long Dark-like rolling snow forms, slope audit passes.
