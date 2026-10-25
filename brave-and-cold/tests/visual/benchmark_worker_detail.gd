extends "res://tests/visual/capture_worker_detail.gd"
## Matched 55 articulated actors / 16 visible. Asset and gait presentation only;
## no world terrain, population AI or renderer-specific attribution.
func run()->void:
	create_timer(120).timeout.connect(func()->void:quit(2));root.size=Vector2i(1920,1080)
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();scene.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.14,.18,.23)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.83,.94);env.environment.ambient_light_energy=.7
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-50,-25,0);sun.shadow_enabled=true
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.position=Vector3(0,4,-11);camera.look_at(Vector3(0,1,3));camera.fov=50;camera.far=35
	var floor_mesh:=MeshInstance3D.new();scene.add_child(floor_mesh);floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(40,40)
	var rows:Array=[]
	for variant:String in ["before","after"]:
		var actors:Array[Zombie]=[]
		for i in 55:
			var z:=actor(scene,"res://assets/infected/skin/winter_worker_skin.glb" if variant=="before" else Zombie.MODEL)
			z.position=Vector3((i%4-1.5)*1.2,0,float(floori(i/4.0))*1.5 if i<16 else 80+float(i));z._phase=float(i)*.71
			z.speed_now=.8;z._gait_speed=.8;z.state=Zombie.State.INVESTIGATE;actors.append(z)
		for repeat in 3:
			var samples:Array[float]=[];var last:=Time.get_ticks_usec();var measured_visible:=0
			for frame in 360:
				for i in actors.size():
					var z:Zombie=actors[i]
					var base_z:=float(floori(i/4.0))*1.5 if i<16 else 80+float(i)
					var next_z:=base_z-fposmod(frame*.8/60,1.5)
					if next_z>z.position.z+.01:z._gait.reset()
					z.position.z=next_z;z._animate(1.0/60)
				await RenderingServer.frame_post_draw
				if frame==119:
					for z:Zombie in actors:
						if camera.is_position_in_frustum(z.position+Vector3.UP*.9):measured_visible+=1
					assert(measured_visible==16,"Matched fixture must retain sixteen visible actor centres")
				var now:=Time.get_ticks_usec()
				if frame>=120:samples.append((now-last)/1000.0)
				last=now
			samples.sort();rows.append({"variant":variant,"repeat":repeat,"actors":55,"visible":measured_visible,"samples":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples.back()})
			print("WORKER_TIMING_ROW ",JSON.stringify(rows.back()))
		for z:Zombie in actors:z.free()
	var out:="res://shots/worker-detail/group-timing.json";var file:=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1920,1080],"scope":"55 posed actors, 16 visible; no terrain or AI; warm 240-frame samples after 120 warmup","rows":rows},"\t"));file.close()
	print("WORKER_TIMING_COMPLETE");quit()
