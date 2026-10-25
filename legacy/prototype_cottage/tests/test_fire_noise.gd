extends SceneTree

var failures := 0
var radii: Array[float] = []
var positions: Array[Vector3] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("Temperature").set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var fire = world.get_node("Cottage/Fireplace")
	var player = world.get_node("Player")
	var zombie = world.get_node("Zombie")
	fire.set_process(false)
	player.set_physics_process(false)
	zombie.set_physics_process(false)
	zombie.global_position = fire.global_position + Vector3(16, 0, 0)
	root.get_node("NoiseEvents").emitted.connect(func(location: Vector3, radius: float):
		positions.append(location)
		radii.append(radius))
	fire.interact(player)
	fire.advance(2.0)
	_check(radii.is_empty(), "unlit/failed ignition stays silent")
	player.wood = 3
	fire.interact(player)
	_check(radii == [24.0] and positions[0] == fire.global_position, "ignition emits at hearth position")
	_check(zombie.noise_remaining > 0.0, "roaring fire reaches distant zombie")
	fire.advance(0.5)
	fire.advance(-1.0)
	_check(radii.size() == 1, "no per-frame or negative-time noise")
	fire.advance(0.5)
	_check(radii.size() == 2, "periodic fire noise")
	fire.advance(14.0)
	_check(fire.get_fire_state() == fire.FireState.DYING and radii.back() == 8.0, "large step reaches dying state and quieter pulse")
	_check(fire.get_node("Light").omni_range == 3.0 and fire.get_node("Flame").scale.x == 0.5, "dying visuals shrink")
	zombie.noise_remaining = 0.0
	fire.advance(1.0)
	_check(zombie.noise_remaining == 0.0, "dying fire does not reach distant zombie")
	zombie.global_position = fire.global_position + Vector3(4, 0, 0)
	fire.advance(1.0)
	_check(zombie.noise_remaining > 0.0, "dying fire still attracts nearby zombie")
	fire.interact(player)
	_check(radii.back() == 24.0 and fire.get_node("Light").omni_range == 6.0, "refueling restores loud bright fire")
	fire.advance(100.0)
	_check(not fire.is_lit() and not fire.get_node("Light").visible, "burnout extinguishes fire")
	var count := radii.size()
	fire.advance(10.0)
	_check(radii.size() == count, "burnout stops noise")
	fire.interact(player)
	_check(radii.size() == count + 1 and radii.back() == 24.0, "relighting emits immediately")
	world.free()
	print("Fire noise tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
