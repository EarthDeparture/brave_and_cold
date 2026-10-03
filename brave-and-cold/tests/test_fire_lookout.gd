extends SceneTree
## Blank-scene contracts: ground under the room, stacked stairs, deck boundaries,
## doorway, shelter volume and elevated save restoration. Failure exits nonzero.

var failures := 0
var tower: FireLookout


func _init() -> void:
	call_deferred('_run')


func check(ok: bool, message: String) -> void:
	print(('PASS ' if ok else 'FAIL ') + message)
	if not ok:
		failures += 1


func _run() -> void:
	tower = FireLookout.new()
	root.add_child(tower)
	tower.build({'origin': {'x': 50.0, 'y': 120.0, 'z': -80.0}, 'yaw_degrees': 31.0}, false)
	check(is_nan(height_at(Vector3(0.0, 0.0, 0.0))), 'Ground underneath cabin never becomes upstairs floor')
	check(is_equal_approx(height_at(Vector3(0.0, 8.64, 0.0)), 128.64), 'Room supplies its upper floor at the correct elevation')
	check(not tower.contains_room(world(Vector3(0.0, 1.7, 0.0))), 'Under-tower eye remains outside room shelter')
	check(tower.contains_room(world(Vector3(0.0, 10.34, 0.0))), 'Standing room occupant is sheltered')
	check(not tower.contains_room(world(Vector3(0.0, 10.34, 2.8))), 'Open deck is outdoors')
	check(not tower.contains_room(world(Vector3(0.0, 13.0, 0.0))), 'Roof exterior is not an indoor room')
	check(is_equal_approx(height_at(Vector3(4.45, 0.18, 1.7)), 120.18), 'First staircase begins near terrain')
	check(is_equal_approx(height_at(Vector3(4.45, 4.50, 1.7)), 124.50), 'Third flight selected above the same X/Z')
	check(is_nan(height_at(Vector3(4.45, 0.0, -1.7))), 'Ground actor at upper end cannot snap onto a stair flight')
	check(is_equal_approx(height_at(Vector3(5.80, 8.64, 2.2)), 128.64), 'Top landing joins final stair elevation')
	check(is_equal_approx(height_at(Vector3(3.65, 8.64, 2.3)), 128.64), 'Upper bridge connects staircase and deck')
	# Exercise both directions through every tread and landing with independent
	# foot height, including the stacked X/Z of flights zero and two.
	var foot := Vector3(4.45, 0.0, 1.78)
	var route: Array[Vector3] = []
	for flight in range(4):
		var x := FireLookout.STAIR_LANES[flight % 2]
		for step in range(12):
			var z := 1.8 - (float(step) + 0.5) * 0.3 if flight % 2 == 0 else -1.8 + (float(step) + 0.5) * 0.3
			route.append(Vector3(x, float(flight) * 2.16 + float(step + 1) * 0.18, z))
		var landing_z := -2.2 if flight % 2 == 0 else 2.2
		route.append(Vector3(x, float(flight + 1) * 2.16, landing_z))
		if flight < 3:
			route.append(Vector3(FireLookout.STAIR_LANES[(flight + 1) % 2], float(flight + 1) * 2.16, landing_z))
	var walked := true
	for target in route:
		var h := height_at(Vector3(target.x, foot.y, target.z))
		if is_nan(h) or absf(h - (120.0 + target.y)) > 0.02:
			walked = false
		foot = target
	check(walked, 'Four stair flights and turn landings form a continuous ascent')
	route.reverse()
	for target in route:
		var h := height_at(Vector3(target.x, foot.y, target.z))
		if is_nan(h) or absf(h - (120.0 + target.y)) > 0.02:
			walked = false
		foot = target
	check(walked, 'Descent chooses the correct overlapping staircase level')
	var inside := world(Vector3(0.0, 8.64, 1.8))
	var through_door := world(Vector3(0.0, 8.64, 2.55))
	var door_result := tower.resolve_at(through_door, inside, 0.35)
	check(door_result.distance_to(Vector2(through_door.x, through_door.z)) < 0.02, 'Open doorway passes a player-sized circle')
	var toward_wall := world(Vector3(1.2, 8.64, 2.25))
	var old_wall := world(Vector3(1.2, 8.64, 1.7))
	var wall_result := tower.resolve_at(toward_wall, old_wall, 0.35)
	check(wall_result.distance_to(Vector2(toward_wall.x, toward_wall.z)) > 0.1, 'Solid front wall blocks upstairs movement')
	var edge := world(Vector3(0.0, 8.64, -3.1))
	var off_edge := world(Vector3(0.0, 8.64, -4.0))
	var edge_result := tower.resolve_at(off_edge, edge, 0.35)
	check(edge_result.distance_to(Vector2(edge.x, edge.z)) < 0.02, 'Deck guardrail prevents terrain snap through an edge')
	var p := Player.new()
	root.add_child(p)
	p.position = world(Vector3(0.0, 10.34, 0.0))
	var saved := tower.saved_location(p.position, p.eye_h)
	p.position.y = 400.0
	check(tower.restore_location(p, saved) and absf(p.position.y - 130.34) < 0.01, 'Saving upstairs restores upper elevation')
	check(tower.saved_location(world(Vector3(0.0, 1.7, 0.0)), 1.7).is_empty(), 'Ground placement does not acquire an elevated save identity')
	check(not tower.restore_location(p, {}), 'Legacy saves without lookout data retain their existing placement')
	p.free()
	tower.free()
	if 'integration=1' in OS.get_cmdline_user_args():
		await _integration()
	print('FIRE_LOOKOUT_TEST failures=', failures)
	quit(1 if failures > 0 else 0)


func world(local: Vector3) -> Vector3:
	return tower.to_global(local)


func height_at(local: Vector3) -> float:
	return tower.floor_at_world(world(local), 120.0)


func _integration() -> void:
	var packed := load('res://world/game_world.tscn') as PackedScene
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	for i in range(15):
		await process_frame
	tower = game.get('fire_lookout') as FireLookout
	check(tower != null and tower.model != null, 'Lookout GLB instantiates in the actual game world')
	if tower == null:
		game.free()
		return
	check(tower.get_node_or_null('LookoutAccessTrack') != null, 'Access track renders from the site manifest')
	var terrain: Terrain3D = game.get('terrain')
	var stair_base := world(Vector3(4.45, 0.0, 1.8))
	var terrain_y: float = terrain.data.get_height(stair_base)
	check(absf(terrain_y - tower.position.y) < 0.12, 'Tower root follows natural terrain at the first stair')
	var player := game.get('player') as Player
	player.frozen = true
	player.sim_on = true
	player.speed_mult = 0.40
	var base := world(Vector3(4.45, 0.0, 2.8))
	player.position = Vector3(base.x, terrain.data.get_height(base) + player.eye_h, base.z)
	player._ready_ground = true
	player._vel = Vector2.ZERO
	var route: Array[Vector3] = []
	for flight in range(4):
		var lane := FireLookout.STAIR_LANES[flight % 2]
		var start := 1.65 if flight % 2 == 0 else -1.65
		var end := -1.65 if flight % 2 == 0 else 1.65
		route.append(Vector3(lane, 0.0, start))
		route.append(Vector3(lane, 0.0, end))
		var landing := -2.2 if flight % 2 == 0 else 2.2
		route.append(Vector3(lane, 0.0, landing))
		if flight < 3:
			route.append(Vector3(FireLookout.STAIR_LANES[(flight + 1) % 2], 0.0, landing))
	route.append(Vector3(3.4, 0.0, 2.30))
	route.append(Vector3(0.0, 0.0, 2.75))
	route.append(Vector3(0.0, 0.0, 0.0))
	var reached_all := true
	for point in route:
		if not _walk_to(player, world(point)):
			reached_all = false
			print('TRAVERSAL_BLOCKED at=', tower.to_local(player.position - Vector3.UP * player.eye_h), ' target=', point)
			break
	check(reached_all and absf(player.position.y - (tower.position.y + FireLookout.DECK_Y + player.eye_h)) < 0.25, 'Actual Player controller climbs all four flights into the room')
	check(player.is_sheltered(), 'Actual player receives shelter only after reaching the room')
	if reached_all:
		var snow: SnowField = game.get('snow')
		var before_trample := snow._trample.duplicate()
		player.moving = true
		player._since_trample = 0.0
		player._last_pos = player.position - Vector3.RIGHT
		player._footsteps(0.1)
		check(snow._trample == before_trample, 'Upstairs footsteps never trample the ground snow beneath the room')
		player.moving = false
		_save_roundtrip(game, player)
	if reached_all:
		route.reverse()
		route.append(Vector3(4.45, 0.0, 2.80))
		for point in route:
			if not _walk_to(player, world(point)):
				reached_all = false
				print('DESCENT_BLOCKED at=', tower.to_local(player.position - Vector3.UP * player.eye_h), ' target=', point)
				break
		var ground: float = terrain.data.get_height(player.position)
		print('DESCENT_FINAL local=', tower.to_local(player.position - Vector3.UP * player.eye_h), ' terrain_y=', ground, ' eye_y=', player.position.y, ' delta=', player.position.y - (ground + player.eye_h))
		check(reached_all and absf(player.position.y - (ground + player.eye_h)) < 0.4, 'Actual controller descends to the unchanged terrain')
	game.free()
	await process_frame


## Exercise the actual restore entry point with JSON data, without touching the
## player's real user:// save slot. The tower is additive to the legacy payload.
func _save_roundtrip(game: Node3D, player: Player) -> void:
	var clock: GameClock = game.get('clock')
	var body: BodyTemperature = game.get('body')
	var needs: Needs = game.get('needs')
	var inventory: Inventory = game.get('inv')
	var saved: Dictionary = {
		'clock': {'hour': clock.hour, 'day': clock.day, 'total': clock.total_game_s},
		'player': {'x': player.position.x, 'z': player.position.z, 'yaw': player.yaw, 'pitch': player.pitch, 'hp': player.health, 'stam': player.stamina},
		'body': {'core': body.core, 'wet': body.wetness},
		'needs': {'cal': needs.calories, 'water': needs.water},
		'inv': {'counts': inventory.counts.duplicate(), 'worn': inventory.jacket(), 'extra': inventory.extra.duplicate(), 'rifle_up': game.get('rifle_up'), 'cond': inventory.cond.duplicate(), 'age': inventory.age.duplicate()},
		'cabins': [], 'fires': [],
		'lookout_location': tower.saved_location(player.position, player.eye_h),
	}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var expected_floor := tower.position.y + FireLookout.DECK_Y
	player.place(float(parsed.player.x), float(parsed.player.z))
	game.call('_apply_save', parsed)
	check(absf(player.position.y - expected_floor - player.eye_h) < 0.01 and player._ready_ground, 'Actual world restore preserves the serialized elevated room location')
	player.eye_h = Player.EYE_CROUCH
	player.position.y = expected_floor + player.eye_h
	saved['lookout_location'] = tower.saved_location(player.position, player.eye_h)
	parsed = JSON.parse_string(JSON.stringify(saved))
	player.eye_h = Player.EYE
	player.place(float(parsed.player.x), float(parsed.player.z))
	game.call('_apply_save', parsed)
	check(absf(player.position.y - expected_floor - Player.EYE) < 0.01, 'Crouched save restores the same floor while standing')


func _walk_to(player: Player, target: Vector3) -> bool:
	player._vel = Vector2.ZERO
	for tick in range(1200):
		var direction := Vector3(target.x - player.position.x, 0.0, target.z - player.position.z)
		if direction.length() < 0.06:
			player.sim_dir = Vector3.ZERO
			for stop in range(12):
				player._move(1.0 / 60.0)
			return true
		player.sim_dir = direction.normalized()
		player._move(1.0 / 60.0)
	return false
