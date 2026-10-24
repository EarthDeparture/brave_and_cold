extends SceneTree
## W1 weak-points review: cabin interior wood (floor boards, logs, furniture) by day and by the stove at night,
## the cabin from outside, a hut interior. -> res://shots/w1/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(25)
	root.get_texture().get_image().save_png("res://shots/w1/" + id + ".png"); print("W1_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261027)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/w1"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 12.5
	w.weather.set_state(0, true); w.weather.locked = true
	var cb: Cabin = w.cabins[1]
	w.player.position = cb.to_global(Vector3(2.0, Cabin.FLOOR_LOCAL_Y + 1.7, 1.8))
	w.rifle_up = false; w.hud.visible = false
	var c := Camera3D.new(); c.fov = 70; c.near = 0.02; root.add_child(c); c.make_current()
	var F := Cabin.FLOOR_LOCAL_Y
	c.global_position = cb.to_global(Vector3(1.8, F + 1.65, 1.9)); c.look_at(cb.to_global(Vector3(-1.5, F + 0.6, -1.2)), Vector3.UP)
	await shot("room_day")
	c.global_position = cb.to_global(Vector3(-0.3, F + 1.6, 1.4)); c.look_at(cb.to_global(Vector3(-0.8, F, 0.2)), Vector3.UP)
	await shot("floor_close")
	c.global_position = cb.to_global(Vector3(-0.5, F + 1.5, 0.5)); c.look_at(cb.to_global(Vector3(-2.8, F + 1.3, 0.2)), Vector3.UP)
	await shot("wall_logs")
	w.clock.hour = 22.5; cb.fire.set_fuel(3600.0 * 3.0); cb.refresh_fire()
	c.global_position = cb.to_global(Vector3(1.8, F + 1.65, 1.9)); c.look_at(cb.to_global(Vector3(-1.5, F + 0.6, -1.2)), Vector3.UP)
	await shot("room_night_stove")
	w.clock.hour = 12.5
	c.global_position = cb.to_global(Vector3(7.0, 2.5, 9.0)); c.look_at(cb.global_position + Vector3(0, 1.5, 0), Vector3.UP)
	await shot("cabin_outside")
	if not w.huts.is_empty():
		var hu: Node3D = w.huts[0]
		w.player.position = hu.to_global(Vector3(0, 1.7, 0.5))
		c.global_position = hu.to_global(Vector3(0.6, 1.65, 1.0)); c.look_at(hu.to_global(Vector3(-0.8, 0.3, -1.0)), Vector3.UP)
		await shot("hut_inside")
		c.global_position = hu.to_global(Vector3(4.0, 2.2, 6.0)); c.look_at(hu.global_position + Vector3(0, 1.2, 0), Vector3.UP)
		await shot("hut_outside")
	quit(0)
