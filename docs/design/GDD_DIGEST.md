# Brave and Cold — GDD Digest v0.2

Full GDD (16 sections, tables and numbers): https://claude.ai/code/artifact/af88c9f0-384a-4dd8-92b4-c30ceb813875
Copy of this digest is also in the Claude project docs (claude/gdd-digest.md).

## Stack (decided)
Godot 4 (Forward+) + typed GDScript. Blender + Python generators (headless batch, glTF export, LOD/impostor bakers, manifest + validation). Terrain3D. Local MCP servers: Godot MCP, Blender MCP.
Godot gaps: no ECS/crowds -> hard zombie caps, MultiMesh+VAT crowd LOD, GDExtension for hot loops. No world streaming -> own 250 m sector streamer. Snow near-field via compute shader. Nav via custom cost grid.
M0 gate: 500 m tile, 20k trees, 30 agents @ 60 fps, else fall back to 1x1 km.

## Pillars
1 Cold is the constant clock. 2 Quiet dread, beautiful world. 3 Snow is a system. 4 Everything costs. 5 Systems interlock (fire = warmth AND beacon). 6 Stylized so we can ship.

## Look
Painterly: hand-painted albedo, low-medium poly, sky-driven light, warm/cool contrast, blue shadows, heavy fog, soft snow (~92% luminance cap), per-time-of-day LUT. Not photoreal. Look-dev gate before production art.

## MVP-1 Map Slice
2x2 km valley, 350-450 m relief, 7 biomes, 14 POIs, >=8 building types (>=6 interiors), snow to waist, weather/day-night, cold+fire+survival, gather/hunt/cook. Zombies at M8.
Order: M0 look-dev + Godot proof, M1 terrain, M2 vegetation, M3 snow/weather, M4 buildings, M5 survival, M6 hunting, M7 predators, M8 zombies, M9 crafting/wounds, M10 skills.

## Snow
Depth field 0.5 m cells, tiers 0-5. Zombie speed by tier 100/95/75/50/30/20%. Trampled = 2 tiers shallower for all. Trails are highways AND trackable (~90 s / 120 m). Deer sink, wolves don't. Snowshoes -2 tiers.

## Survival
Body temp 37 C (hypothermia 35, fatal 28), condition, calories 2500/day (+50% cold), hydration, fatigue, stress. Layered clothing: warmth, windproof, waterproof, wetness. Fire = warmth + light/smoke signature attracting zombies.

## Zombies ("the Turned")
Sight 25 m day / 10 m night. Noise radii: walk 8, run 18, axe 45, gunshot 150. Types: Walker, Frostbitten (dormant ambush), Crawler; later Heavy, Sprinter. Cold slows them. ~200-250 total, dense in town. Bite = infection 24-48 h, rare cure.

## Fauna
MVP-1: rabbit, ptarmigan, deer, fish, raven. M7: moose, goat, wolf, bear. Wind scent, predator struggle, harvest -> cook -> preserve.

## Open decisions
Bite outcome, cold-on-zombies, death model, map size fallback, art sourcing. No multiplayer in MVP.
