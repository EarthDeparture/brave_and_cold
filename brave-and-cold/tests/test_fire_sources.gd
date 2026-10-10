extends SceneTree
## Contract test for the one fire standard. Every type in data/fire_sources.json
## (and so every future stove) runs the same rules; then the real lookout stove,
## a real cabin stove and a real campfire must expose the same interaction list.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func kit(wood: int, matches: int) -> Inventory:
	var inv := Inventory.new(); inv.add("wood", wood)
	if matches > 0: inv.add("matches", matches)
	return inv
func run() -> void:
	# Balance lock: the decided fuel economy.
	check(FireSource.burn_s_for("wood_stove", "wood") == 7200 and FireSource.burn_s_for("campfire", "wood") == 3600, "firewood: 2 h in a stove, 1 h on a campfire")
	check(FireSource.burn_s_for("wood_stove", "stick") == 600 and FireSource.burn_s_for("campfire", "kindling") == 480, "small fuel burns briefly (stick 10 min stove, kindling 8 min fire)")
	check(FireSource.type_spec("wood_stove").max_fuel_h == 12 and FireSource.type_spec("campfire").max_fuel_h == 6, "caps: stove 12 h, campfire 6 h")
	check(FireSource.fuel_ids()[0] == "wood", "longest fuel is offered first")
	for t: String in (FireSource.data().types as Dictionary).keys():
		var f := FireSource.new(t); var wood_s := f.burn_s("wood")
		check(f.needs_starter() and not f.is_lit() and f.heat_at(0.5) == 0, "%s starts cold and gives no heat" % t)
		var inv := kit(30, 0)
		var res := f.stoke(inv, "wood")
		check(not res.ok and inv.count("wood") == 30 and f.fuel_s == 0, "%s: cold start without a match consumes nothing" % t)
		inv.add("matches", 2); res = f.stoke(inv, "wood")
		check(res.ok and inv.count("matches") == 1 and inv.count("wood") == 29 and f.fuel_s == wood_s, "%s: match + log lights it for one log of burn" % t)
		res = f.stoke(inv, "wood")
		check(res.ok and inv.count("matches") == 1 and f.fuel_s == 2 * wood_s, "%s: stoking a lit fire needs no match" % t)
		var guard := 0
		while f.stoke(inv, "wood").ok and guard < 40: guard += 1
		var left := inv.count("wood")
		check(f.fuel_s <= f.max_fuel_s() and f.fuel_s + wood_s > f.max_fuel_s() and not f.stoke(inv, "wood").ok and inv.count("wood") == left, "%s: cap refuses a whole log, keeps it, never overfills" % t)
		var fuel := f.fuel_s
		f.advance(fuel + 120)
		check(not f.is_lit() and f.has_embers() and is_equal_approx(f.ember_s, f.ember_full_s() - 120), "%s: burnt out fire smoulders for its ember window" % t)
		check(f.heat_at(0.5) == 0 and f.glow() > 0 and f.glow() < 0.3, "%s: embers glow dully and give no heat" % t)
		res = f.stoke(inv, "wood")
		check(res.ok and inv.count("matches") == 1 and f.fuel_s == wood_s and f.ember_s == 0, "%s: fuel on embers relights without a match" % t)
		f.advance(wood_s + f.ember_full_s() + 1)
		check(f.needs_starter() and not f.has_embers(), "%s: after the ember window it is cold again" % t)
		var wet := FireSource.new(t); wet.set_fuel(60); wet.advance(60 + f.ember_full_s() * 0.5 * 0.99, 2.0)
		check(wet.has_embers() and wet.ember_s < f.ember_full_s() * 0.02 + 1, "%s: snow/rain (rate 2) halves the ember window" % t)
		# work progresses only with real burn
		var cook := FireSource.new(t); var food := Inventory.new(); food.add("trout_raw", 1)
		cook.set_fuel(300); cook.cooking.begin(food, true); food.add("snow_portion", 1); food.add("empty_bottle", 1); cook.water.begin(food)
		cook.advance(900)
		check(cook.cooking.portions[0].remaining_s == 900 and cook.water.remaining_s == 900, "%s: pans and kettle advance only during real burn" % t)
		check(cook.cooking.capacity == int(FireSource.type_spec(t).cook_slots), "%s: pan count from data" % t)
		check((cook.rack != null) == bool(FireSource.type_spec(t).rack), "%s: drying rack module from data" % t)
		# beacon
		var bus := NoiseBus.new(); var got: Array = []
		bus.light.connect(func(_p: Vector3, r: float, _s: Object) -> void: got.append(r))
		var lit := FireSource.new(t); lit.set_fuel(3600)
		lit.cue(bus, Vector3.ZERO, 1.0, 1.0, null); lit.cue(bus, Vector3.ZERO, 0.0, 1.0, null)
		FireSource.new(t).cue(bus, Vector3.ZERO, 1.0, 1.0, null)
		check(got.size() == 2 and is_equal_approx(got[0], float(lit.spec.light_r)) and is_equal_approx(got[1], float(lit.spec.smoke_r)), "%s: lit fire is a beacon (light at night, smoke by day); cold fire is not" % t)
		# save
		var copy := FireSource.new(t); copy.restore(JSON.parse_string(JSON.stringify(cook.to_dict())))
		check(JSON.stringify(copy.to_dict()) == JSON.stringify(cook.to_dict()), "%s: save round-trip is exact" % t)
		var legacy := FireSource.new(t); legacy.restore({"fuel_s": 100 * 3600})
		check(legacy.fuel_s == legacy.max_fuel_s(), "%s: over-cap legacy fuel clamps to the standard" % t)
	var room := FireSource.new("wood_stove"); room.set_fuel(3600)
	check(room.heat_at(1.0, false) == 0 and room.heat_at(1.0, true) > room.heat_at(2.5, true), "stove heats only its own room, strongest near it")
	var camp := FireSource.new("campfire"); camp.set_fuel(3600)
	check(camp.heat_at(1.0) > camp.heat_at(4.0) and camp.heat_at(7.5) == 0, "campfire radiates and falls off by 7 m")

	# Real world: the three existing fires share one interaction contract.
	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening != null and w.gear != null: break
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs; w.inv.add("wood", 3); w.inv.add("stick", 2); w.inv.add("matches", 1)
	var cb: Cabin = w.cabins[0]; cb.stove_fuel_s = 0; w.opening.fuel_s = 0
	var cf := Campfire.new(); w.add_child(cf); w.campfires.append(cf); freeze(cf); cf.global_position = w.player.position + Vector3(3, 0, 0); cf.fuel_s = 0
	var sources := {"lookout": w.opening.fire, "cabin": cb.fire, "campfire": cf.fire}
	for key: String in sources:
		var src: FireSource = sources[key]
		var acts: Array = w.fire_actions(src, Vector3.ZERO)
		var stokes := acts.filter(func(a: Dictionary) -> bool: return a.tag == "stoke")
		check(stokes.size() == 2 and String(stokes[0].text).begins_with("Light " + src.label()) and String(stokes[0].text).contains("firewood") and String(stokes[1].text).contains("sticks"), "%s offers one light/stoke entry per carried fuel, longest first: %s" % [key, stokes[0].text if not stokes.is_empty() else ""])
		check(stokes.all(func(a: Dictionary) -> bool: return float(a.hold) == 2.0), "%s stoke is the same 2 s hold" % key)
	w.inv.add("matches", 2)
	(w.fire_actions(cb.fire, Vector3.ZERO)[0].act as Callable).call()
	check(cb.is_lit() and w.inv.count("wood") == 2 and w.inv.count("matches") == 2, "cabin stove lights through the shared action")
	cf.fuel_s = 0; cf.fire.ember_s = 300
	var relight: Dictionary = w.fire_actions(cf.fire, Vector3.ZERO)[0]
	check(String(relight.text).begins_with("Relight fire"), "campfire with embers offers relight: " + String(relight.text))
	(relight.act as Callable).call()
	check(cf.is_lit() and w.inv.count("matches") == 2 and w.inv.count("wood") == 1, "campfire relights from embers without a match (fixes free cold relight)")
	cf.fuel_s = 0
	var cold: Dictionary = w.fire_actions(cf.fire, Vector3.ZERO)[0]
	w.inv.counts.erase("matches"); (cold.act as Callable).call()
	check(not cf.is_lit() and w.inv.count("wood") == 1, "a cold campfire no longer relights for free")
	check(cb.fire.rack != null and cb.drying_rack != null and w.fire_actions(cb.fire, Vector3.ZERO).any(func(a: Dictionary) -> bool: return a.tag == "rack"), "cabin stove has the lookout's drying rack")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	check(snap.cabins[0].has("fire") and snap.fires[-1].has("fire") and snap.opening.home.has("fire"), "all three fires save in the one schema")
	w.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("FIRE_SOURCES_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
