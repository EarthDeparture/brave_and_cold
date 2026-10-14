extends "res://tests/test_town_life.gd"
func run()->void:
	create_timer(200).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	var p:=ResidentPresence.new();p.initialize(901)
	var count_by_fps:Array=[]
	for fps in [30,60,120]:
		var live:=ResidentPresence.new();live.initialize(901);var finite:=true;var closed:=0.0
		for i in fps*45:
			live.step(1.0/fps,0,Vector3(.25,0,-1),true,false)
			finite=finite and is_finite(live.blink) and is_finite(live.yaw) and is_finite(live.pitch) and live.eye_uv.is_finite()
			closed=maxf(closed,live.blink)
		check(finite and closed>.94 and absf(live.yaw)<.53,"natural blink and eased attention stay finite at "+str(fps)+" Hz")
		count_by_fps.append(live.blink_count)
	check(abs(count_by_fps[0]-count_by_fps[2])<=1,"blink cadence survives different frame rates")
	var gaze:=ResidentPresence.new();gaze.initialize(901);gaze.step(1.0/60,0,Vector3(.4,.2,-1),true,true)
	check(gaze.yaw<0 and gaze.pitch>0 and gaze.eye_uv.x>0 and gaze.eye_uv.y>0,"head and pupil targets agree with the actual authored X/V directions")
	var other:=ResidentPresence.new();other.initialize(903);p.step(1,0,Vector3.RIGHT,true,false);other.step(1,0,Vector3.ZERO,false,false)
	check(p._wait!=other._wait,"residents have independent schedules")
	p.acknowledge();p.step(.2,0,Vector3.ZERO,false,true);check(p.nod<-.02,"acknowledgement produces a restrained nod")
	p.interrupt();check(p.nod==0,"interrupt releases the nod immediately")
	var blink_before:=p.blink_count
	for phase:int in [3,4,5]:
		for i in 120:p.step(1.0/60,phase,Vector3(.4,.4,-.5),true,true)
		check(absf(p.yaw)<.001 and p.eye_uv.length()<.001 and p.blink_count==blink_before,"nonresponsive phase removes voluntary attention "+str(phase))
	check(p.blink>.95,"dead face settles into a static lid pose")
	var w:Node3D=await build();var life:TownLife=w.town_life;var a:TownResident=life.actors.rowan
	check(a._blink_mesh!=null and a._blink_index>=0 and a._eye_materials.size()==1,"runtime binds actual Blink morph and private eye material")
	var b:TownResident=life.actors.sam
	check(a._eye_materials[0]!=b._eye_materials[0] and a._blink_mesh!=b._blink_mesh,"eyes and blink values are private per resident")
	w.player.position=a.to_global(Vector3(.2,1.69,-1));var where:=a.global_position;var topics:Dictionary=life.history.to_dict();var inv:Dictionary=w.inv.counts.duplicate()
	a.talking=true;a.acknowledge("relay")
	check(a._cue_left_s>1 and a._cue_focus.distance_to(life.store.to_global(LookoutOpening.CASE_LOCAL+Vector3.UP*.12))<.001,"equipment topic focuses the actual reserved case")
	for i in 600:a._update_presence(1.0/60)
	check(a.global_position==where and life.history.to_dict()==topics and w.inv.counts==inv,"presentation cannot move the actor, alter history or issue stock")
	check(a.presence.blink_count>0 and absf(a.presence.yaw)>.01,"living actor blinks and turns its actual head")
	check(a._skin.get_bone_pose_rotation(a._head_bone).angle_to(a._head_rest)>.01,"attention rotates the actual imported head bone")
	w.player.position=a.to_global(Vector3(0,1.69,1));a.talking=false;a._attention_check_s=0
	for i in 300:a._update_presence(1.0/60)
	check(absf(a.presence.yaw)<.03 and a.presence.eye_uv.length()<.001,"unseen player behind a resident does not draw a backwards stare")
	var original_pos:=a.global_position;var original_yaw:=a.rotation.y
	a.global_position=life.store.to_global(Vector3(2.52,Store.FLOOR_LOCAL_Y,1.05));a.rotation.y=life.store.rotation.y-PI/2
	w.player.position=life.store.to_global(Vector3(3.6,Store.FLOOR_LOCAL_Y+1.69,1.05));a._attention_check_s=0
	for i in 300:a._update_presence(1.0/60)
	check(not a._attention_clear and a.presence.eye_uv.length()<.001,"actual opaque shop wall blocks player attention")
	a.global_position=original_pos;a.rotation.y=original_yaw
	a.talking=true
	a._blink_mesh.set_blend_shape_value(a._blink_index,1)
	check(b._blink_mesh.get_blend_shape_value(b._blink_index)==0,"one resident's blink cannot close another's eyes")
	var mesh:ArrayMesh=a._blink_mesh.mesh;var changed:=0;var most:=0.0
	for surface in mesh.get_surface_count():
		var values:PackedVector3Array=mesh.surface_get_blend_shape_arrays(surface)[a._blink_index][Mesh.ARRAY_VERTEX]
		var rest:PackedVector3Array=mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for i in values.size():
			var v:=values[i]-rest[i] if mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED else values[i]
			if v.length()>.00001:changed+=1;most=maxf(most,v.length())
	print("PRESENCE_MORPH_METRICS mode=",mesh.blend_shape_mode," changed=",changed," maximum_m=",most)
	check(changed>=380 and most<.015,"actual eyelid morph moves local lid geometry within a bounded range")
	life.conversation.open(a);life.conversation.choose("relay");life.conversation.close()
	check(a._cue_left_s==0 and a.presence.nod==0 and not a.talking,"closing the live exchange releases its attention cue")
	a.acknowledge("relay");a.hit(1,w.player.position)
	check(a._cue_left_s==0 and a.presence.nod==0,"injury interrupts acting immediately")
	a.acknowledge("relay");a.on_noise(a.global_position+Vector3.RIGHT,20,null)
	check(a._cue_left_s==0 and a.presence.nod==0,"loud noise interrupts acting immediately")
	a._rng.seed=42;var expected:=RandomNumberGenerator.new();expected.seed=42
	for i in 500:a._update_presence(1.0/60)
	check(a._rng.randi()==expected.randi(),"cosmetic random blinking does not consume the gameplay RNG")
	when(w,3,18)
	for i in 180:a._process(1.0/60)
	check(a.presence.blink>.6 and not a.talking,"unresponsive owner rests with partially closed eyes")
	check(a._model.rotation.x==0 and a._rest_pitch<-.27,"illness bends the spine forward rather than tilting the entire body backwards")
	var soles_error:=0.0;var stretch:=1.0
	for mi:MeshInstance3D in a._model.find_children("*","MeshInstance3D",true,false):
		if mi.skin==null:continue
		for surface in mi.mesh.get_surface_count():
			var actual:=preload("res://tests/skin_mesh_probe.gd").vertices(mi,surface,a._skin)
			var rest:PackedVector3Array=mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX];var idx:PackedInt32Array=mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			for i in actual.size():
				if String(mi.name)=="Boots" and rest[i].y<.013:
					var pos:=a._skin.to_global(actual[i]);soles_error=maxf(soles_error,absf(pos.y-a._corpse_floor(pos)))
			for i in range(0,idx.size(),3):
				for e in 3:
					var x:=idx[i+e];var y:=idx[i+(e+1)%3];var length:=rest[x].distance_to(rest[y])
					if length>.001:stretch=maxf(stretch,actual[x].distance_to(actual[y])/length)
	print("PRESENCE_SLUMP_METRICS sole_m=",soles_error," edge_stretch=",stretch)
	check(soles_error<.015 and stretch<2.5,"slump keeps real boot soles supported and has no joint spikes")
	var pre_spine:=a._skin.get_bone_pose_rotation(a._spine_bone)
	a._death_spine_start=a._rest_pitch
	a._death_start_joints.clear()
	for joint:Node3D in a._arms+a._legs+a._knees+a._elbows:a._death_start_joints.append(joint.rotation)
	a._death_start_rotation=a._model.rotation;a._death_pose(0)
	check(pre_spine.angle_to(a._skin.get_bone_pose_rotation(a._spine_bone))<.02,"collapse starts from the weakened spine pose without an upright snap")
	when(w,3,21);var before:=a.presence.blink_count
	for i in 500:a._update_presence(1.0/60)
	check(a.presence.blink==0 and a.presence.blink_count==before,"infection removes voluntary blinks and conversation acting")
	a.hit(200,w.player.position)
	for i in 90:a._update_presence(1.0/60)
	check(a.presence.blink>.95 and a.is_dead(),"death settles lids without changing immediate combat death")
	a._death_pose(1.0);var clearance:=INF
	for mi:MeshInstance3D in a._model.find_children("*","MeshInstance3D",true,false):
		if mi.skin==null:continue
		for surface in mi.mesh.get_surface_count():
			for v:Vector3 in preload("res://tests/skin_mesh_probe.gd").vertices(mi,surface,a._skin):
				var pos:=a._skin.to_global(v);clearance=minf(clearance,pos.y-a._corpse_floor(pos))
	check(clearance>=-.012,"actual closed-lid morph and skin remain above the corpse supporting floor")
	w.queue_free();await process_frame;SaveGame.pending={};print("RESIDENT_PRESENCE_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
