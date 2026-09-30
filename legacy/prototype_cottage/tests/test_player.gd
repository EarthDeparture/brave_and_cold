extends SceneTree
## godot --headless --path brave-and-cold --script res://tests/test_player.gd

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stamina = root.get_node("Stamina")
	stamina.set_process(false)
	var player = load("res://scenes/player.tscn").instantiate()
	player.set_physics_process(false)
	root.add_child(player)
	stamina.current_stamina = 100.0
	Input.action_press("sprint")
	player._physics_process(0.1)
	_check(Vector2(player.velocity.x, player.velocity.z) == Vector2.ZERO and stamina.current_stamina == 100.0, "idle sprint does not drain")
	Input.action_release("sprint")
	Input.action_press("move_right")
	var start: Vector3 = player.position
	player._physics_process(0.1)
	_check(is_equal_approx(player.velocity.x, player.move_speed) and player.position.x > start.x, "walking moves right")
	_check(stamina.current_stamina == 100.0, "walking does not drain")
	Input.action_press("move_down")
	player._physics_process(0.1)
	_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed), "diagonal speed is normalized")
	Input.action_press("sprint")
	player._physics_process(0.1)
	_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.sprint_speed), "sprint increases speed")
	_check(is_equal_approx(stamina.current_stamina, 98.0), "sprint drains rate times delta")
	player._physics_process(0.05)
	_check(is_equal_approx(stamina.current_stamina, 97.0), "drain scales with physics delta")
	stamina.current_stamina = 0.0
	player._physics_process(0.1)
	_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed), "exhausted player walks")
	_check(stamina.current_stamina == 0.0, "exhausted sprint does not overdraw")
	for action in ["move_right", "move_down", "sprint"]:
		Input.action_release(action)
	player._physics_process(0.1)
	_check(Vector2(player.velocity.x, player.velocity.z) == Vector2.ZERO, "release stops movement")
	player.rotation.y = PI / 2.0
	Input.action_press("move_up")
	player._physics_process(0.1)
	_check(is_equal_approx(player.velocity.x, -player.move_speed), "movement follows yaw")
	Input.action_release("move_up")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 100000)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player._unhandled_input(motion)
	_check(player.camera.rotation.x > -PI / 2.0, "pitch is clamped")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	player._unhandled_input(escape)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "escape releases mouse")
	player.free()
	var world = load("res://scenes/main.tscn").instantiate()
	# Start below the cottage ceiling, with room for the player capsule.
	world.get_node("Player").position.y = 1.5
	root.add_child(world)
	for frame in range(60):
		await physics_frame
	var world_player = world.get_node("Player")
	_check(world_player.position.y < 0.2, "gravity brings player to ground")
	_check(world_player.is_on_floor(), "world ground supports player")
	_check(world_player.camera.current, "first person camera is active")
	_check(world.has_node("HUD"), "world retains HUD")
	world.free()
	print("Player tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
