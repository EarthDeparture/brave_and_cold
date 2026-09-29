extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	var zombie = world.get_node("Zombie")
	var cottage = world.get_node("Cottage")
	var temperature = root.get_node("Temperature")
	player.set_physics_process(false)
	zombie.set_physics_process(false)
	root.get_node("DayNight").set_process(false)
	world.get_node("ZombieSpawner").set_process(false)
	player.position = Vector3(0, 0.1, 0)
	for barrier in [cottage.get_node("LeftWindow"), cottage.get_node("Door")]:
		barrier.boarded = false
		player._update_temperature_exposure()
		_check(not temperature.is_outdoors, "intact unboarded barrier preserves warmth")
		barrier.take_hit()
		_check(not barrier.broken, "one hit does not breach")
		for hit in range(barrier.hits_to_break - 1):
			barrier.take_hit()
		_check(barrier.broken and barrier.is_passable(), "broken barrier opens passage")
		barrier.take_hit()
		_check(barrier.hits_taken == barrier.hits_to_break, "broken barrier ignores more hits")
		barrier.interact(player)
		_check(barrier.broken and player.wood == 0, "empty inventory cannot repair")
		player._update_temperature_exposure()
		temperature.current_temperature = 100
		temperature._drain(4, false)
		_check(is_equal_approx(temperature.current_temperature, 98), "breach doubles indoor cold drain")
		for frame in range(5):
			await physics_frame
		_check(world.get_node("NavigationRegion3D").breach_links[barrier].enabled, "breach enables navigation link")
		var center: Vector3 = barrier.global_position
		if barrier.name == "Door":
			center += Vector3(0.95, 1.5, 0)
		var query := PhysicsRayQueryParameters3D.create(center + Vector3(0, 0, 1), center - Vector3(0, 0, 1), 3)
		var hit = world.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() and hit.collider == barrier, "broken barrier remains selectable for repair")
		player.add_wood(1)
		barrier.interact(player)
		_check(not barrier.broken and barrier.hits_taken == 0 and player.wood == 0, "one wood fully repairs barrier")
		_check(not barrier.is_passable() and barrier.collision_layer == 1, "repair restores solid barrier")
		player._update_temperature_exposure()
		_check(not temperature.is_outdoors, "repair restores shelter warmth")
		for frame in range(5):
			await physics_frame
		_check(not world.get_node("NavigationRegion3D").breach_links[barrier].enabled, "repair closes navigation link")
	var door = cottage.get_node("Door")
	cottage.get_node("LeftWindow").boarded = true
	player.position = Vector3(0, 0.1, 0)
	zombie.position = Vector3(0, 0.1, 6.5)
	for frame in range(5):
		await physics_frame
	# Real attacks must break the door, then movement must cross its threshold.
	zombie.set_physics_process(true)
	for frame in range(360):
		await physics_frame
		if zombie.position.z < 4.5:
			break
	_check(door.broken and zombie.position.z < 4.5, "zombie breaks door and walks inside")
	zombie.set_physics_process(false)
	player.add_wood(1)
	door.interact(player)
	zombie._update_target(0)
	_check(zombie.target_player == player, "repair does not hide player from indoor zombie")
	world.free()
	print("Barrier repair tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
