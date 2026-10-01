class_name Zombie
extends Node3D
## Shambler: idle wander -> hears noise / sees player -> investigate -> chase -> grab/bite. Slow by design; deep snow makes it slower still
## (SnowField.zombie_speed_mult: 100/95/75/50/30/20 %). Bashes closed cabin doors while the player is inside. Dies to melee.

enum State { IDLE, INVESTIGATE, CHASE, DEAD }

const MODEL := "res://assets/models/animals/zombie.glb"
const IDLE_SPEED := 0.8
const INVESTIGATE_SPEED := 1.5
const CHASE_SPEED := 2.4
const SIGHT_RANGE := 18.0
const GRAB_RANGE := 1.15
const DAMAGE := 7.0
const COOLDOWN := 1.6
const DOOR_BASH_DPS := 10.0
const CORPSE_LIFE_S := 300.0

static var night_factor := 0.0
static var prof_on := false
static var dbg_skip_anim := false
static var dbg_skip_move := false
static var prof: PackedFloat64Array = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
static var _mats: Array[StandardMaterial3D] = []     # shared tints (batching) instead of one material per zombie
static var _scw_frame := -1
static var _scw_val: Node3D = null
const AI_EVERY_NEAR := 2                              # 20-60 m: brain+move every 2nd frame
const AI_EVERY_FAR := 6                               # > 60 m: every 6th frame

var terrain: Terrain3D
var snow: SnowField
var player: Player
var forest: ForestScatter
var cabins: Array = []
var state: State = State.IDLE
var hp := 100.0
var speed_now := 0.0
var grabs := 0
var _target := Vector3.ZERO
var _last_seen_t := 0.0
var _state_t := 0.0
var _cd := 0.0
var _stagger := 0.0
var _phase := 0.0
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _model: Node3D
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
	if _mats.is_empty():
		var mr := RandomNumberGenerator.new()
		mr.seed = 4242
		for q in 6:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			var kk := 0.75 + 0.4 * float(q) / 5.0
			m.albedo_color = Color(kk, kk * mr.randf_range(0.92, 1.05), kk * mr.randf_range(0.9, 1.08))
			_mats.append(m)
	var mat: StandardMaterial3D = _mats[_rng.randi() % _mats.size()]
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	for n in ["l", "r"]:
		_arms.append(_model.find_child("zombie_arm_" + n, true, false))
		_legs.append(_model.find_child("zombie_leg_" + n, true, false))
	_model.scale = Vector3.ONE * _rng.randf_range(0.94, 1.06)
	_phase = _rng.randf() * TAU
	add_to_group("hostile")
	_pick_wander()


func _exit_tree() -> void:
	if _bus != null:
		_bus.unregister(self)


## Called by NoiseBus.emit_noise for listeners already inside the radius.
func on_noise(pos: Vector3, _radius: float, _source: Object) -> void:
	if state == State.DEAD:
		return
	_target = pos
	if state != State.CHASE:
		_set_state(State.INVESTIGATE)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _pick_wander() -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(3.0, 12.0)
	_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


## Which closed building holds the player. Computed once per frame for all zombies.
func _shut_cabin_with_player() -> Cabin:
	var f := Engine.get_process_frames()
	if f != _scw_frame:
		_scw_frame = f
		_scw_val = null
		for cb in cabins:
			if cb.contains_xz(player.position.x, player.position.z) and not cb.door_open:
				_scw_val = cb
				break
	return _scw_val as Cabin


func _can_see_player() -> bool:
	if _shut_cabin_with_player() != null:
		return false
	var to := player.position - global_position
	to.y = 0.0
	var d := to.length()
	var rng_m := SIGHT_RANGE * (0.55 if player.crouching else 1.0) * (1.0 - 0.45 * night_factor)
	if d > rng_m:
		return false
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	return d < 4.0 or fwd.dot(to / maxf(d, 0.001)) > 0.3


func hit(dmg: float, from: Vector3) -> void:
	if state == State.DEAD:
		return
	hp -= dmg
	_stagger = 0.5
	if hp <= 0.0:
		_die()
	else:
		_target = from
		_set_state(State.CHASE)
		_last_seen_t = 0.0


func _die() -> void:
	state = State.DEAD
	remove_from_group("hostile")
	add_to_group("bodies")
	speed_now = 0.0
	var tw := create_tween()
	tw.tween_property(_model, "rotation:x", -PI / 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_model, "position:y", 0.12, 0.7)


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null or player == null:
		return
	if state == State.DEAD:
		_dead_t += delta
		if _dead_t > CORPSE_LIFE_S:
			queue_free()
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
	var _t0 := Time.get_ticks_usec() if prof_on else 0
	var want := 0.0
	var sees := _can_see_player()
	if sees:
		_target = pp
		_last_seen_t = 0.0
		if state != State.CHASE:
			_set_state(State.CHASE)
	else:
		_last_seen_t += delta
	if prof_on:
		prof[0] += float(Time.get_ticks_usec() - _t0)
		_t0 = Time.get_ticks_usec()
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
			if dd2 < 2.0 or _state_t > 20.0:
				_set_state(State.IDLE)
				_pick_wander()
		State.CHASE:
			want = CHASE_SPEED
			if dist < GRAB_RANGE and absf(pp.y - global_position.y - 1.0) < 2.0:
				want = 0.0
				_face(pp, delta, 10.0)
				if _cd <= 0.0 and _stagger <= 0.0:
					_cd = COOLDOWN
					grabs += 1
					player.hurt(DAMAGE, "Torn apart by the infected")
			var cb := _shut_cabin_with_player()
			if cb != null:
				# heard the player inside: pound on the door
				_target = cb.door_world_pos()
				if Vector2(_target.x - global_position.x, _target.z - global_position.z).length() < 2.3:
					want = 0.0
					_face(_target, delta, 8.0)
					cb.bash_door(DOOR_BASH_DPS * delta)
			if _last_seen_t > 8.0 and cb == null:
				_set_state(State.INVESTIGATE)
	if _stagger > 0.0:
		want = 0.0
	if prof_on:
		prof[1] += float(Time.get_ticks_usec() - _t0)
		_t0 = Time.get_ticks_usec()
	if not dbg_skip_move:
		_move(want, delta)
	if prof_on:
		prof[2] += float(Time.get_ticks_usec() - _t0)
		_t0 = Time.get_ticks_usec()
	if _lod <= 1 and not dbg_skip_anim:
		_animate(delta)
	if prof_on:
		prof[3] += float(Time.get_ticks_usec() - _t0)
		prof[4] += 1.0


func _face(p: Vector3, delta: float, rate: float) -> void:
	var d := p - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * rate))


func _move(want: float, delta: float) -> void:
	var pos := global_position
	var mx := pos.x - _hx
	var mz := pos.z - _hz
	if mx * mx + mz * mz > 0.16:            # height + snow tier only re-sampled after 0.4 m of travel
		var _th := Time.get_ticks_usec() if prof_on else 0
		_hx = pos.x
		_hz = pos.z
		var hq: float = terrain.data.get_height(Vector3(pos.x, 0.0, pos.z))
		_hcache = hq
		_mcache = snow.zombie_speed_mult(pos.x, pos.z)
		if prof_on:
			prof[6] += float(Time.get_ticks_usec() - _th)
	var mult := _mcache
	speed_now = lerpf(speed_now, want * mult, minf(1.0, delta * 5.0))
	if speed_now > 0.03:
		_face(_target, delta, 4.0)
		var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		var np := pos + fwd * speed_now * delta
		np.y = pos.y
		var _tm := Time.get_ticks_usec() if prof_on else 0
		if forest != null:
			var q := forest.resolve_trunks(np.x, np.z, 0.35)
			np.x = q.x
			np.z = q.y
		if prof_on:
			prof[5] += float(Time.get_ticks_usec() - _tm)
			_tm = Time.get_ticks_usec()
		for cb in cabins:
			if absf(cb.position.x - np.x) > 9.0 or absf(cb.position.z - np.z) > 9.0:
				continue
			var q2: Vector2 = cb.resolve(np.x, np.z, 0.4)
			np.x = q2.x
			np.z = q2.y
		if prof_on:
			prof[7] += float(Time.get_ticks_usec() - _tm)
		pos = np
	var h: float = _hcache
	if not is_nan(h):
		pos.y = lerpf(pos.y, h, minf(1.0, delta * 14.0))
	global_position = pos


func _animate(delta: float) -> void:
	_phase += delta * (1.5 + speed_now * 2.6)
	var amp := clampf(speed_now / CHASE_SPEED, 0.0, 1.0) * 0.55
	var s := sin(_phase)
	if _legs.size() == 2 and _legs[0] != null:
		_legs[0].rotation.x = s * amp
		_legs[1].rotation.x = -s * amp
	if _arms.size() == 2 and _arms[0] != null:
		var reach := 0.0 if state == State.CHASE else 0.35
		_arms[0].rotation.x = reach + 0.08 * sin(_phase * 0.8)
		_arms[1].rotation.x = reach + 0.08 * sin(_phase * 0.8 + 1.3)
	_model.rotation.z = sin(_phase * 0.5) * 0.04


func is_dead() -> bool:
	return state == State.DEAD
