# Player tools — human review required

Player starts with bare hands. A hammer outside near the wood sources is collected
with E and stays equipped for the run. Boarding and repairing either barrier take
2 seconds with hands or 1 second with the hammer. Each completed job costs one wood;
the hammer is never consumed. Removing boards and opening doors remain instant.
Press E once (Sprint+E to board a closed door), then stay within 0.5 m of the starting
position. Moving farther or dying cancels without cost. Pause freezes work.

## Files to review

- `scripts/player.gd`: inventory, timer, cancellation, interaction guard.
- `scripts/boardable_window.gd`, `scripts/door.gd`: deferred boarding/repair,
  state validation and wood cost on completion.
- `scripts/hammer_pickup.gd`, `scenes/hammer_pickup.tscn`: one-use pickup and mesh.
- `scenes/main.tscn`: outdoor pickup placement.
- `scripts/hud.gd`, `scenes/hud.tscn`: tool and work feedback.
- `tests/test_player_tools.gd`: progression, pickup ray, timing, costs, pause,
  repeated input, movement, changed barrier state and death.
- `tests/test_cottage.gd`, `tests/test_window_breach.gd`,
  `tests/test_barrier_repair.gd`: existing checks updated for timed completion.

## Manual checklist

- Gather wood, board a window with hands; confirm two-second progress and one wood spent.
- Collect the visible outdoor hammer at (4, 0.5, 8); confirm pickup disappears and HUD updates.
- Board and repair a window and door with hammer; confirm one-second duration.
- Confirm breaches remain cold/passable until repair completes.
- Move away during work; confirm no wood spent and no barrier change.
- Confirm repeated E cannot queue jobs, pause freezes progress, and death cancels.
- Check tool and progress text readability at the supported window size.
- Restart: hands restored, hammer respawns, carried wood resets.

## Automated checks

Run each standalone `tests/test_*.gd` using
`godot --headless --path brave-and-cold --script res://tests/<file>`.
The rename utility test is instead invoked by `tests/run_tests.gd`.

No separate planner brief was present in the supplied task or workspace; its file
and test list could not be verified. This checklist covers the implementation.

Validation: Godot 4.5.1 import succeeded. All 12 gameplay suites passed (barrier
repair, cottage, day/night, exterior threat, firewood, game outcome, HUD, player,
player tools, temperature, window breach, zombie). The unrelated rename runner
could not complete: existing `test_rename_variable.gd` parse errors at lines 7
(missing return) and 52 (`quit()` unavailable) prevent compilation. Human visual
and playtesting review remains pending.
