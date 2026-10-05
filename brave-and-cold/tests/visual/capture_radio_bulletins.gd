extends SceneTree
const OUTPUT := "res://shots/radio-bulletins/"
var w: Node3D
func _initialize() -> void: call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child)
func camera(local: Vector3, target: Vector3) -> void:
	w.player.position=w.fire_lookout.to_global(local+Vector3.UP*FireLookout.DECK_Y)
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.fire_lookout.to_global(target+Vector3.UP*FireLookout.DECK_Y));w.player.cam.make_current()
func at(elapsed: float) -> void:
	var absolute: float=elapsed+w.opening.state.calendar_origin_s
	w.clock.total_game_s=elapsed;w.clock.day=int(floor(absolute/86400))+1;w.clock.hour=fposmod(absolute,86400)/3600
	w.opening.state.last_s=elapsed;w.opening.update_presentation();w.opening._radio_update()
	w.sky_rig.apply_hour(w.clock.hour)
func shot(id: String) -> void:
	for frame in 10:await process_frame
	root.get_texture().get_image().save_png(OUTPUT+id+".png");print("BULLETIN_CAPTURE ",id)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:print("FAIL capture timeout");quit(2))
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null:break
	freeze(w);w.viewmodel.visible=false;w.player.cam.fov=72;w.hud.show_monitor=false
	w.sky_rig.apply_shelter(1)
	camera(Vector3(1.6,1.48,-.62),Vector3(1.80,1.06,-1.17));at(23400+240)
	w.hud.visible=false;await shot("desk_off")
	w.opening.state.receiver_on=true;w.opening.update_presentation();w.opening._radio_update();await shot("desk_public_blue")
	w.hud.visible=true;w.hud._ui.queue_redraw();await shot("public_noon_caption")
	at(18.5*3600+240);w.hud._ui.queue_redraw();await shot("public_first_midnight")
	w.opening.read_log();await shot("communications_service_log");w.reading.close()
	w.sky_rig.apply_shelter(0)
	camera(Vector3(12,-FireLookout.DECK_Y+2,16),Vector3(17,-FireLookout.DECK_Y+1,26))
	w.player.position.y=w.terrain.data.get_height(w.player.position)+w.player.eye_h
	at(2.5*3600+240);w.opening.state.receiver_on=false;w.opening._radio_update();w.hud._ui.queue_redraw()
	await shot("personal_walkie_outside")
	at(74.5*3600+240);w.opening.state.battery_wh=0;w.opening.state.backup_on=false;w.opening._radio_update();w.hud._ui.queue_redraw()
	await shot("walkie_after_local_power_failure")
	w.queue_free();await process_frame;print("BULLETIN_CAPTURE_DONE");quit()
