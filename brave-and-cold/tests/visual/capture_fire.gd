extends SceneTree
## Plan A4 E2 review -> res://shots/fire/: a hamlet cabin burning at night (near / 400 m / from the lookout), after the
## roof falls in, smouldering, the day smoke column from far, the burned shell by day (outside and inside).
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(10)
	root.get_texture().get_image().save_png("res://shots/fire/" + id + ".png"); print("FIRE_CAPTURE ", id)

func look(c: Camera3D, from: Vector3, at: Vector3) -> void:
	c.global_position = from; c.look_at(at, Vector3.UP)

func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261025)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/fire"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.day = 5; w.clock.hour = 22.5; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.rifle_up = false; w.hud.visible = false
	w.ambient_life.voices_enabled = false
	var we: WorldEvents = w.world_events
	we.enabled = false
	var cb: Cabin = w.cabins[3]
	var cp: Vector3 = cb.global_position
	var out: Vector3 = (cb.to_global(Vector3(0, 0, 1)) - cp).normalized()
	var side := Vector3(-out.z, 0, out.x)
	var gy := func(p: Vector3, h: float) -> Vector3: return Vector3(p.x, w._ground_y(p.x, p.z) + h, p.z)
	var c := Camera3D.new(); c.fov = 62; c.near = 0.05; c.far = 4000.0; root.add_child(c); c.make_current()
	var now: float = w.clock.total_game_s
	we.start_fire(3, now - CabinFire.IGNITE_S * 0.6)
	var cf: CabinFire = cb.on_fire
	# a clear side: the direction from the hamlet centre through this cabin (no other cabin in between)
	var hc := Vector3.ZERO
	for o in w.cabins: hc += o.global_position
	hc /= float(w.cabins.size())
	var clear: Vector3 = cp - hc; clear.y = 0; clear = clear.normalized()
	out = clear; side = Vector3(-out.z, 0, out.x)
	var near: Vector3 = gy.call(cp + out * 24.0 + side * 6.0, 1.7)
	w.player.place(near.x, near.z)
	await create_timer(3.0).timeout
	look(c, near, cp + Vector3(0, 1.8, 0))
	await shot("ignition")
	cf.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.2
	await create_timer(14.0).timeout
	look(c, near, cp + Vector3(0, 4.0, 0))
	await shot("blaze_near")
	look(c, gy.call(cp + out * 30.0, 9.0), cp + Vector3(0, 4.0, 0))
	await shot("blaze_high")
	var mid: Vector3 = gy.call(cp + out * 400.0, 30.0)   # raised over the treeline: what a ridge view shows
	w.player.place(mid.x, mid.z)
	await create_timer(2.0).timeout
	look(c, mid, cp + Vector3(0, 20.0, 0))
	await shot("blaze_400m")
	var lkd: Vector3 = (cp - w.fire_lookout.global_position); lkd.y = 0; lkd = lkd.normalized()
	var lk: Vector3 = w.fire_lookout.global_position + lkd * 7.0 + Vector3(0, 14.0, 0)
	w.player.place(w.fire_lookout.global_position.x, w.fire_lookout.global_position.z)
	await create_timer(2.0).timeout
	print("FIRE lookout dist=", lk.distance_to(cp))
	c.fov = 40
	look(c, lk, cp + Vector3(0, 30.0, 0))
	await shot("blaze_from_lookout")
	c.fov = 62
	cf.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.5
	w.player.place(near.x, near.z)
	await create_timer(8.0).timeout
	print("FIRE collapsed=", cf.collapsed, " stage=", cf.stage, " burned=", cb.burned, " lures=", cf.lures)
	look(c, near, cp + Vector3(0, 2.5, 0))
	await shot("blaze_collapsed")
	cf.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S - CabinFire.SMOULDER_S * 0.15
	await create_timer(8.0).timeout
	look(c, gy.call(cp + out * 12.0 + side * 5.0, 1.7), cp + Vector3(0, 1.0, 0))
	await shot("smoulder_night")
	# day: the column from ~1.5 km
	w.clock.hour = 13.0
	cf.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.55
	await create_timer(42.0).timeout
	look(c, gy.call(cp + out * 70.0, 6.0), cp + Vector3(0, 30.0, 0))
	print("FIRE smoke emitting=", cf._smoke.emitting, " ratio=", cf._smoke.amount_ratio, " stage=", cf.stage)
	await shot("day_column_70m")
	var far: Vector3 = gy.call(w.fire_lookout.global_position, 120.0)
	w.player.place(far.x, far.z)
	await create_timer(2.0).timeout
	look(c, far, cp + Vector3(0, 70.0, 0))
	c.fov = 45
	await shot("day_column_1500m")
	c.fov = 62
	# the shell, cold, by day
	cf.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S - CabinFire.SMOULDER_S - 3600.0
	w.player.place(near.x, near.z)
	await create_timer(3.0).timeout
	look(c, gy.call(cp + out * 9.0 + side * 4.0, 1.7), cp + Vector3(0, 1.0, 0))
	await shot("shell_day")
	look(c, cb.to_global(Vector3(1.8, 1.9, 1.6)), cb.to_global(Vector3(-1.5, 0.5, -1.0)))
	await shot("shell_inside")
	quit(0)
