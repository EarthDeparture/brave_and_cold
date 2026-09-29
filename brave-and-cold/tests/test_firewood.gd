extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var temperature = root.get_node("Temperature")
	temperature.set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var source = world.get_node("Deadfall")
	var fire = world.get_node("Cottage/Fireplace")
	fire.set_process(false)
	fire.interact(player)
	_check(fire.fuel_remaining == 0.0 and not fire.get_node("Flame").visible, "empty inventory cannot light fire")
	# Exercise the same raycast used by E, including its distance limit.
	player.position = Vector3(2, 0, 11)
	player.camera.look_at(source.global_position)
	await physics_frame
	await physics_frame
	player._interact()
	_check(player.wood == 0, "distant gathering rejected")
	player.position = Vector3(2, 0, 9)
	player.camera.look_at(source.global_position)
	await physics_frame
	await physics_frame
	# A solid object in the sightline must prevent gathering through it.
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 3, 0.2)
	collision.shape = shape
	blocker.add_child(collision)
	world.add_child(blocker)
	blocker.position = Vector3(2, 1.5, 8)
	await physics_frame
	await physics_frame
	player._interact()
	_check(player.wood == 0 and source.wood_remaining == 5, "obstructed gathering rejected")
	blocker.free()
	await physics_frame
	await physics_frame
	var gather := InputEventKey.new()
	gather.physical_keycode = KEY_E
	gather.keycode = KEY_E
	gather.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player._unhandled_input(gather)
	_check(player.wood == 0, "released mouse prevents gathering")
	_check(gather.is_action_pressed("interact"), "physical E is mapped to interaction")
	# Headless DisplayServer cannot capture the mouse; exercise the ray directly.
	player._interact()
	_check(player.wood == 1 and source.wood_remaining == 4, "aimed gathering yields wood")
	_check(source.get_node("Prompt").text == "E: Gather wood (4)", "prompt reflects remaining stock")
	for index in range(6):
		source.interact(player)
	_check(player.wood == 5 and source.wood_remaining == 0, "source finite and cannot duplicate wood")
	_check(world.get_node("HUD/WoodLabel").text.begins_with("Wood: 5"), "inventory HUD updates")
	_check(source.get_node("Prompt").text == "No wood remaining", "depleted prompt is explicit")
	var second_source = world.get_node("Deadfall2")
	_check(second_source.wood_remaining == 5, "deadfalls have independent stock")
	player.position = Vector3(-3, 0, 11)
	player.camera.look_at(second_source.global_position)
	await physics_frame
	await physics_frame
	player._interact()
	_check(player.wood == 6 and second_source.wood_remaining == 4, "second outdoor source is reachable by interaction")
	player.position = Vector3(0, 0, -2)
	player.camera.look_at(fire.global_position)
	await physics_frame
	await physics_frame
	player._interact()
	_check(player.wood == 5 and fire.fuel_remaining == 20.0, "aimed fueling consumes one wood")
	fire.interact(player)
	_check(player.wood == 4 and fire.fuel_remaining == 40.0, "refueling extends burn")
	temperature.current_temperature = 0.0
	fire.advance(2.0)
	_check(temperature.current_temperature == 10.0 and not temperature.is_frozen, "nearby heat restores warmth and clears freezing")
	player.position = Vector3(0, 0, 4)
	fire.advance(2.0)
	_check(temperature.current_temperature == 10.0 and fire.fuel_remaining == 36.0, "distant player receives no heat while wood burns")
	player.position = Vector3(0, 0, -2)
	fire.fuel_remaining = 1.0
	fire.advance(10.0)
	_check(temperature.current_temperature == 15.0, "partial final frame heats only for remaining fuel")
	_check(fire.fuel_remaining == 0.0 and not fire.get_node("Flame").visible and not fire.get_node("Light").visible, "burnout extinguishes visuals")
	fire.advance(10.0)
	_check(temperature.current_temperature == 15.0, "extinguished fire provides no heat")
	fire.interact(player)
	fire.advance(-1.0)
	_check(fire.fuel_remaining == 20.0, "negative delta ignored")
	temperature.current_temperature = 99.0
	fire.advance(1.0)
	_check(temperature.current_temperature == 100.0, "heat clamps at maximum warmth")
	world.free()
	print("Firewood tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
