extends SceneTree
## A7 root cellar review: the hatch shut and open in the cabin, the pit from standing and leaning over,
## and at night by the stove. -> res://shots/cellar/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(25)
	root.get_texture().get_image().save_png("res://shots/cellar/" + id + ".png"); print("CELLAR_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261026)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/cellar"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 12.5
	w.weather.set_state(0, true); w.weather.locked = true
	var rc: RootCellar = w.root_cellar
	var cb: Cabin = rc.cabin
	w.player.position = cb.to_global(Vector3(-2.0, Cabin.FLOOR_LOCAL_Y + 1.7, 1.5))
	w.rifle_up = false; w.hud.visible = false
	var c := Camera3D.new(); c.fov = 65; c.near = 0.02; root.add_child(c); c.make_current()
	var hp := rc.hatch_world_pos()
	c.global_position = cb.to_global(Vector3(-0.6, Cabin.FLOOR_LOCAL_Y + 1.65, 1.6)); c.look_at(hp, Vector3.UP)
	await shot("hatch_shut_day")
	rc.hold_open = true
	await frames(60)
	c.make_current()
	await shot("hatch_open_day")
	c.global_position = cb.to_global(Vector3(0.7, Cabin.FLOOR_LOCAL_Y + 1.6, 0.75)); c.look_at(hp - Vector3(0, 0.3, 0), Vector3.UP)
	await shot("pit_standing")
	c.global_position = cb.to_global(Vector3(0.75, Cabin.FLOOR_LOCAL_Y + 0.9, 0.45)); c.look_at(cb.to_global(Vector3(0.7, Cabin.FLOOR_LOCAL_Y - 1.4, -0.2)), Vector3.UP)
	await shot("pit_leaning")
	c.global_position = cb.to_global(Vector3(0.2, Cabin.FLOOR_LOCAL_Y + 0.8, 0.3)); c.look_at(cb.to_global(Vector3(1.05, Cabin.FLOOR_LOCAL_Y - 0.8, -0.2)), Vector3.UP)
	await shot("pit_shelves")
	w.clock.hour = 22.5; cb.fire.set_fuel(3600.0 * 3.0); cb.refresh_fire()
	c.global_position = cb.to_global(Vector3(-0.6, Cabin.FLOOR_LOCAL_Y + 1.65, 1.6)); c.look_at(hp, Vector3.UP)
	await shot("hatch_open_night")
	quit(0)
