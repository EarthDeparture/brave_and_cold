extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func run()->void:
	var z:=Zombie.new();root.add_child(z)
	z._model=(load(Zombie.MODEL) as PackedScene).instantiate();z.add_child(z._model)
	for candidate:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=candidate as Skeleton3D;break
	check(z._skin!=null,"live infected export contains a deforming skeleton")
	if z._skin==null:quit(1);return
	var sk:Skeleton3D=z._skin
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
	z.state=Zombie.State.CHASE;z.speed_now=1.4;z._attack_windup=.15;z._animate(.1)
	var cursor:=0;var motion:=0.0;var stretch:=1.0;var finite:=true
	for mesh:MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var actual:=skin_vertices(mesh,surface,sk);var original:=rest[cursor];cursor+=1
			for i in actual.size():finite=finite and actual[i].is_finite();motion=maxf(motion,actual[i].distance_to(original[i]))
			var indices:PackedInt32Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				for edge in 3:
					var a:=indices[i+edge];var b:=indices[i+(edge+1)%3]
					var length:=original[a].distance_to(original[b])
					if length>.001:stretch=maxf(stretch,actual[a].distance_to(actual[b])/length)
	print("INFECTED_VERTEX_METRICS bind_error_m=",bind_error," motion_m=",motion," max_edge_stretch=",stretch)
	check(finite and motion>.10,"attack deforms finite visible vertices")
	check(stretch<2.5,"attack has no stretched sleeve spikes")
	var moved:=0
	for i in sk.get_bone_count():
		if sk.get_bone_pose_rotation(i).angle_to(sk.get_bone_rest(i).basis.get_rotation_quaternion())>.02:moved+=1
	check(moved>=5,"movement and attack drive actual bone rotations")
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
	print("INFECTED_SKIN_TEST checks=",checks," failures=",failures);z.queue_free();await process_frame;quit(1 if failures else 0)
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
