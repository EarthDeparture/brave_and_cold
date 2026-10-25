extends SceneTree
## Plan A7: the root cellar under one hamlet cabin. A fixed 2 C store: spoilage inside is the 2 C rate
## whatever the weather or the stove; the hatch prompt opens it and the lid follows the gear screen;
## hidden from the chest list, ransack and the claim check; survives a fire; saves.
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func secs(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0): await process_frame

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261026)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null: break
	w.out_path = ""; w.player.god = true
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	if w.ambient_life != null: w.ambient_life.voices_enabled = false
	var rc: RootCellar = w.root_cellar
	check(rc != null and rc.store != null, "the world has a root cellar")
	if rc == null: quit(1); return
	var cb: Cabin = rc.cabin
	var home := false
	if w.town_life != null:
		for id in w.town_life.homes: home = home or w.town_life.homes[id] == cb
	check(cb != w.cabins[0] and not home, "it is under a hamlet cabin: not the start cabin, not a resident home")
	check(not rc.store.is_in_group("chests") and not w.chests.has(rc.store), "its store is hidden from the chest list and the gear auto-pick")
	check(rc.store.count("beans") >= 1, "someone's stores were left down there (%d beans)" % rc.store.count("beans"))

	# ---- fixed 2 C, whatever the air above
	var r2 := Spoilage.rate_c(2.0)
	var probe := StorageChest.new(); probe.visual_enabled = false; probe.listed = false
	cb.add_child(probe); probe.position = rc.position + Vector3(0, 0.5, 0)
	cb.fire.set_fuel(3600.0 * 4.0); cb.refresh_fire()
	await frames(10)
	var air_room: float = w.air_at(probe.global_position)
	check(is_equal_approx(rc.store.spoilage_rate, r2), "the cellar rate is the 2 C rate (%.3f)" % rc.store.spoilage_rate)
	var r_room := Spoilage.rate_c(air_room)
	check(absf(r_room - r2) > 0.02, "a box on the cabin floor above keeps a different pace (air %.1f C rate %.3f)" % [air_room, r_room])
	rc.store.put("venison_raw", 1, 1.0, 0.0)
	var a0 := float(rc.store.age.get("venison_raw", 0.0))
	rc.tick(3600.0)
	var a1 := float(rc.store.age.get("venison_raw", 0.0))
	check(absf((a1 - a0) - 3600.0 * r2) < 1.0, "an hour in the cellar ages raw venison %.0f s (2 C: %.0f s)" % [a1 - a0, 3600.0 * r2])
	var ok_weather := true
	for st in [0, 2, 4]:   # clear, snow, blizzard
		w.weather.set_state(st, true)
		await frames(3)
		ok_weather = ok_weather and is_equal_approx(rc.store.spoilage_rate, r2)
	check(ok_weather, "the rate holds through clear, snow and blizzard")
	w.weather.set_state(0, true)
	var ok_hour := true
	for hh in [4.0, 14.0]:
		w.clock.hour = hh
		await frames(3)
		ok_hour = ok_hour and is_equal_approx(rc.store.spoilage_rate, r2)
	check(ok_hour, "and through the cold night and the warm afternoon")
	cb.fire.set_fuel(0.0); cb.refresh_fire()
	await frames(3)
	check(is_equal_approx(rc.store.spoilage_rate, r2), "and with the stove out")
	probe.queue_free()

	# ---- the hatch prompt opens it; the lid follows the gear screen
	var eye := cb.to_global(Vector3(0.7, Cabin.FLOOR_LOCAL_Y + w.player.eye_h, 0.75))
	w.player.position = eye; var d: Vector3 = rc.hatch_world_pos() - eye
	w.player.yaw = atan2(-d.x, -d.z); w.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await frames(2)
	w.player.position = eye; w.player.yaw = atan2(-d.x, -d.z); w.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	w._update_prompt()
	var txt := String(w._cur.get("text", ""))
	check(txt.begins_with("Open root cellar (2 °C"), "looking down at the hatch shows its prompt (%s | %s | miss %.2f dist %.2f)" % [txt, str(w.hud.actions), w._aim_miss(rc.hatch_world_pos()), (rc.hatch_world_pos() - w.player.position).length()])
	check(rc.lid_k < 0.01 and not rc._pit.visible, "the hatch is shut and the pit hidden before")
	if w._cur.has("act"): (w._cur["act"] as Callable).call()
	check(w.gear.is_open and w.gear._chest == rc.store and w.gear._tab == "chest", "the prompt opens the gear screen on the cellar store")
	await secs(0.8)
	check(rc.lid_k > 0.95 and rc._pit.visible and rc._lid.rotation.x < -1.5, "the lid swings up and the pit shows (lid_k %.2f, rot %.2f)" % [rc.lid_k, rc._lid.rotation.x])
	w.gear.close()
	await secs(0.8)
	check(rc.lid_k < 0.01 and not rc._pit.visible, "closing the gear screen drops the lid")

	# ---- ransack never finds it; it is no claim on the cabin
	var ci: int = w.cabins.find(cb)
	var before: Dictionary = rc.store.contents.duplicate()
	w.world_events.claims.erase(ci)
	check(not w.world_events.claimed(ci), "the cellar's food does not claim the cabin for the player")
	w.world_events.ransack(ci)
	check(rc.store.contents == before, "a ransack upstairs leaves the cellar alone")

	# ---- save round trip
	var sv: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	a1 = float(rc.store.age.get("venison_raw", 0.0))
	check(sv.has("cellar") and (sv["cellar"] as Dictionary).has("store"), "the save carries the cellar")
	var rc2 := RootCellar.new(); rc2.setup(cb, sv["cellar"], 1)
	check(rc2.store.contents == before and absf(float(rc2.store.age.get("venison_raw", 0.0)) - a1) < 1.0, "a reload restores what is down there and its age")
	rc2.queue_free()

	# ---- the cabin burns; the cellar does not
	cb.burned = true
	await frames(3)
	rc.tick(60.0)
	check(is_equal_approx(rc.store.spoilage_rate, r2) and rc.store.contents == before, "under a burned cabin the cellar keeps its 2 C and its stores")
	print("ROOT_CELLAR_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
