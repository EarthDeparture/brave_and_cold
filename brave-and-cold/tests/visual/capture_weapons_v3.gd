extends SceneTree
## Weapon kit v3 review in play: the compact .22 with each sight (reflex, red-dot tube, 4x scope,
## irons), hip and aimed, by day and at night with the weapon light on. -> res://shots/weapons_v3/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(40)
	root.get_texture().get_image().save_png("res://shots/weapons_v3/" + id + ".png"); print("W3_CAPTURE ", id)
func fit(optic: String, light: String) -> void:
	var rid := "compact_patrol_rifle"
	w.inv.fitted[rid] = {"optic": optic, "light": light, "light_h": 5.0}
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/weapons_v3"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true
	w.story_skip_to(1, 11.0)
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	w.player.yaw = w.fire_lookout.rotation.y + PI; w.player.pitch = -0.06
	if w.inv.count("compact_patrol_rifle") < 1: w.inv.add("compact_patrol_rifle")
	w.inv.use("compact_patrol_rifle"); w.rifle_up = true; w.player.zoom_i = 0
	fit("reflex_micro", "light_clamp")
	w.aim_override = false; await shot("hip_reflex_day")
	w.aim_override = true; await shot("ads_reflex_day")
	fit("reddot_tube", "light_clamp"); await shot("ads_tube_day")
	fit("", "light_taped"); await shot("ads_irons_day")
	w.aim_override = false; await shot("hip_irons_taped_day")
	fit("scope_4x", "light_clamp"); w.aim_override = true; await shot("ads_scope4x_day")
	# night, light on: on the ground facing the tower legs, so the beam has something to hit
	w.clock.hour = 22.5
	var pt: Vector3 = w.fire_lookout.approach_point(9.0)
	w.player.place(pt.x, pt.z)
	var tgt: Vector3 = w.fire_lookout.to_global(Vector3(0.0, 1.5, 0.0))
	var dir: Vector3 = tgt - w.player.global_position
	w.player.yaw = atan2(-dir.x, -dir.z); w.player.pitch = -0.08
	fit("reflex_micro", "light_clamp"); w.inv.light_on = true
	w.aim_override = false; await shot("hip_reflex_night_light")
	w.aim_override = true; await shot("ads_reflex_night_light")
	# v2 reference for hand contact (same place, day)
	w.clock.hour = 11.0; w.inv.light_on = false
	if w.inv.count("ranger_box_rifle") < 1: w.inv.add("ranger_box_rifle")
	w.inv.use("ranger_box_rifle"); w.aim_override = false; await shot("hip_v2_ranger")
	quit(0)
