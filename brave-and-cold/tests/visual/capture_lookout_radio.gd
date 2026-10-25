extends SceneTree
const OUTPUT := "res://shots/lookout-stairs-radio-logs/"
var w: Node3D
func _initialize() -> void: call_deferred("run")
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child)
func camera(local: Vector3, target: Vector3) -> void:
	w.player.position=w.fire_lookout.to_global(local+Vector3.UP*FireLookout.DECK_Y)
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.fire_lookout.to_global(target+Vector3.UP*FireLookout.DECK_Y));w.player.cam.make_current()
func shot(id: String) -> void:
	for frame in 20:await process_frame
	root.get_texture().get_image().save_png(OUTPUT+id+".png");print("RADIO_CAPTURE ",id)
func run() -> void:
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.clock.hour=10;w.sky_rig.apply_hour(10);w.sky_rig.apply_shelter(1)
	camera(Vector3(1.60,1.48,-.62),Vector3(1.80,1.06,-1.17))
	await shot("receiver_off_day")
	w.opening.toggle_receiver();await shot("receiver_public_day")
	w.clock.hour=22;w.sky_rig.apply_hour(22);w.opening.state.lamp_on=false;w.opening.update_presentation()
	await shot("receiver_public_night")
	w.opening.state.last_s=w.opening.state.grid_fail_s+1;w.opening.state.backup_on=false;w.opening.update_presentation()
	await shot("receiver_without_power")
	w.clock.hour=10;w.sky_rig.apply_hour(10);w.sky_rig.apply_shelter(0)
	camera(Vector3(5.80,1.70,2.20),Vector3(5.80,-.60,.9));await shot("top_stair_descent")
	var landing_y:=9*FireLookout.FLIGHT_RISE-FireLookout.DECK_Y
	camera(Vector3(5.125,landing_y+1.60,-2.22),Vector3(5.125,landing_y+.97,-1.48));await shot("joined_stair_nose")
	w.queue_free();await process_frame;print("RADIO_CAPTURE_DONE");quit()
