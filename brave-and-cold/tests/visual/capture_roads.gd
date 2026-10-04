extends SceneTree
## Seeded, matched full-world player-camera road/sign art review. No saves.
var options:Dictionary={}
var world:Node3D
var output:String
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.split("=",true,1);options[pair[0]]=pair[1] if pair.size()>1 else "1"
	output=String(options.get("capture_out","res://shots/roads-jump/candidate"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0,true);seed(20261003);SaveGame.pending={}
	world=load("res://world/game_world.gd").new();root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud!=null:break
	if world.hud==null:push_error("World did not become ready");quit(1);return
	freeze(world);world.hud.hide();world.viewmodel.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_size(Vector2i(1600,900));await process_frame
	if root.size!=Vector2i(1600,900):push_error("Invalid capture resolution");quit(1);return
	var camera:Camera3D=world.player.cam;camera.fov=70.0
	var records:Array[Dictionary]=[]
	var views:Array[Dictionary]=[]
	for item in [{"id":"road-day","i":180,"hour":11.0,"state":Weather.S.CLEAR},{"id":"road-overcast","i":360,"hour":13.0,"state":Weather.S.CLOUDY},{"id":"road-dusk","i":650,"hour":17.1,"state":Weather.S.CLEAR},{"id":"road-storm","i":360,"hour":13.0,"state":Weather.S.BLIZZARD},{"id":"road-night","i":180,"hour":22.0,"state":Weather.S.CLEAR}]:
		var index:int=item.i;var point:Vector2=world.road.points[index];var far:Vector2=world.road.points[index+14]
		var tangent:Vector2=(world.road.points[index+1]-world.road.points[index-1]).normalized()
		var q:=point+Vector2(-tangent.y,tangent.x)*1.1
		var y:float=world.player._eye_ground(q.x,q.y)
		var ahead_y:float=world.player._eye_ground(far.x,far.y)
		item.eye=Vector3(q.x,y+1.7,q.y);item.target=Vector3(far.x,ahead_y+1.1,far.y);views.append(item)
	# A lower camera exposes relief and transitions, without changing the ground mesh.
	var bank:Dictionary=views[1].duplicate();bank.id="road-surface";bank.eye.y-=.65;bank.target=bank.eye+Vector3(2.0,-.7,-2.5);views.append(bank)
	for slot in [0,1,2,3,4]:
		var sign:Dictionary=world.road.sign_records[slot];var index:int=sign.road_index
		var tangent:Vector2=(world.road.points[index+1]-world.road.points[index-1]).normalized()
		var normal:=Vector3(tangent.x,0,tangent.y)*(1.0 if sign.side>0.0 else -1.0)
		var point:Vector3=sign.position
		views.append({"id":"sign-%d"%slot,"eye":point+normal*3.1+Vector3.UP*2.0,"target":point+Vector3.UP*2.18,"hour":13.0,"state":Weather.S.CLOUDY})
	var repeats:=maxi(1,int(options.get("repeats",1)))
	for repeat in repeats:
		for item in views:
			if options.has("only") and String(options.only)!=item.id:continue
			world.player.global_position=item.eye;camera.global_position=item.eye;camera.look_at(item.target)
			world.weather._t=0.0;world.weather.lock_state(item.state);world.weather.advance(120,0)
			world.clock.hour=item.hour;world.sky_rig.set_cloud_offset(Vector2(.17,.08));world.sky_rig.apply_hour(item.hour);world.sky_rig.apply_shelter(0)
			world.road.update_weather(world.weather.precip)
			if world.forest!=null:world.forest.update_detail_appearance();world.forest._process(0.0)
			world.snowfall.visible=world.weather.precip>.02;world.snowfall.use_fixed_seed=true;world.snowfall.seed=42;world.snowfall.fixed_fps=60;world.snowfall.speed_scale=0.0
			world.snowfall.set_light_tint(world.sky_rig.snow_tint());world.snowfall._process(0.0)
			if world.snowfall.visible:world.snowfall.restart(true);world.snowfall.request_particles_process(4.0);world.snowfall.capture_detail_layers()
			world.weather_presentation.reset_visuals()
			for i in 30:await process_frame;await RenderingServer.frame_post_draw
			var samples:Array[float]=[]
			for i in 120:
				var start:=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw;samples.append((Time.get_ticks_usec()-start)/1000.0)
			samples.sort();var path:=output.path_join(item.id+("-r%d"%repeat if repeats>1 else "")+".png")
			if root.get_texture().get_image().save_png(path)!=OK:push_error("PNG save failed");quit(1);return
			var record:Dictionary={"id":item.id,"repeat":repeat,"eye":[item.eye.x,item.eye.y,item.eye.z],"target":[item.target.x,item.target.y,item.target.z],"hour":item.hour,"weather":item.state,"file":path,"sha256":FileAccess.get_sha256(path),"median_ms":samples[60],"p99_ms":samples[118]}
			records.append(record);print("ROAD_CAPTURE ",JSON.stringify(record))
	var manifest:Dictionary={"resolution":[root.size.x,root.size.y],"gpu":RenderingServer.get_video_adapter_name(),"road_detail":options.get("road_detail","winter"),"seed":20261003,"captures":records}
	var file:=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"\t"));file.close()
	print("ROAD_CAPTURE_COMPLETE ",records.size());quit()

