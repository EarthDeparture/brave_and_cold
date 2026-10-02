class_name Player
extends Node3D
## First-person player (temporary terrain-snap movement until physics/collision land).
## Reads snow depth for speed/stamina, tramples snow, emits footstep noise, exposes activity/shelter for BodyTemperature.

const WALK := 3.2
const SPRINT := 5.8
const CROUCH := 1.6
const EYE := 1.7
const EYE_CROUCH := 1.05
const MAX_SLOPE := 1.0
const STAMINA_DRAIN := 12.0
const STAMINA_REGEN := 8.0
const TRAMPLE_STEP := 0.6
const NOISE_INTERVAL := 0.5
const ACCEL := 16.0          # m/s^2 ramp up/down: no hard start/stop
const DECEL := 22.0
const SLOPE_PROBE := 0.6
const SLIDE_ANGLES: Array[float] = [0.0, 0.6, -0.6, 1.1, -1.1]
const BLUR_OFFSETS: Array[Vector2] = [Vector2(0.7, 0.0), Vector2(-0.7, 0.0), Vector2(0.0, 0.7), Vector2(0.0, -0.7)]

var terrain: Terrain3D
var snow: SnowField
var body: BodyTemperature
var noise: NoiseBus
var cam: Camera3D
var forest: ForestScatter
var cabins: Array = []
var footprints: Footprints
var ice: IceField   # frozen water is walkable: the surface, not the carved bed under it

var yaw := 0.0
var pitch := 0.0
var stamina := 100.0
var exhausted := false
var crouching := false
var sprinting := false
var aim_req := false  # set by GameWorld: RMB held with rifle raised
var aim_k := 0.0  # 0 hip .. 1 fully aimed
var _sway_t := 0.0
const AIM_FOV := 36.0
const HIP_FOV := 70.0
var moving := false
var activity := 0
var speed_now := 0.0
var fire_w := 0.0  # debug fire heat
var eye_h := EYE
var _since_trample := 0.0
var _since_noise := 0.0
var _last_pos := Vector3.ZERO
var _ready_ground := false
var frozen := false  # set by GameWorld for screenshots
signal stepped(tier: int, radius: float)
var health := 100.0
var dead := false
var death_cause := ""
var struggling := false
var speed_mult := 1.0  # encumbrance, set by GameWorld from Inventory.speed_mult()
var god := false
var noclip := false
var noclip_speed := 14.0
var ui_open := false  # gear screen etc: no movement, world keeps running
var struggle_by: Node = null
var struggle_prog := 0.0
var struggle_gain := 0.12
var struggle_t := 0.0
var sim_on := false          # tests: drive movement without key events
var sim_dir := Vector3.ZERO
var sim_sprint := false
var dbg_blocks := 0
var sleeping := false       # lying in a bed: no movement, world keeps running
var hits_taken := 0         # damage events >= 1 HP (wakes sleepers)
var _vel := Vector2.ZERO
var _snow_mult := 1.0
var _bob_t := 0.0
var _bob_amp := 0.0


func start_struggle(attacker: Node, gain: float) -> void:
	struggling = true
	struggle_by = attacker
	struggle_gain = gain
	struggle_prog = 0.15
	struggle_t = 0.0


func struggle_press() -> void:
	if struggling:
		struggle_prog = minf(1.0, struggle_prog + struggle_gain)
		if struggle_prog >= 1.0:
			struggling = false
			if is_instance_valid(struggle_by):
				struggle_by.call("repel")


func _struggle_update(delta: float) -> void:
	struggle_t += delta
	struggle_prog = maxf(0.0, struggle_prog - 0.25 * delta)
	if dead or not is_instance_valid(struggle_by) or bool(struggle_by.call("is_dead")):
		struggling = false
	elif struggle_prog >= 1.0:
		struggling = false
		struggle_by.call("repel")
	elif struggle_t > 6.0:
		struggling = false
		struggle_by.call("struggle_failed")


var injury := Injury.new()


func setup(t: Terrain3D, s: SnowField, b: BodyTemperature, n: NoiseBus) -> void:
	injury.player = self
	Inventory.injury = injury
	terrain = t
	snow = s
	body = b
	noise = n
	cam = Camera3D.new()
	cam.far = 6000.0
	cam.fov = 70.0
	cam.near = 0.05
	add_child(cam)
	cam.make_current()
	terrain.set_camera(cam)


func hurt(amount: float, cause: String = "Killed") -> void:
	if amount >= 1.0:
		hits_taken += 1
	if dead or god:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		dead = true
		death_cause = cause
		frozen = true


func place(x: float, z: float) -> void:
	position = Vector3(x, 400.0, z)
	_ready_ground = false
	_last_pos = position


func _terrain_h(x: float, z: float) -> float:
	var th: float = terrain.data.get_height(Vector3(x, 0.0, z))
	if ice != null:
		var iy := ice.ice_at(x, z)
		if not is_nan(iy) and (is_nan(th) or iy > th):
			return iy
	return th


func ground_at(x: float, z: float) -> float:
	var th: float = _terrain_h(x, z)
	for cb in cabins:
		var f: float = cb.floor_at(x, z, th)
		if not is_nan(f):
			return f
	return th


func is_sheltered() -> bool:
	for cb in cabins:
		if cb.contains_xz(position.x, position.z):
			return true
	return snow.canopy_height_at(position.x, position.z) >= 10.0


func noise_radius() -> float:
	if not moving:
		return 0.0
	var r := NoiseBus.RADIUS_WALK
	if sprinting:
		r = NoiseBus.RADIUS_RUN
	elif crouching:
		r = NoiseBus.RADIUS_CROUCH
	var tier: int = snow.tier_at(position.x, position.z)
	return r * (1.0 - 0.06 * tier)  # deep snow muffles steps


func _update_aim(delta: float) -> void:
	var want := aim_req and not dead and not sleeping and not struggling and not sprinting
	aim_k = move_toward(aim_k, 1.0 if want else 0.0, delta * 5.0)
	cam.fov = lerpf(HIP_FOV, AIM_FOV, aim_k * aim_k * (3.0 - 2.0 * aim_k))
	_sway_t += delta
	var amp := aim_k * (0.0016 if crouching else 0.0032) * (1.0 + (0.8 if sprinting else 0.0))
	var sw := Vector2(sin(_sway_t * 1.1) + 0.5 * sin(_sway_t * 2.3), cos(_sway_t * 0.9) + 0.5 * sin(_sway_t * 1.9 + 1.0)) * amp
	cam.rotation = Vector3(pitch + sw.y, yaw + sw.x, 0.0)


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null:
		return
	if not _ready_ground:
		var h0: float = ground_at(position.x, position.z)
		if is_nan(h0):
			return
		position.y = h0 + eye_h
		_ready_ground = true
	_update_aim(delta)
	if struggling:
		_struggle_update(delta)
	if noclip and not dead:
		_fly(delta)
		return
	if frozen or struggling or ui_open or sleeping:
		return
	_move(delta)
	_stamina(delta)
	_footsteps(delta)


## Dev noclip: free flight along the camera direction, ignores terrain, cabins and trees.
func _fly(delta: float) -> void:
	var b := cam.global_transform.basis
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= b.z
	if Input.is_key_pressed(KEY_S): dir += b.z
	if Input.is_key_pressed(KEY_D): dir += b.x
	if Input.is_key_pressed(KEY_A): dir -= b.x
	if Input.is_key_pressed(KEY_SPACE): dir += Vector3.UP
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL): dir -= Vector3.UP
	var sp := noclip_speed * (4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	moving = false
	sprinting = false
	speed_now = 0.0
	activity = 0
	if dir.length() > 0.01:
		position += dir.normalized() * sp * delta
	_ready_ground = true

func _move(delta: float) -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir += fwd
	if Input.is_key_pressed(KEY_S): dir -= fwd
	if Input.is_key_pressed(KEY_D): dir += right
	if Input.is_key_pressed(KEY_A): dir -= right
	if sim_on:
		dir = sim_dir
	crouching = Input.is_key_pressed(KEY_C)
	var wish := dir.length() > 0.01
	var want_sprint := (Input.is_key_pressed(KEY_SHIFT) or (sim_on and sim_sprint)) and not crouching and not exhausted and stamina > 0.0 and aim_k < 0.3
	var base := CROUCH if crouching else (SPRINT if (want_sprint and wish) else WALK)
	# deep snow: a slight, smoothly blended slowdown (no hard steps when the tier flips under the boots)
	var tier: int = snow.tier_at(position.x, position.z)
	_snow_mult = lerpf(_snow_mult, SnowField.PLAYER_SPEED[tier], minf(1.0, delta * 2.5))
	var want := Vector2.ZERO
	if wish:
		want = Vector2(dir.x, dir.z).normalized() * base * _snow_mult * speed_mult * lerpf(1.0, 0.55, aim_k)
	var rate := ACCEL if want.length_squared() > _vel.length_squared() else DECEL
	_vel = _vel.move_toward(want, rate * delta)
	var sp := _vel.length()
	moving = sp > 0.3
	sprinting = want_sprint and wish and sp > 1.0
	speed_now = sp
	if sp > 0.001:
		var step := _slope_step(_vel * delta)
		if step.length_squared() < 1e-10:
			dbg_blocks += 1
			_vel = Vector2.ZERO
			speed_now = 0.0
			moving = false
			sprinting = false
		else:
			position.x += step.x
			position.z += step.y
			var ax := position.x
			var az := position.z
			if forest != null:
				var q := forest.resolve_trunks(position.x, position.z, 0.35)
				position.x = q.x
				position.z = q.y
			for cb in cabins:
				var q2: Vector2 = cb.resolve(position.x, position.z, 0.35)
				position.x = q2.x
				position.z = q2.y
			var push := Vector2(position.x - ax, position.z - az)
			if push.length_squared() > 1e-8:
				# slide: drop the velocity component pointing into whatever pushed us out
				var pn := push.normalized()
				_vel -= pn * minf(0.0, _vel.dot(pn))
	activity = 0
	if moving:
		activity = 2 if sprinting else 1
	var target_eye := EYE_CROUCH if crouching else EYE
	eye_h = lerpf(eye_h, target_eye, minf(1.0, delta * 8.0))
	var g: float = _eye_ground(position.x, position.z)
	if not is_nan(g):
		position.y = lerpf(position.y, g + eye_h, minf(1.0, delta * 12.0))
	_head_bob(delta, sp)


## Ground-slope gate over a 0.6 m lookahead (a 2-5 cm per-frame step made lidar noise look like a wall). Too steep: slide along the contour.
func _slope_step(step: Vector2) -> Vector2:
	var len := step.length()
	if len < 1e-6:
		return step
	var d := step / len
	var h0: float = ground_at(position.x, position.z)
	if is_nan(h0):
		return step
	for a in SLIDE_ANGLES:
		var dd := d.rotated(a)
		var h1: float = ground_at(position.x + dd.x * SLOPE_PROBE, position.z + dd.y * SLOPE_PROBE)
		if is_nan(h1) or (h1 - h0) / SLOPE_PROBE <= MAX_SLOPE:
			return dd * len * (1.0 if a == 0.0 else cos(a) * 0.9)
	return Vector2.ZERO


## Camera ground height: structures exact, open terrain low-passed over ~1.5 m so lidar-scale bumps don't shake the view.
func _eye_ground(x: float, z: float) -> float:
	var th: float = _terrain_h(x, z)
	for cb in cabins:
		var f: float = cb.floor_at(x, z, th)
		if not is_nan(f):
			return f
	if is_nan(th):
		return th
	var s := th
	var n := 1
	for o in BLUR_OFFSETS:
		var h: float = _terrain_h(x + o.x, z + o.y)
		if not is_nan(h):
			s += h
			n += 1
	return s / float(n)


func _head_bob(delta: float, sp: float) -> void:
	var amp := 0.0
	if sp > 0.3 and not sim_on:
		amp = clampf(sp / WALK, 0.0, 1.7) * (0.55 if crouching else 1.0)
	_bob_amp = lerpf(_bob_amp, amp, minf(1.0, delta * 6.0))
	_bob_t += delta * sp * 1.9
	cam.position = Vector3(sin(_bob_t) * 0.011 * _bob_amp, absf(sin(_bob_t)) * -0.016 * _bob_amp, 0.0)

func _stamina(delta: float) -> void:
	var tier: int = snow.tier_at(position.x, position.z)
	if sprinting:
		stamina -= STAMINA_DRAIN * SnowField.PLAYER_STAMINA_COST[tier] * delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
	else:
		var regen := STAMINA_REGEN * body.stamina_penalty()
		if moving:
			regen *= 0.5
		stamina = minf(100.0, stamina + regen * delta)
		if exhausted and stamina > 25.0:
			exhausted = false


func _footsteps(delta: float) -> void:
	if not moving:
		return
	_since_trample += position.distance_to(_last_pos)
	_last_pos = position
	if _since_trample >= TRAMPLE_STEP:
		_since_trample = 0.0
		snow.trample(position.x, position.z, 0.5)
		stepped.emit(snow.tier_at(position.x, position.z), noise_radius())
		if footprints != null:
			var gy: float = ground_at(position.x, position.z)
			if not is_nan(gy):
				footprints.step(position.x, gy, position.z, yaw, snow.tier_at(position.x, position.z))
	_since_noise += delta
	if _since_noise >= NOISE_INTERVAL:
		_since_noise = 0.0
		noise.emit_noise(position, noise_radius(), self)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var ss: float = Settings.sensitivity * lerpf(1.0, 0.45, aim_k)
		yaw -= e.relative.x * ss
		pitch = clampf(pitch - e.relative.y * ss, -1.5, 1.5)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_G:
				fire_w = 0.0 if fire_w > 0.0 else 350.0
