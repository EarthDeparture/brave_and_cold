extends SceneTree
## Weapons W7 review: flakes lit by the torch / rifle light in snowfall, sun glare (plain + through a scope),
## a road flare's glare at night, warm vs cold bare hands, gloves. -> res://shots/w7/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(30)
	root.get_texture().get_image().save_png("res://shots/w7/" + id + ".png"); print("W7_CAPTURE ", id)
func sling(id: String) -> void:
	if w.inv.count(id) < 1: w.inv.add(id)
	w.inv.use(id); w.rifle_up = true; w.player.zoom_i = 0
func face(dir: Vector3, pitch := -0.06) -> void:
	w.player.yaw = atan2(-dir.x, -dir.z); w.player.pitch = pitch
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261021)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/w7"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true
	w.story_skip_to(1, 11.0)
	var pt: Vector3 = w.fire_lookout.approach_point(9.0)
	w.player.place(pt.x, pt.z)
	var tgt: Vector3 = w.fire_lookout.to_global(Vector3(0.0, 1.5, 0.0))
	var to: Vector3 = tgt - w.player.global_position
	# ---- night snowfall: torch, then the rifle light
	w.clock.hour = 22.5
	w.weather.set_state(Weather.S.SNOW, true); w.weather.locked = true
	face(to, -0.05)
	w.inv.add("flashlight"); w.inv.torch_h = 6.0; w.inv.torch_on = true
	await shot("lamp_flakes_torch")
	w.inv.torch_on = false
	sling("compact_patrol_rifle"); w.inv.fitted["compact_patrol_rifle"] = RifleDB.fitted("compact_patrol_rifle").duplicate()
	w.inv.fitted["compact_patrol_rifle"]["light_h"] = 6.0; w.inv.light_on = true
	await shot("lamp_flakes_rifle")
	w.inv.light_on = false; w.rifle_up = false
	# ---- road flare at night, clear weather
	w.weather.set_state(Weather.S.CLEAR, true)
	var fl: Node3D = load("res://world/flare.gd").new(); w.add_child(fl)
	fl.global_position = w.player.global_position + Vector3(-sin(w.player.yaw), 0, -cos(w.player.yaw)) * 14.0
	fl.global_position.y = w._ground_y(fl.global_position.x, fl.global_position.z) + 0.05
	await shot("flare_road_night")
	fl.queue_free()
	# ---- low sun, plain and through the 4x scope
	w.clock.hour = 16.9
	await frames(10)
	var sd: Vector3 = w.sky_rig.sun.global_basis.z.normalized()
	face(Vector3(sd.x, 0, sd.z), asin(clampf(sd.y, -1, 1)) * 0.9)
	await shot("flare_sun")
	print("W7_FLARE sources=", w.lens_flare.sources.size(), " ", w.lens_flare.sources.map(func(s): return [s["key"], snappedf(s["k"], 0.01)]))
	sling("ranger_box_rifle"); w.aim_override = true
	face(Vector3(sd.x, 0, sd.z), asin(clampf(sd.y, -1, 1)) * 0.95)
	await shot("flare_sun_scope")
	w.aim_override = false; w.rifle_up = false
	# ---- hands: warm, cold, gloved (midday, back to the sun), ranger at the hip
	w.clock.hour = 12.5; await frames(5)
	face(-Vector3(sd.x, 0, sd.z), -0.15)
	sling("ranger_box_rifle")
	w.frostbite.risk["hands"] = 0.0; await shot("hands_warm")
	w.frostbite.risk["hands"] = 45.0; await shot("hands_cold")
	w.frostbite.risk["hands"] = 95.0; await shot("hands_numb")
	w.frostbite.risk["hands"] = 0.0
	w.inv.add("work_gloves"); w.inv.use("work_gloves"); await shot("hands_gloved")
	# ---- gunsmith: lots of parts (scroll), hover another rifle's tab (compare)
	w.rifle_up = false
	for a in ["scope_3_9x", "scope_4_12x", "reddot_tube", "reflex_micro", "scope_4x", "light_taped", "light_clamp", "muzzle_moderator", "screwdriver", "timber_bolt_carbine", "brush_lever_rifle"]: w.inv.add(a)
	w.open_gunsmith("ranger_box_rifle", true); await frames(10)
	var gs = w.gunsmith
	gs._mouse = Vector2(1000, 98); await shot("gunsmith_tab_compare")
	print("W7_GS tab_cmp=", gs._tab_cmp, " content_h=", gs._content_h)
	gs._mouse = Vector2(1100, 500); gs._scroll = 1e6; gs._scroll = clampf(gs._scroll, 0.0, maxf(0.0, gs._content_h - (gs.SLOT_R.end.y - 182.0))); await shot("gunsmith_scrolled")
	quit(0)
