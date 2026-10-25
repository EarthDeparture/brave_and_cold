extends SceneTree
var w:Node3D
const OUTPUT:="res://shots/lookout-door-stove-log/"
func _initialize() -> void:call_deferred("run")
func freeze(node:Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child:Node in node.get_children():freeze(child)
func camera(local:Vector3,target:Vector3) -> void:
	w.player.position=w.fire_lookout.to_global(local+Vector3.UP*FireLookout.DECK_Y)
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.fire_lookout.to_global(target+Vector3.UP*FireLookout.DECK_Y));w.player.cam.make_current()
func shot(id:String) -> void:
	for frame:int in 25:await process_frame
	root.get_texture().get_image().save_png(OUTPUT+id+".png");print("LOOKOUT_FIX_CAPTURE ",id)
func run() -> void:
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame:int in 600:
		await process_frame
		if w.reading!=null and w.opening!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.clock.hour=10;w.sky_rig.apply_hour(10);w.sky_rig.apply_shelter(1)
	camera(Vector3(0,1.60,3.05),Vector3(0,1.10,2.15))
	await shot("door_closed_outside")
	w.fire_lookout.restore_door({"open":true});await shot("door_open_outside")
	w.fire_lookout.restore_door({"boards":3})
	camera(Vector3(.1,1.60,.25),Vector3(0,1.10,2.20));await shot("door_boarded_inside")
	w.fire_lookout.restore_door({})
	var stove:=FireLookout.STOVE_CENTER
	var turn:=Basis(Vector3.UP,FireLookout.STOVE_YAW)
	camera(stove+turn*Vector3(0,1.35,1.00),stove+turn*Vector3(0,.52,.25))
	await shot("stove_faces_room_day")
	w.clock.hour=22;w.sky_rig.apply_hour(22);w.opening.update_presentation();await shot("stove_faces_room_night")
	w.clock.hour=10;w.sky_rig.apply_hour(10)
	camera(Vector3(0,1.70,.3),Vector3(.95,.90,-1.35))
	w.hud.visible=true;w.opening.read_log();w.hud._ui.queue_redraw();await shot("service_log_1600")
	root.size=Vector2i(800,600);await shot("service_log_800")
	w.reading.close();w.queue_free();await process_frame;print("LOOKOUT_FIX_CAPTURE_DONE");quit()
