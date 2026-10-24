class_name Wolf
extends Node3D
## Timber wolf: wander -> (hears noise | sees player) -> alert -> chase -> bite. Slowed by snow depth (less than zombies), uses trampled trails.
## Procedural leg/tail animation on the segmented model.

enum State { WANDER, INVESTIGATE, ALERT, CHASE, RETREAT }
signal attacked   # for GameAudio
signal damaged
signal died
signal growled   # A6: a wolf over its kill warning you off (GameAudio)

var WALK_SPEED := 1.6
var TROT_SPEED := 3.4
var RUN_SPEED := 8.0
var SIGHT_RANGE := 32.0
const SIGHT_FOV_DOT := 0.35  # cos of half-FOV (~70 deg)
var ALERT_TIME := 1.2
var BITE_RANGE := 1.6
var BITE_DAMAGE := 12.0
var BITE_COOLDOWN := 1.3
var GIVE_UP_DIST := 70.0

var model_path := "res://assets/models/animals/wolf.glb"
var part_prefix := "wolf"
var death_msg := "Mauled by a wolf"
var body_radius := 0.4
var struggle_gain := 0.14
var _struggle_cd := 0.0
var _tick := 0.0
var terrain: Terrain3D
var snow: SnowField
var player: Player
var forest: ForestScatter
var cabins: Array = []
var state: State = State.WANDER
var _dazzle_t := 0.0
var speed_now := 0.0
var bites := 0
var hp := 40.0
var dead := false
var _dead_t := 0.0
var _carcass: Node3D = null
var _feed_t := 0.0
var _eaten := 0                 # portions eaten at this kill
var _sated_t := 0.0             # > 0: fed, ignores carcasses (real seconds)
var _bleed_t := 0.0             # > 0: wounded, drips blood as it moves
var _blood_d := 0.0
var _model_root: Node3D
## A6 food web 3: a wolf defends its kill (TLD). Under 30 m it stands over it and growls; under 15 m it bluff-charges
## and goes back; stay close after that (or come within 6 m) and it attacks. A lit torch within 10 m or a flare makes it
## flee and abandon the kill for 5 min - the meat is yours. Several wolves at one kill take turns: one feeds, the
## others circle at ~8 m and swap after each portion.
static var player_torch := false   # a burning torch in hand (GameWorld): wolves give it room
const DEFEND_R := 30.0
const BLUFF_R := 15.0
const TORCH_R := 10.0
var defending := false
var growls := 0
var bluffs := 0
var abandons := 0
var _growl_cd := 0.0
var _bluff_t := 0.0                # > 0 charging, < 0 trotting back to the kill
var _bluff_cd := 0.0
var _close_t := 0.0
var _avoid: Node3D = null          # a kill it was driven off
var _avoid_t := 0.0
var _yield_t := 0.0                # just ate a portion with others waiting: let one of them in
var circling := false
const FEED_PORTION_S := 10.0    # a wolf tears off one meat portion every ~10 s at a kill
var sate_portions := 2          # a wolf eats ~2 portions (a bear more) and leaves the rest
var _scent_t := 0.0
var _target := Vector3.ZERO
var _state_t := 0.0
var _bite_cd := 0.0
var _phase := 0.0
var _stuck_t := 0.0
var _legs: Dictionary = {}
var _tail: Node3D
var _body: Node3D
var _rng := RandomNumberGenerator.new()


func setup(t: Terrain3D, s: SnowField, p: Player, f: ForestScatter, cbs: Array, bus: NoiseBus, seed_value: int) -> void:
	terrain = t
	snow = s
	player = p
	forest = f
	cabins = cbs
	_rng.seed = seed_value
	bus.noise.connect(_on_noise)
	var model := (load(model_path) as PackedScene).instantiate()
	add_child(model)
	_model_root = model
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	for n in ["fl", "fr", "bl", "br"]:
		_legs[n] = model.find_child(part_prefix + "_leg_" + n, true, false)
	_tail = model.find_child(part_prefix + "_tail", true, false)
	_body = model.find_child(part_prefix + "_body", true, false)
	add_to_group("hostile")
	add_to_group("wolves")   # A6: packmates at a kill take turns
	_pick_wander()


func hit(dmg: float, from: Vector3) -> void:
	if dead:
		return
	hp -= dmg
	if hp <= 0.0:
		dead = true
		died.emit()
		remove_from_group("hostile")
		add_to_group("carcasses")
		set_meta("born", Time.get_ticks_msec())
		set_meta("food_age_s",0.0)
		Carcass.blood(get_parent(), global_position, 0.9)
		speed_now = 0.0
		var tw := create_tween()
		tw.tween_property(self, "rotation:z", PI / 2.0, 0.5)
		return
	damaged.emit()
	if dmg >= 8.0:
		_bleed_t = 90.0 + dmg * 3.0   # wounded: a blood trail to follow
	_target = from
	_set_state(State.CHASE)


func _flare_near() -> Node3D:
	for f in get_tree().get_nodes_in_group("flares"):
		var n := f as Node3D
		if n != null and n.global_position.distance_to(global_position) < Flare.REPEL_RADIUS:
			return n
	return null


func repel() -> void:
	_struggle_cd = 12.0
	_bite_cd = 3.0
	var away := global_position - player.position
	away.y = 0.0
	_target = global_position + away.normalized() * 45.0
	_set_state(State.RETREAT)


func struggle_failed() -> void:
	_struggle_cd = 5.0


func _on_noise(pos: Vector3, radius: float, source: Object) -> void:
	if source == self or state == State.CHASE or state == State.ALERT:
		return
	if global_position.distance_to(pos) <= radius:
		_carcass = null
		_target = pos
		_set_state(State.INVESTIGATE)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _pick_wander() -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(8.0, 28.0)
	_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _player_indoors_shut() -> bool:
	for cb in cabins:
		if cb.contains_xz(player.position.x, player.position.z) and not cb.door_open:
			return true
	return false


static var raven_kills: Array = []   # carcasses with ravens over them (AmbientLife): seen from far, followed in
const RAVEN_SIGHT := 450.0
var _give_up := 40.0
static var player_lit := false   # player's flashlight / weapon light on (GameWorld)

func _can_see_player() -> bool:
	var to := player.position - global_position
	to.y = 0.0
	var d := to.length()
	var range_m := SIGHT_RANGE * (0.55 if player.crouching else 1.0) * (1.6 if player_lit else 1.0)
	if d > range_m or _player_indoors_shut():
		return false
	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	return d < 6.0 or fwd.dot(to / maxf(d, 0.001)) > SIGHT_FOV_DOT


## Nearest carcass with meat left whose scent reaches us.
func _smell_carcass() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for cn in get_tree().get_nodes_in_group("carcasses"):
		var c := cn as Node3D
		if c == null or c == self or c.is_queued_for_deletion() or not Carcass.has_meat(c) or _sated_t > 0.0:
			continue
		if c == _avoid and _avoid_t > 0.0:
			continue
		var d := c.global_position.distance_to(global_position)
		if not Carcass.smelled_by(c, global_position) and not (d < RAVEN_SIGHT and raven_kills.has(c)):
			continue
		if d < bd:
			bd = d
			best = c
	return best


## Tear off one portion (shared 'scavenged' count with the ravens). The meat step is gone only when every portion
## is; a sated wolf walks off and leaves the rest for the ravens - or you.
func _eat_carcass() -> void:
	var leave := true
	if _carcass != null and is_instance_valid(_carcass):
		var sp := Carcass.species_of(_carcass)
		var full := int(Carcass.SPECIES[sp].meat_n) if Carcass.SPECIES.has(sp) else 1
		var s := Carcass.scavenged(_carcass) + 1.0
		_carcass.set_meta("scavenged", s)
		_eaten += 1
		if s >= float(full):
			var done: Dictionary = _carcass.get_meta("done", {})
			done["meat"] = true
			_carcass.set_meta("done", done)
			if Carcass.open_steps(sp, done).is_empty():
				_carcass.queue_free()
		else:
			leave = _eaten >= sate_portions
	if not leave:
		_feed_t = 0.0
		if _carcass != null and is_instance_valid(_carcass) and _others_waiting(_carcass):
			_carcass.set_meta("feeder", 0)   # a packmate's turn
			_yield_t = FEED_PORTION_S * 1.2
		return
	if _carcass != null and is_instance_valid(_carcass) and int(_carcass.get_meta("feeder", 0)) == get_instance_id():
		_carcass.set_meta("feeder", 0)
	if _eaten > 0:
		_sated_t = 600.0
	_eaten = 0
	_carcass = null
	_feed_t = 0.0
	_set_state(State.WANDER)
	_pick_wander()


func _others_waiting(c: Node3D) -> bool:
	for w in get_tree().get_nodes_in_group("wolves"):
		if w != self and is_instance_valid(w) and not w.dead and w._carcass == c and w.global_position.distance_to(c.global_position) < 15.0:
			return true
	return false


## Driven off its kill: flee from the player and leave the carcass alone for a while.
func abandon_kill() -> void:
	if _carcass != null and is_instance_valid(_carcass):
		_avoid = _carcass
		_avoid_t = 300.0
		if int(_carcass.get_meta("feeder", 0)) == get_instance_id(): _carcass.set_meta("feeder", 0)
	abandons += 1
	_carcass = null
	defending = false
	circling = false
	_bluff_t = 0.0
	var away := global_position - player.position
	away.y = 0.0
	_target = global_position + (away.normalized() if away.length() > 0.01 else Vector3.FORWARD) * 45.0
	_set_state(State.RETREAT)


## Standing over the kill with the player within DEFEND_R. Returns the speed to move at.
func _defend(delta: float, dist: float, pp: Vector3) -> float:
	if (player_torch and dist < TORCH_R) or _flare_near() != null:
		abandon_kill()
		return TROT_SPEED
	defending = true
	_growl_cd -= delta
	_bluff_cd = maxf(0.0, _bluff_cd - delta)
	if _growl_cd <= 0.0:
		_growl_cd = _rng.randf_range(2.2, 3.8)
		growls += 1
		growled.emit()
	if _bluff_t > 0.0:   # the charge: straight at you, stopping short
		_bluff_t -= delta
		_target = pp
		if dist < 6.0 or _bluff_t <= 0.0:
			_bluff_t = -2.2
		return RUN_SPEED * 0.85
	if _bluff_t < 0.0:   # back over the kill
		_bluff_t = minf(0.0, _bluff_t + delta)
		_target = _carcass.global_position
		return TROT_SPEED
	_face(pp, delta, 6.0)
	if dist < BLUFF_R:
		_close_t += delta
		if dist < 6.0 or (bluffs > 0 and _close_t > 3.0):   # you didn't back off: now it means it
			defending = false
			if int(_carcass.get_meta("feeder", 0)) == get_instance_id(): _carcass.set_meta("feeder", 0)
			_carcass = null
			_set_state(State.ALERT)
			return 0.0
		if _bluff_cd <= 0.0:
			_bluff_cd = 9.0
			_bluff_t = 1.5
			bluffs += 1
			growls += 1
			growled.emit()
	else:
		_close_t = maxf(0.0, _close_t - delta * 0.5)
	return 0.0


func is_feeding() -> bool:
	return state == State.INVESTIGATE and _carcass != null and is_instance_valid(_carcass) and speed_now < 0.3 \
		and Vector2(_carcass.global_position.x - global_position.x, _carcass.global_position.z - global_position.z).length() < 2.5


func animal_snow_mult(x: float, z: float) -> float:
	return pow(snow.zombie_speed_mult(x, z), 0.5)


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null or player == null:
		return
	if dead:
		_dead_t += delta
		if _dead_t > 900.0:
			queue_free()
		return
	_state_t += delta
	_sated_t = maxf(0.0, _sated_t - delta)
	_avoid_t = maxf(0.0, _avoid_t - delta)
	_yield_t = maxf(0.0, _yield_t - delta)
	if _bleed_t > 0.0:
		_bleed_t -= delta
		_blood_d += speed_now * delta
		if _blood_d > _rng.randf_range(1.8, 3.5):
			_blood_d = 0.0
			Carcass.blood(get_parent(), global_position, _rng.randf_range(0.14, 0.26))
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_struggle_cd = maxf(0.0, _struggle_cd - delta)
	var fl := _flare_near()
	if fl != null and _carcass != null:
		abandon_kill()
	if fl != null:
		var away := global_position - fl.global_position
		away.y = 0.0
		_target = global_position + away.normalized() * 40.0
		if state != State.RETREAT:
			_set_state(State.RETREAT)
		if player.struggling and player.struggle_by == self:
			player.struggling = false
		_state_t = minf(_state_t, 6.0)
	var pp := player.position
	var dist := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
	var want_speed := 0.0
	match state:
		State.WANDER:
			if _can_see_player():
				_set_state(State.ALERT)
			else:
				_scent_t -= delta
				if _scent_t <= 0.0:
					_scent_t = 1.5
					var sc := _smell_carcass()
					if sc != null:
						_carcass = sc
						_feed_t = 0.0
						_target = sc.global_position
						_give_up = 40.0 + sc.global_position.distance_to(global_position) / TROT_SPEED
						_set_state(State.INVESTIGATE)
				var dd := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
				if dd < 1.5 or _state_t > 14.0:
					if _state_t > 4.0:
						_pick_wander()
						_state_t = 0.0
					want_speed = 0.0
				else:
					want_speed = WALK_SPEED
		State.INVESTIGATE:
			var kill_ok := _carcass != null and is_instance_valid(_carcass) and not _carcass.is_queued_for_deletion() and Carcass.has_meat(_carcass)
			var kcd := 1e9
			if kill_ok:
				kcd = Vector2(_carcass.global_position.x - global_position.x, _carcass.global_position.z - global_position.z).length()
			if kill_ok and kcd < 11.0 and dist < DEFEND_R:
				want_speed = _defend(delta, dist, pp)
			elif _can_see_player():
				defending = false
				_set_state(State.ALERT)
			elif kill_ok:
				defending = false
				var cd := kcd
				var fid := int(_carcass.get_meta("feeder", 0))
				var fw = instance_from_id(fid) if fid != 0 else null
				var other_feeding: bool = fw != null and fw != self and is_instance_valid(fw) and not fw.dead and fw._carcass == _carcass
				if cd < 11.0 and (other_feeding or _yield_t > 0.0):   # a packmate is eating: circle and wait
					circling = true
					var a := _state_t * 0.22 + float(get_instance_id() % 628) * 0.01
					_target = _carcass.global_position + Vector3(cos(a), 0, sin(a)) * 8.0
					want_speed = WALK_SPEED
					_give_up = _state_t + 40.0   # waiting its turn is not giving up
				elif cd < 2.5:
					circling = false
					if fid == 0 or not other_feeding: _carcass.set_meta("feeder", get_instance_id())
					_target = _carcass.global_position
					want_speed = 0.0
					_feed_t += delta
					if _feed_t > FEED_PORTION_S:
						_eat_carcass()
				else:
					want_speed = TROT_SPEED
					circling = false
					_target = _carcass.global_position   # (a circling packmate's turn: in to the kill)
					if _state_t > _give_up:
						_carcass = null
						_set_state(State.WANDER)
						_pick_wander()
			else:
				_carcass = null
				var dd := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
				want_speed = TROT_SPEED
				if dd < 3.0 or _state_t > 12.0:
					_set_state(State.WANDER)
					_pick_wander()
		State.ALERT:
			_face(pp, delta, 8.0)
			if _state_t >= ALERT_TIME:
				_set_state(State.CHASE)
		State.CHASE:
			_target = pp
			want_speed = RUN_SPEED
			# a light held in its eyes under 15 m: the wolf checks, slows and weaves - wary, not scared off
			if player_lit and dist < 15.0 and dist > BITE_RANGE:
				var look := -player.cam.global_basis.z
				var to_me := (global_position + Vector3.UP * 0.5 - player.cam.global_position).normalized()
				if look.dot(to_me) > 0.975:
					_dazzle_t += delta
					# side-steps out of the beam at its range, then circles in (wolves are wary of a light, not scared off)
					var away := global_position - pp; away.y = 0.0; away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
					var perp := Vector3(-away.z, 0.0, away.x) * (1.0 if sin(_state_t * 0.8 + float(get_instance_id() % 7)) >= 0.0 else -1.0)
					want_speed = WALK_SPEED * (1.0 if _dazzle_t < 1.5 else 1.6)
					_target = global_position + perp * 3.0 - away * (0.0 if _dazzle_t < 1.5 else 1.2)
				else:
					_dazzle_t = maxf(0.0, _dazzle_t - delta)
			if dist < BITE_RANGE and absf(pp.y - global_position.y - 1.0) < 2.5:
				want_speed = 0.0
				_face(pp, delta, 12.0)
				if player.struggling and player.struggle_by == self:
					_tick -= delta
					if _tick <= 0.0:
						_tick = 1.3
						player.hurt(BITE_DAMAGE * 0.3, death_msg)
				elif _bite_cd <= 0.0:
					_bite_cd = BITE_COOLDOWN
					bites += 1
					attacked.emit()
					if not player.struggling and _struggle_cd <= 0.0 and not player.dead:
						player.start_struggle(self, struggle_gain)
						_tick = 1.3
					player.hurt(BITE_DAMAGE, death_msg)
					player.injury.wound(0.6, 0.08)
			if dist > GIVE_UP_DIST or (_state_t > 25.0 and dist > 35.0) or _stuck_t > 6.0:
				_set_state(State.RETREAT)
				var away := (global_position - pp)
				away.y = 0.0
				_target = global_position + away.normalized() * 40.0
				_stuck_t = 0.0
		State.RETREAT:
			want_speed = TROT_SPEED
			if _state_t > 10.0:
				_set_state(State.WANDER)
				_pick_wander()
	_move(want_speed, delta)
	_animate(delta)


func _face(p: Vector3, delta: float, rate: float) -> void:
	var d := p - global_position
	var yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * rate))


func _move(want: float, delta: float) -> void:
	var pos := global_position
	var mult := animal_snow_mult(pos.x, pos.z)
	speed_now = lerpf(speed_now, want * mult, minf(1.0, delta * 6.0))
	if speed_now > 0.05:
		var d := _target - pos
		d.y = 0.0
		if d.length() > 0.05:
			_face(_target, delta, 7.0)
			var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
			var step := fwd * speed_now * delta
			var np := pos + step
			np.y = pos.y
			var before := Vector2(np.x, np.z)
			if forest != null:
				var q := forest.resolve_trunks(np.x, np.z, body_radius)
				np.x = q.x
				np.z = q.y
			for cb in cabins:
				var q2: Vector2 = cb.resolve(np.x, np.z, body_radius + 0.05)
				np.x = q2.x
				np.z = q2.y
			var road_q:=RoadNet.resolve_actor(np,pos,body_radius)
			np.x=road_q.x;np.z=road_q.y
			if state == State.CHASE and Vector2(np.x, np.z).distance_to(before) > step.length() * 0.6:
				_stuck_t += delta
			else:
				_stuck_t = maxf(0.0, _stuck_t - delta)
			pos = np
	var h: float = RoadNet.lift(IceField.lift(terrain.data.get_height(Vector3(pos.x, 0.0, pos.z)), pos.x, pos.z),pos.x,pos.z,pos.y)
	if not is_nan(h):
		pos.y = lerpf(pos.y, h, minf(1.0, delta * 14.0))
	global_position = pos


var defend_k := 0.0   # W6: 0..1 how far into the guarding stance (head low, braced, tail out stiff)
func _animate(delta: float) -> void:
	_phase += delta * speed_now * 3.2
	var amp := clampf(speed_now / RUN_SPEED, 0.0, 1.0) * 0.75 + (0.25 if speed_now > 0.1 else 0.0)
	var guard := defending or (state == State.ALERT and speed_now < 0.5)
	defend_k = move_toward(defend_k, 1.0 if guard else 0.0, delta * (3.0 if guard else 1.5))
	var dk := defend_k * defend_k * (3.0 - 2.0 * defend_k)
	amp *= 1.0 - 0.45 * dk   # the bluff charge is stiff-legged: short hard strides
	var s := sin(_phase) * amp
	if _legs.get("fl") != null:   # braced: forelegs planted forward, hind legs set back under the crouch
		(_legs["fl"] as Node3D).rotation.x = s + 0.24 * dk
		(_legs["br"] as Node3D).rotation.x = s - 0.2 * dk
		(_legs["fr"] as Node3D).rotation.x = -s + 0.24 * dk
		(_legs["bl"] as Node3D).rotation.x = -s - 0.2 * dk
	if _tail != null:   # hanging and swaying -> held straight out behind, rigid
		var t_relaxed := -0.15 + sin(_phase * 0.5) * 0.06 - (0.35 if state == State.CHASE else 0.0)
		_tail.rotation.x = lerpf(t_relaxed, -0.85 + sin(_t_snarl() * 31.0) * 0.015, dk)
	if _body != null:   # a low growl's tremor through the body
		_body.position.y = absf(sin(_phase)) * 0.04 * amp + sin(_t_snarl() * 38.0) * 0.004 * dk
	if _model_root != null:   # feeding: nose down at the kill, tugging; guarding: head and shoulders dropped
		var feed := is_feeding() and dk < 0.5
		var want := (-0.20 + sin(_state_t * 5.0) * 0.05) if feed else -0.13 * dk
		_model_root.rotation.x = lerpf(_model_root.rotation.x, want, minf(1.0, delta * 4.0))
		_model_root.position.y = lerpf(_model_root.position.y, -0.07 * dk, minf(1.0, delta * 4.0))


func _t_snarl() -> float:
	return float(Time.get_ticks_msec()) * 0.001


func is_dead() -> bool:
	return dead
