extends SceneTree

var failures := 0
var events: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock = root.get_node("DayNight")
	clock.set_process(false)
	clock.dusk.connect(func(): events.append("dusk"))
	clock.dawn.connect(func(): events.append("dawn"))
	var temperature = root.get_node("Temperature")
	temperature.is_outdoors = false
	_check(not clock.is_night and clock.time_of_day == 0.0, "starts at dawn")
	clock.advance(119.0)
	_check(events.is_empty(), "no early dusk")
	temperature.current_temperature = 100.0
	clock.advance(2.0)
	_check(events == ["dusk"] and clock.is_night, "cross dusk exactly once")
	_check(is_equal_approx(temperature.current_temperature, 99.25), "temperature shares boundary and drain")
	clock.advance(119.0)
	_check(events == ["dusk", "dawn"] and not clock.is_night, "wrap at dawn")
	events.clear()
	clock.advance(480.0)
	_check(events == ["dusk", "dawn", "dusk", "dawn"], "large step preserves transitions")
	clock.advance(-1.0)
	clock.advance(0.0)
	_check(clock.cycle_time == 0.0 and events.size() == 4, "nonpositive steps ignored")
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.get_node("Player").set_physics_process(false)
	var zombie = world.get_node("Zombie")
	zombie.set_physics_process(false)
	var window = world.get_node("Cottage/LeftWindow")
	zombie.global_position = window.global_position + Vector3(50, 0, 0)
	zombie._update_target(0.0)
	_check(not zombie.has_target, "daylight limits light detection")
	zombie._hear_noise(zombie.global_position + Vector3(12, 0, 0), 10.0)
	_check(zombie.noise_remaining == 0.0, "daylight limits hearing")
	clock.cycle_time = 120.0
	zombie._update_target(0.0)
	_check(zombie.target_window == window, "night expands light detection")
	zombie._hear_noise(zombie.global_position + Vector3(12, 0, 0), 10.0)
	_check(zombie.noise_remaining > 0.0, "night expands hearing")
	clock.cycle_time = 0.0
	zombie.noise_remaining = 0.0
	zombie._update_target(0.0)
	_check(not zombie.has_target, "dawn restores detection range")
	var spawner = world.get_node("ZombieSpawner")
	spawner._advance(15.0, false)
	_check(get_nodes_in_group("zombies").size() == 1, "day spawn interval not reached")
	spawner._advance(15.0, false)
	_check(get_nodes_in_group("zombies").size() == 2, "day spawns every 30 seconds")
	spawner._advance(15.0, true)
	_check(get_nodes_in_group("zombies").size() == 3, "night doubles spawn rate")
	spawner._advance(1000.0, true)
	_check(get_nodes_in_group("zombies").size() == 12, "spawn count capped including initial zombie")
	for spawned in spawner.get_children():
		_check(is_equal_approx(Vector2(spawned.position.x, spawned.position.z).length(), 30.0), "spawn on exterior ring")
	world.free()
	clock.advance(1.0)
	_check(get_nodes_in_group("zombies").is_empty(), "scene cleanup disconnects spawner")
	print("DayNight tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
