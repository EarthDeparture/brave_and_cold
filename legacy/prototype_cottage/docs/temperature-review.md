# Temperature review

Temperature is an autoload with 100 warmth points. Indoors drains 0.25 points/second;
outdoors doubles this, and night doubles it again. The repeating 240-second cycle
starts with 120 seconds of daytime. This survival timer does not change scene lighting.
Cottage local bounds determine shelter. At zero, walking speed halves and sprint
is disabled; the HUD displays the penalty. Shelter slows cooling but does not rewarm.

Human review required:
- Run the main scene and confirm the warmth readout decreases below stamina.
- Confirm cooling doubles after 120 seconds and returns to daytime rate at 240 seconds.
- At zero, confirm the FREEZING message, half movement speed, and disabled sprint.
- To check outdoors, move Player's starting X to 8 in a temporary editor instance;
  confirm cooling is twice as fast as the sheltered start. The cottage has no exit.
- Confirm the HUD remains legible at the intended window size.

Files reviewed: project.godot, scripts/temperature.gd, scripts/player.gd,
scripts/cottage.gd, scripts/hud.gd, scenes/hud.tscn, tests/test_temperature.gd.

Checks run with Godot 4.5.1 (from workspace root):
```
godot --headless --path brave-and-cold --editor --import --quit
godot --headless --path brave-and-cold --script res://tests/test_temperature.gd
godot --headless --path brave-and-cold --script res://tests/test_player.gd
godot --headless --path brave-and-cold --script res://tests/test_cottage.gd
```
All passed. Temperature tests cover indoor/outdoor/night drain, night transitions,
negative delta, shelter entry/exit, zero clamping, transition signals, HUD updates,
movement penalty, and clearing the penalty when warmth is restored programmatically.
The existing tests/run_tests.gd suite fails compilation because
 tests/test_rename_variable.gd:52 calls quit() on RefCounted (pre-existing).
No separate planner brief was supplied or found; its file/test checklist could not
be verified. Human visual review is pending.
