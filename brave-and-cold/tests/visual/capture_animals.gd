extends SceneTree
## X1 review: wolf, deer and bear models side and three-quarter front in open snow by day, plus all three together
## at 25 m (the distance you usually see them). AI paused. -> res://shots/x1/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(c: Camera3D, id: String) -> void:
	c.make_current()
	await frames(20)
	c.make_current()
	await frames(5)
	root.get_texture().get_image().save_png("res://shots/x1/" + id + ".png"); print("X1_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261028)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/x1"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 11.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.hud.visible = false; w.rifle_up = false
	var cb: Cabin = w.cabins[1]
	var base := cb.to_global(Vector3(0.0, 0.0, Cabin.HZ + 12.0))
	w.player.place(base.x + 30.0, base.z + 30.0)
	var spots := {"wolf": cb.to_global(Vector3(0, 0, Cabin.HZ + 16.0)), "deer": cb.to_global(Vector3(0, 0, Cabin.HZ + 22.0)), "bear": cb.to_global(Vector3(0, 0, Cabin.HZ + 29.0))}
	var nodes := {}
	for k: String in spots:
		var p: Vector3 = spots[k]
		p.y = w._ground(p.x, p.z).y
		var n: Node3D
		if k == "deer": n = w._add_deer(p, 970)
		else: n = w._add_wolf(p, 971 if k == "wolf" else 972, k == "bear")
		n.set_process(false); n.global_position = p; n.rotation.y = cb.rotation.y + PI * 0.5
		nodes[k] = n
	var c := Camera3D.new(); c.fov = 32; root.add_child(c)
	for k: String in nodes:
		var n: Node3D = nodes[k]
		var p := n.global_position
		var hgt := 1.0 if k == "deer" else (1.0 if k == "bear" else 0.6)
		var dist := 4.5 if k == "wolf" else (5.5 if k == "deer" else 7.0)
		var fwd := -n.global_basis.z
		var side := n.global_basis.x
		c.global_position = p + side * dist + Vector3(0, hgt * 0.9, 0); c.look_at(p + Vector3(0, hgt * 0.75, 0), Vector3.UP)
		await shot(c, k + "_side")
		c.global_position = p + (fwd * 0.8 + side * 0.6).normalized() * dist + Vector3(0, hgt * 0.9, 0); c.look_at(p + Vector3(0, hgt * 0.75, 0), Vector3.UP)
		await shot(c, k + "_front")
	for k: String in ["wolf", "deer"]:   # X2: mid-stride, knees folding
		var n: Node3D = nodes[k]
		n.speed_now = 6.0 if k == "wolf" else 7.0
		for i in 7: n._animate(1.0 / 60.0)
		var p := n.global_position
		var hgt := 1.0 if k == "deer" else 0.6
		c.global_position = p + n.global_basis.x * (4.5 if k == "wolf" else 5.5) + Vector3(0, hgt * 0.9, 0); c.look_at(p + Vector3(0, hgt * 0.75, 0), Vector3.UP)
		await shot(c, k + "_stride_a")
		for i in 9: n._animate(1.0 / 60.0)
		await shot(c, k + "_stride_b")
		n.speed_now = 0.0
	var mid: Vector3 = nodes["deer"].global_position
	c.fov = 50
	c.global_position = mid + cb.global_basis.x * 25.0 + Vector3(0, 1.7, 0); c.look_at(mid + Vector3(0, 0.8, 0), Vector3.UP)
	await shot(c, "all_25m")
	quit(0)
