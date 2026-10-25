# Barrier repair and breach review

Human review required. No separate planner file/test list was supplied or found in the workspace.

Changed behavior:
- Three zombie hits at the existing one-second attack interval break an unboarded barrier. Open doors ignore damage.
- E on a broken door/window costs one wood, restores full durability, and closes the breach. With no wood, nothing changes. Boarding intact barriers remains a separate action and expense.
- Breaches admit zombies through navigation links and remove physical blocking. Broken windows include a shattered sill opening large enough for the existing zombie capsule. Repair restores the sill.
- Any unrepaired, unboarded breach exposes the interior to the existing outdoor cold multiplier (2x; night still stacks). It also lets zombies see indoor players through clear sight lines. Zombies already inside remain dangerous after repair.
- Layer 2 is reserved for ray selection of broken barriers; movement and sight use layer 1.

Files to review: `scripts/door.gd`, `scripts/boardable_window.gd`, `scripts/cottage.gd`, `scripts/cottage_navigation.gd`, `scripts/player.gd`, `scripts/zombie.gd`; `tests/test_barrier_repair.gd`, `tests/test_window_breach.gd`, `tests/test_zombie.gd`, `tests/test_cottage.gd`.

Run each standalone test with `godot --headless --path brave-and-cold --script res://tests/TEST_NAME.gd --fixed-fps 60`.

Manual checks:
1. Let a zombie break each window and the door; confirm it enters through the opening without walking through intact walls.
2. Aim at each breach and press E with zero wood, then one wood. Check prompt, inventory, visible repair, blocked passage, and renewed three-hit durability.
3. Compare warmth loss indoors before break, during breach, and after repair; also test two simultaneous breaches (repairing only one must leave the cold penalty).
4. Check normal boarding/unboarding and door opening/closing. Confirm zombies inside still chase after the last breach is repaired.
5. Review one-wood instant repair versus three one-second attacks for gameplay balance, and review the broken-window sill visual.

Verification: 11 gameplay suites passed (`test_barrier_repair`, `test_cottage`, `test_day_night`, `test_exterior_threat`, `test_firewood`, `test_game_outcome`, `test_hud`, `test_player`, `test_temperature`, `test_window_breach`, `test_zombie`). The cottage/day-night/zombie fixtures now account for the existing door interaction and target behavior. Also review `tests/test_day_night.gd`.

The separate renamer runner (`tests/run_tests.gd`) remains blocked by existing parse errors in untouched `tests/test_rename_variable.gd`: `quit()` is undefined at line 52 and `run()` lacks a return on all paths. Accelerated headless runs occasionally emit a Jolt job-capacity warning. Human gameplay/visual review remains pending.
