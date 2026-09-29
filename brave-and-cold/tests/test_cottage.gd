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
	for index in range(4):
		left.toggle_boarded()
		_check(left.get_node("Boards").visible == left.boarded, "boards follow state")
		_check(left.get_node("LightBleed").visible != left.boarded, "light visibility follows state")
		_check((left.get_node("LightBleed").light_energy == 0.0) == left.boarded, "boarding removes light energy")
		_check(left.get_node("Pane").material_override.emission_enabled != left.boarded, "boarding blocks material emission")
		_check(right.boarded and not right.get_node("Pane").material_override.emission_enabled, "windows remain independent")
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector3(-2.2, 0, 0)
	await physics_frame
	await physics_frame
	player._interact()
	_check(not left.boarded, "distant interaction is ignored")
	player.position.z = -3
	await physics_frame
	await physics_frame
	player._interact()
	_check(left.boarded, "nearby aimed interaction boards window")
	player._interact()
	_check(not left.boarded, "nearby interaction removes boards")
	_check(cottage.has_node("Hearth") and cottage.has_node("Roof"), "shelter includes hearth and roof")
	_check(cottage.get_node("HearthLight").light_energy == 0, "unfueled hearth starts dark")
	world.free()
	print("Cottage tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
