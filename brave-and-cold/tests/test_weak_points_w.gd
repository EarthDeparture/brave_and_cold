extends SceneTree
## W pass (still-weak fixes after A7): building wood shader on cabins + huts, cellar first-find line / hatch
## sounds / save, track hint blocked by walls and fading, the fire's melt ring filling back in with snow.
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

func _wood_on(n: Node) -> bool:
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var sm := m.material_override as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path.ends_with("building_wood.gdshader"): return true
	return false

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261027)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null: break
	w.out_path = ""; w.player.god = true
	w.weather.set_state(0, true); w.weather.locked = true; w.weather.precip = 0.0
	if w.ambient_life != null: w.ambient_life.voices_enabled = false
	# ---- W1 wood
	var all_cab := true
	for cb: Cabin in w.cabins: all_cab = all_cab and _wood_on(cb)
	check(all_cab, "every cabin wears the procedural building wood (%d cabins)" % w.cabins.size())
	var all_hut: bool = not w.huts.is_empty()
	for hu: Node in w.huts: all_hut = all_hut and _wood_on(hu)
	check(all_hut, "and every hut (%d), with its own boards" % w.huts.size())
	if not w.huts.is_empty():
		var hm: ShaderMaterial = null
		for m: MeshInstance3D in w.huts[0].find_children("*", "MeshInstance3D", true, false):
			var sm := m.material_override as ShaderMaterial
			if sm != null and sm.shader != null and sm.shader.resource_path.ends_with("building_wood.gdshader"): hm = sm
		check(hm != null and hm.get_shader_parameter("wall_vertical") == true and hm.get_shader_parameter("floor_along_x") == false, "hut: vertical siding grain, boards across the short span")

	# ---- W3 cellar: first-find line, hatch sounds, save
	var rc: RootCellar = w.root_cellar
	check(rc != null and rc.audio != null, "the cellar has the world's audio")
	var cb2: Cabin = rc.cabin
	var eye := cb2.to_global(Vector3(0.7, Cabin.FLOOR_LOCAL_Y + w.player.eye_h, 0.75))
	var d: Vector3 = rc.hatch_world_pos() - eye
	for i in 2:
		w.player.position = eye; w.player.yaw = atan2(-d.x, -d.z); w.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await frames(2)
	w._update_prompt()
	var n_msg: int = w.hud._msgs.size() if w.hud.get("_msgs") != null else -1
	if w._cur.has("act"): (w._cur["act"] as Callable).call()
	await frames(3)
	check(rc.found, "opening it the first time marks it found")
	var said := false
	for m in w.hud._msgs: said = said or String(m.get("text", m) if m is Dictionary else m).find("root cellar") >= 0
	check(said, "and says the root-cellar line")
	var players := rc.find_children("*", "AudioStreamPlayer3D", true, false).size()
	check(players >= 1, "the hinge creaks as the lid lifts (%d player)" % players)
	w.gear.close()
	await secs(0.6)
	var sv: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	check(sv["cellar"].get("found", false) == true, "the save remembers it was found")
	var rc2 := RootCellar.new(); rc2.setup(cb2, sv["cellar"], 1)
	check(rc2.found, "and a reload keeps it quiet the second time")
	rc2.queue_free()

	# ---- W4 track hint: walls block it, it fades
	var cb: Cabin = w.cabins[1]
	var out_eye := cb.to_global(Vector3(0.0, Cabin.FLOOR_LOCAL_Y + 1.6, -Cabin.HZ - 0.6))
	var tgt := cb.to_global(Vector3(0.0, Cabin.FLOOR_LOCAL_Y, -Cabin.HZ + 1.6))
	var dd := tgt - out_eye
	w.player.position = out_eye; w.player.yaw = atan2(-dd.x, -dd.z); w.player.pitch = atan2(dd.y, Vector2(dd.x, dd.z).length())
	await frames(2)
	w.player.position = out_eye; w.player.yaw = atan2(-dd.x, -dd.z); w.player.pitch = atan2(dd.y, Vector2(dd.x, dd.z).length())
	await frames(1)
	var lp: Vector3 = w.track_look_point()
	check(is_nan(lp.x), "looking down through a cabin wall reads no tracks")
	w.player.yaw += PI
	await frames(2)
	w.player.position = out_eye
	await frames(1)
	lp = w.track_look_point()
	check(not is_nan(lp.x), "turned away (open snow) the look point is back")
	var hud = w.hud
	w.set_process(false)   # the world rewrites the hint every update; drive the HUD alone
	hud.track_hint = "Deer tracks · fresh"
	await secs(0.08)
	var a_mid: float = hud._th_a
	await secs(0.4)
	check(a_mid > 0.0 and a_mid < 0.95 and hud._th_a > 0.95, "the hint fades in (%.2f then %.2f)" % [a_mid, hud._th_a])
	hud.track_hint = ""
	await secs(0.1)
	check(hud._th_a < 0.95 and hud._th_a > 0.0 and hud._th_text != "", "and fades out keeping its words (%.2f)" % hud._th_a)
	w.set_process(true)

	# ---- W5 melt ring fills back in with snow
	var fc: Cabin = w.cabins[w.cabins.size() - 1]
	var now: float = w.clock.total_game_s
	var fire := CabinFire.new()
	fire.setup(w, fc, now - CabinFire.IGNITE_S - CabinFire.BLAZE_S - 3600.0)
	await frames(3)
	var r0 := fire.ring_left(now)
	check(r0 > 0.9 and r0 < 1.0, "an hour after the blaze the melt ring is nearly all there (%.3f)" % r0)
	var tl: TrackLog = w.animal_tracks.log
	tl.snow_clock += CabinFire.REFILL_S * 0.5
	var r1 := fire.ring_left(now)
	check(r1 > 0.2 and r1 < 0.8, "half a refill of snow later it is half gone (%.2f)" % r1)
	tl.snow_clock += CabinFire.REFILL_S
	check(fire.ring_left(now) < 0.01, "and then snowed over")
	print("W_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
