extends SceneTree
## Real greenhouse action prompts and transactions, without building the whole valley.
var checks := 0
var failures := 0
var quiet := func(_message: String) -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func action(g: Greenhouse, inv: Inventory) -> Dictionary:
	for a: Dictionary in g.actions(inv, quiet):
		if (a.pos as Vector3).is_equal_approx(g.plot_world(0)): return a
	return {}
func prompt(g: Greenhouse, inv: Inventory) -> String: return String(action(g, inv).get("text", ""))
func run() -> void:
	var g := Greenhouse.new(); root.add_child(g); g.room = RoomClimate.new(); g.room.room_c = 20.0; g.light = 1.0
	g.plots.append(Farming.new_plot()); var n := Node3D.new(); g.add_child(n); g._plants.append(n)
	var inv := Inventory.new()
	check(prompt(g, inv).begins_with("Empty plot") and not prompt(g, inv).contains("Too dark"), "empty plot keeps its seed guidance")
	inv.add("potato"); inv.add("clean_water")
	var sow := action(g, inv)
	check(String(sow.text).begins_with("Plant potatoes"), "carried seed still offers planting")
	(sow.act as Callable).call()
	check(inv.count("potato") == 0 and String(g.plots[0].crop) == "potato", "planting still spends one seed potato")
	check(prompt(g, inv).contains("Needs water") and prompt(g, inv).begins_with("Water potatoes"), "dry new crop explains the blocker and keeps the watering action")
	g.light = 0.0
	check(prompt(g, inv).contains("Needs water") and not prompt(g, inv).contains("Too dark"), "no water outranks darkness")
	g.room.room_c = -2.0
	check(prompt(g, inv).contains("Freezing") and not prompt(g, inv).contains("Needs water") and not prompt(g, inv).contains("Too dark"), "freezing outranks dryness and darkness with one explanation")
	var water := action(g, inv); (water.act as Callable).call()
	check(float(g.plots[0].water) > 0.0 and inv.count("clean_water") == 0 and inv.count("empty_bottle") == 1, "watering still works and returns the bottle")
	g.room.room_c = 20.0
	check(prompt(g, inv).contains("Too dark"), "warm watered crop explains missing light")
	g.lantern.lit = true; g.lantern.oil_h = 1.0
	check(not prompt(g, inv).contains("Too dark"), "a burning lantern clears the darkness explanation")
	var growth: float = g.plots[0].growth; g.advance(60, 20)
	check(float(g.plots[0].growth) > growth, "the same effective lantern light actually advances growth")
	g.lantern.lit = false
	check(prompt(g, inv).contains("Too dark"), "an extinguished lantern does not count as light")
	g.lantern.lit = true; g.lantern.oil_h = 0.0
	check(prompt(g, inv).contains("Too dark"), "an empty lantern does not count as light")
	g.light = 1.0; g.room.room_c = 5.0; g.plots[0].water = 1.0
	check(not prompt(g, inv).contains("Freezing"), "a cool room is not described as frozen")
	growth = g.plots[0].growth; g.advance(60, 5)
	check(float(g.plots[0].growth) > growth, "cool-room growth continues at its existing slower rate")
	g.room.room_c = 0.0
	check(not prompt(g, inv).contains("Freezing"), "zero degrees uses the existing non-freezing boundary")
	g.light = 0.001
	check(not prompt(g, inv).contains("Too dark"), "positive dim light is not described as zero growth")
	var state := (g.plots[0] as Dictionary).duplicate(true); var counts := inv.counts.duplicate(true)
	for i in 5: g.actions(inv, quiet)
	check(g.plots[0] == state and inv.counts == counts, "inspection alone never changes the plot or inventory")
	g.plots[0].growth = 1.0; g.plots[0].water = 0.0; g.room.room_c = -5.0; g.light = 0.0
	var harvest := action(g, inv)
	check(String(harvest.text).begins_with("Harvest potatoes") and not String(harvest.text).contains("Freezing"), "ripe crop keeps its harvest prompt")
	(harvest.act as Callable).call()
	check(inv.count("potato") >= 3 and String(g.plots[0].crop) == "", "harvest yield and empty plot behavior are preserved")
	g.plots[0].crop = "potato"; g.plots[0].dead = true
	check(prompt(g, inv).begins_with("Clear dead potatoes") and not prompt(g, inv).contains("Freezing"), "dead crop keeps its clearing prompt")
	g.queue_free(); await process_frame
	print("CROP_INSPECTION_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
