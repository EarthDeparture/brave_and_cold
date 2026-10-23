extends SceneTree
## Alive L2 / L1.4 / food web 2: animal prints + blood splatters, the wounded-deer trail, wolves feeding portion by
## portion and wounded wolves dripping, ravens waiting / squabbling / taking off, ground drift, aurora static.
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
	SaveGame.pending = {}; seed(20261022)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.clock.hour = 12.0; w.clock.time_scale = 48.0
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	w.ambient_life.voices_enabled = false
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var side := Vector3(-od.z, 0, od.x)
	var bp: Vector3 = lk.global_position + od * 40.0
	w.player.place(bp.x, bp.z)
	for d in w.deer.duplicate(): w.deer.erase(d); d.queue_free()
	for x in w.wolves.duplicate(): w.wolves.erase(x); x.queue_free()
	await frames(5)
	var at: AnimalTracks = w.animal_tracks
	check(at != null and AnimalTracks.instance == at, "the world has AnimalTracks")
	# ---- a walking deer lays a single line, a running one bounding groups
	var dp: Vector3 = bp + side * 10.0; dp.y = w._ground_y(dp.x, dp.z)
	var deer: Deer = w._add_deer(dp, 31)
	await frames(2)
	deer.set_process(false)
	var n0: int = at.stamped
	for i in 40:
		deer.speed_now = 0.8
		var q: Vector3 = dp + od * (i * 0.15); q.y = w._ground_y(q.x, q.z)
		deer.global_position = q
		await process_frame
	var walk_n: int = at.stamped - n0
	at.materialize()
	check(walk_n >= 7 and walk_n <= 12 and at.prints_of("deer").size() >= 7, "a walking deer lays a line of prints (%d over 6 m)" % walk_n)
	n0 = at.stamped
	var dp2: Vector3 = deer.global_position
	for i in 30:
		deer.speed_now = 8.0
		var q: Vector3 = dp2 + od * (i * 0.4); q.y = w._ground_y(q.x, q.z)
		deer.global_position = q
		await process_frame
	var run_n: int = at.stamped - n0
	check(run_n >= 12 and run_n % 4 == 0, "a running deer bounds: prints in groups of four (%d over 12 m)" % run_n)
	deer.set_process(true)
	# ---- prints age in game time and fill in faster in snowfall
	var lg: TrackLog = at.log
	var i0: int = lg.add(TrackLog.K.DEER, bp.x, bp.z)
	var e0: float = lg.eff_age(i0); var r0: float = lg.real_age(i0)
	lg.advance(60.0, 0.0)
	var clear_age: float = lg.eff_age(i0) - e0
	var e1: float = lg.eff_age(i0)
	lg.advance(60.0, 1.0)
	var snow_age: float = lg.eff_age(i0) - e1
	var real_d: float = lg.real_age(i0) - r0
	check(clear_age > 59.0 and snow_age > clear_age * 6.0 and is_equal_approx(real_d, 120.0), "prints age in game time, fill in ~8x faster in heavy snow (%.0f s vs %.0f s), real age unaffected" % [clear_age, snow_age])
	# ---- blood splatters
	var b0: int = at.visible_counts().y
	Carcass.blood(w, bp + od * 2.0, 0.3)
	at.materialize()
	check(at.visible_counts().y == b0 + 1, "Carcass.blood draws a splatter decal")
	# ---- a wounded deer bolts away from the shot and leaves a blood trail
	var shooter: Vector3 = w.player.global_position
	var start: Vector3 = deer.global_position
	b0 = at.visible_counts().y
	deer.hit(24.0, shooter)
	await secs(5.0)
	var fled: float = deer.global_position.distance_to(shooter) - start.distance_to(shooter)
	at.materialize()
	var drops: int = at.visible_counts().y - b0
	check(fled > 15.0, "the hit deer bolts away from the shooter (+%.0f m)" % fled)
	check(drops >= 8, "and bleeds a trail (%d drops in 5 s)" % drops)
	deer.hp = Deer.BED_HP - 1.0
	deer._set_state(Deer.State.GRAZE)
	await secs(1.5)
	check(deer.speed_now < 0.4 or deer.is_dead(), "weak from blood loss it beds down (speed %.2f)" % deer.speed_now)
	deer.hp = 0.5
	await secs(1.5)
	check(deer.is_dead() and deer.is_in_group("carcasses"), "and dies there: a carcass at the end of the trail")
	# ---- wolves feed portion by portion and walk off sated
	var wp: Vector3 = deer.global_position + side * 1.5; wp.y = w._ground_y(wp.x, wp.z)
	var wolf: Wolf = w._add_wolf(wp, 41)
	await frames(2)
	wolf.set_process(false)
	deer.set_meta("scavenged", 0.0)
	wolf._carcass = deer; wolf.state = Wolf.State.INVESTIGATE
	wolf._eat_carcass()
	check(is_equal_approx(Carcass.scavenged(deer), 1.0) and wolf._carcass == deer and Carcass.has_meat(deer), "a wolf tears off one portion at a time and keeps feeding")
	wolf._eat_carcass()
	check(wolf._carcass == null and wolf._sated_t > 0.0 and Carcass.has_meat(deer) and Carcass.meat_left(deer, 6) == 4, "sated after two, it walks off and leaves the rest (%d of 6 left)" % Carcass.meat_left(deer, 6))
	check(wolf._smell_carcass() == null, "a sated wolf ignores the kill")
	deer.set_meta("scavenged", 5.0)
	wolf._sated_t = 0.0; wolf._carcass = deer; wolf._eaten = 0
	wolf._eat_carcass()
	check(not Carcass.has_meat(deer), "the last portion eaten: the meat is gone")
	wolf.set_process(true)
	# ---- a wounded wolf drips blood
	b0 = at.visible_counts().y
	wolf.hit(10.0, shooter)
	check(wolf._bleed_t > 60.0, "a wounded wolf bleeds")
	wolf.set_process(false)
	for i in 40:
		wolf.speed_now = 6.0
		wolf._bleed_t = 50.0
		wolf._blood_d += 0.3
		if wolf._blood_d > 3.5: wolf._blood_d = 3.6
		wolf._process(0.05)
	at.materialize()
	check(at.visible_counts().y > b0, "and leaves drops behind it")
	w.wolves.erase(wolf); wolf.queue_free()
	# ---- ravens: wait for wolves, take off, squabble
	var al: AmbientLife = w.ambient_life
	for f0 in al.flocks.duplicate(): al._free_flock(f0)
	var kill := Node3D.new(); w.add_child(kill); var kp: Vector3 = bp + od * 60.0; kp.y = w._ground_y(kp.x, kp.z)
	kill.global_position = kp; kill.add_to_group("carcasses"); kill.set_meta("scent_age_s", 900.0)
	var f: Dictionary = al._new_kill_flock(kill)
	var feeder: Wolf = w._add_wolf(kp + side * 1.0, 42)
	await frames(2)
	feeder.set_process(false)
	f.ts = 30.0; f.quiet = 60.0
	var tw := Time.get_ticks_msec()
	while f.base_h > 14.0 and Time.get_ticks_msec() - tw < 12000: await process_frame
	check(f.state == "circle" and f.base_h <= 14.0, "a wolf on the kill: ravens wait, wheeling low (%.0f m), never landing" % f.base_h)
	w.wolves.erase(feeder); feeder.queue_free()
	await frames(2)
	f.state = "ground"; f.ts = 0.0
	for b in f.birds:
		b.pos = kp + Vector3(randf_range(-2, 2), AmbientLife.PERCH_Y, randf_range(-2, 2)); b.land = b.pos; b.fold = 1.0; b.legs = 1.0
	al.squabble(f)
	var flicked := 0
	for b in f.birds:
		if float(b.flick) > 0.0: flicked += 1
	check(int(f.get("squabbles", 0)) == 1 and flicked == 2, "two ravens squabble over the meat (lunge + retreat)")
	al.scatter(f, w.player.global_position)
	var legs_out := 0
	for b in f.birds:
		if float(b.legs) > 0.5 and float(b.pitch) > 0.3 and b.vel.y > 3.0: legs_out += 1
	check(legs_out == f.birds.size(), "take-off: a jump on the legs, nose up")
	await secs(0.8)
	var tucked := 0
	for b in f.birds:
		if float(b.legs) < 0.5: tucked += 1
	check(tucked == f.birds.size(), "legs tucked once airborne")
	kill.remove_from_group("carcasses"); kill.queue_free()
	# ---- ground drift
	var gd: GroundDrift = w.ground_drift
	gd.force_wind = 3.0; await secs(1.0)
	check(gd.active == 0, "no ground drift in a light wind")
	gd.force_wind = 15.0; await secs(3.0)
	check(gd.level > 0.6 and gd.active > 120 and gd._grains.emitting, "a strong wind streams snow along the ground (%d streaks, level %.2f)" % [gd.active, gd.level])
	var pp2: Vector3 = w.player.global_position
	var inside := 0
	for i in gd.active:
		if (gd._s[i].p - Vector2(pp2.x, pp2.z)).length() <= GroundDrift.R + 3.0: inside += 1
	check(inside == gd.active, "the streak field stays round the player (%d / %d inside %.0f m)" % [inside, gd.active, GroundDrift.R])
	gd.force_wind = -1.0
	# ---- aurora static
	var st = w.opening.state
	var was_on: bool = st.receiver_on
	st.receiver_on = true
	al.force_aurora = 0.0; await secs(0.5)
	check(al.radio_static.x == 0.0, "no aurora: the dead receiver is silent")
	al.force_aurora = 1.0; await secs(1.0)
	check(al.radio_static.x > 0.5 or w.opening.speaker.playing, "aurora up: the switched-on receiver hisses with static (%.2f)" % al.radio_static.x)
	al.force_aurora = -1.0; st.receiver_on = was_on
	check(load(AmbientLife.AMB + "aurora_static.wav") is AudioStream, "static clip")
	w.queue_free(); await process_frame; await process_frame
	print("TRACKS_DRIFT_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
