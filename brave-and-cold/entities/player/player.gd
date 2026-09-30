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

var terrain: Terrain3D
var snow: SnowField
var body: BodyTemperature
var noise: NoiseBus
var cam: Camera3D
var forest: ForestScatter
var footprints: Footprints

var yaw := 0.0
var pitch := 0.0
var stamina := 100.0
var exhausted := false
var crouching := false
var sprinting := false
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


func setup(t: Terrain3D, s: SnowField, b: BodyTemperature, n: NoiseBus) -> void:
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


func place(x: float, z: float) -> void:
	position = Vector3(x, 400.0, z)
	_ready_ground = false
	_last_pos = position


func ground_at(x: float, z: float) -> float:
	return terrain.data.get_height(Vector3(x, 0.0, z))


func is_sheltered() -> bool:
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


func _process(delta: float) -> void:
	if terrain == null or terrain.data == null:
		return
	if not _ready_ground:
		var h0: float = ground_at(position.x, position.z)
		if is_nan(h0):
			return
		position.y = h0 + eye_h
		_ready_ground = true
	cam.rotation = Vector3(pitch, yaw, 0.0)
	if frozen:
		return
	_move(delta)
	_stamina(delta)
	_footsteps(delta)


func _move(delta: float) -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir += fwd
	if Input.is_key_pressed(KEY_S): dir -= fwd
	if Input.is_key_pressed(KEY_D): dir += right
	if Input.is_key_pressed(KEY_A): dir -= right
	crouching = Input.is_key_pressed(KEY_C)
	var want_sprint := Input.is_key_pressed(KEY_SHIFT) and not crouching and not exhausted and stamina > 0.0
	moving = dir.length() > 0.01
	sprinting = want_sprint and moving
	var base := CROUCH if crouching else (SPRINT if sprinting else WALK)
	var tier: int = snow.tier_at(position.x, position.z)
	speed_now = base * SnowField.PLAYER_SPEED[tier] if moving else 0.0
	if moving:
		var step := dir.normalized() * speed_now * delta
		var np := position + step
		var h0: float = ground_at(position.x, position.z)
		var h1: float = ground_at(np.x, np.z)
		if not is_nan(h1) and not is_nan(h0) and (h1 - h0) / maxf(step.length(), 0.001) < MAX_SLOPE:
			position.x = np.x
			position.z = np.z
			if forest != null:
				var q := forest.resolve_trunks(position.x, position.z, 0.35)
				position.x = q.x
				position.z = q.y
		else:
			speed_now = 0.0
			moving = false
			sprinting = false
	activity = 0
	if moving:
		activity = 2 if sprinting else 1
	var target_eye := EYE_CROUCH if crouching else EYE
	eye_h = lerpf(eye_h, target_eye, minf(1.0, delta * 8.0))
	var g: float = ground_at(position.x, position.z)
	if not is_nan(g):
		position.y = lerpf(position.y, g + eye_h, minf(1.0, delta * 14.0))


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
		yaw -= e.relative.x * 0.002
		pitch = clampf(pitch - e.relative.y * 0.002, -1.5, 1.5)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_G:
				fire_w = 0.0 if fire_w > 0.0 else 350.0
			KEY_H:
				if body.warmth < 0.5:
					body.warmth = 0.85
					body.windproof = 0.8
					body.waterproof = 0.6
				else:
					body.warmth = 0.25
					body.windproof = 0.1
					body.waterproof = 0.1
			KEY_ESCAPE:
				get_tree().quit()
