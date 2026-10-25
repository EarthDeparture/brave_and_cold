extends SceneTree
## Actual world movement and rendered-surface contracts, including raised objects.
var failed:=0
var max_contact_error:=0.0
var max_camera_jerk:=0.0
var previous_camera_dy:=0.0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failed+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func spawn(p:Player,q:Vector2)->void:
	previous_camera_dy=0.0
	p.reset_jump();p.cam.position=Vector3.ZERO;p.position=Vector3(q.x,400,q.y);p.position.y=p.ground_at(q.x,q.y)+p.eye_h;p._vel=Vector2.ZERO;p._snow_mult=1.0;p._ready_ground=true
func drive(p:Player,q:Vector2,fps:int=60)->bool:
	for frame in 12*fps:
		var dir:=q-Vector2(p.position.x,p.position.z)
		if dir.length()<.12:return true
		dir=dir.normalized();p.sim_dir=Vector3(dir.x,0,dir.y)
		var old_y:=p.position.y+p.cam.position.y;p._move(1.0/fps)
		var dy:=p.position.y+p.cam.position.y-old_y;max_camera_jerk=maxf(max_camera_jerk,absf(dy-previous_camera_dy));previous_camera_dy=dy
		max_contact_error=maxf(max_contact_error,absf(p.position.y-p.eye_h-p.ground_at(p.position.x,p.position.z)))
	return false
func run()->void:
	seed(20261003);SaveGame.pending={}
	var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud!=null:break
	if world.hud==null:check(false,"world ready");quit(1);return
	freeze(world);var p:Player=world.player;p.sim_on=true;p.frozen=false
	var reached:=true;var count:=0
	for fps in [30,60,120]:
		for index in range(8,world.road.points.size()-12,32):
			for reverse in [false,true]:
				var begin:=index+8 if reverse else index;var end:=index if reverse else index+8
				spawn(p,world.road.points[begin])
				for j in range(begin,end+(-1 if reverse else 1),-1 if reverse else 1):
					reached=drive(p,world.road.points[j],fps) and reached
				count+=1
	check(reached,"192 road-route walks at 30/60/120 FPS with full world collision")
	for reverse in [false,true]:
		var begin:int=world.road.points.size()-1 if reverse else 0
		var end:int=0 if reverse else world.road.points.size()-1
		spawn(p,world.road.points[begin]);var complete:=true
		for j in range(begin,end+(-1 if reverse else 1),-1 if reverse else 1):
			complete=drive(p,world.road.points[j]) and complete
			if j%256==0:print("FULL_ROAD_PROGRESS reverse=",reverse," point=",j," ok=",complete)
		check(complete,"complete 2.56 km road traversable reverse %s"%reverse)
	check(max_contact_error<.002,"feet remain on queried floor (no camera-lag penetration)")
	for lateral in [-2.2,0.0,2.2]:
		for reverse in [false,true]:
			var br:Array=world.road.bridges[0];var begin:int=br[1]+5 if reverse else br[0]-5;var end:int=br[0]-5 if reverse else br[1]+5
			var points:Array[Vector2]=[]
			for j in range(begin,end+(-1 if reverse else 1),-1 if reverse else 1):
				var d:Vector2=(world.road.points[j+1]-world.road.points[j-1]).normalized();points.append(world.road.points[j]+Vector2(-d.y,d.x)*lateral)
			spawn(p,points[0]);var ok:=true
			for q in points:ok=drive(p,q) and ok
			check(ok,"bridge crossing side %.1f reverse %s"%[lateral,reverse])
	var br:Array=world.road.bridges[0];var index:int=br[0]+4;var q:Vector2=world.road.points[index]
	var d:Vector2=(world.road.points[index+1]-world.road.points[index-1]).normalized();var n:=Vector2(-d.y,d.x)
	var height:float=world.road.walk_surface.height_at(q.x,q.y)
	check(is_nan(world.road.floor_at_world(Vector3(q.x,height-3,q.y))),"actor below bridge cannot snap up onto deck")
	var previous:=Vector3(q.x,height,q.y);var edge:Vector2=q+n*3.4
	var corrected:Vector2=world.road.resolve_at(Vector3(edge.x,height,edge.y),previous,.35)
	check((corrected-q).length()<3.0,"bridge guardrail stops walking through deck side")
	var crate:=StorageChest.new();world.add_child(crate);crate.position=Vector3(q.x,height+21,q.y)
	var below:=crate.resolve_at(Vector3(q.x,height,q.y),1.7,.35)
	var contact:=crate.resolve_at(Vector3(q.x,height+21,q.y),1.7,.35)
	check(below==q and contact.distance_to(q)>.35,"elevated crate solid at its floor, clear underneath")
	check(absf(RoadNet.lift(height-2,q.x,q.y)-height)<.001,"creature spawns share visible road and bridge height")
	check(RoadNet.lift(height-3,q.x,q.y,height-3)<height-2.9,"creature beneath bridge retains lower elevation")
	var creature_ok:=true
	for actor in [world._add_wolf(Vector3(q.x,height-2,q.y),9001),world._add_deer(Vector3(q.x,height-2,q.y),9002),world._new_zombie(Vector3(q.x,height-2,q.y),9003)]:
		actor.set_process(false)
		for frame in 30:actor._move(0.0,1.0/60.0)
		creature_ok=creature_ok and absf(actor.global_position.y-height)<.002
	check(creature_ok,"actual wolf, deer and zombie remain on bridge deck")
	var access:WalkRibbon3D=world.fire_lookout.access_ribbon
	check(access!=null and not access.walk_surface._cells.is_empty(),"lookout access path has matching rendered floor")
	var door_count:=0;var doors_ok:=true
	for cabin in p.cabins:
		if not (cabin is Cabin or cabin is Hut or cabin is Store):continue
		var hz:float=Cabin.HZ if cabin is Cabin else (Hut.HZ if cabin is Hut else Store.HZ)
		var ramp:float=Cabin.RAMP_LEN if cabin is Cabin else (Hut.RAMP_LEN if cabin is Hut else Store.RAMP_LEN)
		var porch:float=1.5 if cabin is Store else .4
		cabin.door_open=true
		var a:Vector3=cabin.to_global(Vector3(0,0,hz+porch+ramp+.5))
		var b:Vector3=cabin.to_global(Vector3(0,0,hz-.7))
		spawn(p,Vector2(a.x,a.z));doors_ok=drive(p,Vector2(b.x,b.z)) and doors_ok
		doors_ok=drive(p,Vector2(a.x,a.z)) and doors_ok;door_count+=1
	check(doors_ok and door_count>=16,"all cabin, hut and store entrance ramps traversable in both directions")
	print("WALK_SURFACE_TEST_COMPLETE failures=",failed," routes=",count," max_contact_error_m=",max_contact_error," max_camera_step_change_m=",max_camera_jerk)
	quit(0 if failed==0 else 1)
