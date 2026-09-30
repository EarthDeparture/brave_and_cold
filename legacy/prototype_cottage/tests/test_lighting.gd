extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock = root.get_node("DayNight")
	clock.set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var fire = world.get_node("Cottage/Fireplace")
	fire.set_process(false)
	var light = fire.get_node("Light")
	var sun = world.get_node("Sun")
	var environment = world.get_node("WorldEnvironment").environment
	var player = world.get_node("Player")
	player.wood = 3
	_check(sun.visible and environment.background_energy_multiplier == 1.0, "initial daylight")
	_check(not light.visible and light.light_energy == 0.0 and light.omni_range == 0.0, "initial fire out")
	fire.interact(player)
	_check(light.visible and light.light_energy == 2.5 and light.omni_range == 6.0, "daytime ignition")
	clock.advance(120.0)
	_check(not sun.visible and is_equal_approx(environment.ambient_light_energy, 0.02) and is_equal_approx(environment.background_energy_multiplier, 0.05), "dusk darkens world")
	_check(light.visible and light.light_energy == 2.5, "dusk preserves fire")
	fire.advance(15.0)
	_check(light.visible and light.light_energy == 1.0 and light.omni_range == 3.0, "dying fire dims")
	fire.advance(5.0)
	_check(not light.visible and light.light_energy == 0.0 and light.omni_range == 0.0, "burnout clears light")
	fire.interact(player)
	_check(light.visible and light.light_energy == 2.5, "nighttime relighting")
	clock.advance(120.0)
	_check(sun.visible and is_equal_approx(environment.ambient_light_energy, 0.12) and environment.background_energy_multiplier == 1.0, "dawn restores daylight")
	_check(light.visible and light.light_energy == 2.5, "dawn preserves fire")
	clock.advance(480.0)
	_check(sun.visible, "multiple cycles end in daylight")
	world.free()
	paused = false
	clock.cycle_time = 120.0
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	_check(not world.get_node("Sun").visible, "world loaded at night initializes dark")
	world.free()
	paused = false
	clock.advance(120.0)
	print("Lighting tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
