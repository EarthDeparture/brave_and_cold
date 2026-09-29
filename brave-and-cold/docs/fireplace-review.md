# Fireplace fuel/warmth and HUD review

Fuel/warmth wiring verified: E consumes one wood for 20 seconds of fuel;
burning restores 5 warmth/second within 3 m through Temperature's clamped
setter and signals. Fuel burns out of range; the final partial frame supplies
only its remaining fuel's heat. DayNight drives temperature drain.

Added a fireplace lit-state signal and a HUD Fire label (Lit/Unlit). The HUD
reads initial state and updates on ignition, burnout, and relighting. Warnings
are moved down one row to preserve spacing.

Reviewed scripts/fireplace.gd, scripts/temperature.gd, scripts/hud.gd,
scripts/player.gd, scripts/day_night.gd, scripts/cottage.gd, project.godot,
scenes/fireplace.tscn, scenes/main.tscn, and scenes/hud.tscn.

Validation: Godot 4.5.1 headless editor import passed. Headless test_hud.gd,
test_firewood.gd, test_temperature.gd, test_day_night.gd, test_player.gd,
test_cottage.gd, and test_game_outcome.gd passed with zero failures.
HUD tests cover initial/failed ignition, ignition, refueling, recreation while
lit, burnout, and relighting. Existing firewood tests cover warmth and fuel.

Human review required: gather wood, light/refuel the hearth, and watch the HUD
while approaching/leaving the fire and waiting for burnout. Confirm warmth
rises nearby, drains away from the fire, and flame/light match the HUD state.
Check Fire and simultaneous warning labels remain readable without overlap.

No planner brief was supplied or found; its exact file/test checklist cannot
be verified. Human visual/playability review remains pending.
