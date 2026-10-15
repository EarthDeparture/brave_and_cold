extends SceneTree
## F5 stoves: fishing huts carry a box stove, the store a pot-belly. Both follow the
## fire standard (prompts, match rule, cap), block the player, heat their room and save.
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
	for t in ["box_stove", "pot_belly"]:
		var f := FireSource.new(t)
		check(f.needs_starter(), "%s starts cold and needs a starter" % t)
		f.set_fuel(f.max_fuel_s())
		check(not f.fits("wood"), "%s refuses fuel at its %.0f h cap" % [t, f.max_fuel_s() / 3600.0])
		check(f.max_fuel_s() < FireSource.new("wood_stove").max_fuel_s(), "%s holds less than the cabin wood stove" % t)

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	check(not w.huts.is_empty() and w.huts.all(func(h: Hut) -> bool: return h.stove != null and h.stove.fire.type == "box_stove"), "every fishing hut has a box stove (%d huts)" % w.huts.size())
	check(not w.stores.is_empty() and w.stores.all(func(s: Store) -> bool: return s.stove != null and s.stove.fire.type == "pot_belly"), "the store has a pot-belly stove")
	var hut: Hut = w.huts[0]; var st: Stove = hut.stove
	var store: Store = w.stores[0]

	# Same prompt list as every other fire.
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs; w.inv.add("wood", 2); w.inv.add("matches", 2)
	var acts: Array = w.fire_actions(st.fire, st.top_world())
	check(not acts.is_empty() and String(acts[0].text).begins_with("Light") and String(acts[0].text).contains("match"), "cold hut stove offers 'Light ... needs a match' (%s)" % (acts[0].text if not acts.is_empty() else "none"))
	(acts[0].act as Callable).call()
	check(st.fire.is_lit() and w.inv.count("wood") == 1 and w.inv.count("matches") == 1, "lighting it spends one log and one match")
	acts = w.fire_actions(st.fire, st.top_world())
	check(String(acts[0].text).begins_with("Stoke"), "lit stove offers Stoke (%s)" % acts[0].text)

	# The prompt is reachable in play: stand in the hut and look at the stove.
	var eye := hut.to_global(Vector3(0.0, Hut.FLOOR_LOCAL_Y + w.player.eye_h, 0.5))
	w.player.position = eye; var d := st.top_world() - eye
	w.player.yaw = atan2(-d.x, -d.z); w.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	w._update_prompt()
	check(String(w._cur.get("text", "")).begins_with("Stoke"), "looking at the hut stove from inside shows its prompt (%s)" % w._cur.get("text", ""))

	# Solid: the player cannot walk through it.
	var c := hut.to_global(st.position)
	var pushed: Vector2 = hut.resolve(c.x, c.z, 0.3)
	check(pushed.distance_to(Vector2(c.x, c.z)) > 0.2, "the stove footprint blocks the player")
	var sc := store.to_global(store.stove.position)
	check(store.resolve(sc.x, sc.z, 0.3).distance_to(Vector2(sc.x, sc.z)) > 0.2, "the pot-belly blocks the player too")
	var door := hut.to_global(Vector3(0, 0, Hut.HZ - 0.3))
	check(hut.resolve(door.x, door.z, 0.3).distance_to(Vector2(door.x, door.z)) < 0.01, "the hut doorway stays clear")

	# The room warms with it.
	var room: RoomClimate = w.room_at(hut.to_global(Vector3(0, Hut.FLOOR_LOCAL_Y + 1, 0)))
	check(room != null and room.fire == st.fire, "the hut room is heated by its stove")
	var out_c: float = w.clock.ambient_c()
	st.fire.set_fuel(0); st.fire.ember_s = 0.0; room.settle(out_c); var cold := room.room_c
	st.fire.set_fuel(6 * 3600); room.advance(3 * 3600, out_c)
	check(room.room_c > cold + 15.0, "a lit box stove warms the hut: %.1f -> %.1f C" % [cold, room.room_c])
	var sroom: RoomClimate = w.room_at(store.to_global(Vector3(0, Store.FLOOR_LOCAL_Y + 1, 0)))
	check(sroom != null and sroom.fire == store.stove.fire, "the store room is heated by the pot-belly")

	# Burn and embers follow the standard.
	var before := st.fire.fuel_s; st.advance(3600)
	check(st.fire.fuel_s < before, "the stove burns fuel")
	st.fire.set_fuel(0); st.fire.advance(1)
	check(st.fire.has_embers() or st.fire.needs_starter(), "out of fuel: embers or cold")

	# Save / load.
	st.fire.set_fuel(3 * 3600); store.stove.fire.set_fuel(5 * 3600)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free(); await process_frame; await process_frame
	SaveGame.pending = snap
	var w2: Node3D = load("res://world/game_world.gd").new(); root.add_child(w2)
	for frame in 700:
		await process_frame
		if w2.opening != null and w2.gear != null: break
	freeze(w2)
	check(is_equal_approx((w2.huts[0] as Hut).stove.fire.fuel_s, 3 * 3600.0), "hut stove fuel survives save/load")
	check(is_equal_approx((w2.stores[0] as Store).stove.fire.fuel_s, 5 * 3600.0), "store stove fuel survives save/load")
	w2.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("STOVES_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
