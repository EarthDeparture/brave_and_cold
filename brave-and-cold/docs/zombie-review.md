# Zombie attraction review

The main scene spawns a green capsule zombie southeast of the cottage. It uses
NavigationAgent3D to walk around the cottage toward the nearest unboarded window
within 40 metres. Boarding or deleting its target causes it to select another
window or stop. Audible noise overrides light for four seconds after the latest
heard event, then light targeting resumes.

Walking emits footsteps every 0.5 seconds within 8 metres; sprinting emits them
every 0.3 seconds within 18 metres. Idle players emit no footsteps. Other gameplay
can call `NoiseEvents.emit_noise(world_position, radius)`.

Navigation covers the flat exterior ground, excluding the cottage footprint with
wall clearance. Interior noise is projected onto that exterior navigation mesh;
zombies investigate from outside. The mesh bounds in `cottage_navigation.gd`
must be updated if terrain or the cottage footprint changes. No attacks,
barricade destruction, line-of-sight filtering, or crowd avoidance are implemented.

Human review required:
- Run the main scene and watch the zombie route around the walls to the lit window.
- Board the left window: the zombie should stop once noise memory expires.
- Unboard the right window: the zombie should approach it.
- Walk/sprint near the zombie: it should investigate the latest footstep position.
- Stop moving: after four seconds, it should return to a lit window or remain idle.
- Confirm movement and stopping look acceptable and walls are never crossed.

Implementation files: `scripts/zombie.gd`, `scripts/noise.gd`,
`scripts/cottage_navigation.gd`, `scripts/player.gd`,
`scripts/boardable_window.gd`, `scenes/zombie.tscn`, `scenes/main.tscn`,
`project.godot`. New coverage: `tests/test_zombie.gd`.

Automated checks (workspace root, Godot 4.5.1):
```
godot --headless --path brave-and-cold --editor --import --quit
godot --headless --path brave-and-cold --script res://tests/test_zombie.gd
godot --headless --path brave-and-cold --script res://tests/test_player.gd
godot --headless --path brave-and-cold --script res://tests/test_cottage.gd
godot --headless --path brave-and-cold --script res://tests/test_temperature.gd
```

The existing `tests/run_tests.gd` suite cannot compile because
`test_rename_variable.gd:52` calls `quit()` on RefCounted and its `run()` has a
missing return path. This unrelated issue was left unchanged.

No planner brief was supplied or found in the workspace, so its exact file/test
checklist could not be verified. Human review remains pending.
