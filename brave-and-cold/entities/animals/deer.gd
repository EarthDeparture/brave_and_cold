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
var _blood_next := 1.5
var _pool_t := 0.0
const BLEED_HP_S := 0.65   # a wounded deer runs, then staggers on and beds down: a ~150-250 m blood trail
const BED_HP := 12.0
var _target := Vector3.ZERO
var _state_t := 0.0
var _threat := Vector3.ZERO
var _phase := 0.0
var _legs: Dictionary = {}
var _lows: Dictionary = {}   # X2: lower legs (knee / hock down)
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
	var mat := Wolf.fur_material(1.0)   # X3: soft fur look
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	for n in ["fl", "fr", "bl", "br"]:
		_legs[n] = _model.find_child("deer_leg_" + n, true, false)
		_lows[n] = _model.find_child("deer_leg_" + n + "_lo", true, false)
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
		var away := global_position - from
		away.y = 0.0
		if away.length() < 0.1: away = Vector3(1, 0, 0)
		_target = global_position + away.normalized() * 80.0   # bolt AWAY from the shot (it used to run to its old graze spot)
		_set_state(State.FLEE)


func _die() -> void:
	state = State.DEAD
	died.emit()
	remove_from_group("prey")
	add_to_group("carcasses")
	set_meta("born", Time.get_ticks_msec())
	set_meta("food_age_s",0.0)
	speed_now = 0.0
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", PI / 2.0, 0.45)
	Carcass.blood(get_parent(), global_position, 1.1)


func _sees_player() -> bool:
	var to := player.position - global_position
	to.y = 0.0
	var d := to.length()
	var rng_m := SIGHT_RANGE * (0.5 if player.crouching else 1.0)
	if d >= rng_m:return false
	if d <= 4.0:return true
	if forest != null:
		var trunks:=forest.trunks_on_segment(global_position.x,global_position.z,player.position.x,player.position.z)
		if d > rng_m*maxf(.15,1-.25*trunks):return false
	# Use the same actual terrain supporting the animal, sampled along the
	# sightline. Being close on the other side of a ridge is not visible.
	if terrain != null and terrain.data != null:
		var eye:=global_position+Vector3.UP*1.15
		var steps:=maxi(2,int(ceil(d/2.0)))
		for i in range(1,steps):
			var point:=eye.lerp(player.position,float(i)/steps)
			var ground:float=terrain.data.get_height(point)
			if not is_nan(ground) and ground>point.y-.08:return false
	return true


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null or player == null:
		return
	if state == State.DEAD:
		return
	if bleed:
		hp -= BLEED_HP_S * delta
		_blood_d += speed_now * delta
		if _blood_d > _blood_next:
			_blood_d = 0.0
			_blood_next = _rng.randf_range(1.0, 2.6)
			Carcass.blood(get_parent(), global_position + Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)), _rng.randf_range(0.22, 0.48))
		if speed_now < 0.2:   # standing / bedded: it pools
			_pool_t += delta
			if _pool_t > 4.0:
				_pool_t = 0.0
				Carcass.blood(get_parent(), global_position, _rng.randf_range(0.35, 0.55))
		if hp <= 0.0:
			_die()
			return
	_state_t += delta
	var want := 0.0
	if state == State.GRAZE and _sees_player():
		_threat = player.position
		_set_state(State.ALERT)
	match state:
		State.GRAZE when bleed:   # wounded: staggers on away from where it was hit, then beds down to die
			var away := global_position - _threat
			away.y = 0.0
			if away.length() < 0.1: away = Vector3(1, 0, 0)
			_target = global_position + away.normalized() * 20.0
			want = 2.2 if hp > BED_HP else 0.0
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
		var road_q:=RoadNet.resolve_actor(np,pos,.4)
		np.x=road_q.x;np.z=road_q.y
		pos = np
	var h: float = RoadNet.lift(IceField.lift(terrain.data.get_height(Vector3(pos.x, 0.0, pos.z)), pos.x, pos.z),pos.x,pos.z,pos.y)
	if not is_nan(h):
		pos.y = lerpf(pos.y, h, minf(1.0, delta * 14.0))
	global_position = pos


func _animate(delta: float) -> void:
	_phase += delta * speed_now * 2.6
	var amp := clampf(speed_now / FLEE_SPEED, 0.0, 1.0) * 0.55 + (0.18 if speed_now > 0.1 else 0.0)   # X2: knees fold too
	var s := sin(_phase) * amp
	if _legs.get("fl") != null:
		(_legs["fl"] as Node3D).rotation.x = s
		(_legs["br"] as Node3D).rotation.x = s
		(_legs["fr"] as Node3D).rotation.x = -s
		(_legs["bl"] as Node3D).rotation.x = -s
	for n: String in ["fl", "fr", "bl", "br"]:   # X2: knees fold on the forward swing (the high-stepping deer gait)
		var lo := _lows.get(n) as Node3D
		if lo == null: continue
		var p := _phase if (n == "fl" or n == "br") else _phase + PI
		var swing := maxf(0.0, cos(p)) * amp
		lo.rotation.x = -1.3 * swing if n[0] == "f" else 0.6 * swing
	if _tail != null:
		_tail.rotation.x = -0.3 + (0.6 if state == State.FLEE else 0.0)


func is_dead() -> bool:
	return state == State.DEAD
