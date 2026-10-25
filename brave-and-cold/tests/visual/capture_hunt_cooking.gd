extends SceneTree
const OUT:="res://shots/hunt-cooking-2026-10-07/"
var w:Node3D
func _initialize() -> void:call_deferred("run")
func freeze(n:Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func shot(id:String) -> void:
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png");print("COOK_CAPTURE ",id)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null:break
	freeze(w);w.out_path="capture-no-autosave";w._frames=100;w.hud.hide();w.viewmodel.hide()
	w.weather.lock_state(Weather.S.CLEAR);w.clock.hour=12;w.sky_rig.apply_hour(12)
	var cb:Cabin=w.cabins[0];var stove:Vector3=Cabin.STOVE_LOCAL+Vector3(0,Cabin.FLOOR_LOCAL_Y+.77,.10)
	w.player.position=cb.to_global(stove+Vector3(.7,.95,1.0));w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(cb.to_global(stove));w._process(0);await shot("cabin-empty")
	w.inv.add("venison_raw",2);cb.stove_fuel_s=4800;cb.cooking.begin(w.inv,true);cb.cooking.begin(w.inv,true);cb.advance(0);cb._process(0)
	await shot("cabin-raw")
	cb.advance(1200);await shot("cabin-cooked")
	cb.cooking.collect(w.inv);cb.advance(0);await shot("cabin-collected")
	var op:LookoutOpening=w.opening
	w.player.position=op.home_point(Vector3(-.45,Player.EYE,.35));w.player.cam.look_at(op.home_point(Vector3(-1.65,.80,1.20)))
	w.inv.add("venison_raw");op.fuel_s=9000;op.cook();w._process(0);await shot("lookout-raw")
	op.advance(1200);await shot("lookout-cooked")
	w.clock.hour=0;op.state.grid_fail_s=0;op.state.backup_on=false;op.update_presentation();w.sky_rig.apply_hour(0);op._process(.1)
	await shot("lookout-night-fire")
	w.clock.hour=12;w.sky_rig.apply_hour(12);op.advance(240*3600);await shot("lookout-spoiled")
	print("COOK_CAPTURE_DONE gpu=",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};quit()
