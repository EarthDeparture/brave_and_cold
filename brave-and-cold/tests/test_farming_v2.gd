extends SceneTree
## Farming v2 (2026-10-22): generated crop models per stage, shallot / beet / radish, radish bolting for seed
## (the one saveable seed), shallot replanting, compost (x1.3 growth, +1 yield), the greenhouse lantern for
## night growth (and its light lure), the snowmelt barrel for watering, the compost bin, the seed tin.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func grow(p: Dictionary, h: float, c := 20.0, light := 1.0) -> void:
	for i in int(h * 4.0): Farming.advance(p, 900.0, c, light); p.water = 1.0
func run() -> void:
	create_timer(170).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	seed(20261022)
	# ---- data + models
	var ids := Farming.crop_ids()
	check(ids.size() == 6 and ids.has("shallot") and ids.has("beet") and ids.has("radish"), "six crops (%s)" % str(ids))
	var missing: Array = []
	for cid in ids:
		for st in ["s0", "s1", "s2", "s3", "dead"] + (["bolt"] if cid == "radish" else []):
			if Greenhouse._crop_mesh("crop_%s_%s" % [cid, st]) == null: missing.append("%s_%s" % [cid, st])
	check(missing.is_empty(), "a generated model for every crop and stage %s" % str(missing))
	var inv := Inventory.new()
	# ---- stages
	var p := Farming.new_plot(); inv.add("radish_seeds", 2)
	check(Farming.plant(p, "radish", inv).begins_with("Planted") and Farming.stage(p) == "s0", "radish sown: sprout stage")
	grow(p, 10.0); var mid := Farming.stage(p)
	grow(p, 10.0)
	check(Farming.ripe(p) and Farming.stage(p) == "s3" and mid in ["s1", "s2"], "radish grows through the stages to ready in ~18 h (mid %s)" % mid)
	# ---- bolting: left ripe it goes to seed; the harvest is seed
	grow(p, 21.0)
	check(bool(p.bolted) and Farming.stage(p) == "bolt", "left ripe 20 h in the warm, the radish bolts")
	var before := inv.count("radish_seeds")
	var msg := Farming.harvest(p, inv)
	check(inv.count("radish_seeds") >= before + 2 and inv.count("radish") == 0, "bolted radish gives seed, no roots (%s)" % msg)
	# ---- biennials: no bolting
	var b := Farming.new_plot(); inv.add("beet_seeds"); Farming.plant(b, "beet", inv); grow(b, 52.0); grow(b, 40.0)
	check(Farming.ripe(b) and not bool(b.get("bolted", false)), "beet (biennial) never bolts in a season")
	# ---- shallot replant loop
	var s := Farming.new_plot(); inv.add("shallot")
	Farming.plant(s, "shallot", inv); grow(s, 45.0); Farming.harvest(s, inv)
	check(inv.count("shallot") >= 4, "one shallot bulb grows a cluster to replant (%d)" % inv.count("shallot"))
	# ---- compost: faster, +1
	var pa := Farming.new_plot(); var pb := Farming.new_plot(); inv.add("carrot_seeds", 2); inv.add("compost")
	Farming.plant(pa, "carrot", inv); Farming.plant(pb, "carrot", inv)
	check(Farming.add_compost(pb, inv) == "Worked compost into the plot" and inv.count("compost") == 0, "compost worked into a plot")
	grow(pa, 10.0); grow(pb, 10.0)
	check(absf(float(pb.growth) / float(pa.growth) - 1.3) < 0.02, "composted plot grows x1.3 (%.3f vs %.3f)" % [pb.growth, pa.growth])
	grow(pa, 40.0); grow(pb, 40.0)
	var c0 := inv.count("carrot"); Farming.harvest(pb, inv)
	check(inv.count("carrot") - c0 >= 3, "and gives one more (%d carrots, base 2-3)" % (inv.count("carrot") - c0))
	# ---- live greenhouse props
	SaveGame.pending = {}
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	check(not w.greenhouses.is_empty(), "the hamlet greenhouse exists")
	var g: Greenhouse = w.greenhouses[0]
	var gi: Inventory = w.inv
	var say := func(_m: String) -> void: pass
	var tin_act: Array = g.actions(gi, say).filter(func(a: Dictionary) -> bool: return String(a.text).contains("seed tin"))
	check(tin_act.size() == 1, "the gardener's seed tin is on the shelf")
	(tin_act[0].act as Callable).call()
	check(gi.count("radish_seeds") >= 2 and gi.count("beet_seeds") >= 2 and gi.count("shallot") >= 3 and gi.count("lamp_oil") >= 1 and g.tin_taken, "the tin: radish + beet seed, shallots, lamp oil")
	check(g.actions(gi, say).filter(func(a: Dictionary) -> bool: return String(a.text).contains("seed tin")).is_empty(), "and only once")
	# lantern: night growth
	g.plots[0] = Farming.new_plot(); Farming.plant(g.plots[0], "beet", gi); (g.plots[0] as Dictionary).water = 1.0
	g.light = 0.0
	g.advance(3600.0, 18.0)
	check(float(g.plots[0].growth) == 0.0, "dark night, no lantern: no growth")
	var lact: Array = g.actions(gi, say).filter(func(a: Dictionary) -> bool: return String(a.text).begins_with("Fill the lantern"))
	check(lact.size() == 1, "lamp oil fills the lantern"); (lact[0].act as Callable).call()
	g.advance(3600.0, 18.0)
	check(g.lantern_lit() and float(g.plots[0].growth) > 0.0 and float(g.lantern.oil_h) < 10.0, "lit lantern: half-pace growth at night, burning oil")
	var lit := []
	w.noise_bus.light.connect(func(_p: Vector3, r: float, src: Object) -> void: if src == g: lit.append(r))
	g.lantern_cue(w.noise_bus, 1.0)
	check(not lit.is_empty() and float(lit[0]) > 40.0, "and it is a light beacon at night (%s m)" % str(lit))
	# snowmelt barrel
	gi.add("snow_portion", 6)
	var bact: Array = g.actions(gi, say).filter(func(a: Dictionary) -> bool: return String(a.text).begins_with("Tip snow"))
	(bact[0].act as Callable).call()
	check(gi.count("snow_portion") == 0 and float(g.barrel.snow_kg) >= 3.0, "snow tipped into the melt barrel")
	g.advance(3 * 3600.0, 12.0)
	check(float(g.barrel.water_l) >= 2.9, "it melts by the stove (%.1f L)" % float(g.barrel.water_l))
	(g.plots[0] as Dictionary).water = 0.1
	var bottles := gi.count("clean_water")
	Farming.water(g.plots[0], gi, g.barrel)
	check(gi.count("clean_water") == bottles and float(g.plots[0].water) > 0.5, "beds watered from the barrel, no drinking water used")
	# compost bin
	gi.add("rotten_meat", 3)
	for k in 3:
		var cact: Array = g.actions(gi, say).filter(func(a: Dictionary) -> bool: return String(a.text).begins_with("Add rotten meat"))
		(cact[0].act as Callable).call()
	check(int(g.compost_bin.loads) == 3, "three loads of rotten meat in the compost")
	g.advance(49 * 3600.0, 12.0)
	check(int(g.compost_bin.ready) == 2, "two warm days later: two loads of compost")
	# save round trip
	var d := g.state_dict()
	check(d.has("barrel") and d.has("compost") and d.has("lantern") and bool(d.tin), "greenhouse saves barrel, compost, lantern, tin")
	w.queue_free(); await process_frame; await process_frame
	print("FARMING_V2_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
