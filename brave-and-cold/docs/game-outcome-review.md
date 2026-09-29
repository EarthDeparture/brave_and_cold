# Game outcome review

Human review required. No separate planner brief was present in the workspace.

Main exposes `nights_to_survive` (default 3). Each completed night counts at dawn;
starting at dawn does not count. Zero warmth or physical zombie contact is fatal.
The first result is final; gameplay pauses and the cursor is released.

Files: `scripts/game_outcome.gd`, `scenes/main.tscn`, `scripts/player.gd`,
`scripts/zombie.gd`, `scripts/day_night.gd`, `scripts/hud.gd`,
`tests/test_game_outcome.gd`, `tests/test_temperature.gd`, `tests/test_hud.gd`.

Run from the project directory:

```sh
godot --headless --script res://tests/test_game_outcome.gd
godot --headless --script res://tests/test_temperature.gd
godot --headless --script res://tests/test_hud.gd
godot --headless --script res://tests/test_day_night.gd
godot --headless --script res://tests/test_player.gd
godot --headless --script res://tests/test_zombie.gd
godot --headless --script res://tests/test_firewood.gd
godot --headless --script res://tests/test_cottage.gd
```

Manual checks (restart the game between cases):

- Let warmth reach zero: GAME OVER and freezing reason appear immediately.
- Walk into a zombie, then separately let a zombie walk into the player:
  GAME OVER and zombie reason appear.
- For quick review, set Main's target to 1, DayNight's day length to 4 seconds,
  and Temperature's drain rate to 0 using the remote inspector. Dusk must not
  win; the next dawn must show YOU WIN. Restore settings after review.
- Check the end screen at different window sizes, cursor visibility, and that
  movement, camera look, interactions, zombies, warmth, and clock stop.
- Automated tests cover a large clock step and fatal cold at the final dawn:
  death takes precedence and later events cannot replace the result.

There is no restart/menu flow in this change; relaunch to play again.
