extends SceneTree
## Plan A6 food web 3: a wolf defends its kill (growl 30 m, bluff-charge 15 m, attack if you stay), a flare drives it
## off and it abandons the kill, two wolves take turns at a kill, the carcass shows what is left, ravens tug-of-war.
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

var kp: Vector3
var side: Vector3

func fresh_kill(idx: int) -> Deer:
	var d: Deer = w._add_deer(kp, idx)
	d.set_process(false)
	d.hp = 0.0
	d._die()
	d.set_meta("scent_age_s", 900.0)
	d.set_meta("scavenged", 0.0)
	return d

func wolf_at(p: Vector3, idx: int, kill: Node3D) -> Wolf:
	var q := p; q.y = w._ground_y(q.x, q.z)
	var wf: Wolf = w._add_wolf(q, idx, false)
	wf._carcass = kill
	wf._feed_t = 0.0
	wf._set_state(Wolf.State.INVESTIGATE)
	return wf

## Mean green of the body's tinted materials (1 = untouched, falls as it reddens / darkens).
func _tint(n: Node) -> float:
	var s := 0.0; var c := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("stage_own"):
			var col: Color = (mi.get_meta("stage_own") as StandardMaterial3D).albedo_color
			var b: Color = mi.get_meta("stage_base")
			s += col.g / maxf(b.g, 0.001); c += 1
	return s / maxf(1.0, float(c))


func place_player(d: float) -> void:
	var p := kp + side * d
	w.player.place(p.x, p.z)

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261025)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.ambient_life != null: break
	w.out_path = ""; w.player.god = true; w.clock.hour = 12.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	if w.world_events != null: w.world_events.enabled = false
	w.ambient_life.voices_enabled = false
	for x in w.deer.duplicate(): w.deer.erase(x); x.queue_free()
	for x in w.wolves.duplicate(): w.wolves.erase(x); x.queue_free()
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	side = Vector3(-od.z, 0, od.x)
	kp = lk.global_position + od * 60.0; kp.y = w._ground_y(kp.x, kp.z)
	await frames(3)
	# ---- a wolf at its kill: growls at 25 m, holds its ground
	var deer := fresh_kill(901)
	place_player(25.0)
	var wf := wolf_at(kp + side * -1.2, 902, deer)
	await secs(4.0)
	check(wf.growls >= 1 and wf.defending and wf.state == Wolf.State.INVESTIGATE, "a wolf over its kill growls at 25 m and stands its ground (%d growls)" % wf.growls)
	check(wf.global_position.distance_to(kp) < 4.0 and wf.bluffs == 0, "it doesn't come for you yet")
	# ---- 12 m: a bluff charge, then back over the kill
	place_player(12.0)
	var closest := 99.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		closest = minf(closest, wf.global_position.distance_to(w.player.global_position))
	check(wf.bluffs >= 1 and closest < 9.0 and closest > 1.6, "at 12 m it bluff-charges (to %.1f m) without biting" % closest)
	check(wf.bites == 0, "no bite in a bluff")
	await secs(2.5)
	check(wf.global_position.distance_to(kp) < 4.5 and wf.state == Wolf.State.INVESTIGATE, "then goes back over the kill (%.1f m from it)" % wf.global_position.distance_to(kp))
	# ---- stay close: it attacks
	await secs(4.5)
	check(wf.state == Wolf.State.ALERT or wf.state == Wolf.State.CHASE, "stay close after the bluff and it attacks")
	w.wolves.erase(wf); wf.queue_free()
	# ---- a flare drives it off the kill; the meat is yours
	var deer2 := fresh_kill(903)
	place_player(14.0)
	var wf2 := wolf_at(kp + side * -1.2, 904, deer2)
	await secs(1.0)
	var fl := Flare.new(); w.add_child(fl); fl.global_position = w.player.global_position + side * -6.0
	await secs(1.0)
	check(wf2.abandons >= 1 and wf2.state == Wolf.State.RETREAT and wf2._carcass == null, "a flare: the wolf flees and abandons the kill")
	check(wf2._smell_carcass() != deer2 and Carcass.has_meat(deer2), "it won't come back to it for a while; the meat is still there to take")
	fl.queue_free()
	w.wolves.erase(wf2); wf2.queue_free()
	await frames(3)
	# ---- the pack takes turns
	var deer3 := fresh_kill(905)
	place_player(60.0)
	var a := wolf_at(kp + side * -1.0, 906, deer3)
	var b := wolf_at(kp + side * 7.0, 907, deer3)
	var feeders := []
	var circled := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 26000:
		await process_frame
		var fid := int(deer3.get_meta("feeder", 0))
		if fid != 0 and (feeders.is_empty() or feeders[-1] != fid): feeders.append(fid)
		if a.circling or b.circling: circled = true
		if feeders.size() >= 2: break
	check(circled, "one feeds, the other circles and waits")
	check(feeders.size() >= 2 and feeders[0] != feeders[1], "they swap after a portion (%d feeders in turn)" % feeders.size())
	w.wolves.erase(a); a.queue_free(); w.wolves.erase(b); b.queue_free()
	# ---- carcass stages
	var d4 := fresh_kill(908)
	await frames(3)
	var ov: StandardMaterial3D = d4.get_meta("stage_mat") if d4.has_meta("stage_mat") else null
	var ring: Decal = d4.get_node_or_null("StageRing")
	var tint0 := _tint(d4)
	check(ov != null and ring != null and tint0 > 0.9, "a fresh kill: clean, a small blood ring (body %.2f)" % tint0)
	var rs0 := ring.size.x if ring != null else 0.0
	d4.set_meta("scavenged", 3.0)
	await frames(3)
	var tint1 := _tint(d4)
	check(tint1 < tint0 - 0.2 and ring.size.x > rs0 * 1.3, "half eaten: darker and bloodier (body %.2f -> %.2f, ring %.1f -> %.1f m)" % [tint0, tint1, rs0, ring.size.x])
	var done: Dictionary = d4.get_meta("done", {}); done["meat"] = true; d4.set_meta("done", done)
	await frames(3)
	check(d4.get_node_or_null("StageRibs") != null and d4.has_meta("stripped"), "stripped: flattened, the rib cage shows")
	done["hide"] = true; d4.set_meta("done", done)
	await frames(3)
	var body_hidden := true
	for ch in d4.get_children():
		if ch is Node3D and not (ch is Decal) and ch.name != "StageRibs" and ch.name != "StageRing" and (ch as Node3D).visible and ch.find_children("*", "MeshInstance3D", true, false).size() > 0: body_hidden = false
	check(body_hidden, "skinned too: only the bones are left")
	# ---- raven tug-of-war (visual): two birds face off, pull in turn, the winner springs up with the scrap
	var al: AmbientLife = w.ambient_life
	var c := kp + Vector3(0, 0, 0)
	var mk := func(p: Vector3) -> Dictionary:
		return {"pos": p, "land": p, "yaw": 0.0, "hop_t": 3.0, "flick": 0.0, "amp": 0.0, "fold": 1.0, "peck": 0.0, "legs": 1.0, "pitch": 0.0, "phase": 0.3, "hop_ph": 0.0}
	var fk := {"center": c, "birds": [mk.call(c + Vector3(1, 0, 0)), mk.call(c + Vector3(-1, 0, 0))], "ts": 0.0}
	al.tug(fk)
	var b0: Dictionary = fk.birds[0]; var b1: Dictionary = fk.birds[1]
	var face: float = (b0.tug_dir as Vector3).dot(b1.tug_dir)
	var maxsep := 0.0; var minsep := 9.0; var max_up := 0.0
	var alt := 0
	for i in 400:
		fk.ts = float(fk.ts) + 0.016
		var t0b: bool = al._tug_step(fk, b0, 0.016)
		var t1b: bool = al._tug_step(fk, b1, 0.016)
		if float(b0.get("tug_t", 0.0)) > 0.0:
			var sep: float = (b0.pos - b1.pos).length()
			maxsep = maxf(maxsep, sep); minsep = minf(minsep, sep)
			if (float(b0.amp) > 0.6) != (float(b1.amp) > 0.6): alt += 1
		for bb in [b0, b1]: max_up = maxf(max_up, float(bb.pos.y) - float(bb.land.y))
	check(face < -0.99 and minsep < 0.7, "two ravens face each other over the meat")
	check(alt > 20 and maxsep - minsep > 0.05, "they pull back in turn, wings half spread")
	check(max_up > 1.6, "the winner springs up with the scrap (%.1f m)" % max_up)
	print("FOOD_WEB3_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
