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
	_check(player.velocity == Vector2.ZERO and stamina.current_stamina == 100.0, "idle sprint does not drain")
	Input.action_release("sprint")
	Input.action_press("move_right")
	var start: Vector2 = player.position
	player._physics_process(0.1)
	_check(player.velocity == Vector2(player.move_speed, 0) and player.position.x > start.x, "walking moves right")
	_check(stamina.current_stamina == 100.0, "walking does not drain")
	Input.action_press("move_down")
	player._physics_process(0.1)
	_check(is_equal_approx(player.velocity.length(), player.move_speed), "diagonal speed is normalized")
	Input.action_press("sprint")
	player._physics_process(0.1)
	_check(is_equal_approx(player.velocity.length(), player.sprint_speed), "sprint increases speed")
	_check(is_equal_approx(stamina.current_stamina, 98.0), "sprint drains rate times delta")
	player._physics_process(0.05)
	_check(is_equal_approx(stamina.current_stamina, 97.0), "drain scales with physics delta")
	stamina.current_stamina = 0.0
	player._physics_process(0.1)
	_check(is_equal_approx(player.velocity.length(), player.move_speed), "exhausted player walks")
	_check(stamina.current_stamina == 0.0, "exhausted sprint does not overdraw")
	for action in ["move_right", "move_down", "sprint"]:
		Input.action_release(action)
	player._physics_process(0.1)
	_check(player.velocity == Vector2.ZERO, "release stops movement")
	player.free()
	print("Player tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
