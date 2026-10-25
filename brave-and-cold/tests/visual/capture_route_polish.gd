extends SceneTree
var w:Node3D
var output:="res://shots/route-polish-2026-10-07/before/"
var film:=false
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func view(at:Vector3,target:Vector3)->void:
	w.player.position=at;w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(target)
func shot(id:String)->void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+id+".png");print("ROUTE_CAPTURE ",id)
func weather(hour:float,state:int)->void:
	w.weather.lock_state(state);w.weather.advance(120,0);w.clock.hour=hour;w.sky_rig.apply_hour(hour);w.sky_rig.apply_shelter(0);w.road.update_weather(w.weather.precip)
func run()->void:
	create_timer(180).timeout.connect(func()->void:quit(2))
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("capture_out="):output=arg.trim_prefix("capture_out=")+"/"
		if arg=="gate_film=1":film=true
	root.size=Vector2i(1600,900);DirAccess.make_dir_recursive_absolute(output)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);w.out_path="capture-no-autosave";w._frames=100;w.hud.hide();w.viewmodel.hide();w.snowfall.hide();w.weather_presentation.hide()
	w.player.cam.fov=70;weather(12,Weather.S.CLOUDY)
	for index in [180,360]:
		var p:Vector2=w.road.points[index];var ahead:Vector2=w.road.points[index+14]
		view(Vector3(p.x,w.player.ground_at(p.x,p.y)+Player.EYE,p.y),Vector3(ahead.x,w.player.ground_at(ahead.x,ahead.y)+.8,ahead.y))
		await shot("road-%d"%index)
	var path:Array=w.fire_lookout.site.path.points_world_xyz
	for index in [4,75,165,238]:
		var a:Array=path[index];var b:Array=path[index+6]
		view(Vector3(a[0],w.player.ground_at(a[0],a[2])+Player.EYE,a[2]),Vector3(b[0],w.player.ground_at(b[0],b[2])+.65,b[2]))
		await shot("trail-%d"%index)
	var p:Array=path[165];var q:Array=path[171]
	view(Vector3(p[0],w.player.ground_at(p[0],p[2])+Player.EYE,p[2]),Vector3(q[0],w.player.ground_at(q[0],q[2])+.65,q[2]))
	weather(17.1,Weather.S.CLEAR);await shot("trail-dusk")
	weather(12,Weather.S.BLIZZARD);await shot("trail-storm-light")
	weather(12,Weather.S.CLOUDY)
	var gate:RefugeBoundary=w.opening.boundary
	view(gate.to_global(gate.ground_local(1.9,10)+Vector3.UP*Player.EYE),gate.to_global(gate.ground_local(1.9,7)+Vector3.UP*.9))
	gate.gate_open=false;gate.sync_gate();await shot("gate-closed")
	if film:
		gate.toggle_gate()
		for i in 42:
			gate._process(1.0/30);await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"gate-open-%03d.png"%i)
	gate.gate_open=true;gate.sync_gate();await shot("gate-open")
	if film:
		gate.toggle_gate()
		for i in 42:
			gate._process(1.0/30);await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"gate-close-%03d.png"%i)
	for id:String in ["service_marker","drain_headwall"]:
		for record:Dictionary in w.route_dressing.records:
			if record.id!=id:continue
			var model:Node3D=record.node
			view(model.to_global(Vector3(.65,1.65,3.2)),model.to_global(Vector3(0,.70 if id=="service_marker" else .3,0)))
			await shot(id);break
	# Show the settled surface mask explicitly; weather and survival remain frozen.
	weather(12,Weather.S.BLIZZARD);w.road.snow_cover=.9;w.road.update_weather(.9)
	w.fire_lookout.access_material.set_shader_parameter("fresh_snow",.9)
	view(Vector3(p[0],w.player.ground_at(p[0],p[2])+Player.EYE,p[2]),Vector3(q[0],w.player.ground_at(q[0],q[2])+.65,q[2]))
	await shot("trail-settled-snow")
	print("ROUTE_CAPTURE_DONE gpu=",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};quit()
