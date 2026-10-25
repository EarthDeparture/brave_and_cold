extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c in n.get_children():freeze(c)
func reset(p:Player,point:Vector3)->void:
	p.reset_jump();p.position=point;p.eye_h=Player.EYE;p.position.y=p.ground_at(point.x,point.z)+p.eye_h
	p._ready_ground=true;p._vel=Vector2.ZERO;p._snow_mult=1;p._bob_amp=0;p.stamina=100;p.exhausted=false;p.frozen=false;p.sim_on=true
func walk(p:Player,target:Vector3,seconds:float=6)->float:
	for frame in int(seconds*60):
		var d:=Vector2(target.x-p.position.x,target.z-p.position.z)
		if d.length()<.24:return d.length()
		p.sim_dir=Vector3(d.normalized().x,0,d.normalized().y);p._move(1.0/60)
	return Vector2(target.x-p.position.x,target.z-p.position.z).length()
func run()->void:
	SaveGame.pending={}
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null:break
	freeze(w)
	var p:Player=w.player;var op:LookoutOpening=w.opening;var boundary:=op.boundary
	var rows:Array=w.fire_lookout.site.path.points_world_xyz
	var start:Vector3=Vector3(rows[rows.size()-12][0],0,rows[rows.size()-12][2]);reset(p,start)
	var blocked_target:=boundary.to_global(boundary.ground_local(1.9,6.8))
	for i in range(rows.size()-11,rows.size()-7):
		var row:Array=rows[i];walk(p,Vector3(row[0],0,row[2]))
	var closed_distance:=walk(p,blocked_target)
	check(closed_distance>.35,"actual player stops at closed gate on logging approach")
	reset(p,start) # Move clear of the outward swing after testing the closed leaf.
	boundary.toggle_gate();boundary.advance_gate(RefugeBoundary.GATE_SWING_S)
	var remaining:=0.0
	for i in range(rows.size()-11,rows.size()):
		var row:Array=rows[i];remaining=maxf(remaining,walk(p,Vector3(row[0],0,row[2])))
	check(remaining<.30,"actual player follows preserved logging track through open gate to stair base")
	# Unobstructed yard headings must not acquire lateral correction from distant fence segments.
	# The former (-8,2) sample is now occupied by the existing solar rack.
	var changed:=0;var cases:=0
	for local:Vector2 in [Vector2(-5,0),Vector2(-5,4),Vector2(0,-5),Vector2(-8,4)]:
		for direction in 16:
			var from:=boundary.to_global(boundary.ground_local(local.x,local.y))
			var d:=Vector3(cos(direction*TAU/16),0,sin(direction*TAU/16));var candidate:=from+d*.04
			var q:=boundary.resolve_at(candidate,from,.30)
			if q!=Vector2(candidate.x,candidate.z):
				changed+=1;print("YARD_DIAG local=",local," direction=",direction," error=",q.distance_to(Vector2(candidate.x,candidate.z)))
			cases+=1
	check(changed==0,"64 free yard headings retain exact candidate movement")
	# Every perimeter segment blocks crossings, including both actors and gate joins.
	boundary.toggle_gate();boundary.advance_gate(RefugeBoundary.GATE_SWING_S);var blocked:=0
	for wall:Array in boundary.segments:
		var a:Vector2=wall[0];var b:Vector2=wall[1];var mid:Vector2=(a+b)*.5;var normal:=Vector2(-(b-a).normalized().y,(b-a).normalized().x)
		for side in [-1,1]:
			var from:=boundary.to_global(boundary.ground_local(mid.x+normal.x*side,mid.y+normal.y*side))
			var to:=boundary.to_global(boundary.ground_local(mid.x-normal.x*.1*side,mid.y-normal.y*.1*side))
			if boundary.resolve_at(to,from,.30).distance_to(Vector2(to.x,to.z))>.2:blocked+=1
	check(blocked==boundary.segments.size()*2,"all ten perimeter crossings block in both directions")
	var under:=boundary.to_global(Vector3(1.9,FireLookout.DECK_Y,7.1));var upper:=under+Vector3(0,0,-.2)
	check(boundary.resolve_at(upper,under,.30)==Vector2(upper.x,upper.z),"ground perimeter never pushes an upstairs occupant")
	print("OPENING_TRAVERSAL_TEST failures=",failures," free_cases=",cases," route_error=",remaining)
	w.queue_free();await process_frame;quit(1 if failures else 0)
