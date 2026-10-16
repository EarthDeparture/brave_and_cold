extends SceneTree
## N3 cook pot + forage: teas and stews brew in a pot that takes a pan slot on any lit
## fire; teas warm, hydrate and treat; rose hips, reishi and birch bark are harvested
## once each from seeded forage nodes that save.
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
	check(PotCooking.recipes().size() == 7 and PotCooking.outputs().all(func(id: String) -> bool: return Inventory.ITEMS.has(id)), "7 pot recipes (3 teas, 4 stews/soups), every output is an item")
	var inv := Inventory.new(BodyTemperature.new())
	inv.add("rose_hips", 2); inv.add("clean_water", 1)
	var fire := FireSource.new("campfire")
	check(PotCooking.missing(inv, PotCooking.by_id("tea_rose_hip")) == "Need a cooking pot", "no pot, no tea")
	inv.add("cooking_pot")
	check(PotCooking.ready_recipes(inv).map(func(r: Dictionary) -> String: return r.id) == ["tea_rose_hip"], "pot + hips + water: only rose hip tea is ready")
	check(PotCooking.begin(fire.cooking, inv, PotCooking.by_id("tea_rose_hip"), fire.is_lit()).begins_with("Light"), "a cold fire refuses the pot")
	fire.set_fuel(3600)
	var msg := PotCooking.begin(fire.cooking, inv, PotCooking.by_id("tea_rose_hip"), fire.is_lit(), "campfire")
	check(inv.count("cooking_pot") == 0 and inv.count("rose_hips") == 0 and inv.count("clean_water") == 0 and fire.cooking.portions.size() == 1, "the pot goes on the fire with the hips and water (%s)" % msg)
	inv.add("rose_hips", 2); inv.add("clean_water", 1)
	check(PotCooking.ready_recipes(inv).is_empty(), "one pot: a second brew waits for it")
	var saved := fire.to_dict(); var copy := FireSource.new("campfire"); copy.restore(JSON.parse_string(JSON.stringify(saved)))
	check(copy.cooking.portions.size() == 1 and float(copy.cooking.portions[0].remaining_s) == 600.0, "a brewing pot survives save/load")
	fire.advance(300); check(fire.cooking.collect(inv) == 0, "not ready after 5 min")
	fire.advance(300)
	check(fire.cooking.collect(inv) == 1 and inv.count("tea_rose_hip") == 1 and inv.count("cooking_pot") == 1 and inv.count("empty_bottle") == 1, "after 10 min of burn: tea, pot and empty bottle come back")

	inv.add("venison_raw"); inv.age.venison_raw = 10 * 3600.0; inv.add("clean_water", 1)
	inv.remove("rose_hips", 2)
	PotCooking.begin(fire.cooking, inv, PotCooking.by_id("meat_stew"), true)
	fire.set_fuel(3600); fire.advance(45 * 60); fire.cooking.collect(inv)
	check(inv.count("meat_stew") == 1 and float(inv.age.get("meat_stew", 0)) > 10 * 3600.0, "meat stew keeps the meat's age as a shelf fraction")
	check(float(Inventory.ITEMS.meat_stew.kcal) > float(Inventory.ITEMS.venison_cooked.kcal), "stew beats a seared steak for calories")

	# Drinking: warmth, water, cure.
	var needs := Needs.new(); inv.needs = needs; needs.water = 50.0
	var before_w := needs.water
	var said := inv.use("tea_rose_hip")
	check(said.begins_with("Drank") and inv.body.hot_s > 0.0 and needs.water > before_w, "drinking tea hydrates and starts a hot window: %s" % said)
	var cold := BodyTemperature.new(); var hot := BodyTemperature.new(); hot.hot_s = 3600.0
	for i in 60:
		cold.update(60, -15, 4, false, 0, 1, 0, false); hot.update(60, -15, 4, false, 0, 1, 0, false)
	check(hot.core > cold.core + 0.05, "a hot drink holds core temperature up (%.2f vs %.2f)" % [hot.core, cold.core])
	check(hot.hot_s == 0.0, "the warmth wears off")
	var inj := Injury.new(); inj.inf_t = 3600.0
	check(inj.reishi() == "The wound infection fades" and inj.inf_t < 0.0, "reishi clears an early wound infection")
	inj.inf_t = Injury.INCUBATION_S + 7200.0; inj.reishi()
	check(inj.inf_t < Injury.INCUBATION_S and inj.inf_t > 0.0, "after fever it only buys time")
	inj = Injury.new(); inj.outbreak_t = 100.0; inj.outbreak_exposed = true; inj.reishi()
	check(inj.outbreak_t == 100.0, "reishi never touches the outbreak")

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	var kinds := {}
	for f: ForageNode in w.forage: kinds[f.kind] = int(kinds.get(f.kind, 0)) + 1
	check(int(kinds.get("rose", 0)) >= 8 and int(kinds.get("reishi", 0)) >= 4 and int(kinds.get("birch", 0)) >= 5, "forage scattered: %s" % str(kinds))
	check(w.forage.all(func(f: ForageNode) -> bool: return not w.road.is_near(f.position.x, f.position.z, 4.0)), "nothing grows on the road")
	check(w.opening.pantry.count("cooking_pot") == 1, "the lookout pantry holds the cooking pot")
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs
	var rose: ForageNode; var birch: ForageNode
	for f: ForageNode in w.forage:
		if f.kind == "rose" and rose == null: rose = f
		if f.kind == "birch" and birch == null: birch = f
	w.harvest_forage(rose)
	check(w.inv.count("rose_hips") >= 2 and rose.harvested and not rose._yield_node.visible, "picking a bush gives hips and empties it")
	w.harvest_forage(rose); check(w.inv.count("rose_hips") <= 4, "a bush gives once")
	w.harvest_forage(birch)
	check(not birch.harvested and w.inv.count("birch_bark") == 0, "birch bark needs a knife")
	w.inv.add("knife"); w.harvest_forage(birch)
	check(birch.harvested and w.inv.count("birch_bark") >= 2, "with a knife it peels")
	var mid := birch.to_global(Vector3(0.3, 0, 0))
	check(birch.resolve_at(mid, mid, 0.35).distance_to(Vector2(mid.x, mid.z)) > 0.3 and w.player.spatial_structures.has(birch), "the fallen log is solid")
	w.inv.add("venison_raw"); w.inv.age.venison_raw = Inventory.shelf_s("venison_raw") * 0.8
	w.gear.inv = w.inv
	check(absf(w.gear._hit_fresh("venison_raw", {"k": "pack"}) - 0.2) < 0.01 and w.gear._hit_fresh("knife", {"k": "pack"}) < 0.0, "gear cells read food freshness (bar + olive tint below 40%)")
	# Pot prompt at a lit fire.
	w.inv.add("cooking_pot"); w.inv.add("birch_bark", 2); w.inv.add("clean_water")
	var c := Campfire.new(); w.add_child(c); c.global_position = w.player.position + Vector3(0, -w.player.eye_h, -1.2); c.fire.set_fuel(3600)
	var acts: Array = w.fire_actions(c.fire, c.global_position, Callable(), 2.6, 0.9)
	check(acts.any(func(a: Dictionary) -> bool: return String(a.text).begins_with("Cook pot • birch bark tea")), "a lit fire offers the pot brew")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free(); await process_frame; await process_frame
	SaveGame.pending = snap
	var w2: Node3D = load("res://world/game_world.gd").new(); root.add_child(w2)
	for frame in 700:
		await process_frame
		if w2.opening != null and w2.gear != null: break
	freeze(w2)
	var back := (w2.forage as Array).filter(func(f: ForageNode) -> bool: return f.harvested).size()
	check(back == 2 and w2.forage.size() == snap.forage.size(), "harvested forage stays harvested after load (%d)" % back)
	w2.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("POT_FORAGE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
