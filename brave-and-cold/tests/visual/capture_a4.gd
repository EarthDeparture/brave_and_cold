extends SceneTree
## Plan A4 pass 1 review -> res://shots/a4/: a hamlet cabin interior before / after a ransack, its doorway outside with
## the boot trail, a survivor's camp, a flare at night from ~1.2 km, the store fluorescents lit / grid down / aurora.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(14)
	root.get_texture().get_image().save_png("res://shots/a4/" + id + ".png"); print("A4_CAPTURE ", id)

func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261024)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/a4"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.rifle_up = false; w.hud.visible = false
	w.ambient_life.voices_enabled = false
	var we: WorldEvents = w.world_events
	we.enabled = false
	var cb: Cabin = w.cabins[2]
	var c := Camera3D.new(); c.fov = 70; c.near = 0.05; root.add_child(c); c.make_current()
	w.player.place(cb.global_position.x, cb.global_position.z)
	await frames(10)
	c.global_position = cb.to_global(Vector3(1.9, 1.75, 1.6)); c.look_at(cb.to_global(Vector3(-1.6, 0.6, 0.3)), Vector3.UP)
	await shot("cabin_before")
	w.player.place(cb.global_position.x + 400.0, cb.global_position.z)
	await frames(3)
	w.clock.day = 5
	we.ransack(2)
	w.player.place(cb.global_position.x, cb.global_position.z)
	await frames(6)
	print("A4 ransack broken=", cb.broken, " toppled=", cb.toppled, " door_broken=", cb.door_broken, " open=", cb.door_open)
	c.global_position = cb.to_global(Vector3(1.9, 1.75, 1.6)); c.look_at(cb.to_global(Vector3(-1.6, 0.6, 0.3)), Vector3.UP)
	await shot("cabin_after")
	var dp: Vector3 = cb.door_world_pos()
	var out: Vector3 = cb.to_global(Vector3(0.0, 0.0, Cabin.HZ + 7.0))
	out.y = w._ground_y(out.x, out.z) + 1.7
	w.player.place(out.x, out.z)
	await frames(6)
	c.global_position = out; c.look_at(dp + Vector3(0, 0.6, 0), Vector3.UP)
	await shot("cabin_door_trail")
	# camp site, close
	we.enabled = true
	we.fire_event("shots", false)
	var site: Node3D = null
	for n in get_nodes_in_group("event_sites"): if n.get_meta("kind") == "camp": site = n
	if site != null:
		var sp := site.global_position
		w.player.place(sp.x + 3.0, sp.z + 3.0)
		await frames(8)
		c.global_position = sp + Vector3(2.2, 1.55, 2.2); c.look_at(sp + Vector3(0, 0.0, 0), Vector3.UP)
		await shot("camp_close")
		c.global_position = sp + Vector3(6.0, 1.7, 6.0); c.look_at(sp, Vector3.UP)
		await shot("camp_wide")
	# flare at night from far
	w.clock.hour = 22.5
	w.player.place(cb.global_position.x, cb.global_position.z + 30.0)
	await frames(10)
	we.fire_event("flare", true)
	var f: Dictionary = we._flares[0] if we._flares.size() > 0 else {}
	await create_timer(4.0).timeout
	if not f.is_empty():
		var eye: Vector3 = w.player.cam.global_position
		c.global_position = eye; c.look_at((f.node as Node3D).global_position - Vector3(0, 40, 0), Vector3.UP)
		c.fov = 55
		await shot("flare_night")
		c.fov = 18
		c.look_at((f.node as Node3D).global_position - Vector3(0, 20, 0), Vector3.UP)
		await shot("flare_zoom")
	c.fov = 70
	# store lights
	var st: Node3D = w.stores[0] if w.stores.size() > 0 else null
	if st != null:
		var sl: StoreLights = null
		for ch in st.get_children(): if ch is StoreLights: sl = ch
		w.player.place(st.global_position.x, st.global_position.z)
		await frames(6)
		var ce := st.to_global(Vector3(2.4, 1.7, 1.7))
		w.clock.hour = 19.5
		sl.force_grid = true; sl.force_aurora = 0.0
		await create_timer(0.6).timeout
		c.global_position = ce; c.look_at(st.to_global(Vector3(-1.5, 1.2, -1.5)), Vector3.UP)
		await shot("store_lit_dusk")
		sl.force_grid = false
		await create_timer(1.6).timeout
		await shot("store_grid_down")
		sl.force_aurora = 0.95
		sl._hold = 3.0
		await frames(2)
		await shot("store_aurora_strike")
	quit(0)
