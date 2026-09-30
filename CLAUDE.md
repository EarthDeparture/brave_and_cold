# Brave and Cold — repo rules for Claude

Game: 3D first-person survival horror. Look and survival feel of The Long Dark, zombie systems of Project Zomboid, deep snow as a core system. Full design: docs/design/GDD_DIGEST.md (living doc link inside).

## Working rules
- Chat replies in caveman mode (short, minimal words). Files and code written normally.
- Be extremely critical of own work. Check every asset/scene against the Long Dark look (painterly, soft snow, blue shadows, fog). If it looks generic, redo.
- Stack: Godot 4 (Forward+), GDScript with static typing everywhere. Blender + Python for assets. Terrain3D for terrain (verify version compat first).
- Own assets only. Never rip from other games. Every asset gets a manifest entry (source, license, seed).
- Data-driven: items, recipes, animals, zombies, clothing in Resource (.tres) or JSON.
- Global services are autoloads (GameClock, NoiseBus, SnowField, Weather, Save). Systems talk via signals + typed APIs.
- Every system testable in a blank scene. Add a test with each system. Add debug overlays with each system.
- Performance: 60 fps 1080p on GTX 1660 / RTX 2060 class. Budgets in GDD Section 4. Benchmark on the fixed path each milestone.
- Milestone order is strict (GDD Section 5). Do not build later systems early.
- Legacy prototype lives in legacy/ (cottage-defense prototype). Port ideas, not code, unless it fits the new architecture.

## Layout (target)
brave-and-cold/ (Godot project)
  autoload/  systems/  world/  entities/  buildings/  items/  data/  ui/  shaders/  assets/  tests/
tools/blender/  (repo root: seedable generators, bakers, validators)
docs/design/  docs/reviews/
