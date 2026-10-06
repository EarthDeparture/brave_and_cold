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
	return absf(vm._right.position.distance_to(vm._sl_r.position)-.05)<.0001 and (not vm._left.visible or absf(vm._left.position.distance_to(vm._sl_l.position)-.05)<.0001)
func skin_vertices(hand: SurvivorHandRig,gloved:=false) -> PackedVector3Array:
	var mesh := hand.glove if gloved else hand.bare
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Imported glTF stores absolute positions in NORMALIZED blend shapes.
	assert(mesh.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var base:=vertices.duplicate()
	for shape in mesh.mesh.get_blend_shape_count():
		var blend:float=mesh.get_blend_shape_value(shape)
		if absf(blend)<.000001:continue
		var target:PackedVector3Array=mesh.mesh.surface_get_blend_shape_arrays(0)[shape][Mesh.ARRAY_VERTEX]
		for i in vertices.size():vertices[i]+=(target[i]-base[i])*blend
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
	create_timer(180).timeout.connect(func() -> void: quit(2))
	p = Player.new(); root.add_child(p); p.set_process(false); p.set_physics_process(false)
	p.cam = Camera3D.new(); p.add_child(p.cam); p.cam.fov = 70
	vm = Viewmodel.new(); vm.detail_enabled = true; vm.player = p; p.cam.add_child(vm); vm.set_process(false)
	check("Both hands use new 17-bone anatomy",vm._right.skeleton.get_bone_count()==17 and vm._left.skeleton.get_bone_count()==17)
	for h in [vm._right,vm._left]:
		check("Skin, gloves and nails retain shared skeleton binds",h.bare.skin!=null and h.glove.skin!=null and h.nails.skin!=null)
		check("Fourteen volume correctives on bare skin and gloves",h.bare.mesh.get_blend_shape_count()==14 and h.glove.mesh.get_blend_shape_count()==14)
		h.pose("Open")
	var original: PackedVector3Array = vm._right.bare.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var resting := skin_vertices(vm._right); var error := 0.0
	for i in original.size(): error=maxf(error,original[i].distance_to(resting[i]))
	check("Open pose preserves actual bind vertices",error<.00001); print("HAND_BIND_ERROR ",error)
	for grip: String in ["Relaxed","Fist","Shaft","Trigger","Support","Bolt","PinchReady","Magazine"]:
		vm._right.pose(grip); vm._left.pose(grip)
		var deformed := skin_vertices(vm._right); var motion := 0.0; var finite := true; var mirror := 0.0
		for i in deformed.size(): finite=finite and deformed[i].is_finite(); motion=maxf(motion,deformed[i].distance_to(resting[i]))
		for bone in vm._right.skeleton.get_bone_count():
			var right := vm._right.skeleton.get_bone_global_pose(bone).origin
			var left := vm._left.skeleton.get_bone_global_pose(vm._left.skeleton.find_bone(vm._right.skeleton.get_bone_name(bone))).origin
			mirror=maxf(mirror,left.distance_to(Vector3(-right.x,right.y,right.z)))
		check(grip+" deforms real vertices and preserves mirrored joints",finite and motion>.002 and mirror<.00001)
	vm._right.pose("Shaft")
	var before := vm._right.skeleton.get_bone_global_pose(vm._right.skeleton.find_bone("index_03"))
	vm._right.align_forearm(Vector3(.16,-.25,.35))
	var after := vm._right.skeleton.get_bone_global_pose(vm._right.skeleton.find_bone("index_03"))
	check("Forearm articulation preserves finger contact",before.is_equal_approx(after))
	pose("fists"); vm._guard_k=0; vm._process(0)
	var relaxed_index := vm._right.bare.find_blend_shape_by_name("corrective_Relaxed")
	check("Unarmed resting hands are relaxed",vm._right.bare.get_blend_shape_value(relaxed_index)>.99 and vm._left.visible)
	vm._guard_k=1; vm._process(0)
	check("Guard closes both hands",vm._right.bare.get_blend_shape_value(vm._right.bare.find_blend_shape_by_name("corrective_Fist"))>.99)
	for mode_name: String in ["fists","axe"]:
		var valid := true; var previous := Vector3.ZERO; var jump := 0.0
		for i in 83:
			pose(mode_name,i*.01); valid=valid and cuff_ok() and vm._right.transform.is_finite()
			if i>0: jump=maxf(jump,previous.distance_to(vm._right.position))
			previous=vm._right.position
		print("ATTACK_WRIST_MAX_STEP ",mode_name," ",jump," cuff=",valid)
		check(mode_name+" attack retains attached cuffs and continuous wrist travel",valid and jump<(.15 if mode_name=="axe" else .08))
	for gloved: bool in [false,true]:
		pose("axe"); var penetration:=0.0; var touching:=0; var inverse:=vm._axe.transform.affine_inverse()
		for point in skin_vertices(vm._right,gloved):
			var local:Vector3=inverse*(vm._right.transform*point)
			if absf(local.y)>.04:continue
			var radial:float=pow(pow(absf(local.x/.0122),2.4)+pow(absf((local.z-.002)/.0168),2.4),1/2.4)
			var distance:float=(radial-1)*.0122*1.2
			penetration=maxf(penetration,-distance)
			if absf(distance)<.004:touching+=1
		print("NEW_SHAFT_CONTACT gloves=",gloved," overlap_m=",penetration," contact_vertices=",touching)
		check("Actual new hand has shaft contact without deep overlap "+str(gloved),penetration<.0035 and touching>20)
	for id: String in WeaponPresentation.IDS:
		vm.equip_weapon(id); pose("rifle")
		check(id+" keeps the complete component rig and sockets",vm._rifle.sockets.has("HandR") and vm._rifle.sockets.has("HandL") and vm._rifle.sockets.has("Muzzle"))
		var clips_ok := true
		for clip: String in vm._rifle.animation_player.get_animation_list():
			if clip=="RESET":continue
			vm._fire_t=-1
			vm.play_weapon_clip(clip); var duration:=vm._rifle.clip_length(clip)
			for step in 9:
				vm._weapon_clip_t=duration*step/8.0; vm._process(0)
				clips_ok=clips_ok and vm._right.transform.is_finite() and vm._left.transform.is_finite() and cuff_ok()
			vm.cancel_weapon_clip()
		check(id+" all imported clips preserve hand/cuff transforms",clips_ok)
		if not vm._rifle.is_lever_action():
			vm.play_weapon_clip("reload_tactical"); var previous_contact:=Transform3D.IDENTITY; var contact_error:=0.0
			for time:float in [.68,1.05,1.60]:
				vm._weapon_clip_t=time;vm._process(0)
				var local:=vm._rifle.socket_transform("MagazineHand").affine_inverse()*vm._left.transform
				if time>.68:contact_error=maxf(contact_error,local.origin.distance_to(previous_contact.origin))
				previous_contact=local
			check(id+" left wrist follows the withdrawing/reseating magazine",contact_error<.00001)
			vm.cancel_weapon_clip()
		var max_jump:=0.0;var previous:=Vector3.ZERO
		for i in 107:
			pose("rifle",-1,i*.01)
			if i>0:max_jump=maxf(max_jump,previous.distance_to(vm._right.position))
			previous=vm._right.position
		check(id+" shot/cycle wrist motion is continuous",max_jump<.08)
	vm.equip_weapon("timber_bolt_carbine"); pose("rifle")
	check("Reload presentation can start",vm.play_weapon_clip("reload_empty") and vm.weapon_busy())
	vm.begin_work("hammer",2); vm._process(0)
	check("Work cancels weapon manipulation and restores service-tool pose",not vm.weapon_busy() and vm._hammer.visible)
	vm.end_work(false);pose("rifle");vm.play_weapon_clip("inspect");p.ui_open=true;vm._process(.1);p.ui_open=false
	check("Opening UI cancels weapon manipulation",not vm.weapon_busy())
	pose("rifle");vm.play_weapon_clip("reload_empty");vm.mode="fists";vm.freeze_t=-1;vm._process(.1)
	check("Switching equipment cancels weapon manipulation",not vm.weapon_busy())
	for kind:String in ["split","chop","hammer","reach","drink","treat"]:
		vm.begin_work(kind,2);var finite:=true
		for i in 21:vm.update_work(i*.1);vm._process(0);finite=finite and vm._right.transform.is_finite() and cuff_ok()
		check(kind+" retains new anatomy and attached cuff",finite);vm.end_work(false)
	pose("axe");vm.glove_item="hide_mitts";vm._process(0)
	check("Mitts select new leather shells and hide nails",vm._right.glove.visible and not vm._right.bare.visible and not vm._right.nails.visible)
	vm.glove_item="";vm._process(0)
	check("Removing mitts restores bare hands and nails",vm._right.bare.visible and vm._right.nails.visible and not vm._right.glove.visible)
	p.dead=true;vm._process(.1);check("Death hides viewmodel",not vm.visible)
	p.dead=false;vm._process(.1);check("Revival restores viewmodel",vm.visible)
	vm.mode="axe";vm.freeze_t=-1;vm.swing(true,2);vm._process(.1)
	check("Work swing speed remains doubled",is_equal_approx(vm._swing_t,.2))
	p.free(); print("HAND_RIG_TEST failures=",failures);quit(0 if failures==0 else 1)
