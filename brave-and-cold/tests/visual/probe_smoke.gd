extends SceneTree
## Debug: how high does the CabinFire smoke column actually get (GPU particle AABB over time)?
var w: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(800, 450); SaveGame.pending = {}
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.world_events != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.day = 5; w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.world_events.enabled = false
	var now: float = w.clock.total_game_s
	w.world_events.start_fire(3, now - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.55)
	var cf: CabinFire = w.cabins[3].on_fire
	var pm: ParticleProcessMaterial = cf._smoke.process_material
	print("SMOKE amount=", cf._smoke.amount, " ratio=", cf._smoke.amount_ratio, " life=", cf._smoke.lifetime, " v=", pm.initial_velocity_min, "-", pm.initial_velocity_max, " g=", pm.gravity, " damp=", pm.damping_min, " scale=", pm.scale_min, " emitting=", cf._smoke.emitting)
	for k in 5:
		await create_timer(10.0).timeout
		print("SMOKE t=", (k + 1) * 10, " aabb=", cf._smoke.capture_aabb(), " ratio=", cf._smoke.amount_ratio, " emitting=", cf._smoke.emitting)
	quit(0)
