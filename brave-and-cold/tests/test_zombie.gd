extends SceneTree

var failures := 0
var heard_radii: Array[float] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var zombie = world.get_node("Zombie")
	zombie.set_physics_process(false)
	var left = world.get_node("Cottage/LeftWindow")
	var right = world.get_node("Cottage/RightWindow")
	var noise = root.get_node("NoiseEvents")
	for frame in range(5):
		await physics_frame
	zombie._update_target(0.0)
	_check(zombie.target_window == left, "select unboarded window")
	left.boarded = true
	zombie._update_target(0.0)
	_check(not zombie.has_target, "all boarded means idle")
	right.boarded = false
	zombie._update_target(0.0)
	_check(zombie.target_window == right, "boarding retargets")
	noise.emit_noise(Vector3(100, 0, 100), 1.0)
	_check(zombie.noise_remaining == 0.0, "ignore distant noise")
	var destination: Vector3 = zombie.global_position + Vector3(1, 0, 0)
	noise.emit_noise(destination, 8.0)
	zombie._update_target(0.0)
	_check(zombie.has_target and zombie.target_window == null, "noise overrides light")
	_check(zombie.agent.target_position == destination, "investigate noise location")
	zombie._update_target(zombie.noise_memory + 0.1)
	_check(zombie.target_window == right, "expired noise returns to light")
	right.free()
	zombie._update_target(0.0)
	_check(not zombie.has_target, "freed window is safe")
	left.boarded = false
	zombie._update_target(0.0)
	var path = NavigationServer3D.map_get_path(zombie.agent.get_navigation_map(), zombie.global_position, left.global_position, true)
	_check(path.size() >= 3, "navigation routes around cottage")
	zombie.set_physics_process(true)
	var start: Vector3 = zombie.global_position
	for frame in range(1200):
		await physics_frame
	_check(zombie.global_position.distance_to(start) > 8.0, "zombie follows route")
	_check(zombie.global_position.distance_to(left.global_position) < 2.5, "zombie reaches exterior window")
	_check(left.broken, "zombie breaks window after navigating to it")
	left.boarded = true
	await physics_frame
	await physics_frame
	_check(Vector2(zombie.velocity.x, zombie.velocity.z).length() < 0.01, "boarding stops movement")
	zombie.set_physics_process(false)
	noise.emitted.connect(func(_position: Vector3, radius: float): heard_radii.append(radius))
	player.position = Vector3(20, 0.1, 20)
	player.set_physics_process(true)
	for frame in range(20):
		await physics_frame
	_check(heard_radii.is_empty(), "stationary player is silent")
	Input.action_press("move_up")
	for frame in range(40):
		await physics_frame
	_check(heard_radii.has(8.0), "walking emits footsteps")
	Input.action_press("sprint")
	for frame in range(40):
		await physics_frame
	_check(heard_radii.has(18.0), "sprinting emits louder footsteps")
	Input.action_release("move_up")
	Input.action_release("sprint")
	world.free()
	print("Zombie tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
