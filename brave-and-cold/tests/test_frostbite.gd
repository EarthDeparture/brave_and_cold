extends SceneTree
## N6 frostbite: bare head/hands/feet build risk in deep wind chill, gear holds it off,
## warmth brings it back down, 100% is a permanent condition cap, and it saves.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func run() -> void:
	check(Frostbite.need_at(-5.0) == 0.0 and Frostbite.need_at(-40.0) == Frostbite.FULL_NEED, "no need above -10 C feels-like, full need at -40")
	var inv := Inventory.new(BodyTemperature.new())
	var fb := Frostbite.new()
	var msgs: Array = []
	for i in 12: msgs.append_array(fb.advance(600, -30.0, false, inv, 0.0))
	check(float(fb.risk.hands) >= 50.0 and float(fb.risk.hands) < 100.0, "2 h bare-handed at -30: fingers %.0f%% at risk" % fb.risk.hands)
	check(msgs.any(func(m: String) -> bool: return m.contains("fingers")), "a numbness warning at 50%")
	for i in 12: msgs.append_array(fb.advance(600, -30.0, false, inv, 0.0))
	check(bool(fb.bitten.hands) and fb.count() == 3 and fb.max_condition() == 100.0 - 3 * Frostbite.CAP_LOSS, "4 h bare: head, hands and feet frostbitten, condition capped at %.0f" % fb.max_condition())
	check(msgs.any(func(m: String) -> bool: return m.begins_with("FROSTBITE")), "frostbite is announced")
	var dressed := Frostbite.new()
	for slot_id in [["head", "toque"], ["hands", "wolf_mitts"], ["feet", "hide_boots"]]:
		inv.add(slot_id[1]); inv.extra[slot_id[0]] = slot_id[1]
	for i in 24: dressed.advance(600, -30.0, false, inv, 0.0)
	check(float(dressed.risk.head) == 0.0 and float(dressed.risk.hands) == 0.0 and float(dressed.risk.feet) == 0.0, "toque, mitts and boots hold off -30")
	for i in 24: dressed.advance(600, -30.0, false, inv, 1.0)
	check(float(dressed.risk.feet) > 0.0 and float(dressed.risk.hands) == 0.0, "soaked boots let the toes freeze (%.0f%%)" % dressed.risk.feet)
	var warm := Frostbite.new(); warm.risk.hands = 80.0
	warm.advance(3600, -30.0, true, Inventory.new(), 0.0)
	check(float(warm.risk.hands) < 20.0, "an hour by the fire undoes most of the risk (%.0f%%)" % warm.risk.hands)
	var back := Frostbite.new(); back.restore(JSON.parse_string(JSON.stringify(fb.to_dict())))
	check(back.count() == 3 and is_equal_approx(float(back.risk.hands), float(fb.risk.hands)), "state saves")

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	check(w.frostbite != null and w.frostbite.count() == 0, "a new game starts unhurt")
	w.frostbite.bitten.hands = true; w.player.health = 100.0
	w._process(0.05)
	check(w.player.health <= w.frostbite.max_condition() + 0.01, "frostbitten fingers cap condition (%.1f)" % w.player.health)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	check(snap.has("frostbite") and bool(snap.frostbite.bitten.hands), "frostbite saves with the game")
	w.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("FROSTBITE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
