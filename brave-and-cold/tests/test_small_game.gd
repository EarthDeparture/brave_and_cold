extends SceneTree
## Small game: seeded warrens with hares that flee, can be shot into a whole-rabbit
## pickup, skinned with a knife, and snares that catch them by the hour near a warren.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func run() -> void:
	check(Snare.hourly_chance(0.0) > 0.14 and Snare.hourly_chance(80.0) < 0.03, "snare odds: 15%/h at a warren, 2%/h far away")
	check(RecipeDB.get_recipe("snare").get("place", "") == "snare" and RecipeDB.get_recipe("skin_rabbit").get("tools", []).has("knife"), "snare and skinning recipes exist")
	check(FoodPreservation.RECIPES.has("rabbit_cooked") and Inventory.ITEMS.rabbit_raw.cooked == "rabbit_cooked", "rabbit cooks and dries like other meat")

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	check(w.warrens.size() >= 6 and w.rabbits.size() == w.warrens.size() * 2, "%d warrens, %d hares" % [w.warrens.size(), w.rabbits.size()])
	check(w.warrens.all(func(p: Vector3) -> bool: return not w.road.is_near(p.x, p.z, 7.0)), "warrens sit off the road")
	var r: Rabbit = w.rabbits[0]
	r.set_process(true)
	check(HitZones.kind_of(r) == "rabbit" and HitZones.spheres(r).size() == 2, "a hare has hit zones")
	w.player.position = r.global_position + Vector3(4, w.player.eye_h, 0); w.player.crouching = false
	r._process(0.1)
	check(r.state == Rabbit.State.FLEE, "walking up close spooks it")
	var where := r.global_position
	r.hit(20.0, w.player.position)
	await process_frame
	var found := false
	for n: ItemPickup in get_nodes_in_group("pickups"):
		if n.id == "rabbit" and n.global_position.distance_to(where) < 1.0: found = true
	check(found, "a shot hare drops a whole rabbit")
	# Snare right at a warren: a day of checks catches something.
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs
	var s: Snare = w._add_snare(w.warrens[0] + Vector3(2, 0, 0), 0.0)
	for h in 24: w._advance_small_game(3600.0)
	check(s.caught, "a snare by a warren catches within a day")
	check(s.take(w.inv).begins_with("Took a rabbit") and w.inv.count("rabbit") == 1 and is_equal_approx(s.condition, 0.75), "take the hare, the snare wears 25%")
	w.inv.add("knife")
	var why := RecipeDB.blocked(w.inv, RecipeDB.get_recipe("skin_rabbit"), false)
	check(why == "", "a knife and a rabbit can be skinned (%s)" % why)
	s.set_caught(true)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	check(snap.has("snares") and (snap.snares as Array).size() == 1 and bool(snap.snares[0].caught), "snares save")
	w.queue_free(); await process_frame; await process_frame
	SaveGame.pending = snap
	var w2: Node3D = load("res://world/game_world.gd").new(); root.add_child(w2)
	for frame in 700:
		await process_frame
		if w2.opening != null and w2.gear != null: break
	freeze(w2)
	check(w2.snares.size() == 1 and w2.snares[0].caught and is_equal_approx(w2.snares[0].condition, 0.75), "a loaded snare keeps its catch and wear")
	w2.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("SMALL_GAME_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
