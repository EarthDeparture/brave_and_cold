extends SceneTree
## Interior lighting standard: every enclosed building gets window pools, a bounce
## fill and (with a stove) a warm fire bounce, driven by sky, weather and openings.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func spot_sum(il: InteriorLighting) -> float:
	var e := 0.0
	for s in il._spots: e += s.light_energy
	return e
func run() -> void:
	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening != null and w.gear != null and w.collapse != null: break
	freeze(w); w.out_path = "test-no-autosave"; w._frames = 100
	var all := get_nodes_in_group("interior_lighting")
	var cb: Cabin = w.cabins[0]; var store: Store = w.stores[0]
	check(cb.interior != null and store.interior != null and (w.huts.is_empty() or (w.huts[0] as Hut).interior != null) and (w.collapse.clinic == null or w.collapse.clinic.interior != null), "cabins, store, huts and clinic all use the interior standard")
	check(all.size() >= w.cabins.size() + w.stores.size() + w.huts.size(), "every building registers for central updates (%d rigs)" % all.size())
	check(cb.interior.window_count() == cb.openings.size() and store.interior.window_count() == 4, "one daylight pool per window")
	var shadowed := 0
	for s in store.interior._spots: shadowed += 1 if s.shadow_enabled else 0
	check(shadowed <= 2 and store.interior._spots.all(func(s: SpotLight3D) -> bool: return s.distance_fade_enabled), "shadow-casting pools are capped and all lights fade with distance")
	cb.interior.update(1.0, 0.0, 0.0); var noon := spot_sum(cb.interior); var fill_noon: float = cb.interior._fill.light_energy
	cb.interior.update(1.0, 1.0, 0.8); var storm := spot_sum(cb.interior)
	cb.interior.update(0.0, 0.0, 0.0); var night := spot_sum(cb.interior)
	check(noon > storm and storm > 0.0 and night == 0.0 and cb.interior._fill.light_energy < fill_noon * 0.2, "daylight pools follow sky: bright noon > storm > none at night; fill falls to moonlight")
	var o: Opening = cb.openings[0]
	cb.interior.update(1.0, 0.0, 0.0); var before: float = cb.interior._spots[0].light_energy
	o.curtain = true; cb.interior.update(1.0, 0.0, 0.0)
	check(cb.interior._spots[0].light_energy == 0.0 and before > 0.0, "a curtained window lets no daylight pool in")
	o.curtain = false; o.boards = 3; cb.interior.update(1.0, 0.0, 0.0)
	check(is_equal_approx(cb.interior._spots[0].light_energy, before * 0.4), "boards cut the pool to the gaps between them")
	o.boards = 0
	cb.stove_fuel_s = 0; cb.fire.ember_s = 0; cb.interior.update(0.0, 0.0, 0.0)
	var cold: float = cb.interior._fire_fill.light_energy
	cb.stove_fuel_s = 3600; cb.interior.update(0.0, 0.0, 0.0)
	check(cold == 0.0 and cb.interior._fire_fill.light_energy > 0.4, "the stove's FireSource glow lights the room at night")
	check(store.interior._fire_fill != null and (w.huts as Array).all(func(h: Hut) -> bool: return h.interior._fire_fill != null), "the store pot-belly and hut box stoves bounce firelight too (F5)")
	var clinic = w.collapse.clinic if w.collapse != null else null
	check(clinic == null or clinic.interior._fire_fill == null, "a building without a stove has no fire bounce")
	w.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("INTERIOR_LIGHTING_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
