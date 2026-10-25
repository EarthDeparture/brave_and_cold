extends SceneTree
## Plan A5: the infected notice gradually. Awareness rises with sight weight x how noticeable you are, decays unseen;
## 0.35 suspicious (stops, stares, goes to look), 1 chase; point blank, a hit or a close gunshot = 1.
var checks := 0
var failures := 0
var w: Node3D
var z: Zombie
var zp: Vector3
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame

## Hold the zombie on its spot facing the player for s seconds (real time); return the time it first chased (-1 none).
func hold(s: float, face := true) -> float:
	var t0 := Time.get_ticks_msec()
	var chased := -1.0
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		z.global_position = zp
		if face:
			var to: Vector3 = w.player.global_position - zp
			z.rotation.y = atan2(-to.x, -to.z)
		await process_frame
		if chased < 0.0 and z.state == Zombie.State.CHASE: chased = (Time.get_ticks_msec() - t0) / 1000.0
	return chased

func reset_z() -> void:
	z.awareness = 0.0; z.suspicious = false; z._set_state(Zombie.State.IDLE); z._last_seen_t = 99.0
	z._target = zp

func place_player(d: float) -> void:
	var p: Vector3 = zp + dir * d
	w.player.place(p.x, p.z)

var dir := Vector3.ZERO

## The player reads crouch from the raw C key every frame: press / release it for real.
func crouch(on: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_C; ev.physical_keycode = KEY_C; ev.pressed = on
	Input.parse_input_event(ev)

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261026)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null: break
	w.out_path = ""; w.player.god = true
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	w.world_events.enabled = false
	if w.ambient_life != null: w.ambient_life.voices_enabled = false
	w.clock.time_scale = 0.0
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	dir = Vector3(-od.z, 0, od.x)
	zp = lk.global_position + od * 45.0
	zp.y = w._ground_y(zp.x, zp.z)
	for x in w.zombies.duplicate():
		if is_instance_valid(x) and x.global_position.distance_to(zp) < 150.0: x.park() if x.has_method("park") else x.queue_free()
	z = w._add_zombie(zp, 501)
	await frames(3)
	check(z != null and "awareness" in z, "zombies have awareness")
	# ---- noon, standing, walking, 12 m: chase in under 2 s
	w.clock.hour = 12.0
	crouch(false)
	w.stealth_vis_override = 1.0
	place_player(12.0); reset_z()
	var t := await hold(3.0)
	check(t > 0.0 and t < 2.0, "noon, standing, walking at 12 m: chase in %.2f s" % t)
	# ---- noon, standing still, 15 m: suspicious first, not an instant chase
	w.stealth_vis_override = 0.35
	place_player(15.0); reset_z()
	await hold(2.6)
	check(z.suspicious and z.state == Zombie.State.INVESTIGATE and z.awareness >= Zombie.SUSPICIOUS and z.awareness < 1.0, "noon, still at 15 m: suspicious (%.2f), investigating, not chasing" % z.awareness)
	check(z.speed_now < 0.3, "it stops and stares first (speed %.2f)" % z.speed_now)
	# ---- unseen: it decays
	var a0 := z.awareness
	place_player(80.0)
	await hold(2.0, false)
	check(z.awareness < a0 - 0.15, "out of sight it loses interest (%.2f -> %.2f)" % [a0, z.awareness])
	# ---- night, crouched, still, 12 m in the cone: no chase in 10 s
	w.clock.hour = 1.0
	await frames(5)
	crouch(true)
	w.stealth_vis_override = 0.25
	place_player(12.0); reset_z()
	await frames(3)
	t = await hold(10.0)
	check(w.player.crouching and t < 0.0 and z.awareness < Zombie.SUSPICIOUS, "night, crouched, still at 12 m: unnoticed for 10 s (%.2f)" % z.awareness)
	# ---- night, standing beside a burning campfire, 15 m: noticed
	crouch(false)
	w.stealth_vis_override = 0.35
	place_player(15.0)
	var cf := Campfire.new(); w.add_child(cf)
	var fp: Vector3 = w.player.global_position + dir * 1.5; fp.y = w._ground_y(fp.x, fp.z)
	cf.global_position = fp; w.campfires.append(cf); cf.fire.set_fuel(3600.0)
	reset_z()
	await frames(2)
	check(Zombie.fire_lit, "standing by a fire at night lights you up")
	t = await hold(9.0)
	check(t > 0.0, "night, still beside a fire at 15 m: chased (%.1f s)" % t)
	cf.fire.set_fuel(0.0)
	# ---- point blank
	w.clock.hour = 1.0
	w.stealth_vis_override = 0.25
	crouch(true)
	place_player(2.0); reset_z()
	await hold(0.5)
	check(z.awareness >= 1.0 and z.state == Zombie.State.CHASE, "point blank (2 m) even crouched at night: noticed at once")
	# ---- a close gunshot
	place_player(30.0); reset_z()
	await frames(2)
	w.noise_bus.emit_noise(w.player.global_position, 150.0, w.player)
	await frames(2)
	check(z.awareness >= 0.95 and z.state == Zombie.State.CHASE, "a gunshot 30 m off: it knows where you are")
	# ---- a hit
	place_player(30.0); reset_z()
	z.hit(5.0, w.player.global_position)
	check(z.awareness >= 0.95 and z.state == Zombie.State.CHASE, "a hit: fully aware")
	# ---- behind a wall: a closed cabin between
	var cb: Cabin = w.cabins[1]
	if cb.door_open: cb.toggle_door()
	for o in cb.openings: if o.has_method("close"): o.close()
	w.player.place(cb.global_position.x, cb.global_position.z)
	await frames(2)
	zp = cb.to_global(Vector3(0, 0, -Cabin.HZ - 6.0)); zp.y = w._ground_y(zp.x, zp.z)
	w.clock.hour = 12.0
	w.stealth_vis_override = 1.0
	crouch(false)
	reset_z()
	await hold(2.0)
	var blocked: bool = not cb.sight_line_open(zp + Vector3(0, 1.5, 0), w.player.position)
	check(not blocked or z.awareness == 0.0, "behind a wall: nothing (%.2f, wall blocks=%s)" % [z.awareness, str(blocked)])
	# ---- HUD eye
	zp = lk.global_position + od * 45.0; zp.y = w._ground_y(zp.x, zp.z)
	place_player(15.0); reset_z()
	w.stealth_vis_override = 0.35
	await hold(2.6)
	await frames(8)
	check(w.hud.aware >= Zombie.SUSPICIOUS and not w.hud.aware_chase, "the HUD eye shows it (%.2f)" % w.hud.aware)
	Settings.stealth_eye = false
	await create_timer(0.3).timeout
	check(w.hud.aware == 0.0, "and the option hides it")
	Settings.stealth_eye = true
	print("STEALTH_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
