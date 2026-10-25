extends SceneTree
## Drive the real Player through off-centre turns, both rail sides and stacked flights.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func drive(p: Player, target: Vector3, fps: int) -> bool:
	for frame in 5 * fps:
		var d := Vector2(target.x-p.position.x,target.z-p.position.z)
		if d.length() < .035: return true
		d = d.normalized(); p.sim_dir = Vector3(d.x,0,d.y); p._move(1.0/fps)
	print("UNREACHED fps=",fps," target=",target," actual=",p.position," velocity=",p._vel," blocks=",p.dbg_blocks," local=",p.spatial_structures[0].to_local(p.position))
	return false
func run() -> void:
	var terrain := Terrain3D.new(); terrain.assets=load("res://data/terrain/terrain_assets.tres")
	terrain.data_directory="res://data/terrain/valley_b"; root.add_child(terrain)
	var camera := Camera3D.new(); root.add_child(camera); camera.make_current(); terrain.set_camera(camera)
	await process_frame; await process_frame
	var snow := SnowField.new(); snow.build("res://data/maps/valley_b")
	var p := Player.new(); root.add_child(p); p.setup(terrain,snow,BodyTemperature.new(),NoiseBus.new())
	p.set_process(false); p.sim_on=true
	var tower := FireLookout.new(); root.add_child(tower)
	var h: float=terrain.data.get_height(Vector3(-1,0,803))
	tower.build({"origin":{"x":-1,"y":h,"z":803},"yaw_degrees":31},false)
	p.spatial_structures.assign([tower])
	check(is_equal_approx(float(tower.geometry.stairs.rail_end_inset_m),FireLookout.RAIL_END_INSET),"collision rail ends match the generated asset receipt")
	for fps in [30,60,120]:
		for offset: float in [-.16,-.12,0.0,.12,.16]:
			var route: Array[Vector3]=[]
			for flight in FireLookout.FLIGHT_COUNT:
				var lane: float=FireLookout.STAIR_LANES[flight%2]+offset
				var z: float=-2.10 if flight%2==0 else 2.10
				route.append(tower.to_global(Vector3(lane,0,z)))
				if flight<FireLookout.FLIGHT_COUNT-1:
					route.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[(flight+1)%2]+offset,0,z)))
			p.reset_jump(); p._camera_ground=NAN; p._ground_offset=0; p._vel=Vector2.ZERO
			p.position=tower.to_global(Vector3(FireLookout.STAIR_LANES[0]+offset,p.eye_h,1.95))
			var ok:=true
			for target in route:
				if not drive(p,target,fps):
					print("TURN route_index=",route.find(target))
					ok=false;break
			check(ok and absf(p.position.y-p.eye_h-h-FireLookout.DECK_Y)<.25,"off-centre ascent fps=%d offset=%.2f"%[fps,offset])
			route.reverse()
			for target in route:
				if not drive(p,target,fps):
					print("TURN route_index=",route.find(target))
					ok=false;break
			ok=drive(p,tower.to_global(Vector3(FireLookout.STAIR_LANES[0]+offset,0,1.95)),fps) and ok
			check(ok and absf(p.position.y-p.eye_h-h)<.25,"off-centre descent fps=%d offset=%.2f"%[fps,offset])
	# Diagonal pressure against the outside landing rail must retain lateral motion.
	for landing in range(1,FireLookout.FLIGHT_COUNT+1):
		var z: float=-2.20 if landing%2==1 else 2.20
		var y: float=landing*FireLookout.FLIGHT_RISE
		var start:=tower.to_global(Vector3(4.45,y,z))
		var proposed:=tower.to_global(Vector3(4.53,y,z+signf(z)*.08))
		var result:=tower.resolve_at(proposed,start,.35)
		var local:=tower.to_local(Vector3(result.x,start.y,result.y))
		check(local.x>4.51 and absf(local.z)<2.255,"landing rail slides without cancelling sideways motion %d"%landing)
	# Hold diagonal input into both flight rails while descending. Tangential
	# travel must survive repeated contact, with no backward corrective jitter.
	for flight in FireLookout.FLIGHT_COUNT:
		for side: float in [-1,1]:
			var lane: float=FireLookout.STAIR_LANES[flight%2]
			var z_dir: float=1 if flight%2==0 else -1
			var local:=Vector3(lane+side*.16,flight*FireLookout.FLIGHT_RISE+FireLookout.FLIGHT_RISE*.5,0)
			var world:=tower.to_global(local);var floor_y:=tower.floor_at_world(world)
			p.reset_jump();p._camera_ground=NAN;p._ground_offset=0;p._vel=Vector2.ZERO
			p.position=Vector3(world.x,floor_y+p.eye_h,world.z)
			p.sim_dir=tower.global_basis*Vector3(side,0,z_dir).normalized()
			var backwards:=0.0
			for frame in 30:
				var before:=tower.to_local(p.position);p._move(1.0/60)
				var after:=tower.to_local(p.position)
				backwards=maxf(backwards,-(after.z-before.z)*z_dir)
			var end:=tower.to_local(p.position)
			check(end.z*z_dir>.45 and absf(end.x-lane)<.174 and backwards<.001,"continuous rail pressure slides downhill, no jitter flight=%d side=%d"%[flight,int(side)])
	# Safety boundaries remain solid at both flight sides and all landing rails.
	for flight in FireLookout.FLIGHT_COUNT:
		var lane: float=FireLookout.STAIR_LANES[flight%2]
		var y: float=flight*FireLookout.FLIGHT_RISE+FireLookout.FLIGHT_RISE*.5
		for side: float in [-1,1]:
			var start:=tower.to_global(Vector3(lane,y,0))
			var proposed:=tower.to_global(Vector3(lane+side*.8,y,0))
			var result:=tower.resolve_at(proposed,start,.35)
			var end:=tower.to_local(Vector3(result.x,start.y,result.y))
			check(absf(end.x-lane)<.174 and not is_nan(tower.floor_at_world(Vector3(result.x,start.y,result.y))),"flight rail prevents side fall %d side=%d"%[flight,int(side)])
	# Older saves can begin inside newly joined rail clearance. Let them leave
	# freely without a corrective teleport or being trapped in the new nose.
	for landing in range(1,FireLookout.FLIGHT_COUNT):
		var sign_z: float=-1 if landing%2 else 1
		var start:=tower.to_global(Vector3(5.125,landing*FireLookout.FLIGHT_RISE,sign_z*1.83))
		var proposed:=tower.to_global(Vector3(5.125,landing*FireLookout.FLIGHT_RISE,sign_z*1.96))
		var result:=tower.resolve_at(proposed,start,.35)
		check(result.distance_to(Vector2(proposed.x,proposed.z))<.0001,"old overlapping save can leave inner nose freely %d"%landing)
	var under:=tower.to_global(Vector3(0,0,0));var ground_target:=tower.to_global(Vector3(.1,0,.1))
	check(tower.resolve_at(ground_target,under,.35).distance_to(Vector2(ground_target.x,ground_target.z))<.0001,"upper stair rails do not obstruct ground beneath the room")
	p.free();tower.free();terrain.free();print("STAIR_TURN_TEST failures=",failures);quit(1 if failures else 0)
