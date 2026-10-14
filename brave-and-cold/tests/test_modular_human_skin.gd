extends SceneTree
var failures:=0
var checks:=0
class SlopedZombie extends Zombie:
	var ground_gradient:=Vector2.ZERO
	var stepped_floor:=false
	func _corpse_floor(p:Vector3)->float:return ground_gradient.dot(Vector2(p.x,p.z))+(.18 if stepped_floor and p.x>-.04 else 0.0)
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func run()->void:
	var z:=SlopedZombie.new();root.add_child(z)
	var model_id:=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "rowan"
	z._model=(load("res://assets/modular_human/"+model_id+".glb") as PackedScene).instantiate();z.add_child(z._model)
	for candidate:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=candidate as Skeleton3D;break
	check(z._skin!=null,"live infected export contains a deforming skeleton")
	if z._skin==null:quit(1);return
	var sk:Skeleton3D=z._skin
	check(sk.get_bone_count()==45,"imported modular character has all forty-five deformation bones")
	for side:String in ["l","r"]:
		for pair:Array in [["zombie_arm_",z._arms],["zombie_leg_",z._legs],["zombie_knee_",z._knees],["zombie_elbow_",z._elbows]]:
			var driver:=z._model.find_child(pair[0]+side,true,false) as Node3D
			check(driver!=null,"logical joint retained: "+pair[0]+side)
			if driver==null:continue
			pair[1].append(driver)
			var bone:=sk.find_bone("skin_"+String(driver.name))
			if bone>=0:z._skin_drivers[bone]=driver
	check(z._skin_drivers.size()==8,"all eight existing limb drivers map to skin bones")
	var meshes:Array[MeshInstance3D]=[]
	var rest:Array[PackedVector3Array]=[]
	var bind_error:=0.0
	for mesh:MeshInstance3D in z._model.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		meshes.append(mesh)
		for surface in mesh.mesh.get_surface_count():
			var actual:=skin_vertices(mesh,surface,sk)
			var original:PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i in original.size():bind_error=maxf(bind_error,actual[i].distance_to(original[i]))
			rest.append(actual)
	check(bind_error<.0001,"exported skin bind preserves actual rest vertices")
	for factor:float in [1.0,1.7]:
		var finger_bones:=0
		for side:String in ["l","r"]:
			for digit:String in ["index","middle","ring","little","thumb"]:
				for segment in range(1,4):
					var bone:=sk.find_bone("%s_%d_%s"%[digit,segment,side]);var frame:=sk.get_bone_global_rest(bone).basis.orthonormalized()
					var curl:float=[.10,.27,.12][segment-1]*factor*(.6 if digit=="thumb" else 1)
					sk.set_bone_pose_rotation(bone,(sk.get_bone_rest(bone).basis*frame.inverse()*Basis(Vector3.RIGHT,curl)*frame).get_rotation_quaternion());finger_bones+=1
		var hand_motion:=0.0;var hand_stretch:=1.0;var rest_cursor:=0;var hand_region:=""
		for mesh:MeshInstance3D in meshes:
			for surface in mesh.mesh.get_surface_count():
				var actual:=skin_vertices(mesh,surface,sk);var original:=rest[rest_cursor];rest_cursor+=1
				if String(mesh.name)!="Hands":continue
				for i in actual.size():hand_motion=maxf(hand_motion,actual[i].distance_to(original[i]))
				var ids:PackedInt32Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
				for i in range(0,ids.size(),3):
					for edge in 3:
						var a:=ids[i+edge];var b:=ids[i+(edge+1)%3];var length:=original[a].distance_to(original[b])
						if length>.001:
							var ratio:=actual[a].distance_to(actual[b])/length
							if ratio>hand_stretch:hand_stretch=ratio;hand_region=str(original[a])+" → "+str(original[b])
		print("HAND_VERTEX_METRICS factor=",factor," motion=",hand_motion," stretch=",hand_stretch)
		if hand_stretch>=2.5:print("HAND_STRETCHED_REGION ",hand_region)
		check(finger_bones==30 and hand_motion>.005 and hand_stretch<2.5,"civilian/infected finger poses deform actual hands without spikes "+str(factor))
	sk.reset_bone_poses()
	z.state=Zombie.State.CHASE;z.speed_now=1.4;z._attack_windup=.15;z._animate(.1)
	var cursor:=0;var motion:=0.0;var stretch:=1.0;var finite:=true;var stretched_region:=""
	for mesh:MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var actual:=skin_vertices(mesh,surface,sk);var original:=rest[cursor];cursor+=1
			for i in actual.size():finite=finite and actual[i].is_finite();motion=maxf(motion,actual[i].distance_to(original[i]))
			var indices:PackedInt32Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				for edge in 3:
					var a:=indices[i+edge];var b:=indices[i+(edge+1)%3]
					var length:=original[a].distance_to(original[b])
					if length>.001:
						var ratio:=actual[a].distance_to(actual[b])/length
						if ratio>stretch:stretch=ratio;stretched_region=String(mesh.name)+" "+str(original[a])+" → "+str(original[b])
	print("INFECTED_VERTEX_METRICS bind_error_m=",bind_error," motion_m=",motion," max_edge_stretch=",stretch)
	if stretch>=2.5:print("STRETCHED_REGION ",stretched_region)
	check(finite and motion>.10,"attack deforms finite visible vertices")
	check(stretch<2.5,"attack has no stretched sleeve spikes")
	var moved:=0
	for i in sk.get_bone_count():
		if sk.get_bone_pose_rotation(i).angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion())>.02:moved+=1
	check(moved>=5,"movement and attack drive actual bone rotations")
	var equivalent:=true
	for frame in 40:
		for bone:int in z._skin_drivers:
			var driver:Node3D=z._skin_drivers[bone];driver.rotation=Vector3(sin(frame*.2)*.7,cos(frame*.3)*.2,sin(frame*.4)*.1)
		z._deform_skin()
		for bone:int in z._skin_drivers:
			var driver:Node3D=z._skin_drivers[bone];var basis_frame:=sk.get_bone_global_rest(bone).basis.orthonormalized()
			var original:=sk.get_bone_rest(bone).basis*basis_frame.inverse()*Basis.from_euler(driver.rotation)*basis_frame
			equivalent=equivalent and absf(original.get_rotation_quaternion().dot(sk.get_bone_pose_rotation(bone)))>.999999
	check(equivalent,"cached rest transforms preserve rotations over forty multi-axis poses")
	var skinned:=0
	for mesh:MeshInstance3D in z._model.find_children("*","MeshInstance3D",true,false):
		if mesh.skin!=null:skinned+=1
	check(skinned>0,"visible runtime mesh uses actual skin bind weights")
	z._make_crawler();z.activate(Vector3.ZERO,77)
	var clean:=true
	for i in sk.get_bone_count():
		var ok:=sk.get_bone_pose_scale(i).distance_to(sk.get_bone_rest(i).basis.get_scale())<.0001 and sk.get_bone_pose_rotation(i).angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion())<.001
		clean=clean and ok
		if not ok:print("RESET_BONE ",sk.get_bone_name(i)," scale=",sk.get_bone_pose_scale(i)," angle=",sk.get_bone_pose_rotation(i).angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion()))
	check(clean,"pool activation resets skin deformation and crawler scale")
	var deaths:=[0];z.died.connect(func()->void:deaths[0]+=1)
	for variant:String in ["standing","attack","walking","heavy","crawler","sleeper"]:
		z.activate(Vector3.ZERO,78,Zombie.Kind.HEAVY if variant=="heavy" else (Zombie.Kind.SLEEPER if variant=="sleeper" else 0))
		z.set_process(false)
		if variant=="attack":z.state=Zombie.State.CHASE;z.speed_now=1.4;z._attack_windup=.1;z._animate(.1)
		if variant=="walking":z.state=Zombie.State.CHASE;z.speed_now=1.4;z._gait_speed=1.4;z._animate(.2)
		if variant=="crawler":z._make_crawler()
		var deaths_before:int=deaths[0];z.hit(999,Vector3.ZERO);z.hit(999,Vector3.ZERO);z._die()
		check(z.is_dead() and deaths[0]==deaths_before+1 and z._attack_windup<0 and not z.is_in_group("hostile"),"death remains immediate and single-shot: "+variant)
		var lowest:=INF;var highest:=-INF;var death_stretch:=1.0;var finite_death:=true;var death_region:=""
		for t:float in [0.0,.15,.35,.55,.75,1.0]:
			z._death_pose(t);var rest_cursor:=0
			for mesh:MeshInstance3D in meshes:
				for surface in mesh.mesh.get_surface_count():
					var actual:=skin_vertices(mesh,surface,sk);var original:=rest[rest_cursor];rest_cursor+=1
					for v:Vector3 in actual:
						var p:=sk.global_transform*v;finite_death=finite_death and p.is_finite()
						lowest=minf(lowest,p.y)
						if t==1.0:highest=maxf(highest,p.y)
					var ids:PackedInt32Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
					for i in range(0,ids.size(),3):
						for edge in 3:
							var a:=ids[i+edge];var b:=ids[i+(edge+1)%3];var length:=original[a].distance_to(original[b])
							if length>.001:
								var ratio:=actual[a].distance_to(actual[b])/length
								if ratio>death_stretch:death_stretch=ratio;death_region=String(mesh.name)+" "+str(original[a])+" → "+str(original[b])
		print("DEATH_VERTEX_METRICS ",variant," low=",lowest," settled_top=",highest," edge_stretch=",death_stretch)
		if death_stretch>=2.5:print("DEATH_STRETCHED_REGION ",death_region)
		check(finite_death and lowest>=-.012,"collapse keeps actual mesh above supporting floor: "+variant)
		check(highest<.65 and death_stretch<2.5,"settled corpse has bounded silhouette and no joint spikes: "+variant)
		z.activate(Vector3.ZERO,79);z.set_process(false)
		check(z._dead_t==0 and z._death_progress==0 and not z.is_in_group("bodies") and z._model.position==Vector3.ZERO,"reused actor clears all death presentation: "+variant)
	z.activate(Vector3.ZERO,80,Zombie.Kind.SLEEPER);z._wake();z._die()
	check(z._wake_tween==null or not z._wake_tween.is_running(),"death cancels a pending sleeper rise so it cannot overwrite the collapse")
	z.activate(Vector3.ZERO,82);z.set_process(false);z._vault_t=0;z._vault_from=Vector3.ZERO;z._vault_to=Vector3(0,0,-1)
	z._do_vault(.2)
	var vault_bone:=sk.find_bone("skin_zombie_arm_l")
	check(sk.get_bone_pose_rotation(vault_bone).angle_to(sk.get_bone_rest(vault_bone).basis.get_rotation_quaternion())>1.0,"vault reaching drives the actual weighted arm after the logical pose changes")
	for grade:Vector2 in [Vector2(.12,.10),Vector2(-.14,-.10)]:
		z.activate(Vector3.ZERO,81);z.set_process(false);z.ground_gradient=grade;z._die()
		var clearance:=INF;var raised:=-INF
		for t:float in [.2,.5,.8,1.0]:
			z._death_pose(t)
			for mesh:MeshInstance3D in meshes:
				for surface in mesh.mesh.get_surface_count():
					for vertex:Vector3 in skin_vertices(mesh,surface,sk):
						var p:=sk.global_transform*vertex;clearance=minf(clearance,p.y-z._corpse_floor(p))
						if t==1.0:raised=maxf(raised,p.y-z._corpse_floor(p))
		print("SLOPE_CORPSE_METRICS grade=",grade," clearance=",clearance," raised=",raised)
		check(clearance>=-.012 and raised<.60,"actual corpse mesh settles against inclined support: "+str(grade))
	z.ground_gradient=Vector2.ZERO;z.stepped_floor=true;z.activate(Vector3.ZERO,83);z.set_process(false);z._die();z._death_pose(1)
	var threshold_clearance:=INF
	for mesh:MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			for vertex:Vector3 in skin_vertices(mesh,surface,sk):
				var p:=sk.global_transform*vertex;threshold_clearance=minf(threshold_clearance,p.y-z._corpse_floor(p))
	check(threshold_clearance>=-.012,"conservative cached support does not bury the corpse at a floor threshold")
	print("MODULAR_HUMAN_SKIN_TEST checks=",checks," failures=",failures);z.queue_free();await process_frame;quit(1 if failures else 0)
func skin_vertices(mesh:MeshInstance3D,surface:int,sk:Skeleton3D)->PackedVector3Array:
	var arrays:=mesh.mesh.surface_get_arrays(surface)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var matrices:Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=sk.find_bone(mesh.skin.get_bind_name(bind))
		if bone<0:bone=mesh.skin.get_bind_bone(bind)
		matrices.append(sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var result:=PackedVector3Array();var stride:=int(weights.size()/vertices.size())
	for i in vertices.size():
		var v:=Vector3.ZERO
		for j in stride:v+=(matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
		result.append(v)
	return result
