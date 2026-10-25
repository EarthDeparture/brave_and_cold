extends SceneTree
## Phase F winter greenhouse: plots need warmth, light and water; 2 h below 0 C kills,
## a day dry kills; seeds are finite, potatoes replant; the hamlet greenhouse has a stove
## that heats its room (plus sun through the glazing), and plots save.
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
	var inv := Inventory.new(); inv.add("potato", 1); inv.add("clean_water", 3)
	var p := Farming.new_plot()
	check(Farming.plant(p, "carrot", inv).begins_with("Need"), "no seeds, no carrots")
	check(Farming.plant(p, "potato", inv) == "Planted potatoes" and inv.count("potato") == 0, "a potato plants as seed")
	Farming.advance(p, 3600, 20.0, 1.0)
	check(float(p.growth) == 0.0, "dry soil: nothing grows")
	check(Farming.water(p, inv) == "Watered the plot" and inv.count("empty_bottle") == 1, "a bottle waters the plot (bottle kept)")
	var g0 := float(p.growth); Farming.advance(p, 3600, 20.0, 1.0)
	check(float(p.growth) > g0, "warm, lit and wet: it grows")
	var day := float(p.growth) - g0
	var q := p.duplicate(true); Farming.advance(q, 3600, 20.0, 0.0)
	check(float(q.growth) == float(p.growth), "no growth at night")
	q = p.duplicate(true); Farming.advance(q, 3600, 5.0, 1.0)
	check(float(q.growth) - float(p.growth) < day * 0.3, "cold room (5 C) crawls")
	q = p.duplicate(true); Farming.advance(q, 3600, -3.0, 1.0)
	check(not bool(q.dead), "an hour of frost: still alive")
	Farming.advance(q, 3700, -3.0, 1.0)
	check(bool(q.dead), "two hours below 0 C kills the crop")
	q = p.duplicate(true); q.water = 0.0; Farming.advance(q, 23 * 3600, 20.0, 1.0); Farming.advance(q, 2 * 3600, 20.0, 1.0)
	check(bool(q.dead), "a day dry kills it")
	for i in 30:
		p.water = 1.0; Farming.advance(p, 4 * 3600, 20.0, 1.0)
	check(Farming.ripe(p), "potatoes ripen after ~60 h of good growing")
	var msg := Farming.harvest(p, inv)
	check(inv.count("potato") >= 3 and String(p.crop) == "" and float(p.water) > 0.0, "harvest: %s, plot free, soil stays damp" % msg)
	check(Farming.plant(p, "potato", inv) == "Planted potatoes", "harvested potatoes replant")
	check(PotCooking.by_id("garden_stew").size() > 0 and float(Inventory.ITEMS.garden_stew.kcal) > float(Inventory.ITEMS.meat_stew.kcal), "garden stew is the best pot meal")

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	check(w.greenhouses.size() == 1, "the hamlet has a greenhouse")
	if w.greenhouses.is_empty():
		print("GREENHOUSE_TEST checks=", checks, " failures=", failures); quit(1); return
	var gh: Greenhouse = w.greenhouses[0]
	check(w.colliders.has(gh) and gh.room != null and gh.stove.fire.type == "box_stove", "greenhouse: collider, room, box stove")
	var inside := gh.to_global(Vector3(0, Greenhouse.FT + 1.0, 0))
	check(w.room_at(inside) == gh.room, "standing inside is the greenhouse room")
	var c: Vector2 = w.forest.resolve_trunks(gh.global_position.x, gh.global_position.z, 2.0)
	check(c.distance_to(Vector2(gh.global_position.x, gh.global_position.z)) < 0.01, "no tree grows through it")
	var out_c: float = w.clock.ambient_c()
	gh.stove.fire.set_fuel(0); gh.room.sun = 0.0; gh.room.settle(out_c); var cold := gh.room.room_c
	gh.room.sun = 1.0; var sunny := gh.room.target_c(out_c)
	gh.stove.fire.set_fuel(6 * 3600); var stoked := gh.room.target_c(out_c)
	check(sunny > cold + 8.0 and stoked > sunny + 15.0, "sun warms the glazing (%.1f -> %.1f C), the stove much more (%.1f C)" % [cold, sunny, stoked])
	# Interaction: plant, water through the action list.
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs; w.inv.add("carrot_seeds", 2); w.inv.add("clean_water", 1)
	var acts: Array = gh.actions(w.inv, w._say)
	var plant: Dictionary = {}
	for a: Dictionary in acts:
		if String(a.text).begins_with("Plant carrots") and plant.is_empty(): plant = a
	check(not plant.is_empty(), "an empty plot offers the seeds carried")
	(plant.act as Callable).call()
	check(String(gh.plots[0].crop) == "carrot" and w.inv.count("carrot_seeds") == 1, "planting spends one sowing")
	acts = gh.actions(w.inv, w._say)
	check(acts.any(func(a: Dictionary) -> bool: return String(a.text).begins_with("Water carrots")), "the new plot asks for water")
	# Growth through the world loop: warm room, daylight.
	gh.plots[0].water = 1.0; gh.room.room_c = 20.0; gh.light = 1.0
	gh.advance(3600, 20.0)
	check(float(gh.plots[0].growth) > 0.0, "the world advances the plots")
	gh.advance(3 * 3600, -5.0)
	check(bool(gh.plots[0].dead), "an unheated night freezes the crop")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	check(snap.has("greenhouses"), "greenhouses save")
	w.queue_free(); await process_frame; await process_frame
	SaveGame.pending = snap
	var w2: Node3D = load("res://world/game_world.gd").new(); root.add_child(w2)
	for frame in 700:
		await process_frame
		if w2.opening != null and w2.gear != null: break
	freeze(w2)
	check(not w2.greenhouses.is_empty() and bool(w2.greenhouses[0].plots[0].dead) and String(w2.greenhouses[0].plots[0].crop) == "carrot", "plot state survives save/load")
	w2.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("GREENHOUSE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
