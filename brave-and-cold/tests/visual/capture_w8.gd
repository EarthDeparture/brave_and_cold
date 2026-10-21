extends SceneTree
## Weapons W8 review: mitten vs work glove vs bare skin (warm / cold) close up, beam flakes in snowfall,
## gunsmith with the action open. -> res://shots/w8/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(25)
	root.get_texture().get_image().save_png("res://shots/w8/" + id + ".png"); print("W8_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261021)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/w8"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 12.5
	var pt: Vector3 = w.fire_lookout.approach_point(9.0); w.player.place(pt.x, pt.z)
	w.inv.add("ranger_box_rifle"); w.inv.use("ranger_box_rifle"); w.rifle_up = true
	var vm = w.viewmodel
	var c := Camera3D.new(); c.fov = 35; c.near = 0.01; root.add_child(c)
	await frames(30)
	var cam: Camera3D = w.player.cam
	for look in [["mitts", "hide_mitts"], ["gloves", "work_gloves"], ["bare", ""]]:
		w.inv.extra["hands"] = look[1]; await frames(5)
		var hp: Vector3 = vm._right.global_position
		c.global_position = hp + cam.global_basis.x * 0.22 + cam.global_basis.y * 0.06; c.look_at(hp, Vector3.UP); c.make_current()
		await shot("hand_" + look[0])
		var lp: Vector3 = vm._left.global_position
		c.global_position = lp - cam.global_basis.x * 0.20 - cam.global_basis.y * 0.08; c.look_at(lp, Vector3.UP)
		await shot("support_" + look[0])
	w.frostbite.risk["hands"] = 80.0; await frames(5)
	var hp2: Vector3 = vm._right.global_position
	c.global_position = hp2 + cam.global_basis.x * 0.22 + cam.global_basis.y * 0.06; c.look_at(hp2, Vector3.UP)
	await shot("hand_bare_cold")
	w.frostbite.risk["hands"] = 0.0
	cam.make_current()
	await shot("hip_bare")
	# beam flakes in snowfall
	w.clock.hour = 22.5; w.weather.set_state(Weather.S.SNOW, true); w.weather.locked = true
	w.rifle_up = false; w.inv.add("flashlight"); w.inv.torch_h = 6.0; w.inv.torch_on = true
	var tgt: Vector3 = w.fire_lookout.to_global(Vector3(0.0, 1.5, 0.0)); var d: Vector3 = tgt - w.player.global_position
	w.player.yaw = atan2(-d.x, -d.z) + 0.5; w.player.pitch = -0.05
	await shot("beam_flakes")
	print("W8_BEAM emitting=", w.snowfall.beam != null and w.snowfall.beam.emitting, " ratio=", w.snowfall.beam.amount_ratio if w.snowfall.beam != null else -1)
	w.inv.torch_on = false; w.weather.locked = false; w.weather.set_state(Weather.S.CLEAR, true); w.clock.hour = 12.5
	# gunsmith, action open, close on the receiver's right side
	w.open_gunsmith("ranger_box_rifle", true); await frames(10)
	var gs = w.gunsmith
	gs.action_open = true; gs._yaw = 1.45; gs._pitch = -0.15; gs._dist = 0.55
	await shot("gunsmith_action_open")
	w.inv.add("compact_patrol_rifle"); gs.rid = "compact_patrol_rifle"; gs._rebuild_gun(); await frames(5)
	await shot("gunsmith_action_open_semi")
	quit(0)
