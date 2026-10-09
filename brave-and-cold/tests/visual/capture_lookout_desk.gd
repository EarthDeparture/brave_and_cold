extends SceneTree
## Tower desk/chair check: the chair is tucked under the desk, backrest to the room.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func shot(local:Vector3,target:Vector3,id:String)->void:
	var t:FireLookout=w.fire_lookout
	w.player.position=t.to_global(local+Vector3.UP*FireLookout.DECK_Y);w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(t.to_global(target+Vector3.UP*FireLookout.DECK_Y));w.player.cam.make_current()
	for frame in 20:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/lookout-desk/"+id+".png");print("DESK_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/lookout-desk"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.hud!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.clock.hour=11;w.sky_rig.apply_hour(11);w.sky_rig.apply_shelter(1)
	await shot(Vector3(-.4,1.65,.9),Vector3(1.35,.55,-1.2),"desk_from_room")
	await shot(Vector3(1.35,1.65,.15),Vector3(1.35,.3,-1.0),"desk_standing_front")
	quit(0)
