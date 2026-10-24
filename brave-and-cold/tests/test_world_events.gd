extends SceneTree
## Plan A4 pass 1: deterministic schedule, ransack only unobserved and never a claimed cabin, distant shots / flare /
## wolf kill with their sites and lures, save/load, store lights (grid, outage, aurora electrics + lure).
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

func plan(seed_v: int, days: int) -> Array:
	var we := WorldEvents.new(); we.world = w; we.seed_base = seed_v
	for d in range(1, days + 1): we.roll_day(d)
	var out: Array = []
	for e in we.events: out.append([e.day, snappedf(e.at_h, 0.01), e.kind])
	for p in we.pending: out.append([p.day, p.i])
	we.free()
	return out

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261024)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null: break
	w.out_path = ""; w.player.god = true
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	if w.ambient_life != null: w.ambient_life.voices_enabled = false
	var we: WorldEvents = w.world_events
	check(we != null, "the world has WorldEvents")
	# ---- schedule
	var a := plan(77, 9); var b := plan(77, 9); var c := plan(78, 9)
	check(a == b and a != c, "the plan is deterministic from the seed (%d entries) and differs for another seed" % a.size())
	var ok_sched := true
	var per_day := {}
	var we2 := WorldEvents.new(); we2.world = w; we2.seed_base = 77
	for d in range(1, 10): we2.roll_day(d)
	for e in we2.events:
		if int(e.day) < WorldEvents.FIRST_DAY: ok_sched = false
		per_day[e.day] = per_day.get(e.day, []) + [float(e.at_h)]
	for d in per_day:
		var hs: Array = per_day[d]
		if hs.size() > 3: ok_sched = false
		for i in hs.size():
			for j in range(i + 1, hs.size()):
				if absf(hs[i] - hs[j]) < WorldEvents.SPACING_H: ok_sched = false
	for p in we2.pending:
		if int(p.day) < WorldEvents.RANSACK_FROM or int(p.i) == 0: ok_sched = false
	check(ok_sched and we2.pending.size() >= 6, "no events before D3, at most 3 a day 2 h apart, ransacks from D4 and never the start cabin (%d targets)" % we2.pending.size())
	we2.free()
	# ---- ransack: claimed cabins are spared, observed ones wait, unobserved ones get done
	we.enabled = false   # drive it by hand
	check(w.cabins.size() >= 3, "hamlet has cabins (%d)" % w.cabins.size())
	var ti := 1
	for i in range(1, w.cabins.size()):
		if not we.claimed(i): ti = i; break
	var cb: Cabin = w.cabins[ti]
	# claim another cabin by spending 10 game minutes in it
	var ci := ti + 1 if ti + 1 < w.cabins.size() else ti - 1
	var cc: Cabin = w.cabins[ci]
	w.player.place(cc.global_position.x, cc.global_position.z)
	await frames(2)
	for k in 30: we._claims(25.0, 0.016)
	check(we.claimed(ci), "10 game minutes inside makes a cabin claimed")
	w.clock.day = 5; w.clock.hour = 12.0
	we.rolled_day = 5
	we.pending = [{"i": ci, "day": 5, "at_h": 9.0}, {"i": ti, "day": 5, "at_h": 9.0}]
	# stand 60 m from the target: observed, nothing happens
	var away: Vector3 = (cb.global_position - w.fire_lookout.global_position); away.y = 0; away = away.normalized()
	var near: Vector3 = cb.global_position + away * 60.0
	w.player.place(near.x, near.z)
	await frames(2)
	we.enabled = true
	await frames(3)
	check(not we.ransacked.has(ci), "a claimed cabin is never ransacked (target dropped)")
	check(not we.ransacked.has(ti) and not cb.crate_looted, "with the player 60 m away nothing happens")
	# go 420 m away, facing away
	var far: Vector3 = cb.global_position + away * 420.0
	w.player.place(far.x, far.z)
	w.player.yaw = atan2(-away.x, -away.z)
	await frames(4)
	check(we.ransacked.has(ti), "unobserved and far: the cabin is ransacked")
	var furn_hit := cb.broken.size() + cb.toppled.size()
	check(cb.crate_looted and not cb.fire.is_lit() and cb.wood_pile <= 2 and furn_hit >= 1, "crate emptied, stove dead, woodpile raided, %d furniture broken/toppled" % furn_hit)
	check(cb.door_open or cb.door_broken, "door forced or left open")
	var dp: Vector3 = cb.door_world_pos()
	var boots: int = w.animal_tracks.log.query(dp.x, dp.z, 8.0, [TrackLog.K.BOOT]).size()
	check(boots >= 6, "boot prints lead to and from the door (%d)" % boots)
	we.enabled = false
	w.player.place(cb.global_position.x, cb.global_position.z)
	await frames(2)
	we._claims(1.0, 0.016)
	var said := false
	for m in w.hud._msgs: if String(m.text).find("Someone has been through here") >= 0: said = true
	check(said, "walking in: 'Someone has been through here.'")
	# cabin save carries the ransack
	var sv: Dictionary = w._save_data()
	var cs: Dictionary = sv.cabins[ti]
	check(bool(cs.looted) and (cs.toppled.size() + cs.broken.size()) == furn_hit and bool(cs.dbroken) == cb.door_broken, "the cabin save keeps looted / toppled / broken door")
	# ---- distant shots
	w.player.place(far.x, far.z)
	await frames(2)
	var noises: Array = []
	w.noise_bus.noise.connect(func(p: Vector3, r: float, s: Object) -> void: if s == we: noises.append([p, r]))
	var hd = null
	if w.pop != null and w.pop.hordes.size() > 0: hd = w.pop.hordes[0]
	var sites0 := get_nodes_in_group("event_sites").size()
	we.enabled = true
	we.fire_event("shots", true)
	var site_n: Node3D = null
	for n in get_nodes_in_group("event_sites"): if n.get_meta("kind") == "camp": site_n = n
	check(site_n != null and get_nodes_in_group("event_sites").size() == sites0 + 1, "a survivor's camp appears at the shot site")
	var sp: Vector3 = site_n.global_position if site_n != null else Vector3.ZERO
	var sd: float = sp.distance_to(w.player.global_position)
	check(sd >= 480.0 and sd <= 1520.0, "500-1500 m from the player (%.0f m)" % sd)
	if hd != null:
		hd.center = Vector2(sp.x + 200.0, sp.z); hd.state = 0; hd.target = hd.center
	check(we._shots.size() >= 3 and we._shots.size() <= 8, "3-8 shots queued (%d)" % we._shots.size())
	await secs(30.0)
	var heard := 0
	for h in w.ambient_life.heard: if String(h.name).begins_with("shot_far"): heard += 1
	check(heard >= 2, "shots heard from the site's true direction (%d so far)" % heard)
	check(noises.size() >= 1 and (noises[0][0] as Vector3).distance_to(sp) < 1.0 and float(noises[0][1]) >= 150.0, "the shots are a 150 m noise lure at the site")
	if hd != null:
		check(int(hd.state) == 1 and hd.target.distance_to(Vector2(sp.x, sp.z)) < 2.0, "a horde 200 m off turns toward the shooting")
	check(int(site_n.get_meta("casings")) >= 3, "brass casings at the site (%d)" % int(site_n.get_meta("casings")))
	var ammo := false
	for pk in get_nodes_in_group("pickups"):
		if pk.id == "ammo" and pk.global_position.distance_to(sp) < 4.0: ammo = true
	check(ammo, "a few rounds left by the fire")
	check(w.animal_tracks.log.query(sp.x, sp.z, 4.0, [TrackLog.K.BOOT]).size() >= 10, "boot prints mill round the fire pit")
	# ---- flare
	we.fire_event("flare", true)
	check(we.flares_active() == 1, "a flare goes up")
	await secs(3.5)
	var f: Dictionary = we._flares[0] if we._flares.size() > 0 else {}
	var fh: float = (f.node as Node3D).global_position.y - (f.site as Vector3).y if not f.is_empty() else 0.0
	check(fh > 60.0 and (f.light as OmniLight3D).light_energy > 2.0, "it climbs (%.0f m) and burns red" % fh)
	# ---- wolves take a deer
	var c0 := get_nodes_in_group("carcasses").size()
	we.fire_event("wolfkill", true)
	await frames(3)
	var ks: Vector3 = Vector3(float(we.sites[-1].x), 0, float(we.sites[-1].z))
	var kill_ok := false
	for cn in get_nodes_in_group("carcasses"):
		if Vector2(cn.global_position.x - ks.x, cn.global_position.z - ks.z).length() < 3.0: kill_ok = true
	check(kill_ok and get_nodes_in_group("carcasses").size() == c0 + 1, "wolves leave a deer carcass at the kill site")
	check(w.animal_tracks.log.query(ks.x, ks.z, 5.0, [TrackLog.K.WOLF]).size() >= 15, "wolf prints round it")
	# ---- save / load
	var d: Dictionary = we.to_dict()
	var we3 := WorldEvents.new(); w.add_child(we3); we3.setup(w, we.seed_base)
	var before := get_nodes_in_group("event_sites").size()
	we3.from_dict(JSON.parse_string(JSON.stringify(d)))
	await frames(2)
	check(we3.ransacked.has(ti) and we3.claimed(ci) and we3.rolled_day == we.rolled_day, "save/load keeps ransacked cabins, claims and the rolled day")
	check(get_nodes_in_group("event_sites").size() == we3.sites.size() and we3.sites.size() == before, "site props are rebuilt on load (%d)" % we3.sites.size())
	we3.queue_free()
	# ---- store lights
	var sl: StoreLights = null
	for st in w.stores:
		for ch in st.get_children(): if ch is StoreLights: sl = ch
	check(sl != null, "the store has fluorescents")
	if sl != null:
		w.clock.hour = 12.0
		sl.force_grid = true; sl.force_aurora = 0.0
		await secs(0.6)
		check(sl.mode == "on" and sl.level > 0.9, "grid alive at noon: lit (%.2f)" % sl.level)
		w.clock.hour = 23.0
		await frames(3)
		check(sl.level < 0.01, "closed at night: dark")
		w.clock.hour = 12.0
		await secs(0.6)
		sl.force_grid = false
		await frames(2)
		check(sl.mode == "dying", "the grid dies: buzz-and-pop, stutter")
		await secs(1.2)
		check(sl.mode == "off" and sl.level == 0.0, "then dark")
		sl.force_aurora = 0.3
		await secs(1.0)
		check(sl.mode == "off", "a weak aurora does nothing")
		sl.force_aurora = 0.95
		var lit_max := 0.0
		var l0 := sl.lure_count
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 6000:
			await process_frame
			lit_max = maxf(lit_max, sl.level)
		check(sl.mode == "aurora" and lit_max > 0.3, "strong aurora, grid down: the dead tubes flicker (peak %.2f)" % lit_max)
		check(sl.lure_count > l0, "and the flicker is a light lure (%d)" % (sl.lure_count - l0))
	# ---- E2: the cabin fire
	var fd: Dictionary = we.fire
	check(int(fd.day) >= 4 and int(fd.day) <= 6 and float(fd.at_h) >= 21.0, "one fire planned for D4-D6 at night (D%d %.1fh)" % [int(fd.day), float(fd.at_h)])
	if int(fd.i) >= 0:   # the store-light section above ran D5 at 23:00: it may already have started; start over
		var old: Cabin = w.cabins[int(fd.i)]
		if old.on_fire != null: old.on_fire.queue_free(); old.on_fire = null
		fd.i = -1; fd.start_s = -1.0
	# pick: never claimed, never within 300 m
	var pp0: Vector3 = w.player.global_position
	w.clock.day = int(fd.day); w.clock.hour = float(fd.at_h) + 0.1
	var cl := ci
	we.claims[cl] = w.clock.total_game_s
	we.enabled = true
	await frames(3)
	var fi := int(we.fire.i)
	check(fi >= 1 and fi != cl and not we.claimed(fi), "the fire takes an unclaimed cabin (%d)" % fi)
	var fcb: Cabin = w.cabins[fi] if fi >= 1 else null
	if fcb != null:
		check(fcb.global_position.distance_to(w.player.global_position) >= 300.0, "300 m or more from the player (%.0f m)" % fcb.global_position.distance_to(w.player.global_position))
		var cf: CabinFire = fcb.on_fire
		check(cf != null and cf.stage == "ignition", "it starts with ignition")
		we.enabled = false
		var t0: float = cf.start_s
		cf.start_s = w.clock.total_game_s - CabinFire.IGNITE_S - 60.0
		await frames(3)
		check(cf.stage == "blaze" and not cf.collapsed and not fcb.burned, "then the blaze, roof still on")
		# lures: at night a light lure every 8 s -> a horde 300 m off turns toward it
		var lights: Array = []
		w.noise_bus.light.connect(func(p: Vector3, r: float, s: Object) -> void: if s == cf: lights.append(r))
		var hd2 = w.pop.hordes[0] if w.pop != null and w.pop.hordes.size() > 0 else null
		if hd2 != null:
			hd2.center = Vector2(fcb.global_position.x + 300.0, fcb.global_position.z); hd2.state = 0; hd2.target = hd2.center
		cf._lure_t = 0.0
		await frames(3)
		check(lights.size() >= 1 and lights[0] >= 100.0, "the blaze is a light lure at night (%s)" % str(lights))
		if hd2 != null:
			check(int(hd2.state) == 1 and hd2.target.distance_to(Vector2(fcb.global_position.x, fcb.global_position.z)) < 2.0, "a horde 300 m off heads for the fire")
		cf.start_s = w.clock.total_game_s - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.5
		await frames(3)
		check(cf.collapsed and fcb.burned and fcb.crate_looted and fcb.door_broken, "the roof falls in: a burned shell")
		check(is_inf(fcb.ceiling_at_world(fcb.global_position + Vector3(0, 1.6, 0))) and is_equal_approx(RoomClimate.leak_of(fcb), 1.0), "no roof, holds no heat")
		# save mid-blaze, reload into a fresh WorldEvents: the fire resumes from its time
		var dd: Dictionary = we.to_dict()
		check(int(dd.fire.i) == fi and is_equal_approx(float(dd.fire.start_s), cf.start_s), "the fire is saved with its start time")
		cf.start_s = w.clock.total_game_s - CabinFire.IGNITE_S - CabinFire.BLAZE_S - CabinFire.SMOULDER_S * 0.5
		await frames(3)
		check(cf.stage == "smoulder", "then it smoulders")
		cf.start_s = w.clock.total_game_s - CabinFire.IGNITE_S - CabinFire.BLAZE_S - CabinFire.SMOULDER_S - 10.0
		await frames(3)
		check(cf.stage == "shell" and not cf._light.visible, "and goes cold")
		# walking into a blaze burns
		cf.start_s = w.clock.total_game_s - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.6
		await frames(2)
		w.player.god = false
		var hp0: float = w.player.health
		w.player.place(fcb.global_position.x, fcb.global_position.z)
		await secs(0.6)
		check(w.player.health < hp0, "standing in the blaze burns (%.1f -> %.1f)" % [hp0, w.player.health])
		w.player.health = hp0; w.player.god = true
		w.player.place(pp0.x, pp0.z)
	print("WORLD_EVENTS_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
