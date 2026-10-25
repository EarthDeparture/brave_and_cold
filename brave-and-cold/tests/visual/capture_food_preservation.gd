extends SceneTree
const OUT:="res://shots/food-preservation-2026-10-07/"
var w:Node3D
func _initialize() -> void:call_deferred("run")
func freeze(n:Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func shot(id:String) -> void:
	for frame in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png");print("FOOD_CAPTURE ",id)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null:break
	freeze(w);w.out_path="capture-no-autosave";w._frames=100;w.hud.hide();w.viewmodel.hide()
	w.weather.lock_state(Weather.S.CLEAR);w.clock.hour=12;w.sky_rig.apply_hour(12)
	var op:LookoutOpening=w.opening;var tower:FireLookout=w.fire_lookout
	w.player.position=op.home_point(Vector3(-.7,Player.EYE,.5));w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(op.home_point(Vector3(-2.10,.70,.35)));await shot("rack-empty")
	w.inv.add("venison_cooked",4);op.fuel_s=9000;op.dry_food();await shot("rack-loaded")
	w._act={"text":"Load cooked meat"};op._process(.5);await shot("rack-door-open")
	w._act={};op._process(.5)
	w.clock.hour=0;op.state.grid_fail_s=0;op.state.backup_on=false;op.update_presentation();w.sky_rig.apply_hour(0);await shot("rack-night-fire")
	w.weather.lock_state(Weather.S.BLIZZARD);w.clock.hour=12;w.sky_rig.apply_hour(12);await shot("rack-blizzard-light")
	w.weather.lock_state(Weather.S.CLEAR);w.sky_rig.apply_hour(12);op.advance(7200)
	op.read_food_notes();await shot("food-notes");w.reading.close()
	op.take_dried();await shot("rack-collected")
	w.drop_item("venison_dried",1)
	var pickup:ItemPickup
	for node:ItemPickup in get_nodes_in_group("pickups"):
		if node.id=="venison_dried":pickup=node
	if pickup!=null:
		w.player.cam.look_at(pickup.global_position);await shot("dried-food-pickup")
	print("FOOD_CAPTURE_DONE gpu=",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};quit()
