extends SceneTree
## Plan A2 review -> res://shots/drift2/: open-ground drift vs dense forest at 16 m/s, a cabin's lee, snow streaming
## off its roof, a ridge plume (the crest the feature picked), a gust snow-bomb out of a crown.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(8)
	root.get_texture().get_image().save_png("res://shots/drift2/" + id + ".png"); print("DRIFT2_CAPTURE ", id)
func look(c: Camera3D, from: Vector3, at: Vector3) -> void:
	c.global_position = from; c.look_at(at, Vector3.UP)

func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261024)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/drift2"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.drift_features != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	w.rifle_up = false; w.hud.visible = false
	if w.world_events != null: w.world_events.enabled = false
	w.ambient_life.voices_enabled = false
	var gd: GroundDrift = w.ground_drift
	var df: DriftFeatures = w.drift_features
	gd.force_wind = 16.0; df.force_wind = 16.0
	w.weather.wind = 16.0; w.weather.wind_base = 16.0
	var wd2: Vector2 = w.weather.wind_dir.normalized()
	var wd := Vector3(wd2.x, 0, wd2.y)
	var c := Camera3D.new(); c.fov = 62; c.near = 0.05; c.far = 3000.0; root.add_child(c); c.make_current()
	var gy := func(p: Vector3, h: float) -> Vector3: return Vector3(p.x, w._ground_y(p.x, p.z) + h, p.z)
	# open vs dense from the openness scan
	var p0: Vector3 = w.player.global_position
	var lo := 9.0; var hi := -1.0; var plo := p0; var phi := p0
	for ix in range(-20, 21):
		for iz in range(-20, 21):
			var q := p0 + Vector3(ix * 24.0, 0, iz * 24.0)
			if is_nan(w._ground_y(q.x, q.z)) or w.snow.tier_at(q.x, q.z) <= 0: continue
			var o: float = gd.openness_at(q.x, q.z)
			if o < lo: lo = o; plo = q
			if o > hi: hi = o; phi = q
	w.player.place(phi.x, phi.z)
	await create_timer(4.0).timeout
	look(c, gy.call(phi, 1.7), gy.call(phi + wd * 20.0, 0.0))
	await shot("open_downwind")
	w.player.place(plo.x, plo.z)
	await create_timer(4.0).timeout
	look(c, gy.call(plo, 1.7), gy.call(plo + wd * 20.0, 0.0))
	await shot("forest_calm")
	# cabin lee + roof plume (look across the wind at the cabin)
	var cb: Cabin = w.cabins[2]
	var cp: Vector3 = cb.global_position
	var side := Vector3(-wd.z, 0, wd.x)
	w.player.place(cp.x + side.x * 16.0, cp.z + side.z * 16.0)
	await create_timer(4.0).timeout
	look(c, gy.call(cp + side * 16.0 - wd * 4.0, 1.7), cp + Vector3(0, 2.5, 0) + wd * 3.0)
	await shot("cabin_lee_roof")
	# ridge plume: find a crest
	var found := false
	for k in 14:
		var q := p0 + Vector3(cos(k * 0.9) * (120.0 + 60.0 * k), 0, sin(k * 0.9) * (120.0 + 60.0 * k))
		if is_nan(w._ground_y(q.x, q.z)): continue
		w.player.place(q.x, q.z)
		await frames(2)
		df._ridge_t = 0.0
		await frames(2)
		if not df.ridges.is_empty(): found = true; break
	print("DRIFT2 ridge found=", found, " n=", df.ridges.size())
	if found:
		await create_timer(5.0).timeout
		var r: Vector3 = df.ridges[0]
		var cam: Vector3 = gy.call(r - wd * 30.0 + side * 60.0, 2.0)
		c.fov = 50
		look(c, cam, r + Vector3(0, 3, 0) + wd * 15.0)
		print("DRIFT2 ridge ", r, " plume at ", df._plumes[0].global_position, " emitting=", df._plumes[0].emitting)
		await shot("ridge_plume")
	# snow-bomb in the forest
	w.player.place(plo.x, plo.z)
	await frames(4)
	var ok := false
	for k in 20:
		if df.drop_bomb(w.player.global_position, wd2, 14.0): ok = true; break
	if ok:
		var be: GPUParticles3D = df._bombs[(df._bomb_i + df._bombs.size() - 1) % df._bombs.size()]
		await create_timer(0.35).timeout
		look(c, gy.call(plo, 1.7), be.global_position - Vector3(0, 1.0, 0))
		print("DRIFT2 bomb at ", be.global_position, " d=", be.global_position.distance_to(gy.call(plo, 1.7)))
		await shot("snow_bomb")
	quit(0)
