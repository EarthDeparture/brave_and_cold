extends SceneTree
## Optics: magnification maths per rifle, the right picture per sight type,
## variable vs fixed power, BDC holdover = real ballistics, body-state sway, and
## long-range targets that are visible through glass are real and hittable.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func sling(w: Node3D, id: String) -> void:
	if w.inv.count(id) < 1: w.inv.add(id)
	w.inv.use(id); w.rifle_up = true
func run() -> void:
	create_timer(170).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	# ---- maths and data
	check(is_equal_approx(RifleDB.HIP_FOV, Player.HIP_FOV), "magnification is measured against the real hip FOV")
	var all_ok := true
	for id: String in RifleDB.ids():
		var mags := RifleDB.magnifications(id); var fovs := RifleDB.zoom(id)
		for i in mags.size():
			var m := tan(deg_to_rad(Player.HIP_FOV) * .5) / tan(deg_to_rad(float(fovs[i])) * .5)
			all_ok = all_ok and absf(m - float(mags[i])) < .001
	check(all_ok, "every aim FOV gives exactly its stated true magnification")
	check(RifleDB.zoom("ranger_box_rifle").size() == 1 and RifleDB.zoom("timber_bolt_carbine").size() == 1, "fixed-power scopes have one power: the wheel does nothing")
	var r := RifleDB.magnifications("ridge_scout_rifle")
	check(r.size() == 3 and is_equal_approx(r[0], 3.0) and is_equal_approx(r[2], 9.0) and absf(r[1] - sqrt(27.0)) < .001, "3-9x scope steps 3x, 5.2x, 9x")
	var scoped := RifleDB.ids().filter(func(id: String) -> bool: return RifleDB.is_scoped(id))
	check(scoped.size() == 6 and not RifleDB.is_scoped("compact_patrol_rifle") and not RifleDB.is_scoped("brush_lever_rifle"), "both reflex rifles keep the model in view; six optics use the tube picture")
	var gw: Dictionary = (load("res://world/game_world.gd") as Script).get_script_constant_map()
	check(is_equal_approx(gw.MUZZLE_V, ScopeOverlay.MUZZLE_V) and is_equal_approx(gw.ZERO_M, ScopeOverlay.ZERO_M) and is_equal_approx(gw.GRAV, ScopeOverlay.GRAV), "BDC reticle uses the projectile model's own constants")
	# Integrate the real launch (zeroing lift) and compare holdover at 300 m.
	var v: float = gw.MUZZLE_V; var g: float = gw.GRAV
	var lift: float = 0.5 * g * float(gw.ZERO_M) / (v * v)
	var t := 300.0 / (v * cos(lift)); var y := v * sin(lift) * t - 0.5 * g * t * t
	check(absf(-y / 300.0 - ScopeOverlay.drop_angle(300)) < 2e-6 and is_zero_approx(ScopeOverlay.drop_angle(100)), "300 m holdover mark matches the simulated drop (%.2f mrad)" % (ScopeOverlay.drop_angle(300) * 1000))
	# ---- live world
	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true # run < 120 s: no autosave; "" also skips the frame-40 screenshot
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	sling(w, "ridge_scout_rifle"); w.aim_override = true
	await frames(90)
	check(w.viewmodel.scoped_view and w.hud.scope.visible and w.hud.scope.fade < .01, "ridge scope: tube picture replaces the model after a short blackout")
	check(absf(w.player.cam.fov - RifleDB.fov_for(3.0)) < .3, "first power is a true 3x (%.1f deg)" % w.player.cam.fov)
	var r3: float = w.hud.scope.radius_px; var b3: float = w.hud.scope.bdc.y
	w.player.zoom_step(2); await frames(90)
	check(absf(w.player.cam.fov - RifleDB.fov_for(9.0)) < .3, "wheel up reaches 9x (%.1f deg)" % w.player.cam.fov)
	check(w.hud.scope.radius_px < r3 - 5 and w.hud.scope.bdc.y > b3 * 2.5, "high power: tighter eye box, holdover marks scale with power (first focal plane)")
	var calm: float = w.player.sway_mult
	w.player.stamina = 10.0; w.body.core = 35.2; await frames(5)
	check(w.player.sway_mult > calm * 2.5, "winded and shivering hold sways far more (%.1fx -> %.1fx)" % [calm, w.player.sway_mult])
	w.player.stamina = 100.0; w.body.core = 37.0
	# ---- long range: a virtual zombie 150 m out becomes a real, hittable actor in the cone
	var eye: Vector3 = w.player.cam.global_position
	var best := Vector3.INF
	for k in 16:
		var a := k * TAU / 16.0; var p: Vector3 = w._ground(eye.x + sin(a) * 150, eye.z + cos(a) * 150)
		var clear := true
		for s in range(1, 30):
			var q := eye.lerp(p + Vector3.UP * 1.3, s / 30.0)
			if w._ground(q.x, q.z).y > q.y - .5: clear = false
		if clear: best = p; break
	check(best.is_finite(), "found an open 150 m sight line from the deck")
	if best.is_finite():
		var before: int = w.pop.active.size()
		w.pop.add_virtual(best)
		var to := best + Vector3.UP * 1.3 - eye
		w.player.yaw = atan2(-to.x, -to.z); w.player.pitch = asin(to.normalized().y)
		await frames(40)
		check(is_equal_approx(w.pop.proxy_r, Population.SCOPE_PROXY_R), "proxy ring widens to 420 m behind 2.5x+ glass")
		var z: Zombie = null
		for a in w.pop.active:
			if a.global_position.distance_to(best) < 3.0: z = a
		check(z != null and w.pop.active.size() > before and float(z.get_meta("scope_pin", -1)) > w.pop.clock, "zombie in the reticle at 150 m is promoted to a real pinned actor")
		if z != null:
			var hp: float = z.hp
			var forest = w.forest; w.forest = null; w.instant_bullets = true
			var aim := z.global_position + Vector3.UP * 1.25
			w._spawn_bullet(eye, (aim - eye).normalized())
			w.forest = forest
			check(z.hp < hp or z.is_dead(), "a shot through the scope hits it at %.0f m" % eye.distance_to(aim))
			w.aim_override = false; await frames(30)
			check(is_equal_approx(w.pop.proxy_r, Population.PROXY_R) and not w.hud.scope.visible, "lowering the rifle restores the normal proxy ring and hides the optic")
			if not z.is_dead():
				w.pop.clock += Population.SCOPE_PIN_S + 1; w.pop._despawn_step()
				check(not w.pop.active.has(z), "unwatched promoted actor parks back into the virtual population")
	# ---- other sight types
	sling(w, "compact_patrol_rifle"); w.aim_override = true; await frames(60)
	check(not w.viewmodel.scoped_view and w.hud.optic_kind == "reflex" and w.hud.scope.visible and int(w.hud.scope.mat.get_shader_parameter("mode")) == 1, "reflex sight: model stays, overlay draws only the dot")
	check(w.viewmodel._rifle.lens != null, "reflex lens mesh found for the future see-through pass")
	sling(w, "brush_lever_rifle"); await frames(60)
	check(not w.viewmodel.scoped_view and w.hud.scope.visible and absf(w.player.cam.fov - RifleDB.fov_for(1.25)) < .4, "wooden box reflex: 1.25x, model stays, dot overlay")
	w.aim_override = false; await frames(40)
	check(w.viewmodel._rifle.lens == null or w.viewmodel._rifle.lens.material_override == null, "lowered rifle restores the painted lens")
	w.aim_override = false
	w.queue_free(); await process_frame; await process_frame
	print("SCOPE_OPTICS_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
