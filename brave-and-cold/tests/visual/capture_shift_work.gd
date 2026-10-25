extends SceneTree
## Visual review: deck weather station, rail fire finder, slash-burn smoke from the
## deck at 15:00, and the work-order sheet.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func shot(local: Vector3, target: Vector3, id: String, world_target := false) -> void:
	var t: FireLookout = w.fire_lookout
	w.player.position = t.to_global(local + Vector3.UP * FireLookout.DECK_Y); w.player.cam.position = Vector3.ZERO
	w.player.cam.look_at(target if world_target else t.to_global(target + Vector3.UP * FireLookout.DECK_Y)); w.player.cam.make_current()
	for frame in 30: await process_frame
	get_root().get_texture().get_image().save_png("res://shots/shift-work/" + id + ".png"); print("SHIFT_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1280, 720); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/shift-work"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.opening.shift != null: break
	freeze(w); w.hud.visible = false; w.viewmodel.visible = false; w.player.cam.fov = 70
	var sw: ShiftWork = w.opening.shift
	sw.set_process(true); sw.smoke.set_process(true); sw.smoke.set_physics_process(true) # particles need their node processing
	w.story_skip_to(1, 15.0); w.sky_rig.apply_hour(15); w.sky_rig.apply_shelter(0)
	sw._process(.1)
	await shot(Vector3(-3.0, 1.62, -.25), Vector3(-4.05, 1.3, -1.05), "weather_station")
	await shot(Vector3(-1.5, 1.62, 2.55), Vector3(-1.85, 1.2, 3.35), "fire_finder")
	sw.sight()
	for i in 90: await process_frame
	await shot(Vector3(-1.85, 1.62, 2.75), sw.smoke_point + Vector3.UP * 40, "smoke_from_deck", true)
	var away: Vector3 = (w.fire_lookout.global_position - sw.smoke_point) * Vector3(1, 0, 1)
	w.player.position = sw.smoke_point + away.normalized() * 260 + Vector3.UP * 140; w.player.cam.look_at(sw.smoke_point + Vector3.UP * 35)
	for frame in 30: await process_frame
	get_root().get_texture().get_image().save_png("res://shots/shift-work/smoke_near.png"); print("SHIFT_CAPTURE smoke_near")
	await shot(Vector3(-1.6, 1.62, 2.6), Vector3(-1.85, 1.2, 3.33), "alidade_on_bearing")
	w.hud.visible = true; sw.read_order()
	for i in 20: await process_frame
	get_root().get_texture().get_image().save_png("res://shots/shift-work/work_order.png"); print("SHIFT_CAPTURE work_order")
	quit(0)
