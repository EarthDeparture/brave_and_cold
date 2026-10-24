extends SceneTree
## Plan A2: drift where the wind reaches the snow (openness, building lee, trunks), ridge / roof plumes over 10 m/s,
## gust snow-bombs from crowns, the blowing-snow hiss following the drift level.
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

func ridge_h(x: float, z: float) -> float:
	return 10.0 * exp(-pow(x / 9.0, 2.0))

func live_count(gd: GroundDrift) -> int:
	var o := 0
	for i in gd.active:
		if float(gd._s[i].get("o", 1.0)) > 0.0: o += 1
	return o

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261024)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.drift_features != null: break
	w.out_path = ""; w.player.god = true; w.clock.hour = 12.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	if w.world_events != null: w.world_events.enabled = false
	if w.ambient_life != null: w.ambient_life.voices_enabled = false
	var gd: GroundDrift = w.ground_drift
	var df: DriftFeatures = w.drift_features
	check(gd != null and df != null, "the world has GroundDrift and DriftFeatures")
	# ---- crest detection on a synthetic ridge (wind across it)
	var hf := Callable(self, "ridge_h")
	check(DriftFeatures.crest_k(hf, Vector2(0, 0), Vector2(1, 0)) >= 1.5, "a crest is found on top of a ridge")
	check(DriftFeatures.crest_k(hf, Vector2(-45, 0), Vector2(1, 0)) == 0.0 and DriftFeatures.crest_k(hf, Vector2(0, 0), Vector2(0, 1)) == 0.0, "not on the flat, nor along the ridge line")
	# ---- openness: find a dense-forest cell and an open one near the start
	var p0: Vector3 = w.player.global_position
	var lo := 9.0; var hi := -1.0
	var plo := p0; var phi := p0
	for ix in range(-20, 21):
		for iz in range(-20, 21):
			var q := p0 + Vector3(ix * 24.0, 0, iz * 24.0)
			var h: float = w._ground_y(q.x, q.z)
			if is_nan(h): continue
			if w.snow.tier_at(q.x, q.z) <= 0: continue
			var o: float = gd.openness_at(q.x, q.z)
			if o < lo: lo = o; plo = q
			if o > hi: hi = o; phi = q
	check(lo < 0.35 and hi > 0.9, "openness: dense forest %.2f, open ground %.2f" % [lo, hi])
	# ---- drift density follows openness
	gd.force_wind = 16.0; df.force_wind = 16.0
	w.weather.wind = 16.0; w.weather.wind_base = 16.0
	w.player.place(phi.x, phi.z)
	await secs(3.5)
	var n_open := live_count(gd)
	w.player.place(plo.x, plo.z)
	await secs(3.5)
	var n_dense := live_count(gd)
	check(n_open >= 100 and n_dense < n_open * 0.3, "streaks: %d live in the open, %d under a dense canopy" % [n_open, n_dense])
	check(gd.ground_wind_k < 0.75, "ground wind in the trees x%.2f" % gd.ground_wind_k)
	# ---- building lee
	var cb: Cabin = w.cabins[2]
	var wd: Vector2 = w.weather.wind_dir.normalized()
	var cc := Vector2(cb.global_position.x, cb.global_position.z)
	w.player.place(cc.x - wd.x * 12.0, cc.y - wd.y * 12.0)
	await secs(1.0)
	gd._refresh_blds(w.player.global_position)
	var keep: Array = gd._blds.duplicate()
	gd._blds = [cb]   # this cabin alone (the hamlet's neighbours have lees of their own)
	var l1: bool = gd.in_lee(cc, wd)
	var l2: bool = gd.in_lee(cc + wd * 8.0, wd)
	var l3: bool = gd.in_lee(cc - wd * 10.0, wd)
	var lee_ok: bool = l1 and l2 and not l3
	gd._blds = keep
	check(lee_ok, "lee: inside and 8 m downwind sheltered, 10 m upwind not")
	await secs(2.0)
	var bad := 0
	for i in gd.active:
		var s: Dictionary = gd._s[i]
		if float(s.get("o", 1.0)) > 0.0 and float(s.age) < 0.03 and gd.in_lee(s.p, wd): bad += 1
	check(bad == 0 and gd.lee_rejects > 0, "no fresh streak starts in the lee (%d refused spawns)" % gd.lee_rejects)
	# ---- trunks
	check(gd.trunk_kills > 0, "streaks that reach a trunk die there (%d)" % gd.trunk_kills)
	# ---- roof plumes: on at 16 m/s by a cabin, off at 8
	await secs(0.5)
	var roof_on := false
	for e in df._roofs: if e.emitting: roof_on = true
	check(roof_on, "snow streams off the cabin roof at 16 m/s")
	df.force_wind = 8.0; gd.force_wind = 8.0
	await frames(3)
	roof_on = false
	for e in df._roofs: if e.emitting: roof_on = true
	check(not roof_on, "and not at 8 m/s")
	# ---- ridge plumes: off at 8 m/s; at 16 m/s, where a crest is in range, an emitter sits on it
	df._ridge_t = 0.0
	await frames(2)
	var any_on := false
	for e in df._plumes: if e.emitting: any_on = true
	check(not any_on and df.ridges.is_empty(), "no ridge plumes under 10 m/s")
	df.force_wind = 16.0; gd.force_wind = 16.0
	var found := false
	for k in 12:
		var q := p0 + Vector3(cos(k * 0.9) * (120.0 + 60.0 * k), 0, sin(k * 0.9) * (120.0 + 60.0 * k))
		if is_nan(w._ground_y(q.x, q.z)): continue
		w.player.place(q.x, q.z)
		await frames(2)
		df._ridge_t = 0.0
		await frames(2)
		if not df.ridges.is_empty(): found = true; break
	var on_crest := false
	if found:
		for e in df._plumes:
			if e.emitting and e.global_position.distance_to(df.ridges[0] + Vector3(0, 1, 0)) < 0.5: on_crest = true
	check(found and on_crest, "over 10 m/s a crest in range gets a plume (%d crests)" % df.ridges.size())
	# ---- gust snow-bomb from a crown 4-12 m away
	w.player.place(plo.x, plo.z)
	await frames(3)
	var b0 := df.bombs
	var dropped := false
	for k in 20:
		if df.drop_bomb(w.player.global_position, wd, 14.0): dropped = true; break
	check(dropped and df.bombs > b0, "a gust knocks snow out of a crown nearby")
	var be: GPUParticles3D = df._bombs[(df._bomb_i + df._bombs.size() - 1) % df._bombs.size()]
	var bd: float = Vector2(be.global_position.x - w.player.global_position.x, be.global_position.z - w.player.global_position.z).length()
	var bh: float = be.global_position.y - w._ground_y(be.global_position.x, be.global_position.z)
	check(bd >= 4.0 and bd <= 12.5 and bh >= 5.5, "from a crown %.1f m away, %.1f m up" % [bd, bh])
	# ---- hiss follows the level
	w.player.place(phi.x, phi.z)
	df.force_wind = 16.0; gd.force_wind = 16.0
	await secs(4.0)
	var loud := df.hiss_db
	gd.force_wind = 0.0; df.force_wind = 0.0
	await secs(4.0)
	var quiet := df.hiss_db
	check(loud > -22.0 and quiet < -60.0, "blowing-snow hiss: %.0f dB in a 16 m/s wind in the open, %.0f dB calm" % [loud, quiet])
	print("DRIFT_FEATURES_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
