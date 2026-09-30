# Wood gathering and fire review

Implemented finite deadfall nodes, player wood inventory and HUD, E-key raycast interaction (3 m), and a fireplace that consumes one wood per 20 seconds of fuel. Heat restores 5 warmth/second within 3 m, capped at maximum warmth. Fuel burns even when the player leaves; flame/light extinguish when exhausted. Added a south doorway to reach the two outdoor deadfalls. Windows retain their existing interaction.

Files: scripts/player.gd, scripts/hud.gd, scripts/cottage.gd, scripts/wood_source.gd, scripts/fireplace.gd; scenes/main.tscn, scenes/cottage.tscn, scenes/hud.tscn, scenes/wood_source.tscn, scenes/fireplace.tscn; tests/test_cottage.gd, tests/test_firewood.gd.

Automated mechanic check:
`godot --headless --path brave-and-cold --script res://tests/test_firewood.gd`

Covers interaction distance, gathering, depletion, HUD, empty inventory, fuel consumption, refueling, nearby versus distant heat, thawing, partial-frame burnout, extinguishing, negative delta and warmth cap.

Human review required:
1. Walk out through the south doorway; aim down at a deadfall and press E. Check inventory increases, then depletion prevents further gathering.
2. Return to the hearth and press E. Check one wood is spent, flame/light appear, fuel counts down, and warmth rises nearby.
3. Move away; check warmth drains while fuel continues burning. Return and refuel, then wait for burnout and check heat/light stop.
4. Confirm movement, readable prompts, and window boarding still work.

No separate planner brief was supplied or found, so its file/test checklist could not be verified. Human visual/playability review remains pending. Deadfall and flame visuals are blockouts. Heat uses radial distance; it does not test wall occlusion. Existing zombie navigation remains exterior-only.

Validation: Godot 4.5.1 headless import passed. Firewood, player, cottage, temperature and zombie suites passed with zero failures. The existing renamer runner (`tests/run_tests.gd`) timed out after 60 seconds.

## Exterior loop verification — 2026-09-29

Reviewed every file in the file list above, plus `project.godot` and
`scenes/player.tscn`. Existing gameplay code already supports gathering from
both outdoor deadfalls and spending carried wood at the fireplace; no runtime
change was needed.

Extended `tests/test_firewood.gd` to verify solid obstacles block gathering,
the physical E binding exists, released mouse prevents gathering, remaining
stock and depletion prompts update, and the second deadfall has independent
stock and can be gathered via the player raycast before returning fuel.

Validation: Godot 4.5.1 headless import passed. Firewood, cottage, player, HUD,
and temperature suites each passed with zero failures.

Human review remains required for the walkthrough above, including walking
through the doorway in both directions and checking that holding E gathers
only once until released and pressed again. Headless Godot cannot capture the
mouse, so successful captured-mouse input and key-repeat behavior were not
automated; successful interactions exercise the player raycast directly.
The separate planner brief is still missing, so its exact file/test checklist
cannot be verified.
