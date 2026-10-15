class_name TownResident
extends Zombie
## Reuse the proven skin, hit zones and foot contact, not the hostile brain.
var resident_id := ""
var life: Node3D
var phase := TownResidentState.Phase.ORDINARY
var route: Array[Vector3] = []
var route_index := 0
var routine_s := 0.0
var talking := false
var infected := false
var turn_s := -1.0
var _pause_s := 2.0
var _pose_clock := 0.0
var _rest_pitch := 0.0
var leaving := false
var _alarm_s := 0.0
var _health_materials:Array[StandardMaterial3D]=[]
var _finger_frames:Array=[]
var presence:=ResidentPresence.new()
var _eye_materials:Array[StandardMaterial3D]=[]
var _blink_mesh:MeshInstance3D
var _blink_index:=-1
var _head_actor_left:=Basis.IDENTITY
var _head_actor_right:=Basis.IDENTITY
var _cue_focus:=Vector3.ZERO
var _cue_left_s:=0.0
var _attention_check_s:=0.0
var _attention_clear:=false
var _death_spine_start:=0.0

func _apply_coat(_seed: int) -> void: pass # Keep each imported civilian outfit.
func _pick_wander() -> void:
	# The named owner's quiet infected idle stays in the shop; chase/noise can leave.
	if life != null and resident_id == "rowan":
		_target = life.store.to_global(Vector3(2.52, Store.FLOOR_LOCAL_Y, _rng.randf_range(-.8,.9)))
	else: super._pick_wander()

func initialize(owner: Node3D, id: String, points: Array[Vector3], saved: Dictionary) -> void:
	life = owner; resident_id = id; route = points
	setup(life.world.terrain,life.world.snow,life.world.player,life.world.forest,life.world.colliders,life.world.noise_bus,901 if id=="rowan" else (903 if id=="lin" else 905),"res://assets/resident_presence/"+id+".glb")
	_base_scale = 1.0; _model.scale = Vector3.ONE
	remove_from_group("hostile"); add_to_group("resident")
	global_position = route[0]; rotation.y = life.store.rotation.y+PI/2
	hp = float(saved.hp); route_index = clampi(int(saved.get("route_index",0)),0,route.size()-1)
	turn_s=float(saved.get("turn_s",-1));infected=bool(life.history.record(id).get("dead",false)) and turn_s>=0
	routine_s = float(saved.get("routine_s",0))
	if saved.has("position"):
		var p: Array = saved.position
		if p.size()==3 and is_finite(float(p[0])) and is_finite(float(p[1])) and is_finite(float(p[2])):
			global_position = Vector3(p[0],p[1],p[2]); rotation.y = float(saved.get("yaw",rotation.y))
	_bind_skin_drivers()
	presence.initialize(_id)
	_prepare_appearance()
	died.connect(func() -> void: life.history.killed(resident_id); remove_from_group("resident"))
	state = State.IDLE; _gait_speed = 0; speed_now = 0

func set_phase(next: int, restoring := false) -> void:
	if phase == next and not restoring: return
	phase = next; talking = false
	_cue_left_s=0;presence.interrupt()
	_apply_health_appearance()
	if next == TownResidentState.Phase.DEAD:
		if state != State.DEAD: _die()
		if restoring: _death_progress=1;_dead_t=float(life.history.record(resident_id).get("dead_s",0)); _death_pose(1)
		return
	if next == TownResidentState.Phase.DEPARTED:
		leaving=true;talking=false;route=life.departure_route(self);route_index=0;_pause_s=0
		life.history.record(resident_id).leaving=true
		if restoring:route_index=clampi(int(life.history.record(resident_id).get("exit_index",0)),0,route.size()-1)
		if global_position.distance_squared_to(player.position)>80*80 and not life.observed(self):
			life.history.record(resident_id).departed=true;remove_from_group("resident");_bus.unregister(self);visible=false;set_process(false)
		return
	if next == TownResidentState.Phase.INFECTED:
		infected=true; remove_from_group("resident"); add_to_group("hostile"); _bus.register(self)
		turn_s = float(life.history.record(resident_id).get("turn_s",0)) if restoring else 0.0
		state = State.IDLE; _attack_windup=-1; _cd=COOLDOWN
		_gait.reset(); _pick_wander()

func _prepare_appearance()->void:
	# Private material copies keep one person's deterioration off other bodies.
	for mesh:MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		var index:=mesh.find_blend_shape_by_name("Blink")
		if index>=0:_blink_mesh=mesh;_blink_index=index
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original!=null and original.resource_name=="HumanSkin":
				var material:=original.duplicate() as StandardMaterial3D
				if _health_materials.is_empty():_measure_skin(material)
				mesh.set_surface_override_material(surface,material);_health_materials.append(material)
			elif original!=null and original.resource_name=="HumanEye":
				var material:=original.duplicate() as StandardMaterial3D
				material.roughness=.60;material.metallic_specular=.25
				mesh.set_surface_override_material(surface,material);_eye_materials.append(material)
	for side:String in ["l","r"]:
		for digit:String in ["index","middle","ring","little","thumb"]:
			for segment in range(1,4):
				var bone:=_skin.find_bone("%s_%d_%s"%[digit,segment,side])
				if bone>=0:
					var frame:=_skin.get_bone_global_rest(bone).basis.orthonormalized()
					_finger_frames.append([bone,_skin.get_bone_rest(bone).basis*frame.inverse(),frame,segment,digit=="thumb"])
	_apply_health_appearance()
	if _head_bone>=0:
		_head_actor_right=_skin.get_bone_global_rest(_head_bone).basis.orthonormalized()
		_head_actor_left=_skin.get_bone_rest(_head_bone).basis*_head_actor_right.inverse()

func acknowledge(topic:String)->void:
	if phase>=TownResidentState.Phase.UNRESPONSIVE or is_dead():return
	presence.acknowledge();_cue_left_s=0
	if resident_id=="rowan" and topic=="relay":
		_cue_focus=life.store.to_global(LookoutOpening.CASE_LOCAL+Vector3.UP*.12);_cue_left_s=1.25

func end_exchange()->void:
	_cue_left_s=0;presence.interrupt()

func _update_presence(delta:float)->void:
	_cue_left_s=maxf(0,_cue_left_s-delta)
	var target:Vector3=player.cam.global_position if talking else player.position
	if talking and _cue_left_s>0:target=_cue_focus
	var origin:=global_position+Vector3.UP*1.69
	var focus:=_model.to_local(target)-Vector3(0,1.69,0)
	var nearby:=origin.distance_squared_to(target)<3.2*3.2 and focus.z<0 and absf(atan2(focus.x,-focus.z))<1.2
	_attention_check_s-=delta
	if _attention_check_s<=0:
		_attention_check_s=.15;_attention_clear=false
		if nearby or talking:
			var ray:=target-origin;var length:=ray.length()
			_attention_clear=length<.01 or HitZones.building_block(life.world._building_list(),origin,ray/length,length)>=length-.08
	var attend:=not leaving and _attention_clear and (nearby or talking)
	presence.step(delta,TownResidentState.Phase.DEAD if is_dead() else phase,focus,attend,talking)
	if _blink_mesh!=null:_blink_mesh.set_blend_shape_value(_blink_index,presence.blink)
	for material:StandardMaterial3D in _eye_materials:material.uv1_offset=Vector3(-presence.eye_uv.x,presence.eye_uv.y,0)
	if not is_dead() and not infected and _head_bone>=0:
		_skin.set_bone_pose_rotation(_head_bone,(_head_actor_left*Basis.from_euler(Vector3(presence.pitch+presence.nod,presence.yaw,0))*_head_actor_right).get_rotation_quaternion())

## Sickness reads as ashen pallor relative to THIS person's own skin: the painted skin
## is mixed toward its own mean luminance with the colour drained (grey-olive when ill,
## grey-blue when infected). Never a darker multiply (that read as a skin-tone change)
## and never a fixed light grey (that turned every face into a white mannequin).
## Plus a damp sheen while ill, reddened then clouded eyes. PALLOR_MIX = mix weight.
const PALLOR_SHIFT := {"ill": Color(1.02,1.04,.94), "unresponsive": Color(1.0,1.03,.98), "infected": Color(.90,1.0,1.02)}
const PALLOR_MIX := {"ill": .50, "unresponsive": .66, "infected": .85}
var _skin_mean := Color(.5,.4,.35)
static var _flat_cache := {}
var _skin_rough:Array[float]=[]
var _pallor := 0.0
static func _flat(c:Color)->ImageTexture:
	if not _flat_cache.has(c):
		var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(c);_flat_cache[c]=ImageTexture.create_from_image(image)
	return _flat_cache[c]
func pallor_amount()->float:return _pallor
func _pallor_tone(stage:String)->Color:
	var l:=_skin_mean.get_luminance()*(1.06 if stage=="ill" else 1.0)
	var shift:Color=PALLOR_SHIFT[stage]
	return Color(clampf(l*shift.r,0,1),clampf(l*shift.g,0,1),clampf(l*shift.b,0,1))
func _measure_skin(material:StandardMaterial3D)->void:
	var tex:=material.albedo_texture
	if tex==null:_skin_mean=material.albedo_color;return
	var image:=tex.get_image()
	if image==null:return
	if image.is_compressed():image.decompress()
	image.resize(1,1,Image.INTERPOLATE_BILINEAR);_skin_mean=image.get_pixel(0,0)
func _health_stage()->String:
	if phase==TownResidentState.Phase.INFECTED or (phase==TownResidentState.Phase.DEAD and infected):return "infected"
	if phase==TownResidentState.Phase.UNRESPONSIVE:return "unresponsive"
	if phase==TownResidentState.Phase.ILL:return "ill"
	return ""
func _apply_health_appearance()->void:
	var stage:=_health_stage()
	_pallor=float(PALLOR_MIX.get(stage,0.0))
	if _skin_rough.size()!=_health_materials.size():_skin_rough.assign(_health_materials.map(func(m:StandardMaterial3D)->float:return m.roughness))
	for i in _health_materials.size():
		var material:=_health_materials[i]
		material.albedo_color=Color.WHITE
		material.detail_enabled=_pallor>0
		if _pallor>0:
			material.detail_blend_mode=BaseMaterial3D.BLEND_MODE_MIX
			material.detail_albedo=_flat(_pallor_tone(stage));material.detail_mask=_flat(Color(_pallor,_pallor,_pallor))
		material.roughness=_skin_rough[i]*(.62 if stage=="ill" or stage=="unresponsive" else 1.0)  # feverish damp sheen
	var eye:=Color.WHITE
	if stage=="ill" or stage=="unresponsive":eye=Color(1,.84,.82)
	elif stage=="infected":eye=Color(.86,.84,.78)
	for material:StandardMaterial3D in _eye_materials:
		material.albedo_color=eye;material.roughness=.85 if stage=="infected" else .60  # clouded, no wet glint
	for row:Array in _finger_frames:
		var curl:float=[.10,.27,.12][int(row[3])-1]
		if row[4]:curl*=.6
		if phase==TownResidentState.Phase.INFECTED:curl*=1.7
		_skin.set_bone_pose_rotation(row[0],(row[1]*Basis(Vector3.RIGHT,curl)*row[2]).get_rotation_quaternion())

func hit(amount: float, source: Vector3) -> void:
	if infected: super.hit(amount, source); return
	if state == State.DEAD: return
	hp -= amount; talking=false;end_exchange(); _stagger=.5
	if hp <= 0: _die()
	else: damaged.emit()

func _die()->void:
	if state!=State.DEAD:_death_spine_start=0.0 if infected else _rest_pitch
	super._die()

func _death_pose(t:float)->void:
	super._death_pose(t)
	if _spine_bone>=0 and absf(_death_spine_start)>.001 and t<.35:
		var from_slump:=_death_spine_start*(1-smoothstep(0,.35,t))
		var fold:=smoothstep(0,.55,t)
		var target:=-.16*fold*(1-smoothstep(.65,1,t))
		_skin.set_bone_pose_rotation(_spine_bone,_spine_rest*Quaternion(Vector3.RIGHT,target+from_slump))
		_settle_corpse()

func on_noise(p: Vector3, radius: float, source: Object) -> void:
	if infected: super.on_noise(p,radius,source)
	elif state!=State.DEAD and radius>=10: _alarm_s=3;talking=false;end_exchange();_target=p
func on_light(p: Vector3, radius: float, source: Object) -> void:
	if infected: super.on_light(p,radius,source)

func _move(want: float, delta: float) -> void:
	# The front aisle is the only clear way around the existing shop counter.
	# Keep the real store collision; route the owner's pursuit around its end.
	var desired := _target
	if infected and resident_id == "rowan":
		var p: Vector3 = life.store.to_local(global_position)
		var to: Vector3 = life.store.to_local(_target)
		if p.x > 2.05 and to.x < 2.05:
			_target = life.store.to_global(Vector3(2.52,Store.FLOOR_LOCAL_Y,1.78)) if p.z < 1.65 else life.store.to_global(Vector3(.0,Store.FLOOR_LOCAL_Y,1.78))
	super._move(want,delta); _target = desired

func _process(delta: float) -> void:
	if life == null: return
	if state == State.DEAD: super._process(delta);_update_presence(delta);return
	if infected:
		if turn_s >= 0 and turn_s < 2.5:
			turn_s += delta; _stagger=0; _gait_speed=0; speed_now=0
			_model.rotation.x=0;_animate(delta)
			if _spine_bone>=0:_skin.set_bone_pose_rotation(_spine_bone,_spine_rest*Quaternion(Vector3.RIGHT,lerpf(_rest_pitch,0,smoothstep(0,1.5,turn_s))))
			_update_presence(delta)
			return
		super._process(delta)
		if state!=State.DEAD and _vault_t<0 and not crawling:_model.rotation.x=.08
		_update_presence(delta)
		return
	if global_position.distance_squared_to(player.position)>100*100: return
	if leaving:
		var goal:=route[route_index]
		if Vector2(goal.x-global_position.x,goal.z-global_position.z).length()<.16:
			if route_index<route.size()-1:route_index+=1
			elif not life.observed(self):
				life.history.record(resident_id).departed=true;remove_from_group("resident");_bus.unregister(self);visible=false;set_process(false);return
		_target=route[route_index];_move(.85 if route_index<route.size()-1 or global_position.distance_to(_target)>.16 else 0,delta)
		_animate(delta);_update_presence(delta);return
	_pose_clock += delta; routine_s += delta; _stagger=maxf(0,_stagger-delta)
	_alarm_s=maxf(0,_alarm_s-delta)
	var stopped := talking or phase >= TownResidentState.Phase.ILL or _alarm_s>0
	if not stopped:
		var goal := route[route_index]
		if Vector2(goal.x-global_position.x,goal.z-global_position.z).length()<.14:
			_pause_s -= delta
			if _pause_s<=0: route_index=(route_index+1)%route.size(); _pause_s=4.0 if resident_id=="rowan" else 2.0
			stopped=true
		else:
			# Yield without pushing the player or oscillating contact correction.
			stopped=Vector2(player.position.x-global_position.x,player.position.z-global_position.z).length()<.85
			if not stopped: _target=goal; _move(.65 if resident_id=="rowan" else .85,delta)
	if stopped:
		speed_now=move_toward(speed_now,0,delta*4); _gait_speed=0
		if talking: _face(player.position,delta,3)
		elif _alarm_s>0:_face(_target,delta,3)
	_animate(delta)
	# Healthy posture: quiet arm swing and a task gesture, not a reaching shambler.
	for i in 2:
		_arms[i].rotation.x=-sin(_phase+i*PI)*minf(.14,speed_now*.12)
		_elbows[i].rotation.x=.12
	if stopped and resident_id=="rowan" and not talking and phase<TownResidentState.Phase.ILL:
		_face(life.store.to_global(Vector3(1.65,Store.FLOOR_LOCAL_Y,life.store.to_local(global_position).z)),delta,3)
		_arms[1].rotation.x=.18+.04*sin(_pose_clock*1.3); _elbows[1].rotation.x=.30
	if phase==TownResidentState.Phase.ILL:
		_arms[0].rotation.x=.55; _elbows[0].rotation.x=.70
	var pitch_target := -.28 if phase==TownResidentState.Phase.UNRESPONSIVE else (-.12 if phase==TownResidentState.Phase.ILL else 0.0)
	_rest_pitch=move_toward(_rest_pitch,pitch_target,delta*.16); _model.rotation.x=0
	_deform_skin()
	if _spine_bone>=0: _skin.set_bone_pose_rotation(_spine_bone,_spine_rest*Quaternion(Vector3.RIGHT,_rest_pitch+.015*sin(_pose_clock*1.1)))
	_update_presence(delta)

func snapshot() -> Dictionary:
	return {"hp":maxf(0,hp),"position":[global_position.x,global_position.y,global_position.z],"yaw":rotation.y,"route_index":route_index,"routine_s":routine_s,"leaving":leaving,"exit_index":route_index,"turn_s":turn_s,"dead_s":_dead_t,"corpse_cleared":state==State.DEAD and _dead_t>CORPSE_LIFE_S}
