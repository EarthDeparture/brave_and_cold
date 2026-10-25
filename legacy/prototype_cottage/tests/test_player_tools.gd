extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	world.get_node("Zombie").set_physics_process(false)
	world.get_node("ZombieSpawner").set_process(false)
	var window = world.get_node("Cottage/LeftWindow")
	var door = world.get_node("Cottage/Door")
	window.boarded = false
	window.interact(player)
	_check(player.work_remaining == 0.0, "no wood cannot start work")
	player.add_wood(10)
	window.interact(player)
	player._advance_work(1.0)
	_check(not window.boarded and player.wood == 10, "bare hands need more than one second; no early cost")
	window.interact(player)
	_check(player.work_remaining == 1.0, "repeated interaction cannot restart or duplicate work")
	player._advance_work(1.0)
	_check(window.boarded and player.wood == 9, "bare hands board in two seconds for one wood")
	window.interact(player)
	_check(not window.boarded and player.work_remaining == 0.0, "removing boards stays instant and free")
	var hammer = world.get_node("Hammer")
	player.position = Vector3(4, 0.1, 10)
	player.camera.look_at(hammer.global_position)
	await physics_frame
	await physics_frame
	player._interact()
	_check(player.has_hammer and player.wood == 9, "raycast collects hammer independently of wood")
	hammer.interact(player)
	_check(world.get_node("HUD/ToolLabel").text.contains("Hammer"), "HUD shows equipped hammer")
	for barrier in [window, door]:
		barrier.boarded = false
		if barrier == door:
			barrier.is_open = false
			Input.action_press("sprint")
		barrier.interact(player)
		Input.action_release("sprint")
		player._advance_work(0.5)
		_check(not barrier.boarded, "hammer boarding still takes time")
		player._advance_work(0.5)
		_check(barrier.boarded, "hammer boards window and door in one second")
		barrier.interact(player)
		for hit in range(barrier.hits_to_break):
			barrier.take_hit()
		var wood_before: int = player.wood
		barrier.interact(player)
		player._advance_work(0.5)
		_check(barrier.broken, "repair preserves breach until complete")
		paused = true
		player._advance_work(10.0)
		paused = false
		_check(player.work_remaining == 0.5, "pause freezes work")
		player._advance_work(0.5)
		_check(not barrier.broken and player.wood == wood_before - 1, "hammer repairs in one second for one wood")
	window.interact(player)
	player.position.x += 1.0
	var remaining_wood: int = player.wood
	player._advance_work(2.0)
	_check(not window.boarded and player.wood == remaining_wood and player.work_remaining == 0.0, "movement cancels without spending wood")
	window.interact(player)
	for hit in range(window.hits_to_break):
		window.take_hit()
	player._advance_work(1.0)
	_check(window.broken and not window.boarded and player.wood == remaining_wood, "changed barrier state rejects stale boarding without cost")
	window.interact(player)
	player.die("test")
	player._advance_work(2.0)
	_check(window.broken and player.wood == remaining_wood and player.work_remaining == 0.0, "death cancels pending repairs")
	world.free()
	print("Player tool tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
