extends SceneTree
## W6 review: a wolf relaxed vs in the guarding stance (head low, braced legs, tail out stiff), side and
## three-quarter front. AI paused; _animate driven by hand. -> res://shots/w6/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(c: Camera3D, id: String) -> void:
	c.make_current()
	await frames(20)
	c.make_current()
	await frames(5)
	root.get_texture().get_image().save_png("res://shots/w6/" + id + ".png"); print("W6_CAPTURE ", id)
func pose(wf: Wolf, guard: bool) -> void:
	wf.defending = guard
	for i in 90:
		wf._animate(1.0 / 60.0)
		await process_frame
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261027)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/w6"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 12.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.hud.visible = false; w.rifle_up = false
	var cb: Cabin = w.cabins[1]
	var at := cb.to_global(Vector3(0.0, 0.0, Cabin.HZ + 9.0))
	w.player.place(at.x + 3.0, at.z + 3.0)
	at.y = w._ground(at.x, at.z).y
	var wf: Wolf = w._add_wolf(at, 962, false)
	wf.set_process(false); wf.global_position = at; wf.rotation.y = 0.0; wf.speed_now = 0.0
	var c := Camera3D.new(); c.fov = 30; root.add_child(c)
	var side := at + Vector3(4.5, 0.8, 0.0); var front := at + Vector3(2.6, 0.9, -3.6)
	await pose(wf, false)
	c.global_position = side; c.look_at(at + Vector3(0, 0.55, 0), Vector3.UP); await shot(c, "relaxed_side")
	c.global_position = front; c.look_at(at + Vector3(0, 0.55, 0), Vector3.UP); await shot(c, "relaxed_front")
	await pose(wf, true)
	c.global_position = side; c.look_at(at + Vector3(0, 0.55, 0), Vector3.UP); await shot(c, "guard_side")
	c.global_position = front; c.look_at(at + Vector3(0, 0.55, 0), Vector3.UP); await shot(c, "guard_front")
	quit(0)
