extends SceneTree
## Small game: a hare at its warren, and a set snare with a catch.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func shot(at:Vector3,eye_off:Vector3,id:String)->void:
	w.player.position=at+eye_off;w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(at);w.player.cam.make_current()
	for frame in 30:await process_frame
	get_root().get_texture().get_image().save_png("res://shots/smallgame/"+id+".png");print("SG_CAPTURE ",id)
func run()->void:
	root.size=Vector2i(1280,720);SaveGame.pending={};seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/smallgame"))
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 700:
		await process_frame
		if w.opening!=null and w.hud!=null and w.collapse!=null:break
	freeze(w);w.hud.visible=false;w.viewmodel.visible=false;w.player.cam.fov=55
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0)
	w.clock.hour=13.0;w.sky_rig.apply_hour(13.0);w._indoor_k=0.0
	var r:Rabbit=w.rabbits[0]
	r.state=Rabbit.State.NIBBLE;r._t=0.5;r._animate(0.016)
	await shot(r.global_position+Vector3(0,.15,0),Vector3(1.4,.6,1.2),"hare_nibble")
	r.state=Rabbit.State.HOP;r._hop=1.2;r.speed_now=1.4;r._animate(0.016)
	await shot(r.global_position+Vector3(0,.15,0),Vector3(-1.1,.4,1.0),"hare_hop")
	var s:Snare=w._add_snare(w._ground(w.warrens[0].x+2,w.warrens[0].z),0.6);s.set_caught(true)
	await shot(s.point(),Vector3(1.2,.8,1.0),"snare_caught")
	quit(0)
