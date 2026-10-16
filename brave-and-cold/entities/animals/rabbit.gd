class_name Rabbit
extends Node3D
## Snowshoe hare (TLD rabbit): hops around its warren, freezes then bolts when the player
## gets close or a noise reaches it, and is quiet food for a rifle or a snare. A killed
## hare drops a whole "rabbit" pickup (skin it with a knife). Model: gen_rabbit.py.
enum State { NIBBLE, HOP, FLEE, DEAD }
signal died
const MODEL := "res://assets/smallgame/rabbit.glb"
const HOP_SPEED := 1.4
const FLEE_SPEED := 7.5
const SPOOK_RANGE := 11.0
var terrain: Terrain3D
var snow: SnowField
var player: Player
var forest: ForestScatter
var home := Vector3.ZERO
var state: State = State.NIBBLE
var hp := 8.0
var speed_now := 0.0
var _target := Vector3.ZERO
var _t := 0.0
var _hop := 0.0
var _model: Node3D
var _ears: Node3D
var _hind: Node3D
var _rng := RandomNumberGenerator.new()

func setup(t: Terrain3D, s: SnowField, p: Player, f: ForestScatter, bus: NoiseBus, warren: Vector3, seed_value: int) -> void:
	terrain = t; snow = s; player = p; forest = f; home = warren; _rng.seed = seed_value
	if bus != null: bus.noise.connect(_on_noise)
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D; add_child(_model)
	_model.rotation.y = PI   # the glb faces +Z; creatures face -Z
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 1.0
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat; mi.visibility_range_end = 120.0
	_ears = _model.find_child("rabbit_ears", true, false) as Node3D
	_hind = _model.find_child("rabbit_hind", true, false) as Node3D
	add_to_group("prey")
	_pick()

func _pick() -> void:
	var a := _rng.randf() * TAU; var r := _rng.randf_range(1.0, 7.0)
	_target = home + Vector3(cos(a) * r, 0.0, sin(a) * r)

func _on_noise(pos: Vector3, radius: float, source: Object) -> void:
	if state == State.DEAD or source == self: return
	if global_position.distance_to(pos) <= radius * 1.2: _bolt(pos)

func _bolt(from: Vector3) -> void:
	var away := global_position - from; away.y = 0.0
	if away.length() < 0.01: away = Vector3(1, 0, 0)
	_target = global_position + away.normalized() * 30.0 + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
	state = State.FLEE; _t = 0.0

func hit(dmg: float, from: Vector3) -> void:
	if state == State.DEAD: return
	hp -= dmg
	if hp <= 0.0: _die()
	else: _bolt(from)

func _die() -> void:
	state = State.DEAD; died.emit(); remove_from_group("prey")
	Carcass.blood(get_parent(), global_position, 0.35)
	ItemPickup.spawn(get_parent(), "rabbit", 1, global_position + Vector3(0, 0.05, 0))
	queue_free()

func is_dead() -> bool: return state == State.DEAD

func _process(delta: float) -> void:
	if terrain == null or terrain.data == null or player == null or state == State.DEAD: return
	var to_p := player.position - global_position; to_p.y = 0.0
	if to_p.length() > 220.0: return   # nobody to see it: skip the hop logic
	_t += delta
	var spook := SPOOK_RANGE * (0.45 if player.crouching else 1.0) * (1.6 if player.activity >= 2 else 1.0)
	if state != State.FLEE and to_p.length() < spook: _bolt(player.position)
	var want := 0.0
	match state:
		State.NIBBLE:
			if _t > _rng.randf_range(2.0, 6.0): state = State.HOP; _t = 0.0; _pick()
		State.HOP:
			want = HOP_SPEED
			if Vector2(_target.x - global_position.x, _target.z - global_position.z).length() < 0.4 or _t > 6.0:
				state = State.NIBBLE; _t = 0.0
		State.FLEE:
			want = FLEE_SPEED
			if _t > 5.0 and to_p.length() > 25.0:
				home = global_position.lerp(home, 0.5); state = State.HOP; _t = 0.0; _pick()
	_move(want, delta)
	_animate(delta)

func _move(want: float, delta: float) -> void:
	var pos := global_position
	speed_now = lerpf(speed_now, want, minf(1.0, delta * 8.0))
	if speed_now > 0.05:
		var d := _target - pos
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 10.0))
		var np := pos + Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)) * speed_now * delta
		if forest != null:
			var q := forest.resolve_trunks(np.x, np.z, 0.2); np.x = q.x; np.z = q.y
		np.x = clampf(np.x, -980.0, 980.0); np.z = clampf(np.z, -980.0, 980.0)
		pos = np
	var h: float = terrain.data.get_height(Vector3(pos.x, 0.0, pos.z))
	if not is_nan(h):
		pos.y = h + (absf(sin(_hop)) * (0.10 if state == State.HOP else 0.22) if speed_now > 0.3 else 0.0)
	global_position = pos

func _animate(delta: float) -> void:
	_hop += delta * (9.0 if state == State.HOP else (15.0 if state == State.FLEE else 0.0))
	var s := sin(_hop)
	if _hind != null: _hind.rotation.x = -0.6 * maxf(0.0, s) if speed_now > 0.3 else 0.0
	if _ears != null:
		_ears.rotation.x = (0.7 if state == State.FLEE else 0.0) + (0.12 * sin(_t * 3.0) if state == State.NIBBLE else 0.0)
	if _model != null and state == State.NIBBLE:
		_model.rotation.x = 0.12 + 0.05 * sin(_t * 6.0)   # head down, nibbling
	elif _model != null:
		_model.rotation.x = 0.0
