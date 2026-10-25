extends SceneTree
## Reclaimed wood: cabin furniture breaks down into planks + sticks with a hatchet or
## hammer, disappears, stays broken across save/load, and the planks burn in the stove.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func build(saved: Dictionary = {}) -> Node3D:
	SaveGame.pending = saved; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null: break
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	return w
func run() -> void:
	var w: Node3D = await build()
	var cb: Cabin = w.cabins[0]
	check(cb._furniture.size() == 3 and w.cabins.all(func(c: Cabin) -> bool: return c._furniture.size() == 3), "every cabin (start + hamlet) has a breakable table and two stools")
	w.inv = Inventory.new(w.body); w.inv.needs = w.needs
	var items: Array = w._furniture_items(cb)
	check(items.size() == 3 and items.all(func(a: Dictionary) -> bool: return String(a.text).contains("needs hatchet or hammer") and not a.has("hold")), "without a tool the furniture only explains what is needed")
	w.inv.add("hammer")
	var stool: Dictionary = w._furniture_items(cb).filter(func(a: Dictionary) -> bool: return String(a.text).contains("stool"))[0]
	check(float(stool.hold) == 7.5 and float(stool.noise) >= 30.0, "a hammer works but is slower; breaking furniture is loud")
	w.inv.add("axe")
	var table: Dictionary = w._furniture_items(cb).filter(func(a: Dictionary) -> bool: return String(a.text).contains("table"))[0]
	check(float(table.hold) == 10.0, "hatchet breaks the table in 10 s")
	(table.act as Callable).call()
	check(w.inv.count("plank") == 3 and w.inv.count("stick") == 2 and "Furn_table" in cb.broken and not (cb._furniture.Furn_table as Node3D).visible, "table gives 3 planks + 2 sticks and is gone")
	check(w._furniture_items(cb).size() == 2, "a broken table is no longer offered")
	cb.stove_fuel_s = 0; cb.fire.ember_s = 0; w.inv.add("matches", 1)
	var res: Dictionary = cb.fire.stoke(w.inv, "plank")
	check(res.ok and cb.stove_fuel_s == 3600, "reclaimed plank burns 1 h in the stove")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free(); await process_frame; await process_frame
	var w2: Node3D = await build(snap)
	var cb2: Cabin = w2.cabins[0]
	check("Furn_table" in cb2.broken and not (cb2._furniture.Furn_table as Node3D).visible and (cb2._furniture.Furn_stool_a as Node3D).visible, "broken furniture stays broken after save/load")
	w2.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("FURNITURE_FUEL_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
