extends SceneTree
## Stair bay check: bottom exit clear of braces (bracing only in side planes), no floating rail links.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func shot(local:Vector3,target:Vector3,id:String)->void:
	var t:FireLookout=w.fire_lookout
	w.player.position=t.to_global(local);w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(t.to_global(target));w.player.cam.make_current()
	for frame in 20:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/lookout-stairs/"+id+".png");print("STAIR_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/lookout-stairs"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.hud!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=72
	w.clock.hour=12;w.sky_rig.apply_hour(12)
	await shot(Vector3(5.1,1.65,6.5),Vector3(5.1,1.2,0),"approach_bottom")
	await shot(Vector3(4.45,1.75,1.4),Vector3(4.45,1.5,7),"exit_lane_a")
	await shot(Vector3(5.8,1.75,1.4),Vector3(5.8,1.5,7),"exit_lane_b")
	await shot(Vector3(5.1,1.6,0.0),Vector3(5.1,9.0,-1.5),"under_flights")
	await shot(Vector3(9.5,4.0,-1.0),Vector3(5.1,4.5,0),"side_landings")
	quit(0)
