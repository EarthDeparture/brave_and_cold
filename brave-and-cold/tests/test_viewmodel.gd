extends SceneTree
## Real imported skinning and grip continuity, including missing immutable tracks.
var failures := 0
var p: Player
var vm: Viewmodel
func _initialize() -> void: call_deferred("run")
func check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func pose(mode_name: String, swing_time := -1.0, fire_time := -1.0, aim := 0.0) -> void:
	vm.mode = mode_name; vm._cur = mode_name; vm._equip = 1.0
	vm._clock = 0.0; vm.freeze_t = 0.0; vm._swing_t = -1.0; vm._fire_t = -1.0
	p.aim_k = aim; p.cam.fov = lerpf(70.0,36.0,aim)
	if swing_time >= 0.0:
		vm.swing(mode_name=="axe"); vm.freeze_t = swing_time
	if fire_time >= 0.0:
		vm.fire(); vm.freeze_t = fire_time
	vm._process(0.0)
func cuff_ok() -> bool:
	return vm._right.position.distance_to(vm._sl_r.position)<.0001 and (not vm._left.visible or vm._left.position.distance_to(vm._sl_l.position)<.0001)
func skin_vertices(hand: SurvivorHandRig) -> PackedVector3Array:
	var mesh := hand.bare
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var matrices: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone := hand.skeleton.find_bone(mesh.skin.get_bind_name(bind))
		if bone<0: bone=mesh.skin.get_bind_bone(bind)
		matrices.append(hand.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var result := PackedVector3Array()
	var stride := int(weights.size()/vertices.size())
	for i in vertices.size():
		var v := Vector3.ZERO
		for j in stride:
			v += (matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
		result.append(v)
	return result
func run() -> void:
	p = Player.new(); root.add_child(p); p.set_process(false)
	p.cam = Camera3D.new(); p.add_child(p.cam)
	vm = Viewmodel.new(); vm.detail_enabled = OS.get_cmdline_user_args().has("detail=winter"); vm.player = p; p.cam.add_child(vm); vm.set_process(false)
	check("Both hands have a 16-bone articulated skin, with mirrored left anatomy",vm._right.skeleton.get_bone_count()==16 and vm._left.skeleton.get_bone_count()==16 and vm._left.mirrored)
	var material_ok := true
	for h in [vm._right,vm._left]:
		for mesh in [h.bare,h.glove]:
			var m := mesh.get_surface_override_material(0) as StandardMaterial3D
			material_ok = material_ok and mesh.skin!=null and m.albedo_texture!=null and m.normal_enabled and m.normal_texture!=null
	check("Bare skin and leather gloves retain actual skinning and embedded paint/normal maps",material_ok)
	vm._right.pose("Open")
	var resting := skin_vertices(vm._right)
	var original: PackedVector3Array = vm._right.bare.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rest_error := 0.0
	for i in original.size(): rest_error=maxf(rest_error,original[i].distance_to(resting[i]))
	check("Open pose preserves bind geometry, including discarded constant wrist tracks",rest_error<.00001)
	print("HAND_BIND_ERROR metres=",rest_error)
	var finite := true
	var movement := 0.0
	for grip in ["Fist","Shaft","Trigger","Support","Bolt"]:
		vm._right.pose(grip)
		var deformed := skin_vertices(vm._right)
		for i in deformed.size():
			finite = finite and deformed[i].is_finite()
			movement=maxf(movement,deformed[i].distance_to(resting[i]))
	check("All five grips deform the imported vertices without non-finite skin coordinates",finite and movement>.06)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/viewmodel/survivor_hand_rig.json"))
	var contact_error := 0.0
	var mirror_error := 0.0
	for grip in metadata.thumb_targets_godot:
		vm._right.pose(grip)
		vm._left.pose(grip)
		var tip_bone := vm._right.skeleton.find_bone("thumb_03")
		var tip := vm._right.skeleton.get_bone_global_pose(tip_bone)*Vector3(0,float(metadata.thumb_distal_length),0)
		var target: Array = metadata.thumb_targets_godot[grip]
		contact_error=maxf(contact_error,tip.distance_to(Vector3(target[0],target[1],target[2])))
		for bone in vm._right.skeleton.get_bone_count():
			var right := vm._right.skeleton.get_bone_global_pose(bone).origin
			var left_bone := vm._left.skeleton.find_bone(vm._right.skeleton.get_bone_name(bone))
			var left := vm._left.skeleton.get_bone_global_pose(left_bone).origin
			mirror_error=maxf(mirror_error,left.distance_to(Vector3(-right.x,right.y,right.z)))
	check("Thumb joints reach the fitted grip targets within 1 mm",contact_error<.001)
	check("Both native skeletons preserve mirrored joint motion without negative node scale",mirror_error<.00001 and vm._left.skeleton.global_basis.determinant()>0.0)
	print("HAND_CONTACT_ERROR metres=",contact_error," mirror_error=",mirror_error)
	var valid := true
	for i in range(83):
		pose("axe",i*.01)
		valid = valid and vm._right.visible and not vm._left.visible and cuff_ok() and vm._right.transform.is_finite()
	check("Hatchet wrist and cuff remain joined through the entire chop",valid)
	valid = true
	var max_jump := 0.0
	for aim in [0.0,.5,1.0]:
		var previous := Vector3.ZERO
		for i in range(107):
			pose("rifle",-1.0,i*.01,aim)
			valid = valid and vm._right.visible and vm._left.visible and cuff_ok() and vm._left.transform.is_finite()
			if i>0: max_jump=maxf(max_jump,previous.distance_to(vm._right.position))
			previous=vm._right.position
	check("Rifle aim, recoil, bolt reach and return keep both cuffs joined",valid and max_jump<.10)
	pose("rifle",-1.0,.62)
	var operating := vm._right.transform
	vm.dry(); vm.freeze_t=.62; vm._process(0.0)
	check("Dry fire keeps the trigger grip rather than reaching for the bolt",vm._right.position.distance_to(operating.origin)>.02)
	valid=true
	for i in range(39):
		pose("fists",i*.01)
		valid=valid and vm._right.visible and vm._left.visible and cuff_ok()
	check("Both fists stay attached throughout the jab",valid)
	pose("axe");vm.glove_item="hide_mitts";vm._process(0.0)
	check("Existing hand clothing slot selects gloves on both skeletons",vm._right.glove.visible and not vm._right.bare.visible and vm._left.glove.visible)
	vm.glove_item="";vm._process(0.0)
	check("Removing mitts restores bare skin without changing the grip",vm._right.bare.visible and not vm._right.glove.visible and cuff_ok())
	p.dead=true;vm._process(.01)
	check("Death hides the viewmodel",not vm.visible)
	p.dead=false;vm._process(.01)
	check("Revival restores the viewmodel",vm.visible)
	pose("axe");vm.freeze_t=-1;vm.swing(true,2);vm._process(.1)
	check("Work actions retain the requested doubled swing speed",is_equal_approx(vm._swing_t,.2))
	vm.swing(true);vm._process(.1)
	check("Combat swings retain their normal timing",is_equal_approx(vm._swing_t,.1))
	p.free()
	print("HAND_RIG_TEST failures=",failures)
	quit(0 if failures==0 else 1)
