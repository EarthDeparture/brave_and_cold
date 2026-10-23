extends SceneTree
## Plan A1 review: a 70 m deer line read from eye height (prints near, band far), a wounded deer's bed + blood,
## a horde's trampled path, a deep-snow drag furrow, and the in-game HUD hint looking down at a trail. -> res://shots/a1/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(12)
	root.get_texture().get_image().save_png("res://shots/a1/" + id + ".png"); print("A1_CAPTURE ", id)

func line(at: AnimalTracks, kind: String, a: Vector3, b: Vector3, owner: int, aged_h := 0.0) -> void:
	var k: Dictionary = AnimalTracks.KINDS[kind]
	var d := b - a; d.y = 0.0
	var L := d.length(); var dir := d / L
	var yaw := atan2(-dir.x, -dir.z)
	var s := 0.0; var left := false; var band_from := 0.0
	while s < L:
		var p := a + dir * s
		left = not left
		var n0: int = at.log.head
		at.stamp(kind, p, yaw, left, false, owner)
		if aged_h > 0.0:
			var i: int = n0
			while i != at.log.head:
				at.log.snow_t[i] -= aged_h * 3600.0; at.log.game_t[i] -= aged_h * 3600.0
				i = (i + 1) % TrackLog.MAX
		if s - band_from >= AnimalTracks.BAND_EVERY:
			var m := a + dir * ((s + band_from) * 0.5)
			at.log.add(TrackLog.K.BAND, m.x, m.z, yaw, s - band_from, int(float(k.band_w) * 100.0), int(AnimalTracks.KIND_ID[kind]), aged_h * 3600.0, aged_h * 3600.0)
			band_from = s
		s += float(k.stride)

func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261023)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/a1"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.rifle_up = false; w.hud.visible = false
	w.ambient_life.voices_enabled = false
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var side := Vector3(-od.z, 0, od.x)
	var base: Vector3 = lk.global_position + od * 40.0
	base.y = w._ground_y(base.x, base.z)
	w.player.place(base.x - od.x * 3.0, base.z - od.z * 3.0)
	for d in w.deer.duplicate(): w.deer.erase(d); d.queue_free()
	for x in w.wolves.duplicate(): w.wolves.erase(x); x.queue_free()
	await frames(5)
	var at: AnimalTracks = w.animal_tracks
	var gy := func(p: Vector3) -> Vector3: return Vector3(p.x, w._ground_y(p.x, p.z), p.z)
	# fresh deer line straight away from the camera, an old wolf line crossing it
	line(at, "deer", base, base + od * 70.0 + side * 6.0, 1)
	line(at, "wolf", base + od * 25.0 - side * 30.0, base + od * 32.0 + side * 30.0, 2, 4.0)
	# wounded deer: blood drops to a bed with a pool
	var bed: Vector3 = gy.call(base + side * 9.0 + od * 8.0)
	for i in 8: at.blood(gy.call(bed - od * (1.5 + i * 1.6) + side * sin(i * 1.3) * 0.3), 0.18 + 0.04 * (i % 3))
	at.log.add(TrackLog.K.BED, bed.x, bed.z, atan2(-od.x, -od.z), 1.0)
	at.blood(bed, 0.55)
	# horde path across the field
	var h0: Vector3 = base + od * 18.0 - side * 40.0
	for i in 10:
		var m: Vector3 = h0 + side * (4.0 + i * 8.0)
		at.log.add(TrackLog.K.TRAMPLE, m.x, m.z, atan2(-side.x, -side.z), 8.0, 600)
	# deep-snow drag furrow
	for i in 8:
		var m2: Vector3 = base - side * 6.0 + od * (2.0 + i * 0.9)
		at.log.add(TrackLog.K.DRAG, m2.x, m2.z, atan2(-od.x, -od.z), 0.9, 12)
	at.materialize()
	print("A1 counts=", at.visible_counts())
	var pn: Dictionary = at._pools["n"]
	for i in (pn.decals as Array).size():
		var s: int = (pn.slot as PackedInt32Array)[i]
		if s >= 0 and at.log.kind[s] == TrackLog.K.TRAMPLE:
			var dd: Decal = pn.decals[i]
			print("A1 trample vis=", dd.visible, " a=", dd.modulate.a, " size=", dd.size, " pos=", dd.global_position, " tex=", dd.texture_albedo != null, " fade=", dd.distance_fade_enabled, " ", dd.distance_fade_begin)
	var c := Camera3D.new(); c.fov = 62; c.near = 0.05; root.add_child(c); c.make_current()
	var eye := base - od * 3.0 + Vector3(0, 1.7, 0)
	c.global_position = eye; c.look_at(eye + od * 20.0 + Vector3(0, -2.6, 0), Vector3.UP)
	await shot("trail_eye")
	c.global_position = eye + Vector3(0, 0, 0); c.look_at(eye + od * 40.0 + side * 3.0 + Vector3(0, -2.0, 0), Vector3.UP)
	c.fov = 30
	await shot("trail_far_zoom")
	c.fov = 62
	var hv: Vector3 = gy.call(h0 + side * 40.0)
	c.global_position = gy.call(hv - od * 14.0) + Vector3(0, 1.7, 0); c.look_at(hv, Vector3.UP)
	await shot("horde_path")
	c.global_position = gy.call(bed - od * 3.5 + side * 0.6) + Vector3(0, 1.6, 0); c.look_at(bed - od * 1.5, Vector3.UP)
	await shot("bed_blood")
	var dg: Vector3 = gy.call(base - side * 6.0 + od * 5.0)
	c.global_position = gy.call(dg - od * 3.0 + side * 1.0) + Vector3(0, 1.5, 0); c.look_at(dg, Vector3.UP)
	await shot("drag")
	# the in-game view: HUD on, looking down at the deer line
	c.queue_free(); w.player.cam.make_current()
	w.hud.visible = true
	var pp: Vector3 = base + od * 3.0 - od * 1.6
	w.player.place(pp.x, pp.z)
	w.player.yaw = atan2(-od.x, -od.z); w.player.pitch = -0.85
	Settings.track_hints = true
	for i in 40: await process_frame
	print("A1 hint='", w.hud.track_hint, "'")
	await shot("hud_hint")
	w.player.place(bed.x - od.x * 1.6, bed.z - od.z * 1.6)
	for i in 40: await process_frame
	print("A1 hint2='", w.hud.track_hint, "'")
	await shot("hud_hint_blood")
	quit(0)
