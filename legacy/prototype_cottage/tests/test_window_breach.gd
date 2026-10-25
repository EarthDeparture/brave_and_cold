extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	root.get_node("Temperature").drain_rate = 0.0
	var player = world.get_node("Player")
	var zombie = world.get_node("Zombie")
	var window = world.get_node("Cottage/LeftWindow")
	player.set_physics_process(false)
	zombie.set_physics_process(false)
	player.position = Vector3(-2.2, 0, -4.1)
	zombie.position = Vector3(-2.2, 0, -5.8)
	for frame in range(5):
		await physics_frame
	window.boarded = true
	zombie._attack_windows(10.0)
	_check(window.hits_taken == 0 and not player.is_dead, "boards prevent glass damage and death")
	window.boarded = false
	zombie._attack_windows(10.0)
	_check(window.hits_taken == 1 and not window.broken, "first attack damages glass")
	zombie._attack_windows(0.0)
	_check(window.hits_taken == 1, "cooldown prevents repeated immediate hits")
	for hit in range(window.hits_to_break - 1):
		zombie._attack_windows(zombie.attack_interval)
	_check(window.broken and not window.get_node("Pane").visible, "repeated attacks break glass")
	_check(not player.is_dead, "glass breaking uses its own attack")
	player.add_wood(1)
	window.interact(player)
	player._advance_work(2.0)
	zombie._attack_windows(10.0)
	_check(not window.broken and window.hits_taken == 1 and player.wood == 0 and not player.is_dead, "repair restores glass and fresh hit counter")
	for hit in range(window.hits_to_break):
		window.take_hit()
	window.interact(player)
	player._advance_work(2.0)
	_check(window.broken, "repair requires wood")
	player.position = Vector3(-2.2, 0, 0)
	await physics_frame
	zombie._attack_windows(10.0)
	_check(not player.is_dead, "distant indoor player is safe")
	player.position = Vector3(0, 0, -4.8)
	await physics_frame
	zombie._attack_windows(10.0)
	_check(not player.is_dead, "wall blocks reach to nearby player")
	player.position = Vector3(-2.2, 0, -4.1)
	zombie.position = Vector3(-2.2, 0, -10)
	await physics_frame
	zombie._attack_windows(10.0)
	_check(not player.is_dead, "distant zombie cannot attack breach")
	zombie.position = Vector3(-2.2, 0, -5.8)
	await physics_frame
	zombie._hear_noise(player.global_position, 8.0)
	zombie._update_target(0.0)
	_check(zombie.target_window == null, "noise target active during breach")
	zombie._attack_windows(10.0)
	_check(player.is_dead and world.finished and paused, "breach kills indoor player and ends game")
	world.free()
	paused = false
	print("Window breach tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
