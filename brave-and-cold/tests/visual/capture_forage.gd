extends SceneTree
## N3 forage nodes in place: rose bush, reishi stump, birch log (full and harvested).
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func shot(f:ForageNode,dist:float,h:float,id:String)->void:
	var aim:=f.aim_point();var dir:=Vector3(0.7,0,0.7).normalized()
	w.player.position=aim+dir*dist+Vector3(0,h,0);w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(aim);w.player.cam.make_current()
	for frame in 40:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/forage/"+id+".png");print("FORAGE_CAPTURE ",id," at ",f.position)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/forage"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening!=null and w.hud!=null and w.collapse!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=60
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0)
	w.clock.hour=13.0;w.sky_rig.apply_hour(13.0);w._indoor_k=0.0
	for kind in ["rose","reishi","birch"]:
		var f:ForageNode=null
		for n:ForageNode in w.forage:
			if n.kind==kind:f=n;break
		if f==null:continue
		await shot(f,2.2 if kind!="birch" else 3.0,0.9,kind)
		f.set_harvested(true);await shot(f,1.6,0.6,kind+"_done")
	quit(0)
