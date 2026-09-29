# Day/night cycle review

`DayNight` is an autoload with a configurable 240-second cycle, starting at dawn.
`time_of_day` is normalized to [0, 1); dusk is 0.5 and dawn is 0.
`dusk` and `dawn` emit once per crossed boundary, including large time steps.
`advance(seconds)` permits deterministic simulation. The clock pauses with the
scene tree. Darkness is binary; visual sky/lighting transitions are outside this
code change.

At night, zombie light and noise detection ranges multiply by 1.5. Noise retains
priority and its existing four-second memory. Dawn restores the base ranges.
The main scene spawner creates zombies only at night, every 15 / day_count
seconds (minimum 0.1 seconds), on a 30-metre exterior ring inside the current
navigation mesh. Dawn clears partial progress. The cap is 12 live zombies
including the original scene zombie; time at the cap does not build a backlog.
Temperature consumes the same clock's day/night segments, preserving accurate
drain across transitions. Its standalone `advance` API remains for simulation.

Files: `project.godot`, `scenes/main.tscn`, `scripts/day_night.gd`,
`scripts/zombie_spawner.gd`, `scripts/zombie.gd`, `scripts/temperature.gd`,
`tests/test_day_night.gd`, and this review document. New scripts have Godot UID files.

Automated checks (Godot 4.5.1, from workspace root):
```
godot --headless --path brave-and-cold --editor --import --quit
godot --headless --path brave-and-cold --script res://tests/test_day_night.gd
godot --headless --path brave-and-cold --script res://tests/test_temperature.gd
godot --headless --path brave-and-cold --script res://tests/test_zombie.gd
godot --headless --path brave-and-cold --script res://tests/test_player.gd
godot --headless --path brave-and-cold --script res://tests/test_cottage.gd
godot --headless --path brave-and-cold --script res://tests/test_firewood.gd
```

Human review required:
- Run the main scene through dusk (120 seconds) and dawn (240 seconds), or shorten
  the DayNight autoload's day_length through the remote inspector.
- Confirm distant zombies react to windows and footsteps at longer ranges at
  night, and return to ordinary ranges at dawn after remembered noise expires.
- Confirm spawning starts at dusk, stops at dawn, and accelerates each day.
- Check spawned zombies navigate around the cottage and stop at boarded windows.
- Confirm the population stops at 12 and temperature follows the same phase.

The pre-existing `tests/run_tests.gd` runner fails to compile because
`tests/test_rename_variable.gd` calls `quit()` on RefCounted and lacks a return
path. No planner brief was supplied or found, so its exact file/test checklist
cannot be verified. Human review remains pending.
