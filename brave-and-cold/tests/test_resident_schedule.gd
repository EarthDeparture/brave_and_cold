extends SceneTree
## Plan A3: named residents keep a day - work, a midday break, evenings at a stove, a night asleep indoors - and
## their stoves, doors and the shop sign follow them. Departure and illness still override the routine.
var checks := 0
var failures := 0
var w: Node3D
var life: TownLife
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func at(day: int, hour: float) -> void:
	w.clock.day = day; w.clock.hour = hour; life._last_calendar = -1; life.update(0)
func look_away() -> void:   # camera points at the sky so nothing on the ground is "observed"
	w.player.cam.global_position = Vector3(0, 900, 0); w.player.cam.look_at(Vector3(1, 1800, 0), Vector3.FORWARD)
func outdoors(a: TownResident) -> bool:
	if not a.visible: return false
	for b in w._building_list():
		if b.has_method("contains_xz") and b.contains_xz(a.global_position.x, a.global_position.z): return false
	return true

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261004)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 700:
		await process_frame
		if w.town_life != null and w.gear != null: break
	w.out_path = "test-no-autosave"; w.clock.time_scale = 0.0; w.player.god = true
	life = w.town_life
	var rowan: TownResident = life.actors.rowan
	var lin: TownResident = life.actors.lin
	var sam: TownResident = life.actors.sam
	check(life.homes.has("lin") and life.homes.has("sam") and life.homes.lin != life.homes.sam, "Lin and Sam each have a hamlet cabin")
	check(rowan.mode == "work" and lin.mode == "work" and sam.mode == "work" and not life.closed_sign.visible, "05:30 D1 (game start): all three at work, shop open")
	look_away()
	at(1, 10.0)
	check(rowan.mode == "work" and life.store.door_open, "10:00 Rowan at the counter, shop door open")
	at(1, 12.3)
	check(lin.activity == "lunch" and life.store.contains_xz(lin.global_position.x, lin.global_position.z) and lin.pose == "warm", "12:20 Lin takes lunch inside by the shop stove")
	at(1, 13.2)
	check(sam.activity == "smoke" and outdoors(sam), "13:10 Sam on a smoke break outside the clinic")
	at(1, 17.8)
	check(lin.mode == "away" and not lin.visible, "17:50 Lin is on the road home (out of sight)")
	at(1, 19.0)
	var lc: Cabin = life.homes.lin
	check(lin.activity == "home" and lc.contains_xz(lin.global_position.x, lin.global_position.z) and lin.visible, "19:00 Lin is home, in her cabin")
	check(lc.fire.is_lit() and lc.cue_suppressed, "and her stove is lit (no horde lure before the outbreak)")
	check(rowan.activity == "stove" and life.store.contains_xz(rowan.global_position.x, rowan.global_position.z) and life.store.stove.fire.is_lit() and life.closed_sign.visible, "19:00 Rowan by the shop stove, shop closed")
	var acts := life.actions()
	check(acts.any(func(it: Dictionary) -> bool: return String(it.text).contains("Rowan")), "you can still knock and talk to Rowan in the evening")
	at(1, 23.5)
	check(lin.mode == "sleep" and lc.contains_xz(lin.global_position.x, lin.global_position.z), "23:30 Lin asleep in bed")
	check(not acts.is_empty() and not life.actions().any(func(it: Dictionary) -> bool: return String(it.text).contains("Lin")), "a sleeping resident cannot be talked to")
	check(rowan.mode == "away" and not life.store.door_open, "Rowan has turned in; the shop door is shut")
	at(2, 2.0)
	var out := 0
	for a: TownResident in [rowan, lin, sam]:
		if outdoors(a): out += 1
	check(out == 0, "02:00: nobody is outdoors (%d outside)" % out)
	var fuel0: float = lc.fire.fuel_s
	lc.fire.advance(3600.0)
	life._last_calendar = -1; life.update(0)
	check(lc.fire.fuel_s < fuel0, "an asleep household's stove is left to burn down")
	at(2, 20.0)
	check(sam.mode == "work", "D2 (worried) 20:00: Sam is still at the clinic")
	at(2, 5.6)
	check(rowan.mode == "work" and life.store.door_open and not life.closed_sign.visible, "05:36 next day: the shop is open again")
	# never vanish in front of the player
	look_away()
	at(2, 20.9)
	var away_from: Vector3 = sam.global_position - w.collapse.clinic.global_position; away_from.y = 0
	w.player.cam.global_position = sam.global_position + away_from.normalized() * 5.0 + Vector3(0, 1.6, 0); w.player.cam.look_at(sam.global_position + Vector3.UP * 1.2, Vector3.UP)
	print("  watch observed=", life.observed(sam))
	at(2, 21.05)
	check(sam.mode == "work" and sam.visible, "watched at 21:03, Sam does not vanish mid-sentence")
	at(2, 21.4)
	check(sam.mode == "away" and not sam.visible, "past the grace time Sam goes anyway")
	look_away()
	# departure overrides the routine; the leaver is placed at work first
	at(2, 23.9)
	check(lin.mode == "sleep", "D2 night Lin asleep")
	at(3, 8.0)
	check(lin.leaving or bool(life.history.record("lin").departed), "D3 08:00 Lin departs as before (routine does not block it)")
	# illness overrides
	at(3, 11.0)
	check(rowan.phase == TownResidentState.Phase.ILL and rowan.mode == "work" and rowan.visible, "D3 11:00 ill Rowan stays at the store")
	w.queue_free(); await process_frame; await process_frame
	print("RESIDENT_SCHEDULE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
