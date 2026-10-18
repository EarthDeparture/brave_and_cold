extends SceneTree
## Main-menu backdrop candidates from the current game: the fire lookout, a hamlet cabin
## and the greenhouse at golden hour / blue dusk, every stove lit and smoking.
## Writes res://shots/menu/cand_<id>.png at 2560x1440. "-- only=<id>" for one shot.
var w: Node3D
var only := ""

func _initialize() -> void: call_deferred("run")

func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for c in n.get_children(): freeze(c)

func ground(x: float, z: float) -> float:
	return w._ground(x, z).y

func setup_time(hour: float, state: int) -> void:
	w.clock.hour = hour
	w.weather._t = 0.0; w.weather.lock_state(state); w.weather.advance(120.0, 0.0)
	if w.sky_rig.has_method("set_cloud_offset"): w.sky_rig.set_cloud_offset(Vector2(0.17, 0.08))
	if w.forest != null: w.forest.update_detail_appearance()
	w.sky_rig.apply_hour(hour)
	if w.sky_rig.has_method("snow_tint"): w.snowfall.set_light_tint(w.sky_rig.snow_tint())
	if w.sky_rig.has_method("apply_shelter"): w.sky_rig.apply_shelter(0.0)
	var night: float = w.sky_rig.gameplay_night_factor
	for cb: Cabin in w.cabins: cb.set_night(night)
	if w.fire_lookout != null: w.fire_lookout.set_night(night, true, Vector3(0, -1000, 0))
	for il: Node in get_nodes_in_group("interior_lighting"): (il as InteriorLighting).update(1.0 - night, w.weather.overcast, w.weather.precip)

func light_fires() -> void:
	var wind: Vector2 = w.weather.wind_dir
	for cb: Cabin in w.cabins:
		cb.stove_fuel_s = 4 * 3600; cb.set_process(true)
		if cb.smoke != null: FireVisual.set_smoke(cb.smoke, cb.fire, wind)
	for sb: Node in w._stove_buildings():
		var st: Stove = sb.get("stove"); st.fire.set_fuel(4 * 3600); st.set_process(true); FireVisual.set_smoke(st.smoke, st.fire, wind)
	if w.opening != null:
		w.opening.fire.set_fuel(4 * 3600)
		if w.opening.stove_smoke != null: FireVisual.set_smoke(w.opening.stove_smoke, w.opening.fire, wind)

func shot(id: String, eye: Vector3, target: Vector3, fov: float, hour: float, state: int) -> void:
	if only != "" and only != id and not (only == "glow_all" and id.begins_with("glow_")): return
	setup_time(hour, state)
	light_fires()
	var cam: Camera3D = w.player.cam
	w.player.global_position = eye; cam.global_position = eye; cam.look_at(target); cam.fov = fov
	w.terrain.set_camera(cam)
	w.snowfall.visible = w.weather.precip > 0.02
	if w.snowfall.visible: w.snowfall.restart(true); w.snowfall.request_particles_process(4.0)
	if w.weather_presentation != null:
		w.weather_presentation.reset_visuals()
		for j in 240: w.weather_presentation._process(1.0 / 60.0)
	for i in 120: await process_frame
	root.get_texture().get_image().save_png("res://shots/menu/cand_%s.png" % id)
	print("MENU_BG ", id, " eye=", eye)

## Aim point moved `shift` metres to the left of the line of sight: the subject lands right of centre.
func aim(eye: Vector3, target: Vector3, shift: float) -> Vector3:
	var f := (target - eye).normalized()
	var right := f.cross(Vector3.UP).normalized()
	return target - right * shift

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="): only = a.substr(5)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/menu"))
	AudioServer.set_bus_mute(0, true)
	SaveGame.pending = {}; seed(20261004)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for i in 700:
		await process_frame
		if w.hud != null and w.opening != null and w.collapse != null: break
	DisplayServer.window_set_size(Vector2i(2560, 1440)); await process_frame
	freeze(w); w.hud.hide(); w.viewmodel.hide()
	if w.town_life != null: w.town_life.visible = false
	w.snowfall.use_fixed_seed = true; w.snowfall.seed = 42; w.snowfall.fixed_fps = 60
	var t: FireLookout = w.fire_lookout
	var tp := t.global_position
	# Window-glow review shots (not menu candidates): on the deck outside the glass, and ~24 m out.
	if only.begins_with("glow_"):
		var deck := t.to_global(Vector3(3.35, FireLookout.DECK_Y + 1.62, 0.9))
		await shot("glow_deck", deck, t.to_global(Vector3(0.0, FireLookout.DECK_Y + 1.5, -0.6)), 70.0, 18.6, Weather.S.CLEAR)
		var a2 := 3 * TAU / 4.0 + 0.9
		var mid := Vector3(tp.x + cos(a2) * 24.0, 0, tp.z + sin(a2) * 24.0); mid.y = ground(mid.x, mid.z) + 1.6
		await shot("glow_mid", mid, tp + Vector3(0, FireLookout.DECK_Y + 1.2, 0), 50.0, 18.6, Weather.S.CLEAR)
		quit(0); return
	# Subjects sit in the right third (shift the aim left) so the menu column on the left reads over dark.
	for hr in [17.95, 18.3]:
		var hs := "%02d" % int(round(fmod(hr, 1.0) * 100.0))
		if not w.greenhouses.is_empty():
			var gh: Greenhouse = w.greenhouses[0]
			for side in [-1.0, 1.0]:
				var e4 := gh.to_global(Vector3(side * 9.0, 0, 11.0)); e4.y = ground(e4.x, e4.z) + 1.65
				await shot("gh_%s_%d" % [hs, int(side)], e4, aim(e4, gh.to_global(Vector3(-side * 3.0, 1.6, -2.0)), 5.0), 62.0, hr, Weather.S.FLURRY)
		if w.cabins.size() > 2:
			var cb: Cabin = w.cabins[1]
			var e3 := cb.to_global(Vector3(-12.0, 0, 22.0)); e3.y = ground(e3.x, e3.z) + 1.7
			await shot("hamlet_%s" % hs, e3, aim(e3, cb.to_global(Vector3(4.0, 3.0, -6.0)), 4.0), 64.0, hr, Weather.S.FLURRY)
		var a := 3 * TAU / 4.0 + 0.4
		var e := Vector3(tp.x + cos(a) * 46.0, 0, tp.z + sin(a) * 46.0); e.y = ground(e.x, e.z) + 1.6
		# A dry grass tuft sat dead centre in the foreground of this framing: plants off for it.
		if w.plants != null: w.plants.visible = false
		await shot("lookout_%s" % hs, e, aim(e, tp + Vector3(0, 12.0, 0), 19.0), 58.0, hr, Weather.S.CLEAR)
		if w.plants != null: w.plants.visible = true
	quit(0)
