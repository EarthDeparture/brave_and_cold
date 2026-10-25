extends SceneTree
## C6 cold start: stoves always catch; an exposed campfire rolls against wind and wet
## snow. Tinder and kindling help, a trunk or wall upwind halves the wind, and a
## failed strike spends the match (and tinder) but keeps the fuel.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.001
func run() -> void:
	var sc := FireSource.start_chance
	check(sc.call({}) == 1.0 and sc.call({"outdoors": false, "wind": 20.0}) == 1.0, "indoors (or no context) always catches")
	check(near(sc.call({"outdoors": true, "wind": 3.0}), 0.85), "calm outdoors: a match catches 85%")
	check(near(sc.call({"outdoors": true, "wind": 3.0, "tinder": true, "kindling": true}), 1.0), "tinder + kindling make a calm start sure")
	check(near(sc.call({"outdoors": true, "wind": 12.0}), 0.40), "a 12 m/s gale cuts it to 40%")
	check(near(sc.call({"outdoors": true, "wind": 12.0, "sheltered": true}), 0.625), "shelter upwind halves the wind penalty")
	check(near(sc.call({"outdoors": true, "wind": 3.0, "precip": 0.8}), 0.75), "heavy wet snow costs 10%")
	check(sc.call({"outdoors": true, "wind": 30.0, "precip": 1.0, "base": 0.3}) >= 0.1, "never below 10%")
	check(FireSource.new("campfire").exposed() and not FireSource.new("wood_stove").exposed() and not FireSource.new("box_stove").exposed(), "campfires are exposed, stoves are not")

	var inv := Inventory.new(null); inv.add("wood", 2); inv.add("matches", 2); inv.add("tinder", 1)
	var cf := FireSource.new("campfire"); var gale := {"outdoors": true, "wind": 12.0, "tinder": true}
	var res: Dictionary = cf.stoke(inv, "wood", gale, 0.99)
	check(not bool(res.ok) and bool(res.get("failed_start", false)) and not cf.is_lit(), "a failed strike leaves the fire cold: %s" % res.msg)
	check(inv.count("matches") == 1 and inv.count("tinder") == 0 and inv.count("wood") == 2, "it spent the match and tinder, kept the wood")
	res = cf.stoke(inv, "wood", gale, 0.0)
	check(bool(res.ok) and cf.is_lit() and inv.count("matches") == 0 and inv.count("wood") == 1, "a good strike lights it")
	cf.set_fuel(0); cf.ember_s = 60.0
	res = cf.stoke(inv, "wood", gale, 0.99)
	check(bool(res.ok) and cf.is_lit(), "embers relight regardless of wind, no match")
	var stove := FireSource.new("wood_stove"); inv.add("wood", 1); inv.add("matches", 1)
	check(bool(stove.stoke(inv, "wood", gale, 0.99).ok), "a stove ignores the outdoor roll")

	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	for frame in 3: await process_frame
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs; w.inv.add("wood", 3); w.inv.add("matches", 3)
	# Find open ground (no trunk or wall within 3 m) near the start for a campfire.
	var spot := Vector3.ZERO; var found := false
	for i in 400:
		var p: Vector3 = w.player.position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
		p.y = w._ground(p.x, p.z).y
		if (w.forest.nearest_tree(p, Vector3.FORWARD, 3.0, false) as Dictionary).is_empty() and w._building_list().all(func(b: Node) -> bool: return not b.has_method("contains_xz") or not b.contains_xz(p.x, p.z)):
			spot = p; found = true; break
	check(found, "found open ground for the field test")
	w.weather.wind = 12.0; w.weather.precip = 0.0
	check(not w._upwind_sheltered(spot), "open ground is not sheltered")
	var c := Campfire.new(); w.add_child(c); c.global_position = spot; w.campfires.append(c)
	w.player.position = spot + Vector3(0, w.player.eye_h, 1.2)
	var acts: Array = w.fire_actions(c.fire, spot + Vector3(0, 0.2, 0), Callable(), 2.6, 0.9)
	check(String(acts[0].text).contains("% to catch"), "the cold campfire prompt shows the odds: %s" % acts[0].text)
	w.weather.wind = 2.0
	acts = w.fire_actions(c.fire, spot + Vector3(0, 0.2, 0), Callable(), 2.6, 0.9)
	check(String(acts[0].text).contains("85% to catch"), "calm air: %s" % acts[0].text)
	# A trunk upwind shelters a fire beside it.
	var tr: Dictionary = w.forest.nearest_tree(w.player.position, Vector3.FORWARD, 60.0, false)
	check(not tr.is_empty(), "a tree to test shelter against")
	if not tr.is_empty():
		var wd: Vector2 = w.weather.wind_dir
		var beside := Vector3(float(tr.x) + wd.x * (float(tr.r) + 1.0), 0, float(tr.z) + wd.y * (float(tr.r) + 1.0))
		check(w._upwind_sheltered(beside), "a fire downwind of a trunk is sheltered")
		var upw := Vector3(float(tr.x) - wd.x * (float(tr.r) + 1.0), 0, float(tr.z) - wd.y * (float(tr.r) + 1.0))
		check(not w._upwind_sheltered(upw) or not (w.forest.nearest_tree(upw, Vector3(-wd.x, 0, -wd.y), 2.5, true) as Dictionary).is_empty(), "the trunk does not shelter the upwind side")
	# No campfires inside a hut or the store: use their stove.
	var hut: Hut = w.huts[0]
	w.player.position = hut.to_global(Vector3(0, Hut.FLOOR_LOCAL_Y + w.player.eye_h, 0))
	var site: Dictionary = w._fire_site()
	check(not bool(site.ok), "no campfire inside a hut (%s)" % site.get("msg", ""))
	w.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("FIRE_START_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
