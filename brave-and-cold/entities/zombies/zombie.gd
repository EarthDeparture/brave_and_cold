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
const BREAK_DPS := 6.0            # vs glass / planks at a window
const VAULT_S := 1.4
const CORPSE_LIFE_S := 300.0

static var night_factor := 0.0
static var _mats: Array[StandardMaterial3D] = []     # shared tints (batching) instead of one material per zombie
static var _scw_frame := -1
static var _scw_val = null
static var _scw_any = null
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
	_release()
	if _bus != null:
		_bus.unregister(self)


## Called by NoiseBus.emit_noise for listeners already inside the radius.
func on_noise(pos: Vector3, _radius: float, _source: Object) -> void:
	if state == State.DEAD:
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
	var rng_m := SIGHT_RANGE * (0.55 if player.crouching else 1.0) * (1.0 - 0.45 * night_factor)
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
	_release()
	_vault_t = -1.0
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
					grabs += 1
					player.hurt(DAMAGE, "Torn apart by the infected")
			var cb = _shut_cabin_with_player()
			if cb != null and not cb.contains_xz(global_position.x, global_position.z):
				want = _breach(cb, delta, want)   # smash a window / the door to get in
			elif _bo != null:
				_release()
				_bo = null
			if _last_seen_t > 8.0 and cb == null:
				_set_state(State.INVESTIGATE)
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
			bld.bash_door(DOOR_BASH_DPS * delta)
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
	_bo.hit(BREAK_DPS * delta)   # glass_break / board_break raise the noise via Opening.event
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
	var mx := pos.x - _hx
	var mz := pos.z - _hz
	if mx * mx + mz * mz > 0.16:            # height + snow tier only re-sampled after 0.4 m of travel
		_hx = pos.x
		_hz = pos.z
		var hq: float = terrain.data.get_height(Vector3(pos.x, 0.0, pos.z))
		_hcache = hq
		_mcache = snow.zombie_speed_mult(pos.x, pos.z)
	var mult := _mcache
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
