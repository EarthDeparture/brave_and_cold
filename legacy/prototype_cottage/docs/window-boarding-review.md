# Window boarding cost review

Boarding spends one gathered wood through the existing player inventory. Empty inventory leaves the window unchanged. Removing boards is free and does not refund wood. The prompt displays the cost; inventory signals update the HUD. Initial scene boarding remains unchanged.

Changed files: `scripts/boardable_window.gd`, `scripts/player.gd`, `tests/test_cottage.gd`, and this review document. Reviewed the existing wood source, fireplace, inventory, and related test integration.

Validation: Godot 4.5.1 headless import passed. Cottage, firewood, player, HUD, and zombie suites passed with zero failures. Cottage coverage includes gathered wood consumption, empty inventory, repeat boarding/removal, distance, HUD updates, independent window visuals, and shared fireplace inventory.

Human review required:
1. With no wood, aim at the unboarded window and press E; it should stay open.
2. Gather wood outside, return, and board the window; check one wood is spent and light is blocked.
3. Remove boards at zero wood; check no refund, then confirm boarding fails until more wood is gathered.
4. Confirm the cost prompt is readable and the fireplace shares the same wood count.

No separate planner brief was supplied or found; its exact file/test checklist cannot be verified. Human review remains pending.
