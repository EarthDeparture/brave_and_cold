# Door closing review

Opening the door disabled its only collider, preventing the player's interaction
ray from selecting it again. The collider now stays enabled on layer 2 while the
door is passable; closing restores solid layer 1. Selection remains at the doorway,
as it does for broken-door repair.

Files: `scripts/door.gd`, `tests/test_cottage.gd`, this review.
The regression test uses player interaction rays from both sides and checks that
the open doorway does not block layer 1. It failed before the fix and passes after.

Verified with Godot 4.5.1: headless editor import and `test_cottage`, `test_player`,
`test_barrier_repair`, `test_player_tools`, `test_window_breach`, `test_zombie`.
Run suites with `godot --headless --path brave-and-cold --script res://tests/TEST_NAME.gd --fixed-fps 60`.

Human review required: from inside and outside, aim at the doorway and press E
to open, walk through, then press E to close. Confirm the closed door blocks
walking; also check Sprint+E boarding, board removal, and broken-door repair.

No separate planner brief was supplied or found, so its file/test checklist could
not be verified. Human gameplay review remains pending.
