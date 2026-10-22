extends SceneTree
## Alive L1: ravens over kills (circle, land when quiet, scatter on approach / shot, roost at night), aurora
## schedule + sky/light hookup, distant howls sourced from real wolves, owls, the bird mesh.
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

const PERCH_Y_T := 0.16
func flock_for(n: Node) -> Dictionary:
	for f in w.ambient_life.flocks:
		if f.kind == "kill" and f.target == n: return f
	return {}

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261022)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.clock.hour = 12.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	var al: AmbientLife = w.ambient_life
	check(al != null, "the world has an AmbientLife node")
	al.voices_enabled = false
	for f in al.flocks.duplicate(): al._free_flock(f)
	var pp: Vector3 = w.player.global_position
	# ---- a fresh kill 80 m off: ravens find it once it is a few minutes old
	var cp := pp + Vector3(80, 0, 10); cp.y = w._ground_y(cp.x, cp.z)
	var young := Node3D.new(); w.add_child(young); young.global_position = cp + Vector3(6, 0, 0); young.add_to_group("carcasses")
	young.set_meta("scent_age_s", 10.0)
	var kill := Node3D.new(); w.add_child(kill); kill.global_position = cp; kill.add_to_group("carcasses")
	kill.set_meta("scent_age_s", 900.0)
	al._scan()
	var f := flock_for(kill)
	check(not f.is_empty(), "ravens find a kill 80 m away")
	check(flock_for(young).is_empty(), "a kill only seconds old has no birds yet")
	if f.is_empty():
		print("AMBIENT_LIFE_TEST checks=", checks, " failures=", failures); quit(1); return
	var n: int = f.birds.size()
	check(n >= 3 and n <= 7 and (f.mi as MultiMeshInstance3D).multimesh.instance_count == n, "a flock of %d in one MultiMesh (one draw call)" % n)
	await frames(90)
	var hmin := 1e9; var rmax := 0.0
	for b in f.birds:
		hmin = minf(hmin, b.pos.y - cp.y); rmax = maxf(rmax, Vector2(b.pos.x - cp.x, b.pos.z - cp.z).length())
	check(f.state == "circle" and hmin > 12.0 and rmax < 30.0, "they wheel over it (lowest %.0f m up, widest %.0f m out)" % [hmin, rmax])
	check(float(f.birds[0].amp) >= 0.1, "wings flap / glide (flap %.2f)" % float(f.birds[0].amp))
	# ---- quiet for a while -> they come down and peck
	f.ts = 30.0; f.quiet = 60.0
	var t0 := Time.get_ticks_msec()
	while f.state != "ground" and Time.get_ticks_msec() - t0 < 15000: await process_frame
	var gmax := 0.0
	for b in f.birds: gmax = maxf(gmax, b.pos.y - w._ground_y(b.pos.x, b.pos.z))
	check(f.state == "ground" and gmax < 0.5, "with nobody near they land at the kill (highest %.2f m off the snow)" % gmax)
	await secs(0.5)
	check(float(f.birds[0].fold) > 0.9, "wings folded on the ground")
	# ---- walk up -> they scatter with calls and wingbeats
	al.heard.clear()
	w.player.place(cp.x - 15.0, cp.z)
	await frames(6)
	var kinds := {}
	for h in al.heard: kinds[h.kind] = true
	check(f.state == "scatter", "walking up to the kill scatters them")
	check(kinds.has("wings") and kinds.has("raven"), "take-off wingbeats and raven calls")
	await secs(1.5)
	var hy := 1e9
	for b in f.birds: hy = minf(hy, b.pos.y - cp.y)
	check(hy > 1.5, "they climb away (lowest now %.1f m up)" % hy)
	# ---- back down, then a distant shot scatters them too
	w.player.place(pp.x, pp.z); await frames(4)
	f.state = "ground"; f.ts = 0.0
	for b in f.birds: b.pos = cp + Vector3(1, 0.1, 0); b.land = b.pos; b.fold = 1.0
	w.noise_bus.emit_noise(pp, NoiseBus.RADIUS_GUNSHOT, w.player)
	check(f.state == "scatter", "a gunshot 80 m away scatters a landed flock")
	# ---- roost at night: hidden, and no new flocks
	w.clock.hour = 1.0; await secs(0.3)
	check(not (f.mi as MultiMeshInstance3D).visible, "at night they roost (flock hidden)")
	var k2 := Node3D.new(); w.add_child(k2); k2.global_position = cp + Vector3(-20, 0, 30); k2.add_to_group("carcasses"); k2.set_meta("scent_age_s", 900.0)
	al._scan()
	check(flock_for(k2).is_empty(), "no new flocks after dark")
	w.clock.hour = 12.0; await frames(4)
	# ---- the kill is butchered away -> they leave
	kill.remove_from_group("carcasses"); kill.queue_free()
	await frames(4)
	check(f.state == "leave", "carcass gone: the flock leaves")
	k2.queue_free(); young.queue_free()
	# ---- flyover
	al._new_flyover()
	var fly: Dictionary = al.flocks[al.flocks.size() - 1]
	var p0: Vector3 = fly.birds[0].pos
	await secs(0.6)
	print("  flyover start y above player %.1f moved %.1f" % [p0.y - pp.y, fly.birds[0].pos.distance_to(p0)])
	check(fly.kind == "fly" and fly.birds[0].pos.distance_to(p0) > 2.0 and p0.y - w._ground_y(pp.x, pp.z) > 31.0, "daytime flyover crosses high overhead")
	# ---- aurora schedule
	var nights := 0
	var first := -1
	for d in range(1, 401):
		if AmbientLife.aurora_night(d):
			nights += 1
			if first < 0: first = d
	check(nights > 70 and nights < 130, "about one night in four has an aurora (%d / 400)" % nights)
	var other := first + 1
	while AmbientLife.aurora_night(other): other += 1
	w.clock.day = first; w.clock.hour = 23.0; w.weather.overcast = 0.0; w.weather.precip = 0.0
	check(al.aurora_target() > 0.9, "aurora night %d, clear, 23:00 -> full aurora" % first)
	w.weather.overcast = 0.8
	check(al.aurora_target() < 0.01, "overcast hides it")
	w.weather.overcast = 0.0; w.clock.hour = 14.0
	check(al.aurora_target() < 0.01, "never by day")
	w.clock.day = other; w.clock.hour = 23.0
	check(al.aurora_target() < 0.01, "an ordinary night has none")
	al.force_aurora = 1.0
	await secs(0.8)
	var rig = w.sky_rig
	if rig is AtmosphereRig:
		check((rig as AtmosphereRig).aurora > 0.9, "the sky rig gets it (shader param set in apply_hour)")
		var mc: Color = (rig as AtmosphereRig).moon.light_color
		check(mc.g > AtmosphereRig.MOON_COLOR.g + 0.03, "and the moonlight goes a little green (g %.2f)" % mc.g)
	al.force_aurora = -1.0
	# ---- distant howls come from where the real wolves are
	for wf in w.wolves.duplicate(): w.wolves.erase(wf); wf.queue_free()
	await frames(2)
	pp = w.player.global_position
	var wp := pp + Vector3(-420, 0, 260); wp.y = w._ground_y(wp.x, wp.z)
	var wolf: Wolf = w._add_wolf(wp, 5)
	await frames(2)
	al.heard.clear()
	al.howl_chorus()
	var lead: Dictionary = al.heard[0] if al.heard.size() > 0 else {}
	var dir_ok := false
	if not lead.is_empty():
		var a := Vector2(lead.pos.x - pp.x, lead.pos.z - pp.z).normalized()
		var b := Vector2(wp.x - pp.x, wp.z - pp.z).normalized()
		dir_ok = a.dot(b) > 0.99
	check(not lead.is_empty() and lead.kind == "howl" and lead.real and dir_ok, "the lead howl comes from the real pack's direction")
	check(al._pending.size() >= 1, "and is answered (%d answers queued)" % al._pending.size())
	wolf.global_position = pp + Vector3(30, 0, 0)
	wolf._set_state(Wolf.State.CHASE)
	check(al._hunted(), "no chorus while a wolf is running you down")
	al.heard.clear(); al.owl_call()
	check(al.heard.size() == 1 and al.heard[0].kind == "owl", "owl call")
	# ---- food web: ravens strip a real kill, wolves far beyond scent range follow the ravens, wolves displace them
	w.clock.hour = 12.0; w.wolves.erase(wolf); wolf.queue_free(); await frames(2)
	for f0 in al.flocks.duplicate(): al._free_flock(f0)
	pp = w.player.global_position
	var kp := pp + Vector3(90, 0, -60); kp.y = w._ground_y(kp.x, kp.z)
	var dw: Wolf = w._add_wolf(kp, 11)
	await frames(2)
	dw.hit(999.0, kp); dw.set_meta("scent_age_s", 900.0)
	await frames(2)
	check(dw.is_in_group("carcasses") and Carcass.species_of(dw) == "wolf", "a shot wolf is a carcass")
	al._scan()
	var kf := flock_for(dw)
	check(not kf.is_empty(), "ravens come to the wolf kill")
	var zb := Node3D.new(); w.add_child(zb); zb.global_position = kp + Vector3(30, 0, 0); zb.add_to_group("bodies")
	al._scan()
	var bf := flock_for(zb)
	check(not bf.is_empty() and bf.birds.size() <= 4, "a zombie body draws a smaller flock (%d)" % (bf.birds.size() if not bf.is_empty() else 0))
	zb.remove_from_group("bodies"); zb.queue_free()
	if not kf.is_empty():
		var hunter_p := kp + Vector3(-330, 0, 40); hunter_p.y = w._ground_y(hunter_p.x, hunter_p.z)
		var hunter: Wolf = w._add_wolf(hunter_p, 12)
		await frames(2)
		hunter.state = Wolf.State.WANDER
		Wolf.raven_kills = []
		check(not Carcass.smelled_by(dw, hunter.global_position) and hunter._smell_carcass() == null, "330 m off a wolf cannot smell the kill")
		kf.age = 70.0; await frames(2)
		check(Wolf.raven_kills.has(dw) and hunter._smell_carcass() == dw, "but it sees the ravens over it and goes there")
		hunter.global_position = kp + Vector3(40, 0, 0)   # out of the way for the pecking part
		kf.state = "ground"; kf.ts = 0.0
		for b in kf.birds: b.pos = kp + Vector3(1.5, PERCH_Y_T, 0); b.land = b.pos; b.fold = 1.0
		w.clock.time_scale = 48.0
		al._peck(kf, 300.0)   # 300 s real at 48x = 4 game hours
		w.clock.time_scale = 0.0
		var sv := Carcass.scavenged(dw)
		check(sv > 0.5 and Carcass.meat_left(dw, 3) < 3 and Carcass.meat_left(dw, 3) >= 1, "landed ravens strip meat (%.2f portions gone, %d of 3 left)" % [sv, Carcass.meat_left(dw, 3)])
		dw.set_meta("scavenged", 99.0); al._peck(kf, 1.0)
		check(Carcass.meat_left(dw, 3) == 1, "they never take the last portion")
		var acts: Array = w._carcass_actions(dw)
		var txt := ""
		for a in acts: txt += String(a.get("text", "")) + " | "
		check(txt.contains("ravens have been at it") and txt.contains("+1"), "butcher prompt shows the loss: " + txt.left(80))
		hunter.global_position = kp + Vector3(5, 0, 0)
		await frames(3)
		check(kf.state == "scatter", "a wolf arriving at the kill scatters the ravens")
		w.wolves.erase(hunter); hunter.queue_free()
	w.wolves.erase(dw); dw.queue_free()
	# ---- the bird mesh
	var bm := AmbientLife.bird_mesh()
	var ab := bm.get_aabb()
	check(ab.size.x > 1.2 and ab.size.x < 1.6 and ab.size.z > 0.6 and ab.size.z < 0.9, "raven mesh ~1.4 m span, ~0.8 m long (%.2f x %.2f)" % [ab.size.x, ab.size.z])
	for nm in ["howl_far_0", "owl_0", "raven_0", "wings_0"]:
		check(load(AmbientLife.AMB + nm + ".wav") is AudioStream, "clip " + nm)
	w.queue_free(); await process_frame; await process_frame
	print("AMBIENT_LIFE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
