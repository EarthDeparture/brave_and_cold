extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock = root.get_node("DayNight")
	var temperature = root.get_node("Temperature")
	clock.set_process(false)
	temperature.set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var hud = world.get_node("HUD")
	var player = world.get_node("Player")
	var warnings = hud.get_node("WarningLabel")
	_check(hud.get_node("DayLabel").text == "Day 1 — Daytime", "initial day")
	_check("LOW WOOD" in warnings.text, "initial low wood")
	player.add_wood(3)
	_check(not warnings.visible, "safe state hides warnings")
	player.consume_wood()
	_check("LOW WOOD" in warnings.text, "wood boundary")
	temperature.current_temperature = 25.0
	_check("COLD" in warnings.text and "LOW WOOD" in warnings.text, "simultaneous warnings")
	temperature.current_temperature = 0.0
	_check("FREEZING" in warnings.text and "half speed" in hud.get_node("TemperatureLabel").text, "frozen warning and existing penalty")
	temperature.current_temperature = 26.0
	_check(not "COLD" in warnings.text and not "FREEZING" in warnings.text, "recovery clears cold warning")
	clock.advance(120.0)
	_check(hud.get_node("DayLabel").text == "Day 1 — Night" and "NIGHT" in warnings.text, "dusk")
	clock.advance(120.0)
	_check(hud.get_node("DayLabel").text == "Day 2 — Daytime" and not "NIGHT" in warnings.text, "dawn")
	clock.advance(480.0)
	_check(clock.day_count == 4 and hud.get_node("DayLabel").text == "Day 4 — Daytime", "multiple days")
	world.free()
	clock.advance(120.0)
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	_check(world.get_node("HUD/DayLabel").text == "Day 4 — Night", "HUD recreation preserves clock state")
	world.free()
	print("HUD tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
