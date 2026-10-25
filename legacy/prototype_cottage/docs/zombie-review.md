# Zombie attraction review

The main scene spawns a green capsule zombie southeast of the cottage. It uses
NavigationAgent3D to walk around the cottage toward the nearest unboarded window
within 40 metres. Boarding or deleting its target causes it to select another
window or stop. Visible outdoor players within 12 metres take priority and are tracked continuously.
Walls block sight; sheltered and dead players are ignored. Night multiplies sight
range by the same aggro multiplier as hearing. Without a visible outdoor player,
audible noise overrides light for four seconds, then light targeting resumes.

Walking emits footsteps every 0.5 seconds within 8 metres; sprinting emits them
every 0.3 seconds within 18 metres. Idle players emit no footsteps but remain visible outdoors. Gathering costs 15
stamina and emits noise within 20 metres; insufficient stamina prevents gathering
without consuming wood or making noise. Gathering leaves less stamina for sprinting. Other gameplay
can call `NoiseEvents.emit_noise(world_position, radius)`.

Navigation covers the flat exterior ground, excluding the cottage footprint with
wall clearance. Interior noise is projected onto that exterior navigation mesh;
zombies investigate from outside. The mesh bounds in `cottage_navigation.gd`
must be updated if terrain or the cottage footprint changes. Zombies attack visible
unboarded windows within 2 metres once per second; three hits break the glass.
Subsequent attacks can kill a player within 3 metres through the breach, with
walls blocking the attack ray. Zombies remain outside. Boards prevent attacks,
including on broken windows; removing boards exposes the existing breach.
The interaction collider remains in place so broken windows can be boarded.
Barricade destruction and crowd avoidance are not implemented.

Human review required:
- Run the main scene and watch the zombie route around the walls to the lit window.
- Board the left window: the zombie should stop once noise memory expires.
- Unboard the right window: the zombie should approach it.
- Walk/sprint near the zombie: it should investigate the latest footstep position.
- Stop moving outdoors in sight: it should keep approaching and kill on contact.
- Break sight and stop making noise: after four seconds it returns to window targeting.
- Gather wood near a zombie: verify attraction and stamina loss; at low stamina,
  verify gathering fails and resumes after recovery. Compare walking and sprint escape.
- Confirm movement and stopping look acceptable and walls are never crossed.
- Leave a window unboarded: verify the glass disappears after three attacks.
- Stand inside near the breach: verify the next attack triggers game over.
- Board a broken window: verify protection; remove boards and verify danger returns.
- Stand farther inside or behind a wall: verify breach attacks cannot reach you.

Implementation files: `scripts/zombie.gd`, `scripts/noise.gd`,
`scripts/cottage_navigation.gd`, `scripts/player.gd`,
`scripts/boardable_window.gd`, `scenes/zombie.tscn`, `scenes/main.tscn`,
`project.godot`. Coverage: `tests/test_exterior_threat.gd`, `tests/test_firewood.gd`, `tests/test_zombie.gd` and
`tests/test_window_breach.gd` (cooldown, glass damage, reboarding, distance,
wall occlusion, noise priority, and indoor death/game over).

Automated checks (workspace root, Godot 4.5.1):
```
godot --headless --path brave-and-cold --editor --import --quit
godot --headless --path brave-and-cold --script res://tests/test_zombie.gd
godot --headless --path brave-and-cold --script res://tests/test_player.gd
godot --headless --path brave-and-cold --script res://tests/test_cottage.gd
godot --headless --path brave-and-cold --script res://tests/test_temperature.gd
godot --headless --path brave-and-cold --script res://tests/test_window_breach.gd
godot --headless --path brave-and-cold --script res://tests/test_game_outcome.gd
```

The existing `tests/run_tests.gd` suite cannot compile because
`test_rename_variable.gd:52` calls `quit()` on RefCounted and its `run()` has a
missing return path. This unrelated issue was left unchanged.

No planner brief was supplied or found in the workspace, so its exact file/test
checklist could not be verified. Human review remains pending.

Exterior threat follow-up (task 009240ed-e705-47dd-bfd1-0ee22e0a5442):
- Changed `scripts/zombie.gd`, `scripts/wood_source.gd`,
  `tests/test_firewood.gd`, `tests/test_exterior_threat.gd`, and this review.
- Verified the existing night-only `scripts/zombie_spawner.gd` unchanged: spawned
  zombies use the same pursuit behavior, ring, cadence, and population cap.
- Headless editor import and all ten gameplay suites passed: exterior threat,
  zombie, firewood, player, cottage, temperature, window breach, game outcome,
  day/night, and HUD.
- Additional commands:
  `godot --headless --path brave-and-cold --script res://tests/test_exterior_threat.gd`
  and `godot --headless --path brave-and-cold --script res://tests/test_firewood.gd`.
- Human playthrough and the unavailable planner checklist remain pending.
