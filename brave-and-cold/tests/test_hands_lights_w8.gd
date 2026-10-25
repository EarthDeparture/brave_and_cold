extends SceneTree
## Weapons W8: mitten shell for mitts (glove for work gloves, skin shader bare), the support hand on screen at
## the hip for every rifle, the dense beam-flake emitter (only lamp + snow + dark), aperture lens ghosts + dirt,
## the gunsmith's open-action inspect.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(170).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261023)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true; w.clock.hour = 12.5
	var pt: Vector3 = w.fire_lookout.approach_point(9.0); w.player.place(pt.x, pt.z)   # outdoors
	var vm = w.viewmodel
	# ---- hands
	w.inv.add("ranger_box_rifle"); w.inv.use("ranger_box_rifle"); w.rifle_up = true
	w.inv.extra["hands"] = "hide_mitts"; await frames(20)
	check(vm._right.trigger_mitt != null and vm._right.trigger_mitt.visible and not vm._right.glove.visible and vm._left.trigger_mitt.visible, "hide mitts: trigger mitts (bag + free index)")
	w.inv.extra["hands"] = "wolf_mitts"; await frames(5)
	check(vm._right.mitten.visible and not vm._right.trigger_mitt.visible, "wolf mitts: full fur mitten")
	var ib: bool = w.instant_bullets; w.instant_bullets = false; w.inv.add("ammo", 20)
	var rl := func() -> Array:
		w.inv.set_loaded(0); w._reload_t = 0.0; vm.cancel_weapon_clip(); await frames(2)
		w._start_reload(); var r := [w._reload_t, vm.clip_speed]; w._reload_t = 0.0; vm.cancel_weapon_clip(); return r
	var fur: Array = await rl.call()
	w.inv.extra["hands"] = "hide_mitts"; await frames(3)
	var trig: Array = await rl.call()
	w.instant_bullets = ib; w.inv.extra["hands"] = "wolf_mitts"
	check(float(trig[0]) > 0.5 and absf(float(fur[0]) / float(trig[0]) - 1.2) < 0.01 and absf(float(fur[1]) - 1.0 / 1.2) < 0.01 and float(trig[1]) == 1.0,
		"wolf mitts fumble the reload: %.2f s vs %.2f s, clip slowed to %.2f" % [float(fur[0]), float(trig[0]), float(fur[1])])
	check(vm._right.mitten.skin != null and vm._right.mitten.mesh.get_blend_shape_count() == vm._right.glove.mesh.get_blend_shape_count(), "mitten keeps the rig skin and the correctives")
	w.inv.extra["hands"] = "work_gloves"; await frames(5)
	check(vm._right.glove.visible and not vm._right.mitten.visible and not vm._right.trigger_mitt.visible, "work gloves show the five-finger glove")
	w.inv.extra["hands"] = ""; await frames(5)
	var sm = vm._right.bare.get_surface_override_material(0)
	check(vm._right.bare.visible and sm is ShaderMaterial and (sm as ShaderMaterial).shader.resource_path.ends_with("skin.gdshader"), "bare hands use the skin shader (pores, roughness, SSS)")
	# ---- support hand on screen at the hip, every rifle
	var off: Array = []
	for rid: String in WeaponPresentation.IDS:
		w.inv.add(rid); w.inv.use(rid); w.rifle_up = true; w.aim_override = false
		await frames(25)
		var hp: Vector3 = vm._left.global_position
		var sp: Vector2 = w.player.cam.unproject_position(hp)
		var vp: Vector2 = root.get_visible_rect().size
		if w.player.cam.is_position_behind(hp) or sp.x < 0 or sp.y < 0 or sp.x > vp.x or sp.y > vp.y * 1.02: off.append("%s %s" % [rid, sp])
	check(off.is_empty(), "hip: the support hand is on screen for every rifle %s" % str(off))
	# ---- beam flakes
	w.rifle_up = false; w.inv.add("flashlight"); w.inv.torch_h = 6.0
	w.weather.set_state(Weather.S.SNOW, true); w.weather.locked = true
	w.clock.hour = 12.5; w.inv.torch_on = true; await frames(10)
	check(w.snowfall.beam == null or not w.snowfall.beam.emitting, "daylight: no beam flakes")
	w.clock.hour = 22.5; await frames(30)
	check(w.snowfall.beam != null and w.snowfall.beam.emitting and w.snowfall.beam.amount_ratio > 0.4, "night + snow + torch: dense flakes in the beam")
	w.inv.torch_on = false; await frames(10)
	check(w.snowfall.beam != null and not w.snowfall.beam.emitting, "torch off: beam flakes stop")
	w.weather.locked = false
	# ---- lens flare textures
	check(w.lens_flare._hex != null and w.lens_flare._dirt != null, "aperture ghost and lens-dirt textures built")
	# ---- gunsmith open action
	w.clock.hour = 12.5
	w.open_gunsmith("ranger_box_rifle", true); await frames(5)
	var gs = w.gunsmith
	var bolt: Node3D = gs._gun.model.find_child("ranger_box_rifle__Pivot_Bolt", true, false)
	var z0: float = bolt.position.z
	gs.action_open = true; await frames(5)
	check(bolt.position.z - z0 > 0.05, "gunsmith OPEN ACTION draws the bolt back (%.3f m)" % (bolt.position.z - z0))
	gs.action_open = false; await frames(5)
	check(absf(bolt.position.z - z0) < 0.01, "and closes it again")
	gs.close()
	w.queue_free(); await process_frame; await process_frame
	print("HANDS_LIGHTS_W8_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
