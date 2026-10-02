class_name Wolf
extends Node3D
## Timber wolf: wander -> (hears noise | sees player) -> alert -> chase -> bite. Slowed by snow depth (less than zombies), uses trampled trails.
## Procedural leg/tail animation on the segmented model.

enum State { WANDER, INVESTIGATE, ALERT, CHASE, RETREAT }
signal attacked   # for GameAudio
signal damaged
signal died

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
var speed_now := 0.0
var bites := 0
var hp := 40.0
var dead := false
var _dead_t := 0.0
var _carcass: Node3D = null
var _feed_t := 0.0
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
		Carcass.blood(get_parent(), global_position, 0.9)
		speed_now = 0.0
		var tw := create_tween()
		tw.tween_property(self, "rotation:z", PI / 2.0, 0.5)
		return
	damaged.emit()
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


func _can_see_player() -> bool:
	var to := player.position - global_position
	to.y = 0.0
	var d := to.length()
	var range_m := SIGHT_RANGE * (0.55 if player.crouching else 1.0)
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
		if c == null or c == self or c.is_queued_for_deletion() or not Carcass.has_meat(c):
			continue
		if not Carcass.smelled_by(c, global_position):
			continue
		var d := c.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = c
	return best


func _eat_carcass() -> void:
	if _carcass != null and is_instance_valid(_carcass):
		var done: Dictionary = _carcass.get_meta("done", {})
		done["meat"] = true
		_carcass.set_meta("done", done)
		if Carcass.open_steps(Carcass.species_of(_carcass), done).is_empty():
			_carcass.queue_free()
	_carcass = null
	_feed_t = 0.0
	_set_state(State.WANDER)
	_pick_wander()


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
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_struggle_cd = maxf(0.0, _struggle_cd - delta)
	var fl := _flare_near()
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
			if _can_see_player():
				_set_state(State.ALERT)
			elif _carcass != null and is_instance_valid(_carcass) and not _carcass.is_queued_for_deletion() and Carcass.has_meat(_carcass):
				var cd := Vector2(_carcass.global_position.x - global_position.x, _carcass.global_position.z - global_position.z).length()
				if cd < 2.5:
					want_speed = 0.0
					_feed_t += delta
					if _feed_t > 14.0:
						_eat_carcass()
				else:
					want_speed = TROT_SPEED
					if _state_t > 40.0:
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
			if state == State.CHASE and Vector2(np.x, np.z).distance_to(before) > step.length() * 0.6:
				_stuck_t += delta
			else:
				_stuck_t = maxf(0.0, _stuck_t - delta)
			pos = np
	var h: float = IceField.lift(terrain.data.get_height(Vector3(pos.x, 0.0, pos.z)), pos.x, pos.z)
	if not is_nan(h):
		pos.y = lerpf(pos.y, h, minf(1.0, delta * 14.0))
	global_position = pos


func _animate(delta: float) -> void:
	_phase += delta * speed_now * 3.2
	var amp := clampf(speed_now / RUN_SPEED, 0.0, 1.0) * 0.75 + (0.25 if speed_now > 0.1 else 0.0)
	var s := sin(_phase) * amp
	if _legs.get("fl") != null:
		(_legs["fl"] as Node3D).rotation.x = s
		(_legs["br"] as Node3D).rotation.x = s
		(_legs["fr"] as Node3D).rotation.x = -s
		(_legs["bl"] as Node3D).rotation.x = -s
	if _tail != null:
		_tail.rotation.x = -0.15 + sin(_phase * 0.5) * 0.06 - (0.35 if state == State.CHASE else 0.0)
	if _body != null:
		_body.position.y = absf(sin(_phase)) * 0.04 * amp


func is_dead() -> bool:
	return dead
