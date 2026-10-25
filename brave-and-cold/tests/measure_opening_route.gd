extends SceneTree
## Scripted, fixed-step developer outing. Actual Player collision and survival;
## direct interaction callbacks, no exploration/menu time. Not a human playthrough.
const DT := 1.0/30.0
const ARRIVAL_DISTANCE := .24 # Match the established local traversal diagnostic.
var w: Node3D
var elapsed := 0.0
var distance := 0.0
var samples: Array = []
var failed := ""
var label := "candidate"
var ticks := 0
var record_frames := false
var next_frame_s := 0.0
var output := "res://shots/opening-pacing-2026-10-06/"
func _initialize() -> void: call_deferred("run")
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func mark(id: String) -> void:
	samples.append({"segment":id,"completed_so_far":failed.is_empty(),"real_s":elapsed,"calendar":w.clock.time_string(),"game_s":w.clock.total_game_s,"distance_m":distance,"calories":w.needs.calories,"water":w.needs.water,"fatigue":w.needs.fatigue,"core_c":w.body.core,"hp":w.player.health,"stove_game_hours":w.opening.fuel_s/3600,"wood_pack":w.inv.count("wood"),"food_pack":w.inv.count("beans"),"walkie_percent":w.opening.state.walkie_percent(),"position":[w.player.position.x,w.player.position.y,w.player.position.z]})
func tick() -> void:
	var before: Vector3 = w.player.position
	w.opening.boundary.advance_gate(DT)
	w.player._move(DT)
	w._process(DT)
	elapsed += DT; ticks += 1
	distance += Vector2(before.x,before.z).distance_to(Vector2(w.player.position.x,w.player.position.z))
	if ticks%30==0:
		await process_frame
	if record_frames and elapsed >= next_frame_s:
		next_frame_s += 10
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+label+"-frame-%04d.png"%int(elapsed))
func walk(target: Vector3, max_s: float = 15.0) -> bool:
	var left: float = max_s
	while left>0 and not w.player.dead:
		var d := Vector2(target.x-w.player.position.x,target.z-w.player.position.z)
		if d.length()<ARRIVAL_DISTANCE:
			w.player.sim_dir=Vector3.ZERO; return true
		var dir: Vector2 = d.normalized()
		w.player.sim_dir=Vector3(dir.x,0,dir.y)
		w.player.yaw=atan2(-dir.x,-dir.y); w.player.pitch=-.08
		w.player.rotation.y=w.player.yaw; w.player.cam.rotation.x=w.player.pitch
		await tick(); left-=DT
	failed="Waypoint blocked or player died: target=%s actual=%s"%[target,w.player.position]
	return false
func action(prefix: String) -> bool:
	w.player.sim_dir=Vector3.ZERO
	for entry: Dictionary in w.opening.actions():
		if not String(entry.text).begins_with(prefix): continue
		if w.player.position.distance_to(entry.pos)>3:
			failed="Action out of reach: "+prefix; return false
		entry=entry.duplicate(); entry.auto=true
		w._act_begin(entry)
		for i in 180:
			await tick()
			if w._act.is_empty():return true
		failed="Action did not finish: "+prefix; return false
	failed="Missing action: "+prefix; return false
func chain(route: Array[Vector3]) -> bool:
	for point: Vector3 in route:
		if not await walk(point):return false
	return true
func run() -> void:
	create_timer(240).timeout.connect(func()->void: print("FAIL measurement timeout"); quit(2))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("route_out="):output=arg.trim_prefix("route_out=")+"/"
		if arg.begins_with("route_label="):label=arg.trim_prefix("route_label=")
		if arg=="record_frames=1":record_frames=true
	DirAccess.make_dir_recursive_absolute(output); root.size=Vector2i(1280,720)
	SaveGame.pending={}; seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null and w.reading!=null:break
	freeze(w);w.out_path="measurement-no-autosave";w._frames=100
	w.player.sim_on=true;w.player.sim_dir=Vector3.ZERO
	# Match clock/weather origin; timers, survival and live population then advance.
	w.clock.hour=5.5;w.clock.day=1;w.clock.total_game_s=0
	w.opening.state.last_s=0;w.opening.state.align_calendar(1,5.5,0,true)
	w.body.core=37;w.needs.calories=2000;w.needs.water=85;w.needs.fatigue=0
	var tower:FireLookout=w.fire_lookout
	w.opening.state.receiver_on=true
	# Approach from the clear aisle, outside the desk chair's collision bounds.
	var ok:bool=await walk(tower.to_global(Vector3(.65,0,.05)))
	if ok:w.opening.toggle_walkie_dock()
	if not w.opening.state.walkie_carried:failed="Walkie pickup failed";ok=false
	mark("depart_room")
	if not w.fire_lookout.door_open:w.fire_lookout.toggle_door()
	var stairs:Array[Vector3]=[tower.to_global(Vector3(0,0,2.8)),tower.to_global(Vector3(3.45,0,2.3)),tower.to_global(Vector3(4.45,0,2.1)),tower.to_global(Vector3(5.80,0,2.1))]
	for flight in range(FireLookout.FLIGHT_COUNT-1,-1,-1):
		var z:float=2.1 if flight%2==0 else -2.1
		stairs.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[flight%2],0,z)))
		if flight>0:stairs.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[(flight-1)%2],0,z)))
	if ok:ok=await chain(stairs)
	mark("stairs_down")
	var cabinet:Vector3=w.opening.relay.to_global(Vector3(0,0,1.35))
	if ok:ok=await walk(cabinet)
	if ok:ok=await action("Inspect transfer cabinet")
	mark("cabinet_inspected")
	if not w.opening.boundary.gate_open:w.opening.boundary.toggle_gate()
	if ok:ok=await walk(tower.to_global(Vector3(-5,0,4)))
	if ok:ok=await walk(tower.to_global(Vector3(1.9,0,6)))
	if ok:ok=await walk(tower.to_global(Vector3(1.9,0,8.8)))
	var path:Array[Vector3]=[]
	for row:Array in tower.site.path.points_world_xyz:path.append(Vector3(row[0],row[1],row[2]))
	if path[0].distance_to(tower.global_position)>path[-1].distance_to(tower.global_position):path.reverse()
	var access_start:=0;var access_best:=INF
	for i in path.size():
		var d:float=Vector2(path[i].x,path[i].z).distance_squared_to(Vector2(w.player.position.x,w.player.position.z))
		if d<access_best:access_best=d;access_start=i
	var outward:Array[Vector3]=[]
	for i in range(access_start,path.size()):outward.append(path[i])
	if ok:ok=await chain(outward)
	mark("main_road")
	var store:Store=w.stores[0]
	var approach:Array[Vector3]=[]
	var nearest:=0;var best:=INF
	for i in w.road.points.size():
		var d:float=w.road.points[i].distance_squared_to(Vector2(w.player.position.x,w.player.position.z))
		if d<best:best=d;nearest=i
	var entry:Vector3=store.to_global(Vector3(0,0,4.2))
	var last:=0;best=INF
	for i in w.road.points.size():
		var d:float=w.road.points[i].distance_squared_to(Vector2(entry.x,entry.z))
		if d<best:best=d;last=i
	var inc:int=1 if last>=nearest else -1
	for i in range(nearest,last+inc,inc):approach.append(w._ground(w.road.points[i].x,w.road.points[i].y))
	approach.append(entry);approach.append(store.to_global(Vector3(0,0,1.7)));approach.append(store.to_global(Vector3(.6,0,1.02)))
	if ok:ok=await chain(approach)
	if ok:ok=await action("Collect reserved transfer relay")
	mark("depot_part_collected")
	approach.reverse()
	if ok:ok=await chain(approach)
	path.reverse()
	if ok:ok=await chain(path)
	if ok:ok=await walk(tower.to_global(Vector3(1.9,0,6)))
	if ok:ok=await walk(tower.to_global(Vector3(-5,0,4)))
	if ok:ok=await walk(cabinet)
	if ok:ok=await action("Install replacement transfer relay")
	if ok:ok=await action("Verify backup transfer")
	mark("cabinet_commissioned")
	if ok:ok=await walk(tower.to_global(Vector3(-5,0,4)))
	if ok:ok=await walk(tower.to_global(Vector3(1.9,0,6)))
	stairs.reverse()
	if ok:ok=await chain(stairs)
	if ok:ok=await walk(tower.to_global(Vector3(0,0,.3)))
	if ok and (not tower.contains_room(w.player.position) or w.opening.state.repair_stage!=3):
		failed="Route ended outside the living room or before commissioning";ok=false
	ok=ok and failed.is_empty()
	mark("returned_room")
	var receipt:Dictionary={"label":label,"pace":w.clock.base_time_scale,"completed":ok,"failure":failed,"samples":samples,"repair_stage":w.opening.state.repair_stage,"renderer":RenderingServer.get_video_adapter_name(),"limitations":"Scripted fixed-step route with actual Player movement/collision, world survival/weather and population tick. Direct action callbacks and no menu/exploration time; other entity process/animation is frozen. Not human playtesting or a frame-time benchmark. No user save files used."}
	var f:=FileAccess.open(output+label+"-route.json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "));f.close()
	print("OPENING_ROUTE_MEASURE ",JSON.stringify(receipt))
	w.queue_free();await process_frame;SaveGame.pending={};quit(0 if ok else 1)
