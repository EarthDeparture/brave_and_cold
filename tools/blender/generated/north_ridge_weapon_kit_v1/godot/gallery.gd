extends SceneTree
var world:Node3D
var cam:Camera3D
var entries:Dictionary
var results:Dictionary={}
var saved:Dictionary={}
func _initialize()->void:call_deferred("run")
func vertices(n:Node,p:Array[Vector3])->void:
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			for v:Vector3 in n.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:p.append(n.global_transform*v)
	for child in n.get_children():vertices(child,p)
func find(n:Node,id:String)->Node:
	if str(n.name)==id:return n
	return n.find_child(id,true,false)
func remember(n:Node)->void:
	if n is Node3D:saved[n]=n.transform
	for child in n.get_children():remember(child)
func reset_pose(player:AnimationPlayer)->void:
	if player:player.stop()
	for n:Node3D in saved:n.transform=saved[n]
func frame_bounds(model:Node3D)->Array[Vector3]:
	var p:Array[Vector3]=[];vertices(model,p);var lo:=Vector3(INF,INF,INF);var hi:=-lo
	for v in p:lo=lo.min(v);hi=hi.max(v)
	return [lo,hi]
func capture(id:String)->void:
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/"+id+".png").simplify_path())
func run()->void:
	create_timer(180).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1200,600);world=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();world.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.045,.057,.063);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.76,.83,.88);env.environment.ambient_light_energy=.48;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-48,-32,0);sun.light_energy=1.5
	var fill:=DirectionalLight3D.new();world.add_child(fill);fill.rotation_degrees=Vector3(25,145,0);fill.light_energy=.5
	cam=Camera3D.new();world.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.current=true
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://metadata.json"))
	for id:String in entries:
		var r:Dictionary=entries[id];var model:Node3D=load("res://"+id+".glb").instantiate();world.add_child(model)
		var b:Array[Vector3]=frame_bounds(model);var dims:Vector3=b[1]-b[0];var expected:Array=r.dimensions_m
		assert(dims.distance_to(Vector3(expected[0],expected[1],expected[2]))<.001,"Dimension mismatch: "+id)
		for node:String in r.nodes:assert(find(model,node)!=null,"Missing node: "+node)
		saved.clear();remember(model)
		var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
		var clips:Dictionary={}
		for clip:String in r.animations:
			assert(player!=null and player.has_animation(clip),"Missing clip: "+id+" / "+clip)
			var animation:Animation=player.get_animation(clip);var duration:float=r.animations[clip].duration_s
			assert(absf(animation.length-duration)<.018,"Clip duration mismatch")
			reset_pose(player);var changed:=false
			for fraction:float in [.2,.45,.7,1.0]:
				player.play(clip);player.seek(duration*fraction,true);player.advance(0)
				for n:Node3D in saved:
					if not n.transform.is_equal_approx(saved[n]):changed=true
			assert(changed,"Imported clip does not move: "+id+" / "+clip)
			if clip in ["reload_tactical","reload_empty"]:
				var mag:Node3D=find(model,id+"__Pivot_Magazine");reset_pose(player);player.play(clip);player.seek(1.05,true);player.advance(0)
				assert(mag.position.distance_to(saved[mag].origin)>.10,"Magazine did not detach")
				player.seek(duration,true);player.advance(0);assert(mag.transform.is_equal_approx(saved[mag]),"Magazine did not reseat")
			if clip in ["cycle","fire"] and r.kind=="weapon":
				var eject:Node3D=find(model,id+"__Pivot_SpentCase")
				if clip=="cycle" or id not in ["timber_bolt_carbine","brush_lever_rifle"]:
					reset_pose(player);player.play(clip);player.seek(.10 if clip=="fire" else .30,true);player.advance(0)
					assert(eject.scale.x>.4,"Ejection prop stayed hidden")
					var p:Array[Vector3]=[];vertices(eject,p);var low:=Vector3(INF,INF,INF);var high:=-low
					for v in p:low=low.min(v);high=high.max(v)
					assert((high-low).length()>.015,"Ejection geometry collapsed")
			clips[clip]={"duration_s":animation.length,"tracks":animation.get_track_count(),"actual_motion":true}
		reset_pose(player)
		var center:Vector3=(b[0]+b[1])*.5;var length:float=maxf(dims.x,maxf(dims.y,dims.z))
		cam.size=length*1.2;cam.position=center+Vector3(2.9,1.0,.5)*length;cam.look_at(center,Vector3.UP)
		await capture("godot_"+id)
		if r.kind=="weapon":
			cam.position=center+Vector3(-2.9,1.0,-.5)*length;cam.look_at(center,Vector3.UP);await capture("godot_left_"+id)
			cam.position=center+Vector3(2.9,1.0,.5)*length;cam.look_at(center,Vector3.UP)
		if id in ["ridge_scout_rifle","brush_lever_rifle","compact_patrol_rifle"]:
			cam.size=length*1.55;cam.position=center+Vector3(0,-.06,0)+Vector3(2.9,.65,.35)*length;cam.look_at(center+Vector3(0,-.06,0),Vector3.UP)
			var clip:String="reload_insert" if id=="brush_lever_rifle" else "reload_empty"
			for index in 5:
				reset_pose(player);player.play(clip);player.seek(float(r.animations[clip].duration_s)*index/4.0,true);player.advance(0);player.pause()
				await capture("reload_"+id+"_"+str(index))
			reset_pose(player)
		if id=="compact_patrol_rifle":
			cam.size=length*1.2;cam.position=center+Vector3(2.9,1.0,.5)*length;cam.look_at(center,Vector3.UP)
			player.play("stock_fold");player.seek(float(r.animations.stock_fold.duration_s),true);player.advance(0);player.pause();await capture("godot_stock_folded");reset_pose(player)
		results[id]={"dimensions_m":[dims.x,dims.y,dims.z],"nodes":r.nodes.size(),"animations":clips}
		saved.clear();model.queue_free();await process_frame
	var f:=FileAccess.open("res://engine_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify({"engine":"Godot 4.7.2","assets":results,"scope":"Isolated metre-scale import and animation playback; no live hand fitting or gameplay replacement."},"  "));f.close()
	print("WEAPON_GODOT_PASS assets=",results.size());quit()
