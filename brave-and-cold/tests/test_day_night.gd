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
	zombie.global_position = window.global_position + Vector3(-50, 0, 0)
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
	clock.day_count = 1
	var spawner = world.get_node("ZombieSpawner")
	_check(spawner.runner_chance() == 0.0, "first night only walkers")
	spawner._advance(15.0, false)
	_check(get_nodes_in_group("zombies").size() == 1, "day spawn interval not reached")
	spawner._advance(15.0, false)
	_check(get_nodes_in_group("zombies").size() == 1, "daylight does not spawn zombies")
	spawner._advance(15.0, true)
	_check(get_nodes_in_group("zombies").size() == 2, "first night spawns every 15 seconds")
	_check(spawner.get_child(0).move_speed == 2.0, "first-night walker speed unchanged")
	clock.day_count = 2
	_check(is_equal_approx(spawner.runner_chance(), 0.15), "runners unlock on second night")
	spawner._advance(7.5, true)
	_check(get_nodes_in_group("zombies").size() == 3, "second night doubles first-night frequency")
	clock.day_count = 3
	spawner._advance(10.0, true)
	_check(get_nodes_in_group("zombies").size() == 5, "large night step spawns multiple at day-three rate")
	spawner._advance(-1.0, true)
	spawner._advance(INF, true)
	_check(spawner.spawn_progress == 0.0, "invalid time ignored")
	spawner._advance(2.0, true)
	clock.dawn.emit()
	_check(spawner.spawn_progress == 0.0, "dawn clears partial progress")
	spawner._advance(4.0, true)
	spawner._advance(1000.0, false)
	_check(spawner.spawn_progress == 0.0 and get_nodes_in_group("zombies").size() == 5, "daylight clears progress without spawning")
	spawner._advance(1000.0, true)
	_check(get_nodes_in_group("zombies").size() == 12, "spawn count capped including initial zombie")
	for spawned in spawner.get_children():
		_check(is_equal_approx(Vector2(spawned.position.x, spawned.position.z).length(), 30.0), "spawn on exterior ring")
	spawner.get_child(0).free()
	spawner._advance(4.0, true)
	_check(get_nodes_in_group("zombies").size() == 11, "cap discards backlog")
	spawner._advance(1.0, true)
	_check(get_nodes_in_group("zombies").size() == 12, "spawn resumes after population drops")
	clock.day_count = 100
	_check(is_equal_approx(spawner.runner_chance(), 0.6), "runner chance capped on late nights")
	var runner = load("res://scenes/zombie.tscn").instantiate()
	runner.zombie_type = runner.ZombieType.RUNNER
	world.add_child(runner)
	runner.set_physics_process(false)
	_check(runner.move_speed == 3.0, "runner moves faster than walker")
	_check(runner.get_node("MeshInstance3D").material_override != zombie.get_node("MeshInstance3D").material_override, "runner has independent visual material")
	runner.free()
	world.free()
	paused = false
	spawner = load("res://scripts/zombie_spawner.gd").new()
	root.add_child(spawner)
	spawner.max_zombies = 100
	spawner._reset_progress()
	clock.day_count = 1
	clock.cycle_time = 0.0
	clock.advance(480.0)
	_check(spawner.get_child_count() == 24, "two full cycles spawn eight then sixteen zombies")
	_check(clock.day_count == 3 and spawner.spawn_progress == 0.0, "large step ends at third dawn with no backlog")
	spawner.free()
	clock.advance(1.0)
	_check(get_nodes_in_group("zombies").is_empty(), "scene cleanup disconnects spawner")
	print("DayNight tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
