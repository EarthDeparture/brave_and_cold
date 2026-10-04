extends SceneTree
## Actual Terrain3D and Player movement at previously broken shoreline crossings.
var failed := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var terrain := Terrain3D.new()
	terrain.assets = load("res://data/terrain/terrain_assets.tres")
	terrain.data_directory = "res://data/terrain/valley_b"
	root.add_child(terrain)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	terrain.set_camera(camera)
	await process_frame
	await process_frame
	var ice := IceField.new()
	ice.load_map()
	ice.activate_shoreline()
	var snow := SnowField.new()
	snow.build("res://data/maps/valley_b")
	var p := Player.new()
	root.add_child(p)
	p.setup(terrain,snow,BodyTemperature.new(),NoiseBus.new())
	p.ice = ice
	p.set_process(false)
	p.sim_on = true
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/shore_walk_cases.json"))
	for fps in [30,60,120]:
		var max_bump := 0.0
		var blocks := 0
		var min_progress := INF
		for c in cases:
			for reverse in [false,true]:
				var a := Vector2(c.start[0],c.start[1])
				var b := Vector2(c.end[0],c.end[1])
				if reverse:
					var t := a; a = b; b = t
				var dir := (b-a).normalized()
				p.reset_jump()
				p.cam.position=Vector3.ZERO
				p.position = Vector3(a.x,p.ground_at(a.x,a.y)+p.eye_h,a.y)
				p._vel = Vector2.ZERO
				p._snow_mult = 1.0
				p.dbg_blocks = 0
				p.sim_dir = Vector3(dir.x,0,dir.y)
				var previous_dy := 0.0
				for frame in 12*fps:
					var old_y := p.position.y+p.cam.position.y
					p._move(1.0/fps)
					var dy := p.position.y+p.cam.position.y-old_y
					max_bump = maxf(max_bump,absf(dy-previous_dy))
					previous_dy = dy
					if Vector2(p.position.x-a.x,p.position.z-a.y).dot(dir)>=25.0: break
				var progress := Vector2(p.position.x-a.x,p.position.z-a.y).dot(dir)
				min_progress = minf(min_progress,progress)
				blocks += p.dbg_blocks
		print("SHORE_WALK fps=",fps," crossings=",cases.size()*2," blocked_frames=",blocks," minimum_metres=",min_progress," max_vertical_bump_m=",max_bump)
		if blocks>0 or min_progress<24.9 or max_bump>.025: failed+=1
	# Exercise the actual controller, not just independent stair floor queries.
	var tower := FireLookout.new()
	root.add_child(tower)
	var base_y := ice.ice_at(-1.0,803.0)
	tower.build({"origin":{"x":-1.0,"y":base_y,"z":803.0},"yaw_degrees":31.0},false)
	p.spatial_structures.assign([tower])
	p.position = tower.to_global(Vector3(FireLookout.STAIR_LANES[0],p.eye_h,1.95))
	p._vel = Vector2.ZERO
	p.dbg_blocks = 0
	var route: Array[Vector3] = []
	for flight in FireLookout.FLIGHT_COUNT:
		var lane := FireLookout.STAIR_LANES[flight%2]
		var landing_z := -2.2 if flight%2==0 else 2.2
		route.append(tower.to_global(Vector3(lane,0,landing_z)))
		if flight<FireLookout.FLIGHT_COUNT-1:
			route.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[(flight+1)%2],0,landing_z)))
	var reached := true
	for target in route:
		reached = drive_to(p,target) and reached
	var ascent_height := p.position.y-p.eye_h-base_y
	var ascent_ok := reached and p.dbg_blocks==0 and absf(ascent_height-FireLookout.DECK_Y)<.3
	print("STAIR_CONTROLLER ascent=",ascent_ok," height=",ascent_height," blocked_frames=",p.dbg_blocks)
	if not ascent_ok: failed+=1
	route.reverse()
	for target in route:
		reached = drive_to(p,target) and reached
	reached = drive_to(p,tower.to_global(Vector3(FireLookout.STAIR_LANES[0],0,1.95))) and reached
	var descent_height := p.position.y-p.eye_h-base_y
	var descent_ok := reached and p.dbg_blocks==0 and absf(descent_height)<.3
	print("STAIR_CONTROLLER descent=",descent_ok," height=",descent_height," blocked_frames=",p.dbg_blocks)
	if not descent_ok: failed+=1
	p.free()
	terrain.free()
	quit(0 if failed==0 else 1)

func drive_to(p: Player,target: Vector3) -> bool:
	p._vel = Vector2.ZERO
	for i in 5*60:
		var direction := Vector2(target.x-p.position.x,target.z-p.position.z)
		if direction.length()<.035: return true
		direction=direction.normalized()
		p.sim_dir=Vector3(direction.x,0,direction.y)
		p._move(1.0/60.0)
	return false
