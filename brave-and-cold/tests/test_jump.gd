extends SceneTree
## Exercises actual terrain/ice, existing Player controller and stacked lookout surfaces.
var failed := 0
var steps := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failed += 1
func reset(p: Player, point: Vector3) -> void:
	p.reset_jump(); p.position=point; p.eye_h=Player.EYE; p._ready_ground=true
	p.stamina=100.0; p.exhausted=false; p._vel=Vector2.ZERO; p.sim_dir=Vector3.ZERO
	p.crouching=false; p._last_pos=point; steps=0
func run() -> void:
	var terrain := Terrain3D.new()
	terrain.assets=load("res://data/terrain/terrain_assets.tres")
	terrain.data_directory="res://data/terrain/valley_b"
	root.add_child(terrain)
	var camera:=Camera3D.new();root.add_child(camera);camera.make_current();terrain.set_camera(camera)
	await process_frame; await process_frame
	var ice := IceField.new(); ice.load_map(); ice.activate_shoreline()
	var snow := SnowField.new(); snow.build("res://data/maps/valley_b")
	var p := Player.new(); root.add_child(p)
	p.setup(terrain,snow,BodyTemperature.new(),NoiseBus.new());p.ice=ice
	p.set_process(false);p.sim_on=true
	p.stepped.connect(func(_tier:int,_radius:float)->void:steps+=1)
	var y := p._eye_ground(-1.0,803.0)
	var apexes: Array[float]=[]
	for fps in [30,60,120]:
		reset(p,Vector3(-1,y+Player.EYE,803))
		check(p.request_jump(),"jump starts on actual lake ice at %d FPS"%fps)
		check(is_equal_approx(p.stamina,92.0),"one 8-point stamina charge")
		check(not p.request_jump(),"no second jump while airborne")
		var apex:=0.0;var duration:=0.0;var airborne_steps:=false
		for frame in fps*2:
			p._move(1.0/fps);p._footsteps(1.0/fps);duration+=1.0/fps
			apex=maxf(apex,p.position.y-Player.EYE-y)
			if p.airborne:airborne_steps=airborne_steps or steps>0
			else:break
		apexes.append(apex)
		check(not airborne_steps,"no airborne footsteps")
		check(not p.airborne and absf(p.position.y-Player.EYE-y)<.005,"lands exactly on ice")
		check(steps==1 and absf(duration-.575)<.04,"one landing sound; bounded jump duration")
		print("JUMP_METRIC fps=",fps," apex_m=",apex," duration_s=",duration)
	check(apexes.max()-apexes.min()<.003,"consistent jump height across frame rates")
	reset(p,Vector3(-1,y+Player.EYE,803));p.speed_mult=.65
	p.request_jump();var encumbered_apex:=0.0
	for i in 120:
		p._move(1.0/120.0);encumbered_apex=maxf(encumbered_apex,p.position.y-Player.EYE-y)
		if not p.airborne:break
	check(encumbered_apex<.30 and encumbered_apex>.26,"encumbrance reduces jump height")
	p.speed_mult=1.0
	for flag in ["dead","sleeping","struggling","ui_open","frozen","noclip","crouching","exhausted"]:
		reset(p,Vector3(-1,y+Player.EYE,803));p.set(flag,true)
		check(not p.request_jump(),"jump suppressed during "+flag);p.set(flag,false)
	reset(p,Vector3(-1,y+Player.EYE,803));p.stamina=7.9
	check(not p.request_jump(),"insufficient stamina cannot jump")
	check(InputMap.has_action("jump"),"Spacebar jump action registered")
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	check(key.is_action_pressed("jump"),"Spacebar maps to jump")
	var tower:=FireLookout.new();root.add_child(tower)
	tower.build({"origin":{"x":-1,"y":y,"z":803},"yaw_degrees":31},false)
	p.spatial_structures.assign([tower])
	reset(p,tower.to_global(Vector3(0,FireLookout.DECK_Y+Player.EYE,0)))
	check(p.request_jump(),"jump works inside elevated lookout")
	var head_max:=-INF
	for i in 90:
		p._move(1.0/120.0);head_max=maxf(head_max,p.position.y+Player.HEAD_CLEARANCE)
	check(head_max<=tower.ceiling_at_world(p.position)+.001,"head never crosses lookout ceiling")
	check(absf(tower.to_local(p.position).y-Player.EYE-FireLookout.DECK_Y)<.01,"land upstairs without terrain snap")
	reset(p,tower.to_global(Vector3(3.32,FireLookout.DECK_Y+Player.EYE,0)))
	p.sim_dir=tower.global_transform.basis.x;p.request_jump()
	for i in 90:p._move(1.0/120.0)
	check(tower.to_local(p.position).x<=3.451,"jump retains deck guardrail collision")
	for flight in [0,4,8]:
		var foot:=Vector3(FireLookout.STAIR_LANES[flight%2],float(flight)*FireLookout.FLIGHT_RISE+.4,1.25)
		var world_foot:=tower.to_global(foot)
		var floor_y:=tower.floor_at_world(world_foot)
		reset(p,Vector3(world_foot.x,floor_y+Player.EYE,world_foot.z))
		check(p.request_jump(),"jump on stacked stair flight "+str(flight))
		for i in 90:p._move(1.0/120.0)
		check(absf(p.position.y-Player.EYE-floor_y)<.01,"lands on the same stair flight "+str(flight))
	var uphill_foot:=tower.to_global(Vector3(FireLookout.STAIR_LANES[0],.35,1.25))
	var uphill_floor:=tower.floor_at_world(uphill_foot)
	reset(p,Vector3(uphill_foot.x,uphill_floor+Player.EYE,uphill_foot.z))
	var uphill:=tower.global_transform.basis*Vector3.FORWARD
	p.sim_dir=uphill;p._vel=Vector2(uphill.x,uphill.z)*Player.WALK;p.request_jump()
	var penetrated:=false
	for i in 90:
		p._move(1.0/120.0)
		penetrated=penetrated or (p.airborne and p.position.y-p.eye_h<p._eye_ground(p.position.x,p.position.z)-.015)
	check(not penetrated,"uphill moving jump lands on rising treads without sinking through them")
	# Existing cabin walls stay solid and a low hut underside clips upward motion.
	p.spatial_structures.clear()
	var hut:=Hut.new();root.add_child(hut);hut.position=Vector3(-1,y-.3,803);hut.floor_y=y
	p.cabins.assign([hut]);reset(p,Vector3(-.05,y+Player.EYE,804.14));p.request_jump()
	var max_eye:=-INF
	for i in 90:p._move(1.0/120.0);max_eye=maxf(max_eye,p.position.y+Player.HEAD_CLEARANCE)
	check(max_eye<=hut.ceiling_at_world(p.position)+.001,"low hut roof stops the head")
	# Jumping toward an open door must stop horizontally until the head clears.
	reset(p,Vector3(-1,y+Player.EYE,803.55));p.request_jump()
	for i in 32:p._move(1.0/120.0)
	p.sim_dir=Vector3(0,0,1)
	var crossed_header:=false
	for i in 60:
		p._move(1.0/120.0)
		if absf(p.position.z-804.3)<.3 and p.position.y+Player.HEAD_CLEARANCE>y+2.0+.003:crossed_header=true
	check(not crossed_header,"airborne head cannot enter low doorway header")
	# Normal airborne forward movement remains useful without a speed boost.
	p.cabins.clear();reset(p,Vector3(-1,y+Player.EYE,803));p.sim_dir=Vector3.FORWARD
	for i in 60:p._move(1.0/60.0)
	var start:=p.position;p.request_jump();var maximum_speed:=0.0
	for i in 60:
		p._move(1.0/120.0);maximum_speed=maxf(maximum_speed,p.speed_now)
	check(start.distance_to(p.position)>.6 and maximum_speed<=Player.WALK+.001,"walking jump keeps forward travel without adding speed")
	print("JUMP_TEST_COMPLETE failures=",failed)
	p.free();hut.free();tower.free();terrain.free();quit(0 if failed==0 else 1)
