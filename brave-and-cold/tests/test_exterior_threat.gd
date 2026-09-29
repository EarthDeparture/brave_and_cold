extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("DayNight").set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var initial = world.get_node("Zombie")
	initial.set_physics_process(false)
	for frame in range(5):
		await physics_frame
	initial._update_target(0.0)
	_check(initial.target_player == null, "sheltered player is not pursued")
	# Gathering is audible beyond the daytime sight radius.
	initial.position = Vector3(20, 0.1, 7)
	world.get_node("Deadfall").interact(player)
	initial._update_target(0.0)
	_check(initial.noise_remaining > 0.0 and initial.agent.target_position == world.get_node("Deadfall").global_position, "gathering attracts zombie beyond sight range")
	# Cottage walls block sight even when both actors are outdoors.
	initial.position = Vector3(6, 0.1, 0)
	player.position = Vector3(-6, 0.1, 0)
	for frame in range(2):
		await physics_frame
	initial._update_target(0.0)
	_check(initial.target_player == null, "walls block outdoor player detection")
	var spawner = world.get_node("ZombieSpawner")
	spawner._advance(15.0, true)
	_check(spawner.get_child_count() == 1, "night creates an exterior threat")
	var zombie = spawner.get_child(0)
	zombie.set_physics_process(false)
	player.position = zombie.position * 0.85
	player.position.y = 0.1
	for frame in range(2):
		await physics_frame
	zombie._update_target(0.0)
	_check(zombie.target_player == player, "spawned zombie detects stationary outdoor player")
	player.position += Vector3(0, 0, 1)
	for frame in range(2):
		await physics_frame
	zombie._update_target(0.0)
	_check(zombie.agent.target_position == player.global_position, "pursuit tracks current player position")
	zombie.set_physics_process(true)
	for frame in range(360):
		await physics_frame
		if player.is_dead:
			break
	_check(player.is_dead and world.finished and paused, "spawned zombie navigates to player and triggers game over on contact")
	paused = false
	world.free()
	print("Exterior threat tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
