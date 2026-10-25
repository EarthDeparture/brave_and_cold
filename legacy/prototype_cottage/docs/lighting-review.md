# Lighting fix review

The main scene's sun and environment were never connected to DayNight, so
night retained daytime illumination. world_lighting.gd now initializes from
the clock and applies dusk/dawn changes to the sun, ambient energy, and sky
brightness. Fireplace illumination remains fuel-driven during both phases;
OUT now explicitly clears energy and range as well as hiding the light.
DayNight's existing boundary signals required no changes.

Reviewed scripts/fireplace.gd, scripts/day_night.gd, scripts/world_lighting.gd,
scenes/main.tscn, scenes/fireplace.tscn, and tests/test_lighting.gd, including
new script UID files. Godot 4.5.1 headless editor import passed.

Passed with zero failures: test_lighting.gd, test_day_night.gd,
test_fire_noise.gd, test_firewood.gd, test_hud.gd, test_temperature.gd,
test_game_outcome.gd, test_player.gd, test_zombie.gd, and test_cottage.gd.

Human review required: run the main scene through dusk and dawn, confirming
night is dark but readable and daylight returns. Light/refuel the fireplace,
wait for its dying phase and burnout, then relight; check flame, light, and HUD
agree in both phases. Review the chosen night ambient/sky brightness visually;
headless tests verify state only.

No planner brief/checklist was supplied or found. Its exact file/test coverage
cannot be certified. Human review remains pending.
