extends SceneTree
var checks:=0
var failures:=0
class Walker extends Zombie:
	var grade:=Vector2.ZERO
	func _corpse_floor(p:Vector3)->float:return grade.dot(Vector2(p.x,p.z))
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func make_actor()->Walker:
	var z:=Walker.new();root.add_child(z);z.set_process(false)
	z._model=(load(Zombie.MODEL) as PackedScene).instantiate();z.add_child(z._model)
	for n:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=n as Skeleton3D;break
	for ap:AnimationPlayer in z._model.find_children("*","AnimationPlayer",true,false):ap.stop()
	for side:String in ["l","r"]:
		for pair:Array in [["zombie_arm_",z._arms],["zombie_leg_",z._legs],["zombie_knee_",z._knees],["zombie_elbow_",z._elbows]]:
			var joint:=z._model.find_child(pair[0]+side,true,false) as Node3D;pair[1].append(joint)
			z._skin_drivers[z._skin.find_bone("skin_"+String(joint.name))]=joint
	z._bind_skin_drivers();return z
func run()->void:
	var z:=make_actor()
	var rubber:=z._model.find_child("Skin_rubber",true,false) as MeshInstance3D
	var sole_points:Array=[]
	var arr:=rubber.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var slots:PackedInt32Array=arr[Mesh.ARRAY_BONES]
	var weights:PackedFloat32Array=arr[Mesh.ARRAY_WEIGHTS];var count:=weights.size()/vertices.size()
	for v in vertices.size():
		if vertices[v].y>.013:continue
		var main:=0
		for j in count:
			if weights[v*count+j]>weights[v*count+main]:main=j
		var bind:=slots[v*count+main];var bone:=z._skin.find_bone(rubber.skin.get_bind_name(bind))
		sole_points.append([vertices[v],bone,rubber.skin.get_bind_pose(bind),0 if vertices[v].x<0 else 1])
	check(sole_points.size()>20,"actual imported boot soles supply contact vertices")
	check(z._skin.get_bone_count()==13 and z._ankle_frames.size()==2,"13-bone export retains both independent ankles")
	var cadence_ok:=true
	for fps:int in [30,60,120]:
		for speed:float in [.8,2.4]:
			for grade:Vector2 in [Vector2.ZERO,Vector2(.08,.12),Vector2(-.10,-.14)]:
				z.activate(Vector3.ZERO,14);z.set_process(false);z.rotation.y=0;z.grade=grade;z._phase=0;z.state=Zombie.State.CHASE;z.speed_now=speed;z._gait_speed=speed
				var error:=0.0;var sole_error:=0.0;var upright:=1.0;var finite:=true;var stance_frames:=0
				for frame in fps*3:
					z.position.z-=speed/fps;z.position.y=z._corpse_floor(z.position);z._animate(1.0/fps)
					for i in 2:
						var bone:=z._skin.find_bone("skin_zombie_ankle_"+("l" if i==0 else "r"))
						var pose:=z._skin.global_transform*z._skin.get_bone_global_pose(bone)
						finite=finite and pose.is_finite()
						if z._gait.planted[i]:
							stance_frames+=1;error=maxf(error,pose.origin.distance_to(z._gait.anchors[i]))
					for point:Array in sole_points:
						if not z._gait.planted[point[3]]:continue
						var xf:Transform3D=z._skin.global_transform*z._skin.get_bone_global_pose(point[1])*point[2]
						var p:Vector3=xf*point[0]
						sole_error=maxf(sole_error,absf(p.y-z._corpse_floor(p)))
						upright=minf(upright,(xf.basis*Vector3.UP).normalized().dot(z._gait.floor_bases[point[3]].y))
				print("GAIT_METRICS fps=",fps," speed=",speed," grade=",grade," ankle_anchor_error_m=",error," sole_plane_error_m=",sole_error," sole_normal_dot=",upright)
				check(finite and stance_frames>fps and error<.006,"world-space stance holds under measured travel: %d / %.1f / %s"%[fps,speed,grade])
				check(sole_error<.003 and upright>.999,"visible boot soles follow ground plane: %d / %.1f / %s"%[fps,speed,grade])
				var cycles_per_second:=z._phase/TAU/3
				cadence_ok=cadence_ok and (cycles_per_second>.6 and cycles_per_second<1.0 if speed<1 else cycles_per_second>1.5 and cycles_per_second<2.0)
	check(cadence_ok,"walking/chase cadence retains adult-length strides across all frame rates")
	z.grade=Vector2.ZERO;z.activate(Vector3.ZERO,15);z.set_process(false);z.speed_now=1;z._gait_speed=1;z._animate(.05)
	z._gait_speed=0;z._animate(.05)
	check(not z._gait.active and z._model.position.y==0,"blocked movement releases contacts and visual crouch")
	for reason:String in ["stagger","vault","crawler","death","sleep"]:
		z.activate(Vector3.ZERO,16);z.set_process(false);z.speed_now=1;z._gait_speed=1;z._animate(.05)
		if reason=="stagger":z._stagger=.4
		if reason=="vault":z._vault_t=.1
		if reason=="crawler":z._make_crawler()
		if reason=="death":z.state=Zombie.State.DEAD
		if reason=="sleep":z.state=Zombie.State.SLEEP
		z._animate(.05);check(not z._gait.active,"contacts release on "+reason)
	z.activate(Vector3.ZERO,17);check(not z._gait.active and not z._gait.planted[0] and not z._gait.planted[1],"pool reuse clears both old world-space contacts")
	z.activate(Vector3.ZERO,18,Zombie.Kind.HEAVY);z.set_process(false);z.rotation.y=0;z.grade=Vector2(.08,.12);z.speed_now=1;z._gait_speed=1;z._phase=0
	var heavy_error:=0.0
	for i in 120:
		z.position.z-=1.0/60;z.position.y=z._corpse_floor(z.position);z._animate(1.0/60)
		for side in 2:
			if not z._gait.planted[side]:continue
			var bone:=z._skin.find_bone("skin_zombie_ankle_"+("l" if side==0 else "r"))
			heavy_error=maxf(heavy_error,(z._skin.global_transform*z._skin.get_bone_global_pose(bone)).origin.distance_to(z._gait.anchors[side]))
	check(heavy_error<.006,"heavy actor scale preserves stance contact on a grade")
	z.grade=Vector2.ZERO;z.activate(Vector3.ZERO,19);z.set_process(false);z.rotation.y=0;z._phase=0;z.speed_now=1;z._gait_speed=1;z._animate(.01)
	var previous:=z._gait.anchors.duplicate();z.rotation.y=.18;z._animate(.01)
	check(z._gait.anchors[0].distance_to(previous[0])>.005,"turning releases and reseats the stance instead of dragging a locked foot")
	z.free();print("INFECTED_GAIT_TEST checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
