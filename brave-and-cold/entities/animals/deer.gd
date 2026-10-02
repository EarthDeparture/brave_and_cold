class_name Deer
extends Node3D
## Huntable deer: grazes, bolts when it sees/hears the player (gunshots carry far), slowed by deep snow like everything else.
## Dead deer leave a carcass that can be harvested for venison.

enum State { GRAZE, ALERT, FLEE, DEAD }
signal damaged   # for GameAudio
signal died

const MODEL := "res://assets/models/animals/deer.glb"
const GRAZE_SPEED := 0.8
const FLEE_SPEED := 9.0
const SIGHT_RANGE := 38.0
const MEAT_YIELD := 3

var terrain: Terrain3D
var snow: SnowField
var player: Player
var forest: ForestScatter
var state: State = State.GRAZE
var hp := 60.0
var speed_now := 0.0
var harvested := false
var bleed := false  # wounded: loses hp and leaves a blood trail
var _blood_d := 0.0
var _target := Vector3.ZERO
var _state_t := 0.0
var _threat := Vector3.ZERO
var _phase := 0.0
var _legs: Dictionary = {}
var _tail: Node3D
var _model: Node3D
var _rng := RandomNumberGenerator.new()


func setup(t: Terrain3D, s: SnowField, p: Player, f: ForestScatter, bus: NoiseBus, seed_value: int) -> void:
	terrain = t
	snow = s
	player = p
	forest = f
	_rng.seed = seed_value
	bus.noise.connect(_on_noise)
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	for n in ["fl", "fr", "bl", "br"]:
		_legs[n] = _model.find_child("deer_leg_" + n, true, false)
	_tail = _model.find_child("deer_tail", true, false)
	add_to_group("prey")
	_pick_graze()


func _pick_graze() -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(4.0, 14.0)
	_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _on_noise(pos: Vector3, radius: float, source: Object) -> void:
	if state == State.DEAD or source == self:
		return
	if global_position.distance_to(pos) <= radius:
		_threat = pos
		if state != State.FLEE:
			_set_state(State.ALERT)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func hit(dmg: float, from: Vector3) -> void:
	if state == State.DEAD:
		return
	hp -= dmg
	_threat = from
	if hp <= 0.0:
		_die()
	else:
		damaged.emit()
		if dmg >= 15.0:
			bleed = true
		_set_state(State.FLEE)


func _die() -> void:
	state = State.DEAD
	died.emit()
	remove_from_group("prey")
	add_to_group("carcasses")
	set_meta("born", Time.get_ticks_msec())
	speed_now = 0.0
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI / 2.0, 0.45)
	Carcass.blood(get_parent(), global_position, 1.1)


func _sees_player() -> bool:
	var to := player.position - global_position
	to.y = 0.0
	var d := to.length()
	var rng_m := SIGHT_RANGE * (0.5 if player.crouching else 1.0)
	return d < rng_m


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null or player == null:
		return
	if state == State.DEAD:
		return
	if bleed:
		hp -= 1.6 * delta
		_blood_d += speed_now * delta
		if _blood_d > 2.0:
			_blood_d = 0.0
			Carcass.blood(get_parent(), global_position, randf_range(0.22, 0.4))
		if hp <= 0.0:
			_die()
			return
	_state_t += delta
	var want := 0.0
	if state == State.GRAZE and _sees_player():
		_threat = player.position
		_set_state(State.ALERT)
	match state:
		State.GRAZE:
			var dd := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
			if dd < 1.0 or _state_t > 12.0:
				if _state_t > 5.0:
					_pick_graze()
					_state_t = 0.0
			else:
				want = GRAZE_SPEED
		State.ALERT:
			_face(_threat, delta, 6.0)
			if _state_t > 0.8:
				var away := global_position - _threat
				away.y = 0.0
				_target = global_position + away.normalized() * 80.0
				_set_state(State.FLEE)
		State.FLEE:
			want = FLEE_SPEED
			if _state_t > 9.0 and global_position.distance_to(player.position) > 55.0:
				_set_state(State.GRAZE)
				_pick_graze()
	_move(want, delta)
	_animate(delta)


func _face(p: Vector3, delta: float, rate: float) -> void:
	var d := p - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * rate))


func _move(want: float, delta: float) -> void:
	var pos := global_position
	var mult := pow(snow.zombie_speed_mult(pos.x, pos.z), 0.5)
	speed_now = lerpf(speed_now, want * mult, minf(1.0, delta * 5.0))
	if speed_now > 0.05:
		_face(_target, delta, 6.0)
		var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		var np := pos + fwd * speed_now * delta
		np.y = pos.y
		if forest != null:
			var q := forest.resolve_trunks(np.x, np.z, 0.4)
			np.x = q.x
			np.z = q.y
		np.x = clampf(np.x, -980.0, 980.0)
		np.z = clampf(np.z, -980.0, 980.0)
		pos = np
	var h: float = terrain.data.get_height(Vector3(pos.x, 0.0, pos.z))
	if not is_nan(h):
		pos.y = lerpf(pos.y, h, minf(1.0, delta * 14.0))
	global_position = pos


func _animate(delta: float) -> void:
	_phase += delta * speed_now * 2.6
	var amp := clampf(speed_now / FLEE_SPEED, 0.0, 1.0) * 0.8 + (0.2 if speed_now > 0.1 else 0.0)
	var s := sin(_phase) * amp
	if _legs.get("fl") != null:
		(_legs["fl"] as Node3D).rotation.x = s
		(_legs["br"] as Node3D).rotation.x = s
		(_legs["fr"] as Node3D).rotation.x = -s
		(_legs["bl"] as Node3D).rotation.x = -s
	if _tail != null:
		_tail.rotation.x = -0.3 + (0.6 if state == State.FLEE else 0.0)


func is_dead() -> bool:
	return state == State.DEAD
