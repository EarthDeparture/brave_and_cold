extends SceneTree
## F4 room climate: rooms warm with their stove over tens of minutes, keep residual
## heat when it goes out, lose heat through an open door, and the body feels the room.
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
	var stove := FireSource.new("wood_stove"); var room := RoomClimate.new(6.0, stove, 24.0)
	room.settle(-15.0)
	check(is_equal_approx(room.room_c, -9.0), "cold shut cabin holds outside + 6 C")
	stove.set_fuel(6 * 3600); var start := room.room_c
	room.advance(15 * 60, -15.0); var after15 := room.room_c
	room.advance(30 * 60, -15.0); var after45 := room.room_c
	var target := room.target_c(-15.0)
	check(after15 > start and after45 > after15 and after45 < target, "lighting the stove warms the room gradually, not instantly (%.1f -> %.1f -> %.1f of %.1f C)" % [start, after15, after45, target])
	check(absf((after45 - start) / (target - start) - (1.0 - exp(-1.0))) < 0.02, "45 game minutes closes ~63% of the gap")
	room.advance(6 * 3600, -15.0); var warm := room.room_c
	check(warm > 13.0, "a stoked cabin settles warm: %.1f C at -15 outside" % warm)
	stove.set_fuel(0); room.advance(30 * 60, -15.0)
	check(room.room_c < warm and room.room_c > warm - 0.5 * (warm - room.target_c(-15.0)), "a dead stove leaves residual warmth (cools slower than it warmed)")
	var shut := RoomClimate.new(6.0, null); shut.settle(-15.0); var open := RoomClimate.new(6.0, null); open.leak = 0.5; open.room_c = shut.room_c
	open.advance(3600, -15.0)
	check(open.room_c < shut.room_c, "an open door bleeds the room toward outside")

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	var cb: Cabin = w.cabins[0]
	check(w.rooms.size() >= w.cabins.size() + w.stores.size() + w.huts.size() + 1, "every enclosed building has a room climate (%d)" % w.rooms.size())
	var tower: RoomClimate = w.room_at(w.fire_lookout.to_global(Vector3(0, FireLookout.DECK_Y + 1.0, 0)))
	check(tower != null and tower.room_c > w.clock.ambient_c() + 12.0, "new game: the crew-lit lookout stove has the room already warm (%.1f C vs %.1f outside)" % [tower.room_c if tower != null else 0.0, w.clock.ambient_c()])
	var inside := cb.to_global(Vector3(0, Cabin.FLOOR_LOCAL_Y + 1.0, 0))
	w.player.position = inside
	check(w.room_at(inside) != null and is_equal_approx(w.air_c(), w.room_at(inside).room_c), "inside, the body feels the room's air")
	w.player.position = cb.to_global(Vector3(0, 1, 12))
	check(w.room_at(w.player.position) == null and w.air_c() == w.clock.ambient_c(), "outside, the body feels the weather")
	w.player.position = inside
	w._process(0.1)
	check(not is_nan(w.hud.indoor_c), "HUD reports indoor temperature")
	(w.room_at(inside) as RoomClimate).room_c = 7.25
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	check(snap.has("rooms") and (snap.rooms as Array).size() == w.rooms.size(), "room temperatures are saved")
	w.queue_free(); await process_frame; await process_frame
	SaveGame.pending = snap
	var w2: Node3D = load("res://world/game_world.gd").new(); root.add_child(w2)
	for frame in 700:
		await process_frame
		if w2.opening != null and w2.gear != null: break
	freeze(w2)
	var back: RoomClimate = w2.room_at(w2.cabins[0].to_global(Vector3(0, Cabin.FLOOR_LOCAL_Y + 1.0, 0)))
	check(back != null and is_equal_approx(back.room_c, 7.25), "room temperature survives save/load")
	w2.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("ROOM_CLIMATE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
