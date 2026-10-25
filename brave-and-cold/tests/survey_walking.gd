extends SceneTree
var options:Dictionary={}
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.split("=",true,1);options[pair[0]]=pair[1] if pair.size()>1 else "1"
	var t:=Terrain3D.new();t.assets=load("res://data/terrain/terrain_assets.tres");t.data_directory="res://data/terrain/valley_b";root.add_child(t)
	var cam:=Camera3D.new();root.add_child(cam);cam.make_current();t.set_camera(cam)
	await process_frame;await process_frame
	var ice:=IceField.new();ice.load_map();ice.activate_shoreline()
	var snow:=SnowField.new();snow.build("res://data/maps/valley_b")
	var road:=RoadNet.new();root.add_child(road);road.plan();road.grading_enabled=not options.has("baseline");road.build_mesh(t)
	var p:Player=load("res://shots/walk-surfaces/baseline_player.gd").new() if options.has("baseline") else Player.new();root.add_child(p);p.setup(t,snow,BodyTemperature.new(),NoiseBus.new());p.ice=ice;p.set_process(false);p.sim_on=true
	p.walk_ribbons.assign([road])
	var records:Array=[]
	for x in range(-850,851,85):
		for z in range(-850,851,85):
			var a:=Vector2(x+.31,z+.27);var dir:=Vector2(.8,.6)
			var h:float=p._eye_ground(a.x,a.y);var h1:float=p._eye_ground(a.x+dir.x*8,a.y+dir.y*8)
			if is_nan(h) or is_nan(h1) or absf(h1-h)>6.4:continue
			p.reset_jump();p.cam.position=Vector3.ZERO;p.position=Vector3(a.x,400,a.y);p.position.y=p.ground_at(a.x,a.y)+p.eye_h;p._vel=Vector2.ZERO;p._snow_mult=1.0;p.dbg_blocks=0;p.sim_dir=Vector3(dir.x,0,dir.y)
			var max_jerk:=0.0;var last_dy:=0.0;var deflections:=0
			for frame in 240:
				var old:Vector3=p.position;old.y+=p.cam.position.y;var wish:Vector2=p._slope_step(dir*.04)
				if wish.length()>.001 and wish.normalized().dot(dir)<.99:deflections+=1
				p._move(1.0/60);var dy:=p.position.y+p.cam.position.y-old.y;max_jerk=maxf(max_jerk,absf(dy-last_dy));last_dy=dy
			var offset:=Vector2(p.position.x-a.x,p.position.z-a.y)
			records.append({"fps":60,"index":-1,"side":0,"start":[a.x,a.y],"progress":offset.dot(dir),"lateral":absf(offset.cross(dir)),"blocks":p.dbg_blocks,"deflections":deflections,"jerk":max_jerk})
	for fps in [30,60,120]:
		for index in range(8,road.points.size()-12,16):
			for side in [-5.5,0.0,5.5]:
				var a:Vector2=road.points[index];var b:Vector2=road.points[index+8];var dir:Vector2=(b-a).normalized();a+=Vector2(-dir.y,dir.x)*side
				p.reset_jump();p.cam.position=Vector3.ZERO;p.position=Vector3(a.x,400,a.y);p.position.y=p.ground_at(a.x,a.y)+p.eye_h;p._vel=Vector2.ZERO;p._snow_mult=1.0;p.dbg_blocks=0;p.sim_dir=Vector3(dir.x,0,dir.y)
				var max_jerk:=0.0;var last_dy:=0.0;var deflections:=0;var max_support_error:=0.0
				for frame in 4*fps:
					var old:Vector3=p.position;old.y+=p.cam.position.y;var wish:Vector2=p._slope_step(dir*.04)
					if wish.length()>.001 and wish.normalized().dot(dir)<.99:deflections+=1
					p._move(1.0/fps);var dy:=p.position.y+p.cam.position.y-old.y;max_jerk=maxf(max_jerk,absf(dy-last_dy));last_dy=dy
					max_support_error=maxf(max_support_error,absf(p.position.y-p.eye_h-p.ground_at(p.position.x,p.position.z)))
				var offset:=Vector2(p.position.x-a.x,p.position.z-a.y)
				records.append({"fps":fps,"index":index,"side":side,"start":[a.x,a.y],"progress":offset.dot(dir),"lateral":absf(offset.cross(dir)),"blocks":p.dbg_blocks,"deflections":deflections,"jerk":max_jerk,"support_error":max_support_error})
	var path:String=options.get("report","res://shots/walk-surfaces/baseline.json");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()));var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(records,"\t"));f.close()
	print("WALK_SURVEY_COMPLETE cases=",records.size()," report=",path)
	p.free();road.free();t.free();quit()
