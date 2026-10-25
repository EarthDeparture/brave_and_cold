extends SceneTree
## Alive L2 + L1.4 review: print types close up, a live wounded-deer blood trail, ground drift in wind.
## -> res://shots/l2/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func secs(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0): await process_frame
func shot(id: String) -> void:
	await frames(12)
	root.get_texture().get_image().save_png("res://shots/l2/" + id + ".png"); print("L2_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261022)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/l2"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.rifle_up = false; w.hud.visible = false
	w.ambient_life.voices_enabled = false
	var lk: Node3D = w.fire_lookout
	var out_dir: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var base: Vector3 = lk.global_position + out_dir * 40.0
	base.y = w._ground_y(base.x, base.z)
	w.player.place(base.x - out_dir.x * 6.0, base.z - out_dir.z * 6.0)
	for d in w.deer.duplicate(): w.deer.erase(d); d.queue_free()
	await frames(5)
	var at: AnimalTracks = w.animal_tracks
	var side := Vector3(-out_dir.z, 0, out_dir.x)
	var yaw := atan2(-out_dir.x, -out_dir.z)
	var kinds := ["deer", "wolf", "bear", "hare"]
	for li in 4:
		var lane: Vector3 = base + side * (float(li) - 1.5) * 1.1
		for s in 7:
			var p: Vector3 = lane + out_dir * (float(s) * float(AnimalTracks.KINDS[kinds[li]].stride))
			at.stamp(kinds[li], p, yaw, s % 2 == 0, kinds[li] == "hare")
	for i in 5:
		at.blood(base + side * 3.2 + out_dir * (float(i) * 1.4), randf_range(0.16, 0.34))
	var c := Camera3D.new(); c.fov = 55; c.near = 0.05; root.add_child(c); c.make_current()
	c.global_position = base - out_dir * 1.5 + Vector3(0, 2.2, 0); c.look_at(base + out_dir * 2.5, Vector3.UP)
	await shot("prints_lanes")
	c.global_position = base + side * 3.2 + out_dir * 1.0 + Vector3(0, 0.9, 0) - out_dir * 0.6; c.look_at(base + side * 3.2 + out_dir * 2.0, Vector3.UP)
	await shot("blood_close")
	# ---- live: wounded deer
	var dp: Vector3 = base + out_dir * 14.0 + side * 8.0; dp.y = w._ground_y(dp.x, dp.z)
	var deer: Deer = w._add_deer(dp, 77) if w.has_method("_add_deer") else null
	if deer != null:
		await frames(3)
		deer.hit(24.0, w.player.global_position)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 25000 and not deer.is_dead(): await process_frame
		print("L2 deer dead=", deer.is_dead(), " dist=", deer.global_position.distance_to(dp), " tracks=", at.visible_counts())
		var mid: Vector3 = dp.lerp(deer.global_position, 0.25)
		var to: Vector3 = (deer.global_position - dp); to.y = 0
		c.global_position = dp - to.normalized() * 3.0 + Vector3(0, 1.7, 0); c.look_at(dp + to.normalized() * 14.0, Vector3.UP)
		await shot("deer_trail_start")
		var endp: Vector3 = deer.global_position
		c.global_position = endp - to.normalized() * 7.0 + Vector3(0, 1.7, 0); c.look_at(endp, Vector3.UP)
		await shot("deer_trail_end")
	else:
		print("L2 no _add_deer")
	# ---- ground drift
	w.ground_drift.force_wind = 15.0
	w.weather.wind = 15.0
	await secs(3.0)
	var eye: Vector3 = w.player.cam.global_position
	var wd: Vector2 = w.weather.wind_dir.normalized()
	c.fov = 62; c.global_position = eye; c.look_at(eye + Vector3(wd.x, -0.12, wd.y) * 10.0, Vector3.UP)
	await shot("drift_downwind")
	c.look_at(eye + Vector3(-wd.y, -0.15, wd.x) * 10.0, Vector3.UP)
	await shot("drift_crosswind")
	print("L2 drift level=", w.ground_drift.level, " active=", w.ground_drift.active)
	w.clock.hour = 18.0; await secs(0.5)
	await shot("drift_dusk")
	quit(0)
