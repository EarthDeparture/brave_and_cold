extends SceneTree

var failures := 0
var frozen_events := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var temperature = root.get_node("Temperature")
	temperature.set_process(false)
	temperature.frozen_changed.connect(func(_frozen): frozen_events += 1)
	temperature.is_outdoors = false
	temperature.advance(10.0)
	_check(is_equal_approx(temperature.current_temperature, 97.5), "indoor daytime drain")
	temperature.is_outdoors = true
	temperature.advance(10.0)
	_check(is_equal_approx(temperature.current_temperature, 92.5), "outdoor drain doubles")
	temperature.cycle_time = 120.0
	temperature.advance(10.0)
	_check(is_equal_approx(temperature.current_temperature, 82.5), "night and outdoor multipliers stack")
	temperature.cycle_time = 119.0
	temperature.advance(2.0)
	_check(is_equal_approx(temperature.current_temperature, 81.0), "frame crossing night boundary splits drain")
	temperature.advance(-1.0)
	_check(is_equal_approx(temperature.current_temperature, 81.0), "negative delta ignored")
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player._update_temperature_exposure()
	_check(not temperature.is_outdoors, "cottage spawn sheltered")
	player.position.x = 8.0
	player._update_temperature_exposure()
	_check(temperature.is_outdoors, "outside cottage exposed")
	player.position.x = 0.0
	player._update_temperature_exposure()
	_check(not temperature.is_outdoors, "returning to cottage restores shelter")
	temperature.current_temperature = 0.1
	temperature.advance(10.0)
	temperature.advance(10.0)
	_check(temperature.current_temperature == 0.0 and temperature.is_frozen, "drain clamps at zero")
	_check(frozen_events == 1, "frozen transition emitted once")
	_check("FREEZING" in world.get_node("HUD/TemperatureLabel").text, "HUD shows penalty")
	Input.action_press("move_right")
	Input.action_press("sprint")
	player._physics_process(0.1)
	_check(is_equal_approx(player.velocity.x, player.move_speed * 0.5), "frozen sprint restricted to half walking speed")
	Input.action_release("move_right")
	Input.action_release("sprint")
	temperature.current_temperature = 1000.0
	_check(temperature.current_temperature == 100.0 and not temperature.is_frozen, "restoring warmth clears penalty and clamps maximum")
	_check(not "FREEZING" in world.get_node("HUD/TemperatureLabel").text, "HUD clears penalty")
	world.free()
	print("Temperature tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
