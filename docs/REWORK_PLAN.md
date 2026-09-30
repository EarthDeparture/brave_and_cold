# Rework plan: existing prototype -> GDD architecture

## Verdict
Keep the repo, git history and Godot project shell. Treat all current gameplay code as a legacy prototype. Rebuild on the GDD architecture. Do not extend the prototype.

## What exists (audit)
Godot project (features string says 4.7, Forward Plus), about 40 scripts, 12 scenes, 16 review docs, custom test runner, rename-variable dev tool.
It is a single-cottage night-defense prototype: capsule zombie, boardable windows, fireplace, wood gathering, stamina, abstract warmth points, 4-minute day, 1000 m noise-mesh terrain, one snow/rock shader.

## Keep / port
- NoiseEvents autoload idea (signal with position + radius): keep, extend with noise type and surface.
- DayNight and Temperature as autoload pattern: keep the pattern, rewrite the model to GDD Section 9 (body temp, wind chill, wetness, insulation).
- Test-per-system habit and human-review checklists (docs/reviews): keep. Consider moving tests to gdUnit4 or GUT.
- .gitignore, .gitattributes, .editorconfig, dev_tools addon: keep.
- Door, window boarding, fireplace logic: reuse as reference for M4/M5 interaction design.

## Replace
- terrain_generator.gd (one 512x512 mesh over 1000 m = about 2 m per vertex, single mesh, no streaming, no collision LOD): replace with Terrain3D + mask pipeline + sector streaming.
- terrain_snow_rock.gdshader (slope/height blend, flat colors): replace with stylized painterly snow shader (GDD Section 3).
- Capsule zombie, flat navmesh with hard-coded bounds: replace with perception model + cost-grid pathing (GDD Sections 8, 11).
- Warmth points (0-100): replace with GDD meters.

## Problems found
1. Nested layout: git root is brave_and_cold, Godot project is brave-and-cold subfolder. Keep, but put tools/blender and docs at repo root.
2. Engine version 4.7 in project.godot: confirm the installed Godot and Terrain3D compatibility before M0.
3. Navmesh bounds hard-coded to the cottage: does not scale; discard.
4. Time scale 240 s/day is a prototype value; GDD default is 48 min/day.

## Steps
1. git mv existing scripts, scenes, shaders, models, tests into legacy/prototype_cottage/ (needs a shell; pending).
2. Create target folder layout (CLAUDE.md).
3. Install and verify Godot MCP + Blender MCP locally (pinned versions, reviewed).
4. M0: look-dev scene, stylized shaders, perf proof (500 m tile, 20k trees, 30 agents @ 60 fps).
5. M1: heightmap + mask pipeline -> Terrain3D, sector streamer skeleton.
