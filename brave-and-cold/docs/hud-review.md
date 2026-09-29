# HUD review

The HUD shows the current day (starting at 1) and Daytime/Night. DayNight owns
and increments the counter at dawn, including multiple cycles in one advance;
recreating the HUD preserves the day. Night displays a colder/more-zombies warning.
Low wood means inventory <= 2; cold means warmth <= 25% of maximum. Both HUD
thresholds are exported. Freezing replaces the cold warning at zero warmth.
Warnings clear on recovery and can appear together. Existing warmth, frozen
movement penalty, stamina, wood, and interaction text remain visible.

Files reviewed: scripts/hud.gd, scripts/day_night.gd, scenes/hud.tscn,
tests/test_hud.gd, its generated .uid, and this document.

Passed with Godot 4.5.1 from workspace root:
```
godot --headless --path brave-and-cold --editor --import --quit
godot --headless --path brave-and-cold --script res://tests/test_hud.gd
godot --headless --path brave-and-cold --script res://tests/test_day_night.gd
godot --headless --path brave-and-cold --script res://tests/test_temperature.gd
godot --headless --path brave-and-cold --script res://tests/test_firewood.gd
```

Human review required: run the main scene, check label readability and spacing,
observe dusk/dawn and day increments, gather/spend wood across the threshold,
and cool/freeze/rewarm near a lit fireplace. Confirm simultaneous warnings remain
readable and disappear after recovery, with existing HUD information intact.

No planner brief was supplied or found; its exact file/test checklist cannot be
verified. Human visual review remains pending.
