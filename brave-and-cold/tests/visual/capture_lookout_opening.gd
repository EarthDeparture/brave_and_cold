extends SceneTree
var w:Node3D
var output := "res://shots/lookout-opening"
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func frame_wait()->void:
	for frame in 20:await process_frame
func camera(at:Vector3,target:Vector3)->void:
	w.player.position=at;w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(target);w.player.cam.make_current()
func home_camera(local:Vector3,target:Vector3)->void:
	camera(w.fire_lookout.to_global(local+Vector3.UP*FireLookout.DECK_Y),w.fire_lookout.to_global(target+Vector3.UP*FireLookout.DECK_Y))
func shot(id:String)->void:
	await frame_wait()
	get_root().get_texture().get_image().save_png(output+"/"+id+".png")
	print("OPENING_CAPTURE ",id)
func hour(value:float)->void:
	w.clock.hour=value;w.sky_rig.apply_hour(value);w.sky_rig.apply_shelter(1)
func run()->void:
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.hud!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	var op:LookoutOpening=w.opening
	hour(10)
	home_camera(Vector3(.18,1.65,1.82),Vector3(-.28,.82,-.70))
	op.home_model.visible=false
	await shot("home_before")
	op.home_model.visible=true
	await shot("home_day")
	hour(22);op.fuel_s=7200;op.state.last_s=0;op.state.lamp_on=true;op.update_presentation()
	home_camera(Vector3(.45,1.60,.20),Vector3(-.95,.82,.15))
	await shot("home_warm_night")
	op.state.last_s=op.state.grid_fail_s;op.state.backup_on=false;op.update_presentation()
	await shot("home_stove_only")
	op.state.backup_on=true;op.update_presentation()
	await shot("home_backup")
	home_camera(Vector3(-1.65,1.38,1.94),Vector3(-1.65,.50,1.40))
	await shot("stove_detail")
	hour(10);w.sky_rig.apply_shelter(0)
	var at:Vector3=op.relay.to_global(Vector3(5,2.2,7))
	camera(at,op.relay.to_global(Vector3(0,3,-.4)))
	await shot("relay_site")
	camera(w.fire_lookout.to_global(Vector3(-3,FireLookout.DECK_Y+4.5,3)),w.fire_lookout.to_global(Vector3(-1.65,FireLookout.DECK_Y+4.10,1.20)))
	await shot("chimney_smoke")
	camera(op.relay.to_global(Vector3(1.55,1.62,2.5)),op.relay.to_global(Vector3(0,1,.1)))
	await shot("relay_cabinet")
	var compound:RefugeBoundary=op.boundary
	camera(compound.to_global(compound.ground_local(1.70,9.5)+Vector3.UP*1.7),compound.to_global(Vector3(-.7,3,-1)))
	await shot("compound_gate")
	hour(12);w.sky_rig.apply_shelter(1)
	var store:Store=w.stores[0];store.set_night(0)
	camera(store.to_global(Vector3(.10,1.80,1.5)),store.to_global(Vector3(1.60,1.53,1.02)))
	await shot("reserved_case")
	hour(19)
	home_camera(Vector3(.05,1.56,.50),Vector3(1.40,.95,-1.30))
	op.state.last_s=7200;op.state.receiver_on=true;op.state.channel="work";op._radio_update();op.update_presentation()
	w.hud.visible=true;w.hud._ui.queue_redraw()
	await shot("live_dispatch")
	hour(7);op.state.last_s=0;op.state.receiver_on=false;op.state.backup_on=false;op.update_presentation();op._radio_update()
	home_camera(Vector3(0,1.70,.3),Vector3(0,1.2,-2.08))
	w.viewmodel.visible=true;w.viewmodel.set_process(true);w._update_viewmodel();w._update_prompt();w.hud._ui.queue_redraw()
	await shot("new_game_view")
	print("LOOKOUT_CAPTURE_DONE")
	w.queue_free();await process_frame;quit()
