extends SceneTree
## Walk the real Player up and down all ten tower flights and measure what the
## camera does (plus the tucked desk chair aisle). Stairs must read as a steady climb: no per-tread bob, no surge
## and settle, no overshoot at landings. Prints a trace summary for tuning.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
var samples: Array = [] # [t, cam_y, feet_y, local]
func drive(p: Player, tower: FireLookout, target: Vector3, fps: int, t: Array) -> bool:
	for frame in 8 * fps:
		var d := Vector2(target.x-p.position.x,target.z-p.position.z)
		if d.length() < maxf(.035, p._vel.length()*1.2/fps): return true # a 30 fps sprint frame is 19 cm
		d = d.normalized(); p.sim_dir = Vector3(d.x,0,d.y); p._move(1.0/fps)
		t[0] += 1.0/fps
		p.stamina = 100.0 # isolate the camera from sprint/exhaustion speed changes
		samples.append([t[0], p.position.y+p.cam.position.y, p.position.y-p.eye_h, tower.to_local(p.position)])
	print("UNREACHED fps=",fps," target=",tower.to_local(target)," actual=",tower.to_local(p.position)," vel=",p._vel," blocks=",p.dbg_blocks)
	return false
## Mid-flight frames only (well away from the landings), where the ideal camera
## climbs at a constant vertical speed.
func mid_flight(s: Array) -> bool:
	var l: Vector3 = s[3]
	return absf(l.z) < 1.2 and (absf(l.x-FireLookout.STAIR_LANES[0]) < .4 or absf(l.x-FireLookout.STAIR_LANES[1]) < .4)
func analyse(label: String, fps: int) -> Dictionary:
	var vs: Array[float] = []
	var reversals := 0
	var worst_acc := 0.0
	var dt := 1.0/fps
	var hs := 0.0; var hn := 0
	# Camera climb per metre walked: speed-independent, so acceleration out of a
	# landing turn is not mistaken for bounce. On the ramp it must be constant.
	for i in range(2, samples.size()):
		if not (mid_flight(samples[i]) and mid_flight(samples[i-1]) and mid_flight(samples[i-2])): continue
		var run1: float = Vector2(samples[i-1][3].x-samples[i-2][3].x, samples[i-1][3].z-samples[i-2][3].z).length()
		var run2: float = Vector2(samples[i][3].x-samples[i-1][3].x, samples[i][3].z-samples[i-1][3].z).length()
		if run1 < .4*dt or run2 < .4*dt: continue
		var v1: float = (samples[i-1][1]-samples[i-2][1])/run1
		var v2: float = (samples[i][1]-samples[i-1][1])/run2
		hs += run2/dt; hn += 1
		vs.append(v2); worst_acc = maxf(worst_acc, absf(v2-v1))
	for i in range(2, vs.size()):
		if signf(vs[i]-vs[i-1]) != signf(vs[i-1]-vs[i-2]) and absf(vs[i]-vs[i-1]) > .02: reversals += 1
	var mean := 0.0
	for v in vs: mean += absf(v)
	mean /= maxf(1, vs.size())
	var var_sum := 0.0
	for v in vs: var_sum += (absf(v)-mean)*(absf(v)-mean)
	var cv := sqrt(var_sum/maxf(1, vs.size()))/maxf(.001, mean)
	# Largest gap between camera and feet: a lagging spring reads as sinking/surging.
	var lag := 0.0
	for s: Array in samples:
		# Whole route incl. landings and turns (overshoot shows here), after the first half second.
		if float(s[0])-float(samples[0][0]) > .5: lag = maxf(lag, absf(float(s[1])-float(s[2])-Player.EYE))
	print("STAIR_CAMERA %s fps=%d frames=%d climb_per_m=%.3f cv=%.3f reversals_per_s=%.2f worst_jump=%.3f max_eye_error=%.3f" % [label, fps, vs.size(), mean, cv, reversals/(vs.size()*dt+.001), worst_acc, lag])
	print("STAIR_SPEED %s fps=%d mid_flight_m_s=%.2f" % [label, fps, hs/maxf(1,hn)])
	return {"cv":cv,"rev":reversals/(vs.size()*dt+.001),"acc":worst_acc,"lag":lag,"mean":mean,"speed":hs/maxf(1,hn)}
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
	var route: Array[Vector3]=[]
	for flight in FireLookout.FLIGHT_COUNT:
		var z: float=-2.10 if flight%2==0 else 2.10
		route.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[flight%2],0,z)))
		if flight<FireLookout.FLIGHT_COUNT-1:
			route.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[(flight+1)%2],0,z)))
	for fps in [30,60,144]:
		for sprint in [false,true]:
			var mode := ("sprint" if sprint else "walk")
			p.sim_sprint=sprint;p.stamina=100.0
			p.reset_jump(); p._camera_ground=NAN; p._ground_offset=0; p._vel=Vector2.ZERO
			p.position=tower.to_global(Vector3(FireLookout.STAIR_LANES[0],p.eye_h,1.95))
			samples.clear();var t:=[0.0];var ok:=true
			for target in route: ok=drive(p,tower,target,fps,t) and ok
			var up:=analyse("up_"+mode,fps)
			check(ok and absf(p.position.y-p.eye_h-h-FireLookout.DECK_Y)<.25,"reach the deck %s fps=%d"%[mode,fps])
			check(up.cv<.15 and up.rev<1.0,"ascent camera climbs steadily, no per-tread bounce %s fps=%d"%[mode,fps])
			var back:=route.duplicate();back.reverse();samples.clear()
			for target in back: ok=drive(p,tower,target,fps,t) and ok
			ok=drive(p,tower,tower.to_global(Vector3(FireLookout.STAIR_LANES[0],0,1.95)),fps,t) and ok
			var down:=analyse("down_"+mode,fps)
			check(ok and absf(p.position.y-p.eye_h-h)<.25,"reach the ground %s fps=%d"%[mode,fps])
			check(down.cv<.15 and down.rev<1.0,"descent camera falls steadily, no per-tread bounce %s fps=%d"%[mode,fps])
			var pace:float=(Player.SPRINT if sprint else Player.WALK)*FireLookout.STAIR_SPEED_MULT
			check(absf(up.speed-pace)<pace*.08 and absf(down.speed-pace)<pace*.08,"stair pace is %.0f%% of flat %s (up %.2f down %.2f want %.2f m/s) fps=%d"%[FireLookout.STAIR_SPEED_MULT*100,mode,up.speed,down.speed,pace,fps])
			check(up.lag<.25 and down.lag<.25,"camera stays within 25 cm of eye height on treads, landings and turns %s fps=%d"%[mode,fps])
	# Slowdown is on the flights only: landings, deck, ground keep full pace.
	var mid:=tower.to_global(Vector3(FireLookout.STAIR_LANES[0],FireLookout.FLIGHT_RISE*.5,0))
	var landing:=tower.to_global(Vector3(5.1,FireLookout.FLIGHT_RISE,-2.2))
	var deck:=tower.to_global(Vector3(0,FireLookout.DECK_Y,0))
	var beside:=tower.to_global(Vector3(8.5,0,0))
	check(is_equal_approx(tower.speed_mult_at(mid),FireLookout.STAIR_SPEED_MULT),"mid-flight tread is slowed")
	check(tower.speed_mult_at(landing)==1.0 and tower.speed_mult_at(deck)==1.0 and tower.speed_mult_at(beside)==1.0,"landing, deck and ground keep full pace")
	# Tucked desk chair: the aisle in front of the desk is open up to the backrest.
	var from:=tower.to_global(Vector3(1.35,FireLookout.DECK_Y,.30))
	var near:=tower.to_global(Vector3(1.35,FireLookout.DECK_Y,-.45));var free:=tower.resolve_at(near,from,.35)
	check(free.distance_to(Vector2(near.x,near.z))<.0001,"tucked chair leaves the desk aisle walkable")
	var into:=tower.to_global(Vector3(1.35,FireLookout.DECK_Y,-.80));var stop:=tower.resolve_at(into,from,.35)
	var stop_l:=tower.to_local(Vector3(stop.x,from.y,stop.y))
	check(stop_l.z>-.58 and stop_l.z<-.55,"backrest at the desk edge still blocks the body")
	p.free();tower.free();terrain.free();print("STAIR_CAMERA_TEST failures=",failures);quit(1 if failures else 0)
