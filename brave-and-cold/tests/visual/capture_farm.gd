extends SceneTree
## Farming v2 review: the greenhouse beds with every crop at a different stage, close-ups, the props, the
## lantern at night. -> res://shots/farm/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(25)
	root.get_texture().get_image().save_png("res://shots/farm/" + id + ".png"); print("FARM_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261022)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/farm"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 12.5
	var g: Greenhouse = w.greenhouses[0]
	var set_plot := func(i: int, crop: String, growth: float, extra := {}) -> void:
		var p: Dictionary = Farming.new_plot(); p.crop = crop; p.growth = growth; p.water = 0.8; p.merge(extra, true); g.plots[i] = p
	set_plot.call(0, "potato", 0.7); set_plot.call(1, "carrot", 1.0); set_plot.call(2, "kale", 0.9); set_plot.call(3, "shallot", 1.0)
	set_plot.call(4, "beet", 1.0); set_plot.call(5, "radish", 1.0, {"bolted": true}); set_plot.call(6, "radish", 1.0); set_plot.call(7, "potato", 0.6, {"dead": true})
	g.refresh_all(); g.tin_taken = false; g.barrel.water_l = 18.0; g.compost_bin.loads = 2; g._update_props()
	w.rifle_up = false; w.hud.visible = false
	var c := Camera3D.new(); c.fov = 60; c.near = 0.02; root.add_child(c); c.make_current()
	c.global_position = g.to_global(Vector3(0.0, Greenhouse.FT + 1.55, 2.0)); c.look_at(g.to_global(Vector3(0, 0.5, -0.4)), Vector3.UP)
	await shot("beds_day")
	for i in 8:
		var pw: Vector3 = g.plot_world(i)
		var side := -1.0 if Greenhouse.PLOTS[i].x < 0 else 1.0
		c.global_position = pw + g.global_basis * Vector3(-side * 0.55, 0.45, 0.25); c.look_at(pw + Vector3(0, 0.05, 0), Vector3.UP)
		await shot("plot_%d_%s" % [i, Farming.stage(g.plots[i])])
	c.global_position = g.to_global(Vector3(0.0, Greenhouse.FT + 1.3, -0.4)); c.look_at(g.to_global(Vector3(0, Greenhouse.FT + 0.4, 2.0)), Vector3.UP)
	await shot("props_door_end")
	w.clock.hour = 22.5; g.lantern.oil_h = 6.0; g.lantern.lit = true; g._update_props()
	c.global_position = g.to_global(Vector3(0.0, Greenhouse.FT + 1.55, 2.0)); c.look_at(g.to_global(Vector3(0, 0.5, -0.4)), Vector3.UP)
	await shot("beds_night_lantern")
	c.global_position = g.to_global(Vector3(6.0, 3.0, 9.0)); c.look_at(g.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	await shot("outside_night_lantern")
	quit(0)
