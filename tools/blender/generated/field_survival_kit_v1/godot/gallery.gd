extends SceneTree
var w:Node3D
var cam:Camera3D
var entries:Dictionary
var current:Node3D
var results:Dictionary={}
func _initialize()->void:call_deferred("run")
func vertices(n:Node,points:Array[Vector3])->void:
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			for v:Vector3 in n.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:points.append(n.global_transform*v)
	for child in n.get_children():vertices(child,points)
func run()->void:
	create_timer(90).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);w=Node3D.new();root.add_child(w)
	var env:=WorldEnvironment.new();w.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.065,.08,.085);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.76,.83,.88);env.environment.ambient_light_energy=.45;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun:=DirectionalLight3D.new();w.add_child(sun);sun.rotation_degrees=Vector3(-48,-32,0);sun.light_energy=1.2;sun.shadow_enabled=true
	cam=Camera3D.new();w.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.keep_aspect=Camera3D.KEEP_WIDTH;cam.current=true
	entries=JSON.parse_string(FileAccess.get_file_as_string("res://metadata.json"))
	var ids:Array=entries.keys()
	for page in 4:
		var group:=Node3D.new();w.add_child(group)
		for k in 8:
			var name:String=ids[page*8+k];var model:Node3D=load("res://"+name+".glb").instantiate();group.add_child(model)
			var p:Array[Vector3]=[];vertices(model,p);var lo:=Vector3(INF,INF,INF);var hi:=-lo
			for v in p:lo=lo.min(v);hi=hi.max(v)
			var expected:Array=entries[name].measured_size_m;var actual:=hi-lo
			assert(actual.distance_to(Vector3(expected[0],expected[1],expected[2]))<.001,"Godot dimension mismatch: "+name)
			for pivot:String in entries[name].pivots:
				var part:Node3D=model.find_child(pivot,true,false);assert(part!=null,"Lost pivot: "+pivot)
				if "__Pivot_" in pivot:
					var before:Array[Vector3]=[];vertices(part,before);assert(not before.is_empty(),"Unbound pivot: "+pivot)
					var original:Transform3D=part.transform;part.rotate_x(.3);var after:Array[Vector3]=[];vertices(part,after);part.transform=original
					var moved:=false
					for j in before.size():
						if before[j].distance_to(after[j])>.00001:moved=true;break
					assert(moved,"Non-functional pivot: "+pivot)
			results[name]={"dimensions_m":[actual.x,actual.y,actual.z],"pivots":entries[name].pivots.size()}
			# Gallery display copies are normalised, while imported resources stay metre-scale.
			var factor:float=.98/maxf(actual.x,maxf(actual.y,actual.z));model.scale=Vector3.ONE*factor;model.position=Vector3((k%4)*1.8,.70-(k/4)*1.6,0)-(lo+hi)*.5*factor
			var text:=Label3D.new();group.add_child(text);text.text=name.replace("_"," ")+"\n"+str(entries[name].triangles)+" triangles";text.font_size=34;text.pixel_size=.0023;text.position=Vector3((k%4)*1.8,-.1-(k/4)*1.6,.20);text.modulate=Color(.83,.85,.77);text.no_depth_test=true
		cam.size=7.4;cam.position=Vector3(2.7,2.0,6.8);cam.look_at(Vector3(2.7,-.05,0),Vector3.UP)
		for frame in 20:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/godot_page_"+str(page+1)+".png").simplify_path())
		group.queue_free();await process_frame
	root.size=Vector2i(900,900)
	for name:String in ids:
		var model:Node3D=load("res://"+name+".glb").instantiate();w.add_child(model)
		var points:Array[Vector3]=[];vertices(model,points);var lo:=Vector3(INF,INF,INF);var hi:=-lo
		for v in points:lo=lo.min(v);hi=hi.max(v)
		var dims:=hi-lo;var length:=maxf(dims.x,maxf(dims.y,dims.z));var center:Vector3=(hi+lo)*.5
		cam.size=length*1.45;cam.position=center+Vector3(.9,.65,1.5)*length;cam.look_at(center,Vector3.UP)
		for frame in 12:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../previews/godot_"+name+".png").simplify_path())
		model.queue_free();await process_frame
	var f:=FileAccess.open("res://engine_validation.json",FileAccess.WRITE);f.store_string(JSON.stringify({"engine":"Godot 4.7.2","assets":results,"scope":"Isolated import, metre-scale dimensions, named pivots and GPU contact sheets; no gameplay item replacement."},"  "));f.close()
	print("FIELD_KIT_GODOT_PASS assets=",results.size());quit()
