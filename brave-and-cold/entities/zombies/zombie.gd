class_name Zombie
extends Node3D
## Shambler: idle wander -> hears noise / sees player -> investigate -> chase -> grab/bite. Slow by design; deep snow makes it slower still
## (SnowField.zombie_speed_mult: 100/95/75/50/30/20 %). Bashes closed cabin doors while the player is inside. Dies to melee.

enum State { IDLE, INVESTIGATE, CHASE, DEAD, SLEEP }
enum Kind { SHAMBLER, HEAVY, SLEEPER }
signal attacked   # for GameAudio: grunt from this body
signal damaged
signal died

const MODEL := "res://assets/infected/detail/winter_worker_detail.glb"
const IDLE_SPEED := 0.8
const INVESTIGATE_SPEED := 1.5
const CHASE_SPEED := 2.4
const SIGHT_RANGE := 18.0
const GRAB_RANGE := 1.15
const DAMAGE := 7.0
const COOLDOWN := 1.6
const DOOR_BASH_DPS := 10.0
const BREAK_DPS := 6.0            # vs glass / planks at a window
const VAULT_S := 1.4
const CORPSE_LIFE_S := 300.0

static var night_factor := 0.0
static var ambient_c := 0.0       # cold stiffens them: slower below -24 C, idle ones freeze solid below -32 C
static var _mats: Array[StandardMaterial3D] = []     # shared tints (batching) instead of one material per zombie
static var _scw_frame := -1
static var _scw_val = null
static var _scw_any = null
const AI_EVERY_NEAR := 2                              # 20-60 m: brain+move every 2nd frame
const AI_EVERY_FAR := 6                               # > 60 m: every 6th frame
const GROUND_GAIT_M:=20.0 # precise sole contact where encounter detail is visible

var terrain: Terrain3D
var snow: SnowField
var player: Player
var forest: ForestScatter
var cabins: Array = []
var state: State = State.IDLE
var hp := 100.0
var from_pop := false           # owned by Population (may be parked when far)
var kind := 0                   # Kind: heavy = 160 hp, bigger, breaks barriers twice as fast, slower
var crawling := false           # legs gone after a heavy hit: slow, low, small sight
var _base_scale := 1.0
var _wake_cd := 0.0
var speed_now := 0.0
var grabs := 0
var _target := Vector3.ZERO
var _last_seen_t := 0.0
var _state_t := 0.0
var _cd := 0.0
var _stagger := 0.0
var _phase := 0.0
var _gait_speed := -1.0
var _gait:=InfectedGait.new()
var _ankle_frames:Array=[]
var _arms: Array[Node3D] = []
var _knees:Array[Node3D]=[]
var _elbows:Array[Node3D]=[]
var _attack_windup:=-1.0
var _coat_meshes:Array[MeshInstance3D]=[]
static var _coats:Array[StandardMaterial3D]=[]
var _legs: Array[Node3D] = []
var _model: Node3D
var _skin: Skeleton3D
var _skin_drivers: Dictionary = {}
var _skin_frames:Array=[]
var _spine_bone:=-1
var _head_bone:=-1
var _spine_rest:=Quaternion.IDENTITY
var _head_rest:=Quaternion.IDENTITY
static var _contact_templates:Array=[]
const COLLAPSE_S:=.85
var _death_progress:=0.0
var _death_start_rotation:=Vector3.ZERO
var _death_start_joints:Array[Vector3]=[]
var _death_ground_pitch:=0.0
var _death_ground_roll:=0.0
var _death_floor_cache:Dictionary={}
var _wake_tween:Tween
var _rng := RandomNumberGenerator.new()
var _dead_t := 0.0
var _id := 0
var _bus: NoiseBus
var _acc := 0.0
var _lod := 0
var _hx := 1e9
var _hz := 1e9
var _hcache := 0.0
var _mcache := 1.0
var _bo: Opening = null         # window being breached
var _bdoor := false
var _bpick_t := 99.0
var _bbld = null
var _sight_cd := 0.0
var _sight_val := false
var _vault_t := -1.0
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO


func setup(t: Terrain3D, s: SnowField, p: Player, f: ForestScatter, cbs: Array, bus: NoiseBus, seed_value: int) -> void:
	terrain = t
	snow = s
	player = p
	forest = f
	cabins = cbs
	_rng.seed = seed_value
	_id = seed_value
	_bus = bus
	bus.register(self)
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)
	for candidate:Node in _model.find_children("*","Skeleton3D",true,false):
		_skin = candidate as Skeleton3D;break
	var clips:=_model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if clips!=null:clips.stop()
	if _skin!=null:_skin.reset_bone_poses()
	for mi:MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		if String(mi.name).contains("winter_canvas"):_coat_meshes.append(mi)
	if _coats.is_empty() and not _coat_meshes.is_empty():
		var original:=_coat_meshes[0].mesh.surface_get_material(0) as StandardMaterial3D
		for color:Color in [Color(1,1,1),Color(.72,.87,1.12)]:
			var m:=original.duplicate() as StandardMaterial3D;m.albedo_color=color;_coats.append(m)
	_apply_coat(seed_value)
	for n in ["l", "r"]:
		_arms.append(_model.find_child("zombie_arm_" + n, true, false))
		_legs.append(_model.find_child("zombie_leg_" + n, true, false))
		_knees.append(_model.find_child("zombie_knee_"+n,true,false));_elbows.append(_model.find_child("zombie_elbow_"+n,true,false))
	if _skin != null:
		for driver:Node3D in _arms+_legs+_knees+_elbows:
			if driver != null:
				var bone := _skin.find_bone("skin_"+String(driver.name))
				if bone >= 0:_skin_drivers[bone]=driver
	_base_scale = _rng.randf_range(0.94, 1.06)
	_model.scale = Vector3.ONE * _base_scale
	_phase = _rng.randf() * TAU
	_bind_skin_drivers();_prepare_contact_samples()
	add_to_group("hostile")
	_pick_wander()


## Pool reuse (Population): reset everything per-life, no instantiate cost.
func activate(p: Vector3, seed_value: int, k: int = 0) -> void:
	p.y=RoadNet.lift(p.y,p.x,p.z)
	global_position = p
	rotation.y = randf() * TAU
	_rng.seed = seed_value
	_id = seed_value
	hp = 100.0
	if _wake_tween!=null and _wake_tween.is_valid():_wake_tween.kill()
	_dead_t=0;_death_progress=0;_death_start_joints.clear();_death_floor_cache.clear();remove_from_group("bodies")
	state = State.IDLE
	speed_now = 0.0
	grabs = 0
	_state_t = 0.0
	_cd = 0.0
	_stagger = 0.0
	_acc = 0.0
	_vault_t = -1.0
	_bo = null
	_bdoor = false
	_bbld = null
	_bpick_t = 99.0
	_sight_cd = 0.0
	_sight_val = false
	_hx = 1e9
	_hz = 1e9
	_last_seen_t = 0.0
	_attack_windup=-1;_apply_coat(seed_value)
	_gait_speed=-1
	_gait.reset()
	for joint:Node3D in _arms+_legs+_knees+_elbows:
		if joint!=null:joint.rotation=Vector3.ZERO
	if _skin != null:_skin.reset_bone_poses()
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	kind = k
	crawling = false
	for lg in _legs:
		if lg != null:
			lg.visible = true
	_model.scale = Vector3.ONE * _base_scale * (1.15 if k == Kind.HEAVY else 1.0)
	if k == Kind.HEAVY:
		hp = 160.0
	if k == Kind.SLEEPER:
		state = State.SLEEP
		_model.rotation.x = -PI / 2.0
		_model.position.y = 0.12
		_wake_cd = randf() * 0.25
	visible = true
	set_process(true)
	add_to_group("hostile")
	if _bus != null:
		_bus.register(self)
	_pick_wander()


func park() -> void:
	_release()
	_bo = null
	remove_from_group("hostile")
	if _bus != null:
		_bus.unregister(self)
	visible = false
	set_process(false)


## Mid-vault or breaching zombies stay real until they are done.
func can_park() -> bool:
	return _vault_t < 0.0 and _bo == null and state != State.DEAD


func _exit_tree() -> void:
	_release()
	if _bus != null:
		_bus.unregister(self)


## Called by NoiseBus.emit_noise for listeners already inside the radius.
func on_noise(pos: Vector3, _radius_in: float, _source: Object) -> void:
	var _radius := _radius_in
	if state == State.DEAD:
		return
	if state == State.SLEEP:
		var dd := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
		if dd < maxf(12.0, _radius * 0.25):
			_target = pos
			_wake()
		return
	_target = pos
	if state != State.CHASE:
		_set_state(State.INVESTIGATE)


## Weak lure: lit windows at night draw idle zombies to look.
func on_light(pos: Vector3, _radius: float, _source: Object) -> void:
	if state == State.IDLE:
		_target = pos
		_set_state(State.INVESTIGATE)


func _release() -> void:
	if _bo != null:
		_bo.release(self)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _pick_wander() -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(3.0, 12.0)
	_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


## Which building holds the player (any door state) / which CLOSED one does. Computed once per frame for all zombies.
func _scan_bld() -> void:
	var f := Engine.get_process_frames()
	if f != _scw_frame:
		_scw_frame = f
		_scw_val = null
		_scw_any = null
		for cb in cabins:
			if cb.contains_xz(player.position.x, player.position.z):
				_scw_any = cb
				if not cb.door_open and not cb.openings.is_empty():
					_scw_val = cb
				break


func _shut_cabin_with_player():
	_scan_bld()
	return _scw_val


func _can_see_player() -> bool:
	var to := player.position - global_position
	to.y = 0.0
	var d := to.length()
	var rng_m := SIGHT_RANGE * (0.55 if player.crouching else 1.0) * (1.0 - 0.45 * night_factor) * (0.5 if crawling else 1.0)
	if d > rng_m:
		return false
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	if not (d < 4.0 or fwd.dot(to / maxf(d, 0.001)) > 0.3):
		return false
	# walls block sight except through uncovered windows / the open door (either side of the wall)
	var zeye := global_position + Vector3(0, 1.5, 0)
	_scan_bld()
	var pb = _scw_any
	if pb != null and not pb.contains_xz(global_position.x, global_position.z):
		if not pb.sight_line_open(zeye, player.position):   # player.position is already eye height
			return false
	elif pb == null:
		for cb in cabins:
			if cb.contains_xz(global_position.x, global_position.z):
				if not cb.sight_line_open(zeye, player.position):
					return false
				break
	# trunks in between: each one cuts the range by a quarter (close range is exempt)
	if forest != null and d > 4.0:
		var n := forest.trunks_on_segment(global_position.x, global_position.z, player.position.x, player.position.z)
		if n > 0 and d > rng_m * maxf(0.0, 1.0 - 0.25 * float(n)):
			return false
	return true


func _sees_cached(delta: float) -> bool:
	_sight_cd -= delta
	if _sight_cd <= 0.0:
		_sight_cd = 0.12
		_sight_val = _can_see_player()
	return _sight_val


func hit(dmg: float, from: Vector3) -> void:
	if state == State.DEAD:
		return
	if state == State.SLEEP:
		dmg *= 3.0   # a sleeper dies to a sneak attack
	hp -= dmg
	_stagger = 0.5
	if hp <= 0.0:
		_die()
	else:
		damaged.emit()
		if state == State.SLEEP:
			_wake()
		if not crawling and hp < 40.0 and randf() < 0.5:
			_make_crawler()
		_target = from
		_set_state(State.CHASE)
		_last_seen_t = 0.0


func _die() -> void:
	if state==State.DEAD:return
	_gait.reset()
	state = State.DEAD
	died.emit()
	_release()
	_vault_t = -1.0
	remove_from_group("hostile")
	add_to_group("bodies")
	speed_now = 0.0
	_attack_windup=-1;_dead_t=0;_death_progress=0;_death_floor_cache.clear()
	if _wake_tween!=null and _wake_tween.is_valid():_wake_tween.kill()
	_death_start_rotation=_model.rotation;_death_start_joints.clear()
	var front:=global_position-global_basis.z*1.3
	var back:=global_position+global_basis.z*.3
	_death_ground_pitch=clampf(atan2(_corpse_floor(front)-_corpse_floor(back),1.6),-.42,.42)
	_death_ground_roll=clampf(atan2(_corpse_floor(global_position+global_basis.x*.4)-_corpse_floor(global_position-global_basis.x*.4),.8),-.35,.35)
	for joint:Node3D in _arms+_legs+_knees+_elbows:_death_start_joints.append(joint.rotation if joint!=null else Vector3.ZERO)


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null or player == null:
		return
	if state == State.DEAD:
		_dead_t += delta
		if _death_progress<1:
			_death_progress=minf(1,_death_progress+delta/COLLAPSE_S);_death_pose(_death_progress)
		if _dead_t > CORPSE_LIFE_S:
			queue_free()
		return
	if state == State.SLEEP:
		_wake_cd -= delta
		if _wake_cd <= 0.0:
			_wake_cd = 0.25
			var sx := player.position.x - global_position.x
			var sz := player.position.z - global_position.z
			var near := 3.0 if player.crouching else 6.0
			if sx * sx + sz * sz < near * near:
				_target = player.position
				_wake()
		return
	if _vault_t >= 0.0:
		_do_vault(delta)
		return
	var pp := player.position
	var gx := pp.x - position.x
	var gz := pp.z - position.z
	var d2 := gx * gx + gz * gz
	_lod = 0 if d2 < 400.0 else (1 if d2 < 3600.0 else 2)
	if _lod > 0:
		_acc += delta
		var every := AI_EVERY_NEAR if _lod == 1 else AI_EVERY_FAR
		if (Engine.get_process_frames() + _id) % every != 0:
			return
		delta = _acc
		_acc = 0.0
	_state_t += delta
	_cd = maxf(0.0, _cd - delta)
	_stagger = maxf(0.0, _stagger - delta)
	var dist := sqrt(d2)
	var want := 0.0
	var sees := _sees_cached(delta)
	if sees:
		_target = pp
		_last_seen_t = 0.0
		if state != State.CHASE:
			_set_state(State.CHASE)
	else:
		_last_seen_t += delta
	match state:
		State.IDLE:
			var dd := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
			if dd < 1.0 or _state_t > 10.0:
				if _state_t > 3.0:
					_pick_wander()
					_state_t = 0.0
			else:
				want = IDLE_SPEED
		State.INVESTIGATE:
			want = INVESTIGATE_SPEED
			var dd2 := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
			if _shut_cabin_with_player() != null and dist < 30.0 and _state_t > 1.0:
				_set_state(State.CHASE)   # someone is hiding in there: go for them
			elif dd2 < 2.0 or _state_t > 20.0:
				_set_state(State.IDLE)
				_pick_wander()
		State.CHASE:
			want = CHASE_SPEED
			if dist < GRAB_RANGE and absf(pp.y - global_position.y - 1.0) < 2.0:
				want = 0.0
				_face(pp, delta, 10.0)
				if _cd <= 0.0 and _stagger <= 0.0:
					_cd = COOLDOWN
					_attack_windup=.35
			var cb = _shut_cabin_with_player()
			if cb != null and not cb.contains_xz(global_position.x, global_position.z):
				want = _breach(cb, delta, want)   # smash a window / the door to get in
			elif _bo != null:
				_release()
				_bo = null
			if _last_seen_t > 8.0 and cb == null:
				_set_state(State.INVESTIGATE)
	if _attack_windup>=0:
		_attack_windup-=delta
		if _attack_windup<=0:
			_attack_windup=-1
			if _stagger<=0 and state==State.CHASE and dist<GRAB_RANGE+.08 and absf(pp.y-global_position.y-1)<2 and _can_see_player():
				grabs+=1;attacked.emit();player.hurt(DAMAGE,"Torn apart by the infected");player.injury.wound(.45,.30,true)
	if _stagger > 0.0:
		want = 0.0
	_move(want, delta)
	if _lod <= 1:
		_animate(delta)


func _barrier(o: Opening) -> float:
	if o.passable():
		return 0.0
	return (0.0 if o.glass_broken else 3.0) + 10.0 * float(o.boards)


func _pick_opening(bld) -> void:
	_release()
	_bo = null
	_bdoor = false
	_bbld = bld
	var pos := global_position
	var best := 1e9
	for o in bld.openings:
		var c: float = pos.distance_to(o.outside_pos()) + _barrier(o)
		if not o.has_slot(self):
			c += 30.0
		if c < best:
			best = c
			_bo = o
	var dc: float = pos.distance_to(bld.door_world_pos()) + (0.0 if bld.door_open else 20.0 + 10.0 * float(bld.door_boards))
	if dc <= best:
		_bo = null
		_bdoor = true
	_bpick_t = 0.0


## Cheapest way in: window (glass 3 + 10 per plank + distance), door (20 closed), crowding. Returns wanted speed.
func _breach(bld, delta: float, want: float) -> float:
	_bpick_t += delta
	if _bbld != bld or (_bo == null and not _bdoor) or _bpick_t > 3.0:
		_pick_opening(bld)
	var gp := global_position
	if _bdoor:
		if bld.door_open:
			_target = player.position
			return CHASE_SPEED
		_target = bld.door_world_pos()
		if Vector2(_target.x - gp.x, _target.z - gp.z).length() < 2.3:
			_face(_target, delta, 8.0)
			bld.bash_door(DOOR_BASH_DPS * delta * (2.0 if kind == Kind.HEAVY else 1.0))
			return 0.0
		return CHASE_SPEED
	var slot := _bo.reserve(self)
	if slot < 0:
		_pick_opening(bld)
		return want
	var sp := _bo.slot_pos(slot)
	if Vector2(sp.x - gp.x, sp.z - gp.z).length() > 0.6:
		_target = sp
		return CHASE_SPEED
	_face(_bo.global_position, delta, 8.0)
	if _bo.passable():
		_vault_from = gp
		var ip := _bo.inside_pos()
		_vault_to = Vector3(ip.x, bld.floor_y, ip.z)
		_vault_t = 0.0
		return 0.0
	_bo.hit(BREAK_DPS * delta * (2.0 if kind == Kind.HEAVY else 1.0))   # glass_break / board_break raise the noise via Opening.event
	return 0.0


func _do_vault(delta: float) -> void:
	_vault_t += delta
	var t := clampf(_vault_t / VAULT_S, 0.0, 1.0)
	var p := _vault_from.lerp(_vault_to, t)
	p.y += sin(t * PI) * 0.3
	global_position = p
	_face(_vault_to, delta, 10.0)
	_animate(delta)
	_model.rotation.x = -0.35 * sin(t * PI)          # lean over the sill, arms grabbing ahead
	for ar in _arms:
		if ar != null:
			ar.rotation.x = -1.2
	_deform_skin()
	if t >= 1.0:
		_model.rotation.x = 0.0
		_vault_t = -1.0
		_release()
		_bo = null
		_hx = 1e9


func _face(p: Vector3, delta: float, rate: float) -> void:
	var d := p - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * rate))


func _move(want: float, delta: float) -> void:
	var pos := global_position
	var start:=Vector2(pos.x,pos.z)
	var mx := pos.x - _hx
	var mz := pos.z - _hz
	if mx * mx + mz * mz > 0.16:            # height + snow tier only re-sampled after 0.4 m of travel
		_hx = pos.x
		_hz = pos.z
		var hq: float = RoadNet.lift(IceField.lift(terrain.data.get_height(Vector3(pos.x, 0.0, pos.z)), pos.x, pos.z),pos.x,pos.z,pos.y)
		_hcache = hq
		_mcache = snow.zombie_speed_mult(pos.x, pos.z)
	var mult := _mcache * _cold_mult() * (0.35 if crawling else 1.0) * (0.9 if kind == Kind.HEAVY else 1.0)
	speed_now = lerpf(speed_now, want * mult, minf(1.0, delta * 5.0))
	if speed_now > 0.03:
		_face(_target, delta, 4.0)
		var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		var np := pos + fwd * speed_now * delta
		np.y = pos.y
		if forest != null:
			var q := forest.resolve_trunks(np.x, np.z, 0.35)
			np.x = q.x
			np.z = q.y
		for cb in cabins:
			if absf(cb.position.x - np.x) > 9.0 or absf(cb.position.z - np.z) > 9.0:
				continue
			var q2: Vector2 = cb.resolve(np.x, np.z, 0.4)
			np.x = q2.x
			np.z = q2.y
		var road_q:=RoadNet.resolve_actor(np,pos,.4)
		np.x=road_q.x;np.z=road_q.y
		pos = np
	var h: float = _hcache
	for cb2 in cabins:
		if absf(cb2.position.x - pos.x) < 9.0 and absf(cb2.position.z - pos.z) < 9.0:
			var fh: float = cb2.floor_at(pos.x, pos.z, _hcache)
			if not is_nan(fh):
				h = fh
				break
	if not is_nan(h):
		pos.y = lerpf(pos.y, h, minf(1.0, delta * 14.0))
	global_position = pos
	_gait_speed=start.distance_to(Vector2(pos.x,pos.z))/maxf(delta,.0001)


func _apply_coat(id:int)->void:
	if _coats.is_empty():return
	for mesh:MeshInstance3D in _coat_meshes:mesh.material_override=_coats[posmod(id,2)]
func _animate(delta:float)->void:
	var travel:=speed_now if _gait_speed<0 else minf(_gait_speed,speed_now)
	var stride:=lerpf(.85,1.30,clampf(travel/CHASE_SPEED,0,1))
	_phase+=delta*travel*TAU/(stride*maxf(.1,_model.scale.y))
	var amp:=clampf(travel/CHASE_SPEED,0,1)*.48
	for i in mini(2,_legs.size()):
		var wave:=sin(_phase+i*PI)
		if _legs[i]!=null:_legs[i].rotation.x=wave*amp
		if _knees[i]!=null:_knees[i].rotation.x=-maxf(0,-wave)*amp*.9
		var reach:= .60 if state==State.CHASE else .08
		if _attack_windup>=0:reach=.90+sin((.35-_attack_windup)/.35*PI)*.35
		elif state==State.CHASE and _cd>COOLDOWN-.75:reach=lerpf(.60,.90,smoothstep(COOLDOWN-.75,COOLDOWN-.35,_cd))
		elif _bo!=null or _bdoor:reach=.6+.25*sin(_state_t*6+i)
		if _arms[i]!=null:_arms[i].rotation.x=reach-wave*amp*.3
		if _elbows[i]!=null:_elbows[i].rotation.x=.15+amp*.1
	var close_detail:=player==null or global_position.distance_squared_to(player.global_position)<GROUND_GAIT_M*GROUND_GAIT_M
	var grounded:=close_detail and travel>.03 and _gait_speed>=0 and not crawling and _vault_t<0 and _stagger<=0 and state not in [State.SLEEP,State.DEAD]
	_model.rotation.z=sin(_state_t*12)*.10*clampf(_stagger/.5,0,1)
	if grounded and _ankle_frames.size()==2:
		_gait.solve(self,_phase,stride)
	else:
		_gait.reset()
		if not crawling and _vault_t<0 and state not in [State.SLEEP,State.DEAD] and (_wake_tween==null or not _wake_tween.is_running()):_model.position.y=0
	_deform_skin()

func _deform_skin() -> void:
	if _skin == null:return
	if _skin_frames.size()!=_skin_drivers.size():_bind_skin_drivers()
	# Existing logical joints drive skin in the exported rest frame. Damage and
	# movement remain authoritative gameplay outcomes, independent of animation.
	for entry:Array in _skin_frames:
		var driver:Node3D=entry[1]
		var local:Basis=entry[2]*Basis.from_euler(driver.rotation)*entry[3]
		_skin.set_bone_pose_rotation(entry[0],local.get_rotation_quaternion())
	for i in _ankle_frames.size():
		var entry:Array=_ankle_frames[i]
		var rotation_basis:Basis=_gait.ankle_bases[i] if _gait.active else Basis.IDENTITY
		var local:Basis=entry[1]*rotation_basis*entry[2]
		_skin.set_bone_pose_rotation(entry[0],local.get_rotation_quaternion())
	if _spine_bone>=0:
		var anticipation:=sin(clampf((.35-_attack_windup)/.35,0,1)*PI)*.10 if _attack_windup>=0 else 0.0
		_skin.set_bone_pose_rotation(_spine_bone,_spine_rest*Quaternion(Vector3.RIGHT,anticipation))
	if _head_bone>=0:
		_skin.set_bone_pose_rotation(_head_bone,_head_rest*Quaternion(Vector3.UP,sin(_state_t*1.2)*(.09 if state==State.INVESTIGATE else .015)))

func _bind_skin_drivers()->void:
	if _skin==null:return
	_skin_frames.clear()
	_ankle_frames.clear()
	for bone:int in _skin_drivers:
		var frame:=_skin.get_bone_global_rest(bone).basis.orthonormalized()
		_skin_frames.append([bone,_skin_drivers[bone],_skin.get_bone_rest(bone).basis*frame.inverse(),frame])
	for side:String in ["l","r"]:
		var bone:=_skin.find_bone("skin_zombie_ankle_"+side)
		if bone>=0:
			var frame:=_skin.get_bone_global_rest(bone).basis.orthonormalized()
			_ankle_frames.append([bone,_skin.get_bone_rest(bone).basis*frame.inverse(),frame])
	_spine_bone=_skin.find_bone("spine");_head_bone=_skin.find_bone("head")
	if _spine_bone>=0:_spine_rest=_skin.get_bone_rest(_spine_bone).basis.get_rotation_quaternion()
	if _head_bone>=0:_head_rest=_skin.get_bone_rest(_head_bone).basis.get_rotation_quaternion()

## Original joint acting; gameplay death has already happened before this runs.
func _death_pose(t:float)->void:
	_gait.reset()
	var fold:=smoothstep(0.0,.55,t)
	var fall:=smoothstep(.12,1.0,t)
	var side:float=-1.0 if posmod(_id,2)==0 else 1.0
	var buckle:=sin(t*PI)*.32
	var target:Array[Vector3]=[Vector3(.02,.02,-.45),Vector3(.02,-.02,.30),Vector3.ZERO,Vector3.ZERO,Vector3(-.04-buckle,0,0),Vector3(-.01-buckle*.6,0,0),Vector3(0,0,-.20),Vector3(0,0,.35)]
	var joints:Array=_arms+_legs+_knees+_elbows
	for i in joints.size():
		if joints[i]!=null:joints[i].rotation=_death_start_joints[i].lerp(target[i],fold)
	_deform_skin()
	if _skin!=null:
		if _spine_bone>=0:_skin.set_bone_pose_rotation(_spine_bone,_spine_rest*Quaternion(Vector3.RIGHT,-.16*fold*(1-smoothstep(.65,1.0,t))))
		if _head_bone>=0:_skin.set_bone_pose_rotation(_head_bone,_head_rest*Quaternion(Vector3.UP,side*.24*fold))
	_model.rotation=_death_start_rotation.lerp(Vector3(-PI/2+_death_ground_pitch,0,side*.025+_death_ground_roll),fall)
	_settle_corpse()

## Cache extremal vertices per weighted body region once for the shared model.
## These are visual support probes, not new collision shapes or rigid bodies.
func _prepare_contact_samples()->void:
	if _skin==null or not _contact_templates.is_empty():return
	for mi:MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		if mi.skin==null:continue
		var bone_ids:=PackedInt32Array();var binds:Array[Transform3D]=[]
		for i in mi.skin.get_bind_count():
			var bone:=_skin.find_bone(mi.skin.get_bind_name(i))
			if bone<0:bone=mi.skin.get_bind_bone(i)
			bone_ids.append(bone);binds.append(mi.skin.get_bind_pose(i))
		for surface in mi.mesh.get_surface_count():
			var ar:=mi.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=ar[Mesh.ARRAY_VERTEX]
			var slots:PackedInt32Array=ar[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=ar[Mesh.ARRAY_WEIGHTS]
			var stride:=int(weights.size()/vertices.size());var extremes:Dictionary={}
			for i in vertices.size():
				var main:=0
				for j in stride:
					if weights[i*stride+j]>weights[i*stride+main]:main=j
				var region:=slots[i*stride+main]
				for axis in 3:
					for direction:int in [-1,1]:
						var key:=region*6+axis*2+(1 if direction>0 else 0)
						if not extremes.has(key) or vertices[i][axis]*direction>vertices[extremes[key]][axis]*direction:extremes[key]=i
			var points:Array=[];var used:Dictionary={}
			for i:int in extremes.values():
				if used.has(i):continue
				used[i]=true;points.append([vertices[i],slots.slice(i*stride,(i+1)*stride),weights.slice(i*stride,(i+1)*stride)])
			_contact_templates.append({"bone_ids":bone_ids,"binds":binds,"points":points})

func _corpse_floor(p:Vector3)->float:
	if terrain==null or terrain.data==null:return global_position.y
	var h:float=terrain.data.get_height(Vector3(p.x,0,p.z))
	if is_nan(h):return global_position.y
	h=RoadNet.lift(IceField.lift(h,p.x,p.z),p.x,p.z,global_position.y)
	for cb in cabins:
		if absf(cb.position.x-p.x)<9 and absf(cb.position.z-p.z)<9:
			var floor_h:float=cb.floor_at(p.x,p.z,h)
			if not is_nan(floor_h):return floor_h
	return h

func _settle_corpse()->void:
	if _skin==null:return
	_prepare_contact_samples()
	_model.position.y=0
	var offset:=-INF
	for group:Dictionary in _contact_templates:
		var matrices:Array[Transform3D]=[]
		for i in group.bone_ids.size():matrices.append(_skin.get_bone_global_pose(group.bone_ids[i])*group.binds[i])
		for point:Array in group.points:
			var local:=Vector3.ZERO
			for j in point[1].size():local+=(matrices[point[1][j]]*point[0])*point[2][j]
			var p:Vector3=_skin.global_transform*local
			offset=maxf(offset,_support_floor(p)+.04-p.y)
	if is_finite(offset):_model.position.y=offset/maxf(.001,global_basis.get_scale().y)

## Static local ground at 10 cm spacing; share the four samples across probes.
## Discontinuous floor edges take the higher support instead of interpolating
## down through a threshold. This cache only affects the falling visual skin.
func _support_floor(p:Vector3)->float:
	var q:=Vector2(p.x,p.z)*10
	var cell:=Vector2i(floori(q.x),floori(q.y));var frac:=q-Vector2(cell)
	var heights:Array[float]=[]
	for corner:Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i.ONE]:
		var key:=cell+corner
		if not _death_floor_cache.has(key):_death_floor_cache[key]=_corpse_floor(Vector3(key.x*.1,p.y,key.y*.1))
		heights.append(_death_floor_cache[key])
	if heights.max()-heights.min()>.065:return heights.max()
	return lerpf(lerpf(heights[0],heights[1],frac.x),lerpf(heights[2],heights[3],frac.x),frac.y)


func is_dead() -> bool:
	return state == State.DEAD


func _wake() -> void:
	if state != State.SLEEP:
		return
	state = State.INVESTIGATE
	_state_t = 0.0
	_stagger = 1.2
	_wake_tween=create_tween()
	_wake_tween.tween_property(_model, "rotation:x", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_wake_tween.parallel().tween_property(_model, "position:y", 0.0, 1.0)


func _make_crawler() -> void:
	crawling = true
	for lg in _legs:
		if lg != null:
			lg.visible = false
	_model.position.y = -0.55
	_model.rotation.x = 0.35
	if _skin != null:
		for side:String in ["l","r"]:
			var bone:=_skin.find_bone("skin_zombie_leg_"+side)
			if bone>=0:_skin.set_bone_pose_scale(bone,Vector3.ONE*.001)


## 1.0 above -24 C; stiffening to 0.5 at -32 C; idle zombies stand frozen below -32 C.
func _cold_mult() -> float:
	if ambient_c > -24.0:
		return 1.0
	if ambient_c < -32.0 and state == State.IDLE:
		return 0.0
	return lerpf(1.0, 0.5, clampf((-24.0 - ambient_c) / 8.0, 0.0, 1.0))
