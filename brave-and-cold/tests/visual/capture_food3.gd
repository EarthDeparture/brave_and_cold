extends SceneTree
## Plan A6 review -> res://shots/food3/: four deer carcasses at fresh / half / stripped / bones, and a wolf standing
## over its kill facing you (defending).
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(10)
	root.get_texture().get_image().save_png("res://shots/food3/" + id + ".png"); print("FOOD3_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261025)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/food3"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.rifle_up = false; w.hud.visible = false
	if w.world_events != null: w.world_events.enabled = false
	w.ambient_life.voices_enabled = false
	w.ambient_life.set_process(false)
	for x in w.deer.duplicate(): w.deer.erase(x); x.queue_free()
	for x in w.wolves.duplicate(): w.wolves.erase(x); x.queue_free()
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var side := Vector3(-od.z, 0, od.x)
	var base: Vector3 = lk.global_position + od * 55.0
	w.player.place(base.x - od.x * 8.0, base.z - od.z * 8.0)
	await frames(5)
	var stages := [[0.0, false, false], [3.0, false, false], [0.0, true, false], [0.0, true, true]]
	for i in 4:
		var p: Vector3 = base + side * (float(i) - 1.5) * 2.6
		p.y = w._ground_y(p.x, p.z)
		var d: Deer = w._add_deer(p, 950 + i)
		d.set_process(false); d.hp = 0.0; d._die()
		d.set_meta("scavenged", stages[i][0])
		var done := {}
		if stages[i][1]: done["meat"] = true
		if stages[i][2]: done["hide"] = true
		d.set_meta("done", done)
	await create_timer(1.5).timeout
	var c := Camera3D.new(); c.fov = 55; c.near = 0.05; root.add_child(c); c.make_current()
	var ground: float = w._ground_y(base.x, base.z)
	c.global_position = base - od * 5.5 + Vector3(0, ground - base.y + 2.4, 0); c.look_at(base + Vector3(0, ground - base.y, 0), Vector3.UP)
	await shot("carcass_stages")
	c.global_position = base - od * 2.6 + side * 3.9 + Vector3(0, ground - base.y + 1.3, 0); c.look_at(base + side * 3.9 + Vector3(0, ground - base.y, 0), Vector3.UP)
	await shot("carcass_bones_close")
	# a wolf over a fresh kill, facing you at 22 m
	var kp: Vector3 = base + od * 25.0; kp.y = w._ground_y(kp.x, kp.z)
	var dk: Deer = w._add_deer(kp, 960)
	dk.set_process(false); dk.hp = 0.0; dk._die(); dk.set_meta("scavenged", 1.0)
	var wf: Wolf = w._add_wolf(kp + side * 1.2, 961, false)
	wf._carcass = dk; wf._set_state(Wolf.State.INVESTIGATE)
	var pp: Vector3 = kp - od * 22.0
	w.player.place(pp.x, pp.z)
	await create_timer(3.0).timeout
	print("FOOD3 wolf defending=", wf.defending, " growls=", wf.growls)
	c.fov = 40
	c.global_position = Vector3(pp.x, w._ground_y(pp.x, pp.z) + 1.7, pp.z); c.look_at(kp + Vector3(0, 0.6, 0), Vector3.UP)
	await shot("wolf_defends")
	quit(0)
