extends SceneTree
## Debug: are the DriftFeatures emitters visible at all? A bomb 6 m in front against trees, a plume emitter 40 m
## ahead, a roof emitter on a box, all in clear view. -> res://shots/drift2/dbg_*.png
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720); SaveGame.pending = {}
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.drift_features != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.hud.visible = false
	var df: DriftFeatures = w.drift_features
	df.force_wind = 16.0
	var wd2: Vector2 = w.weather.wind_dir.normalized()
	var wd := Vector3(wd2.x, 0, wd2.y)
	var side := Vector3(-wd.z, 0, wd.x)
	var c := Camera3D.new(); c.fov = 62; root.add_child(c); c.make_current()
	var eye: Vector3 = w.player.global_position
	c.global_position = eye; c.look_at(eye + side * 10.0 + Vector3(0, 2, 0), Vector3.UP)
	var e: GPUParticles3D = df._plumes[0]
	df.set_process(false)
	e.global_position = eye + side * 40.0 + Vector3(0, 1, 0)
	df._aim(e, wd2, 16.0, 0.55, 1.8)
	e.emitting = true
	var b: GPUParticles3D = df._bombs[0]
	b.global_position = eye + side * 8.0 + Vector3(0, 7, 0)
	df._aim(b, wd2, 14.0, 0.25, -0.5)
	b.restart(); b.emitting = true
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("res://shots/drift2/dbg_bomb.png")
	await create_timer(5.0).timeout
	root.get_texture().get_image().save_png("res://shots/drift2/dbg_plume.png")
	print("DBG plume emitting=", e.emitting, " pos=", e.global_position, " amount=", e.amount, " mat=", (e.draw_pass_1 as QuadMesh).material)
	quit(0)
