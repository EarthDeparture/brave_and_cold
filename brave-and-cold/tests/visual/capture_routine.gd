extends SceneTree
## Plan A3 review: residents' day. -> res://shots/routine/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(20)
	root.get_texture().get_image().save_png("res://shots/routine/" + id + ".png"); print("RT_CAPTURE ", id)
func at(day: int, hour: float) -> void:
	w.clock.day = day; w.clock.hour = hour; w.town_life._last_calendar = -1; w.town_life.update(0)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/routine"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.town_life != null and w.hud != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.time_scale = 0.0; w.hud.visible = false; w.rifle_up = false
	w.weather.set_state(0, true); w.weather.locked = true
	var life: TownLife = w.town_life
	var c := Camera3D.new(); c.fov = 60; c.near = 0.05; root.add_child(c); c.make_current()
	c.global_position = Vector3(0, 900, 0); c.look_at(Vector3(1, 1800, 0), Vector3.FORWARD)
	w.player.cam.global_position = Vector3(0, 900, 0); w.player.cam.look_at(Vector3(1, 1800, 0), Vector3.FORWARD)
	var lc: Cabin = life.homes.lin
	at(1, 19.5)
	await frames(30)
	var lin: TownResident = life.actors.lin
	w.player.place(lc.global_position.x, lc.global_position.z)   # so the resident processes (within 100 m)
	await frames(10)
	w.player.cam.global_position = Vector3(0, 900, 0)
	c.global_position = lc.to_global(Vector3(1.2, 0, 1.4)) + Vector3(0, lc.floor_y - lc.global_position.y + 1.55, 0)
	c.look_at(lin.global_position + Vector3.UP * 1.1, Vector3.UP)
	await shot("lin_home_evening")
	at(1, 23.5)
	await frames(30)
	c.global_position = lc.to_global(Vector3(-0.6, 0, -0.2)) + Vector3(0, lc.floor_y - lc.global_position.y + 1.6, 0)
	c.look_at(lc.to_global(Vector3(2.0, 0, -1.65)) + Vector3(0, lc.floor_y - lc.global_position.y + 0.5, 0), Vector3.UP)
	await shot("lin_asleep")
	c.global_position = lc.to_global(Vector3(2.0, 0, -0.2)) + Vector3(0, lc.floor_y - lc.global_position.y + 1.25, 0)
	c.look_at(lc.to_global(Vector3(2.0, 0, -1.65)) + Vector3(0, lc.floor_y - lc.global_position.y + 0.55, 0), Vector3.UP)
	await shot("lin_asleep_side")
	c.global_position = lc.to_global(Vector3(0, 0, 18)) + Vector3(0, 3.0, 0); c.look_at(lc.global_position + Vector3.UP * 2.0, Vector3.UP)
	at(1, 20.5); await frames(40)
	await shot("hamlet_evening_home_lit")
	at(1, 2.5); await frames(40)
	await shot("hamlet_2am_dark")
	var st: Store = life.store
	at(1, 19.0)
	w.player.place(st.global_position.x + 8, st.global_position.z); await frames(10)
	w.player.cam.global_position = Vector3(0, 900, 0)
	var rowan: TownResident = life.actors.rowan
	c.global_position = st.to_global(Vector3(1.4, Store.FLOOR_LOCAL_Y + 1.6, 1.4)); c.look_at(rowan.global_position + Vector3.UP * 1.1, Vector3.UP)
	await shot("rowan_shop_stove")
	c.global_position = st.to_global(Vector3(0, 1.7, Store.HZ + 9)); c.look_at(st.global_position + Vector3.UP * 1.5, Vector3.UP)
	await shot("store_evening_closed")
	at(1, 13.2); await frames(10)
	var sam: TownResident = life.actors.sam
	var cl: Node3D = w.collapse.clinic
	var away: Vector3 = sam.global_position - cl.global_position; away.y = 0
	c.global_position = sam.global_position + away.normalized().rotated(Vector3.UP, 0.6) * 4.0 + Vector3(0, 1.6, 0); c.look_at(sam.global_position + Vector3.UP * 1.3, Vector3.UP)
	await shot("sam_smoke_break")
	quit(0)
