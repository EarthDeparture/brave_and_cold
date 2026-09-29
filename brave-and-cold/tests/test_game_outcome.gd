extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _world():
	paused = false
	root.get_node("DayNight").cycle_time = 0.0
	root.get_node("DayNight").day_count = 1
	root.get_node("Temperature").current_temperature = 100.0
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	return world


func _run() -> void:
	var clock = root.get_node("DayNight")
	var temperature = root.get_node("Temperature")
	clock.set_process(false)
	temperature.drain_rate = 0.0
	var world = _world()
	world.nights_to_survive = 2
	_check(not world.finished and not world.get_node("EndScreen").visible, "starts playing")
	clock.advance(120.0)
	_check(world.nights_survived == 0, "dusk does not count")
	clock.advance(120.0)
	_check(world.nights_survived == 1 and not world.finished, "first dawn counts one night")
	clock.advance(1000.0)
	_check(world.finished and paused and clock.day_count == 3, "wins at target and stops large clock step")
	_check("YOU WIN" in world.result_label.text and world.get_node("EndScreen").visible, "win UI visible")
	world.get_node("Player").die("late hit")
	_check("YOU WIN" in world.result_label.text, "result cannot be overwritten")
	world.free()
	world = _world()
	temperature.current_temperature = 0.0
	_check(world.get_node("Player").is_dead and paused, "freezing is fatal")
	_check("GAME OVER" in world.result_label.text and "froze" in world.result_label.text, "freeze reason visible")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "end releases cursor")
	temperature.current_temperature = 100.0
	world._on_dawn()
	_check(world.nights_survived == 0 and "GAME OVER" in world.result_label.text, "death is permanent")
	world.free()
	world = _world()
	world.nights_to_survive = 1
	temperature.drain_rate = 1.0
	clock.cycle_time = 239.0
	temperature.current_temperature = 0.1
	clock.advance(1.0)
	_check("GAME OVER" in world.result_label.text, "fatal cold on final dawn takes precedence")
	world.free()
	world = _world()
	temperature.drain_rate = 0.0
	var player = world.get_node("Player")
	var zombie = world.get_node("Zombie")
	player.position = Vector3(20, 0.1, 20)
	zombie.position = Vector3(21.2, 0.1, 20)
	Input.action_press("move_right")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_right")
	_check(player.is_dead and paused and "zombie" in world.result_label.text, "physical zombie contact kills")
	world.free()
	paused = false
	print("Game outcome tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
