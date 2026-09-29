extends SceneTree
## godot --headless --path brave-and-cold --script res://tests/test_cottage.gd

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var cottage = world.get_node("Cottage")
	var left = cottage.get_node("LeftWindow")
	var right = cottage.get_node("RightWindow")
	_check(not left.boarded and right.boarded, "scene initializes both states")
	_check(right.get_node("Boards").visible and not right.get_node("LightBleed").visible, "initial boards block light")
	_check(not right.get_node("Pane").material_override.emission_enabled, "initial boards block emission")
	var player = world.get_node("Player")
	player.set_physics_process(false)
	left.interact(player)
	_check(not left.boarded and player.wood == 0, "empty inventory cannot board")
	_check(left.get_node("LightBleed").visible and not left.get_node("Boards").visible, "failed boarding preserves visuals")
	_check(left.get_node("Prompt").text.contains("1 wood"), "prompt displays boarding cost")
	var source = world.get_node("Deadfall")
	for index in range(3):
		source.interact(player)
	_check(player.wood == 3 and source.wood_remaining == 2, "gathered wood supplies boarding")
	for index in range(4):
		left.interact(player)
		_check(player.wood == 2 - index / 2, "only boarding spends one wood; removal gives no refund")
		_check(left.get_node("Boards").visible == left.boarded, "boards follow state")
		_check(left.get_node("LightBleed").visible != left.boarded, "light visibility follows state")
		_check((left.get_node("LightBleed").light_energy == 0.0) == left.boarded, "boarding removes light energy")
		_check(left.get_node("Pane").material_override.emission_enabled != left.boarded, "boarding blocks material emission")
		_check(right.boarded and not right.get_node("Pane").material_override.emission_enabled, "windows remain independent")
	player.position = Vector3(-2.2, 0, 0)
	await physics_frame
	await physics_frame
	player._interact()
	_check(not left.boarded and player.wood == 1, "distant interaction spends no wood")
	player.position.z = -3
	await physics_frame
	await physics_frame
	player._interact()
	_check(left.boarded and player.wood == 0, "nearby aimed interaction consumes last wood")
	_check(world.get_node("HUD/WoodLabel").text.begins_with("Wood: 0"), "boarding updates inventory HUD")
	player._interact()
	_check(not left.boarded and player.wood == 0, "removal works without wood and gives no refund")
	player._interact()
	_check(not left.boarded and player.wood == 0, "reboarding requires more wood")
	var fire = cottage.get_node("Fireplace")
	fire.interact(player)
	_check(fire.fuel_remaining == 0.0, "spent boarding wood cannot fuel fire")
	source.interact(player)
	fire.interact(player)
	left.interact(player)
	_check(not left.boarded and player.wood == 0, "spent firewood cannot board window")
	_check(cottage.has_node("Hearth") and cottage.has_node("Roof"), "shelter includes hearth and roof")
	_check(cottage.get_node("HearthLight").light_energy == 0, "unfueled hearth starts dark")
	var door = cottage.get_node("Door")
	_check(not door.is_open and not door.boarded and door.get_node("CollisionShape3D").disabled == false,
		"door starts closed and solid")
	door.interact(player)
	_check(door.is_open and door.get_node("CollisionShape3D").disabled, "interact opens the door")
	door.interact(player)
	_check(not door.is_open and not door.get_node("CollisionShape3D").disabled, "interact closes the open door")
	source.interact(player)
	door.interact(player)
	_check(not door.boarded and player.wood == 1, "boarding requires holding sprint")
	door.interact(player) # Close the door before barricading.
	Input.action_press("sprint")
	door.interact(player)
	Input.action_release("sprint")
	_check(door.boarded and player.wood == 0 and door.get_node("Boards").visible,
		"sprint+interact boards the closed door")
	door.interact(player)
	_check(not door.boarded and door.is_in_group("attracting_windows"), "door unboards and attracts zombies like a window")
	world.free()
	print("Cottage tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
