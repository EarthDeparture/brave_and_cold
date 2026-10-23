extends SceneTree
## Plan A1: track history. Crumbs are logged anywhere (an animal far off still leaves a trail to find later),
## materialized only near the player, age with snowfall, read as TLD hints, survive save/load, ring stays bounded.
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	# ---- pure TrackLog
	var lg := TrackLog.new()
	var a := lg.add(TrackLog.K.WOLF, 10.0, 10.0)
	lg.add(TrackLog.K.DEER, 500.0, 500.0)
	check(lg.query(10.0, 10.0, 2.0).size() == 1 and lg.query(500.0, 500.0, 2.0).size() == 1, "crumbs are found by chunk query")
	check(lg.query(10.0, 10.0, 2.0, [TrackLog.K.DEER]).is_empty(), "query filters by kind")
	lg.advance(7.0 * 3600.0, 0.0)
	check(not lg.alive(a), "prints expire after 6 effective hours")
	var b := lg.add(TrackLog.K.BLOOD, 0.0, 0.0)
	lg.advance(4.0 * 3600.0, 0.0)
	check(lg.alive(b), "blood outlasts prints (alive at 4 h)")
	lg.advance(1.0 * 3600.0, 1.0)   # one hour of heavy snow = 8 effective hours
	check(not lg.alive(b), "heavy snow buries blood faster (gone after 4 h clear + 1 h blizzard)")
	# ring cap
	var big := TrackLog.new()
	for i in TrackLog.MAX + 500:
		big.add(TrackLog.K.HARE, float(i % 200), floorf(float(i) / 200.0))
	check(big.count == TrackLog.MAX and big.query(0.0, 0.0, 1.5).is_empty() and big.query(0.0, 200.0, 1.5).size() >= 1, "the ring stays bounded at MAX, recycled slots leave their chunk")
	# save / load round trip
	var s1 := TrackLog.new()
	s1.add(TrackLog.K.DEER, 5.0, 5.0, 1.0, 1.0, 1, 7)
	s1.advance(1800.0, 0.0)
	s1.add(TrackLog.K.BLOOD, 6.0, 5.0, 0.0, 0.4)
	s1.add(TrackLog.K.BEAR, 900.0, 900.0)   # beyond the 400 m save radius
	var d := s1.to_dict(Vector3(0, 0, 0))
	var s2 := TrackLog.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)))
	var got := s2.query(5.0, 5.0, 3.0)
	var ok_rt := got.size() == 2 and s2.query(900.0, 900.0, 3.0).is_empty()
	for s in got:
		if s2.kind[s] == TrackLog.K.DEER:
			ok_rt = ok_rt and absf(s2.eff_age(s) - 1800.0) < 1.0 and s2.gait[s] == 1 and s2.owner[s] == 7
	check(ok_rt, "save/load keeps nearby crumbs with their age, gait and owner, drops far ones")
	# ---- in the world
	SaveGame.pending = {}; seed(20261023)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.clock.hour = 12.0; w.clock.time_scale = 48.0
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	if w.ambient_life != null: w.ambient_life.voices_enabled = false
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var side := Vector3(-od.z, 0, od.x)
	var bp: Vector3 = lk.global_position + od * 40.0
	w.player.place(bp.x, bp.z)
	for x in w.deer.duplicate(): w.deer.erase(x); x.queue_free()
	for x in w.wolves.duplicate(): w.wolves.erase(x); x.queue_free()
	await frames(5)
	var at: AnimalTracks = w.animal_tracks
	# a deer 300 m away walks: crumbs are logged though nothing is materialized
	var far: Vector3 = bp + side * 300.0; far.y = w._ground_y(far.x, far.z)
	var deer: Deer = w._add_deer(far, 51)
	await frames(2)
	deer.set_process(false)
	var n0: int = at.stamped
	for i in 60:
		deer.speed_now = 0.8
		var q: Vector3 = far + od * (i * 0.2); q.y = w._ground_y(q.x, q.z)
		deer.global_position = q
		await process_frame
	var logged: int = at.stamped - n0
	at.materialize()
	var shown_far := 0
	for e in at.prints_of("deer"):
		if (e as Decal).global_position.distance_to(far) < 30.0: shown_far += 1
	check(logged >= 8 and shown_far == 0, "a deer 300 m off still logs prints (%d) but none are drawn there" % logged)
	var bands := at.log.query(far.x + od.x * 6.0, far.z + od.z * 6.0, 10.0, [TrackLog.K.BAND]).size()
	check(bands >= 1, "and its line is logged as a band for long-distance reading (%d)" % bands)
	# walk over: they materialize
	w.player.place(far.x + side.x * 3.0, far.z + side.z * 3.0)
	await frames(3)
	at.materialize()
	shown_far = 0
	for e in at.prints_of("deer"):
		if (e as Decal).global_position.distance_to(far) < 30.0: shown_far += 1
	check(shown_far >= 8, "walk over to it and the trail is there (%d prints drawn)" % shown_far)
	# bands show past ~30 m, prints are faint there; bands hidden up close
	var vc: Vector3i = at.visible_counts()
	check(vc.z >= 1, "band decals are in the pool (%d)" % vc.z)
	# read_at
	var mid: Vector3 = far + od * 6.0
	var hint: String = at.read_at(mid)
	check(hint.begins_with("Deer") and hint.find("fresh") >= 0, "looking at it: '%s'" % hint)
	at.log.advance(3.0 * 3600.0, 0.0)
	hint = at.read_at(mid)
	check(hint.begins_with("Deer") and hint.find("fresh") < 0, "three hours later it reads older: '%s'" % hint)
	Carcass.blood(w, mid + side * 0.3, 0.3)
	for i in 4: Carcass.blood(w, mid + od * (1.0 + i), 0.25)
	hint = at.read_at(mid + side * 0.3)
	check(hint.begins_with("Blood") and hint.find("fresh") >= 0 and hint.find("bleeding badly") >= 0, "blood wins the read: '%s'" % hint)
	check(at.read_at(mid + side * 20.0) == "", "bare snow reads nothing")
	# horde trample
	var hz := mid + side * 40.0
	at.log.add(TrackLog.K.TRAMPLE, hz.x, hz.z, 0.0, 8.0, 600)
	hint = at.read_at(hz)
	check(hint.find("horde") >= 0, "a horde's path reads as many feet: '%s'" % hint)
	# HUD: look down at the trail
	Settings.track_hints = true
	w.player.place(mid.x - od.x * 1.6, mid.z - od.z * 1.6)
	w.player.yaw = atan2(-od.x, -od.z)
	w.player.pitch = -0.9
	await frames(3)
	var lp: Vector3 = w.track_look_point()
	check(not is_nan(lp.x) and Vector2(lp.x - mid.x, lp.z - mid.z).length() < 2.5, "the look point lands on the trail ahead (%.1f m off)" % Vector2(lp.x - mid.x, lp.z - mid.z).length())
	await create_timer(0.4).timeout
	check(w.hud.track_hint != "", "the HUD shows the read: '%s'" % w.hud.track_hint)
	Settings.track_hints = false
	await create_timer(0.4).timeout
	check(w.hud.track_hint == "", "and the option turns it off")
	Settings.track_hints = true
	w.player.pitch = 0.0
	await create_timer(0.4).timeout
	check(w.hud.track_hint == "", "looking at the horizon shows nothing")
	# save data
	var sv: Dictionary = w._save_data()
	check(sv.has("tracks") and int(sv["tracks"]["n"]) >= 10, "the save carries the nearby crumbs (%d)" % int(sv["tracks"].get("n", 0)))
	print("TRACK_LOG_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
