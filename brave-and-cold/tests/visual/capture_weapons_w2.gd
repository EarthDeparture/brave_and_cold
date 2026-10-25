extends SceneTree
## Weapon kit v3 W2 review in play: every rifle with its factory fit, hip + aimed (day, deck), a few
## customised fits, the bolt cycle mid-stroke, the handheld flashlight at night and the gunsmith
## screen. -> res://shots/weapons_w2/  (args after --: only=id,id  skip_gs)
var w: Node3D
var only: Array = []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(40)
	root.get_texture().get_image().save_png("res://shots/weapons_w2/" + id + ".png"); print("W2_CAPTURE ", id)
func sling(id: String) -> void:
	if w.inv.count(id) < 1: w.inv.add(id)
	w.inv.use(id); w.rifle_up = true; w.player.zoom_i = 0
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="): only = a.substr(5).split(",")
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/weapons_w2"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true
	w.story_skip_to(1, 11.0)
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	w.player.yaw = w.fire_lookout.rotation.y + PI; w.player.pitch = -0.06
	for rid: String in WeaponPresentation.IDS:
		if not only.is_empty() and not only.has(rid): continue
		sling(rid)
		w.aim_override = false; await shot("hip_" + rid)
		w.aim_override = true; await shot("ads_" + rid)
	if only.is_empty():
		# customised: service + clamp-on scout mount + 2x, compact + moderator, ranger on irons
		w.inv.add("scout_mount_clamp"); w.inv.add("scope_scout_2x"); w.inv.add("muzzle_moderator")
		sling("north_service_rifle")
		w.inv.fit_attachment("north_service_rifle", "mount", "scout_mount_clamp", true); w.inv.fit_attachment("north_service_rifle", "optic", "scope_scout_2x", true)
		w.aim_override = false; await shot("hip_service_scout")
		sling("compact_patrol_rifle"); w.inv.fit_attachment("compact_patrol_rifle", "muzzle", "muzzle_moderator", true)
		w.aim_override = false; await shot("hip_compact_moderator")
		w.aim_override = true; await shot("ads_compact_moderator")
		sling("ranger_box_rifle"); w.inv.fit_attachment("ranger_box_rifle", "optic", "", true)
		w.aim_override = true; await shot("ads_ranger_irons")
		# bolt cycle mid-stroke (handle up, bolt back)
		w.aim_override = false; w.viewmodel._weapon_clip = "cycle"; w.viewmodel._weapon_clip_t = 0.45
		await shot("cycle_ranger"); w.viewmodel._weapon_clip = ""
		# gunsmith screen at the deck (field), ranger
		w.open_gunsmith("ranger_box_rifle", false); await shot("gunsmith_field")
		w.gunsmith.close()
		# night, handheld flashlight on the ground
		w.clock.hour = 22.5
		var pt: Vector3 = w.fire_lookout.approach_point(9.0)
		w.player.place(pt.x, pt.z)
		var tgt: Vector3 = w.fire_lookout.to_global(Vector3(0.0, 1.5, 0.0))
		var dir: Vector3 = tgt - w.player.global_position
		w.player.yaw = atan2(-dir.x, -dir.z); w.player.pitch = -0.08
		w.rifle_up = false; w.inv.add("flashlight"); w.inv.torch_on = true; w.inv.torch_h = 6.0
		await shot("night_flashlight")
	quit(0)
