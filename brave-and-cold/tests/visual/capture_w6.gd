extends SceneTree
## Weapons follow-up review: flashlight in hand (day + night), gun details up close (checkering,
## screws, scope rings, camo), hands on the lever and service rifles. -> res://shots/w6/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(30)
	root.get_texture().get_image().save_png("res://shots/w6/" + id + ".png"); print("W6_CAPTURE ", id)
func sling(id: String) -> void:
	if w.inv.count(id) < 1: w.inv.add(id)
	w.inv.use(id); w.rifle_up = true; w.player.zoom_i = 0
func close(target: Vector3, from: Vector3) -> Camera3D:
	var c := Camera3D.new(); c.fov = 30.0; c.near = 0.01; root.add_child(c)
	c.global_position = from; c.look_at(target, Vector3.UP); c.make_current(); return c
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/w6"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true
	w.story_skip_to(1, 11.0)
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	w.player.yaw = w.fire_lookout.rotation.y + PI; w.player.pitch = -0.06
	var cam: Camera3D = w.player.cam
	# gun details from debug cameras
	for rid in ["ranger_box_rifle", "brush_lever_rifle", "timber_bolt_carbine", "north_service_rifle"]:
		sling(rid); w.aim_override = false; await shot("hip_" + rid)
		var rp = w.viewmodel._rifle
		var m: Transform3D = rp.global_transform * rp.model.transform
		var cb := cam.global_basis
		var grip: Vector3 = m * Vector3(0, .03, .09)
		var c := close(grip, grip + m.basis.x * .26 + cb.y * .03); await shot(rid + "_grip_side")
		var rec: Vector3 = m * Vector3(0, .10, -.05)
		c.global_position = rec + m.basis.x * .22 + m.basis.y * .12 + m.basis.z * .12; c.look_at(rec, Vector3.UP); await shot(rid + "_receiver")
		var fe: Vector3 = m * Vector3(0, .06, -.33)
		c.global_position = fe - m.basis.x * .22 - m.basis.y * .06; c.look_at(fe, Vector3.UP); await shot(rid + "_foreend_left")
		c.queue_free(); cam.make_current()
		w.aim_override = true; await shot("ads_" + rid)
	# flashlight in hand, day then night
	w.aim_override = false; w.rifle_up = false
	w.inv.add("flashlight"); w.inv.torch_h = 6.0; w.inv.torch_on = true
	await shot("torch_day_hatchet")
	w.clock.hour = 22.5
	var pt: Vector3 = w.fire_lookout.approach_point(9.0)
	w.player.place(pt.x, pt.z)
	var tgt: Vector3 = w.fire_lookout.to_global(Vector3(0.0, 1.5, 0.0))
	var dir: Vector3 = tgt - w.player.global_position
	w.player.yaw = atan2(-dir.x, -dir.z); w.player.pitch = -0.08
	await shot("torch_night")
	# hand torch in falling snow + fog: the beam shaft shows
	w.weather.set_state(Weather.S.SNOW, true); w.weather.locked = true; await frames(5); print("W6_BEAM k=", w.beam_k(), " precip=", w.weather.precip)
	await shot("torch_night_snow")
	# rifle light in snow (compact: factory clamp light)
	w.inv.torch_on = false
	sling("compact_patrol_rifle"); w.inv.fitted["compact_patrol_rifle"] = RifleDB.fitted("compact_patrol_rifle").duplicate()
	w.inv.fitted["compact_patrol_rifle"]["light_h"] = 6.0; w.inv.light_on = true
	await shot("rifle_light_snow")
	print("W6_BEAM rifle shaft=", w.viewmodel._rifle.lamp.get_node_or_null("BeamShaft") != null); w.inv.light_on = false; w.weather.locked = false; w.weather.set_state(Weather.S.CLEAR, true); w.clock.hour = 11.0
	# gunsmith: two rangers (x2 tab + next rifle), parts with icons, hover compare on a scope
	w.inv.add("ranger_box_rifle"); w.inv.add("ranger_box_rifle")
	for a in ["scope_3_9x", "reddot_tube", "light_taped", "light_clamp", "muzzle_moderator", "screwdriver"]: w.inv.add(a)
	w.open_gunsmith("ranger_box_rifle", true); await frames(10)
	await shot("gunsmith_plain")
	var gs = w.gunsmith
	var target := Vector2(1200, 0)
	for y in range(180, 780, 4):
		gs._mouse = Vector2(1100, y); gs._c.queue_redraw(); await process_frame
		if not gs._preview.is_empty() and String(gs._preview["label"]).find("3-9x") >= 0: target = gs._mouse; break
	gs._mouse = target; await shot("gunsmith_hover_scope")
	for y in range(180, 780, 4):
		gs._mouse = Vector2(1100, y); gs._c.queue_redraw(); await process_frame
		if not gs._preview.is_empty() and String(gs._preview["label"]).find("clamp") >= 0: target = gs._mouse; break
	gs._mouse = target; await shot("gunsmith_hover_light")
	quit(0)
