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
	world.get_node("Player").position = Vector3(0, 0.1, 7)
	world.get_node("Player")._update_temperature_exposure()
	_check(temperature.is_outdoors, "win run is outdoors")
	_check(world.nights_to_survive == 3, "default goal is three nights")
	_check(not world.finished and not world.get_node("EndScreen").visible, "starts playing")
	_check(world.nights_survived == 0, "initial dawn does not count")
	clock.advance(120.0)
	_check(world.nights_survived == 0, "dusk does not count")
	clock.advance(120.0)
	_check(world.nights_survived == 1 and not world.finished, "first dawn counts one night")
	clock.advance(240.0)
	_check(world.nights_survived == 2 and not world.finished and not paused, "second dawn keeps run active")
	_check(not world.get_node("EndScreen").visible, "intermediate dawn keeps end screen hidden")
	clock.advance(1000.0)
	_check(world.finished and paused and clock.day_count == 4 and world.nights_survived == 3, "wins at target and stops large clock step")
	_check("YOU WIN" in world.result_label.text and world.get_node("EndScreen").visible, "win UI visible")
	_check(world.result_label.text == "YOU WIN\nDawn survived!\nSurvived 3 nights.", "final dawn message shows completed goal")
	world._on_dawn()
	_check(world.nights_survived == 3, "later dawn cannot advance finished run")
	world.get_node("Player").die("late hit")
	_check("YOU WIN" in world.result_label.text, "result cannot be overwritten")
	world.free()
	world = _world()
	world.get_node("Player").position = Vector3(0, 0.1, 7)
	world.get_node("Player")._update_temperature_exposure()
	temperature.drain_rate = 1.0
	temperature.current_temperature = 1.0
	clock.advance(1.0)
	_check(temperature.is_outdoors, "fatal cold occurs outdoors")
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
	world.get_node("Player").position = Vector3(0, 0.1, 7)
	world.get_node("Player")._update_temperature_exposure()
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
	world = _world()
	current_scene = world
	var restart_key := InputEventKey.new()
	restart_key.keycode = KEY_R
	restart_key.pressed = true
	root.push_input(restart_key)
	await process_frame
	_check(current_scene == world and not world.finished, "R does not restart active play")
	clock.day_count = 4
	clock.cycle_time = 180.0
	root.get_node("Stamina").current_stamina = 0.0
	temperature.current_temperature = 0.0
	_check(paused, "frozen restart begins paused")
	root.push_input(restart_key)
	await scene_changed
	world = current_scene
	_check(not paused and not world.finished and not world.get_node("Player").is_dead, "R restarts while paused")
	_check(not world.get_node("EndScreen").visible and world.nights_survived == 0, "restart clears outcome")
	_check(clock.day_count == 1 and clock.cycle_time == 0.0, "restart resets clock")
	_check(not temperature.is_frozen and temperature.current_temperature == temperature.max_temperature, "restart restores warmth")
	_check(root.get_node("Stamina").current_stamina == root.get_node("Stamina").max_stamina, "restart restores stamina")
	world.nights_to_survive = 1
	world._on_dawn()
	_check(paused and "YOU WIN" in world.result_label.text, "restarted game can finish again")
	_check(world.result_label.text == "YOU WIN\nDawn survived!\nSurvived 1 night.", "single-night goal uses singular message")
	var restart_button = world.get_node("EndScreen").find_child("Restart", true, false)
	_check(restart_button.is_visible_in_tree() and restart_button.can_process(), "restart button available while paused")
	restart_button.pressed.emit()
	await scene_changed
	_check(not paused and not current_scene.finished, "button restarts after win")
	current_scene.free()
	paused = false
	print("Game outcome tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
