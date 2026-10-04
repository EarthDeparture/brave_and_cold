class_name Player
extends Node3D
## First-person custom terrain-following controller with bounded vertical jumping.
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
const JUMP_SPEED := 4.6
const JUMP_GRAVITY := 16.0
const JUMP_COST := 8.0
const HEAD_CLEARANCE := 0.12
const ACCEL := 16.0          # m/s^2 ramp up/down: no hard start/stop
const DECEL := 22.0
const SLOPE_PROBE := 0.6
const WALK_STEP_TOLERANCE := 0.30
const CONTACT_TOLERANCE := 0.0005
var head_bob_strength := 0.0

var terrain: Terrain3D
var snow: SnowField
var body: BodyTemperature
var noise: NoiseBus
var cam: Camera3D
var forest: ForestScatter
var cabins: Array = []
var spatial_structures: Array[Node3D] = [] # Optional height-aware surfaces, separate from ground cabins.
var walk_ribbons: Array[Node3D] = []
var _camera_ground := NAN
var _ground_velocity := 0.0
var _ground_acceleration := 0.0
var _ground_offset := 0.0
var chests: Array = []   # StorageChest colliders
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
var _breath := 4.0      # seconds of held breath left (Shift while aimed steadies the rifle)
var breath_held := false
var _winded := false
const AIM_FOV := 36.0
const AIM_FOVS := [36.0, 22.0, 13.0]   # wheel while aimed: iron sights -> 2x -> 3x style zoom
var zoom_i := 0
var _aim_fov := 36.0
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
var airborne := false
var _vertical_speed := 0.0
var _air_support_y := 0.0
var _jump_cooldown := 0.0
var _landing_dip := 0.0


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
	reset_jump()
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
	for structure in spatial_structures:
		var f: float = structure.call("floor_at_world", Vector3(x, _surface_probe_y(), z), th)
		if not is_nan(f):
			return f
	for ribbon in walk_ribbons:
		var f:float=ribbon.call("floor_at_world",Vector3(x,_surface_probe_y(),z),th)
		if not is_nan(f) and (is_nan(th) or f>th):th=f
	return th


func is_sheltered() -> bool:
	for structure in spatial_structures:
		if bool(structure.call("is_sheltered_at", position)):
			return true
	for cb in cabins:
		if cb.contains_xz(position.x, position.z):
			return true
	return snow.canopy_height_at(position.x, position.z) >= 10.0


func _on_spatial_surface() -> bool:
	for structure in spatial_structures:
		var floor_y: float = structure.call("floor_at_world", Vector3(position.x, _surface_probe_y(), position.z), NAN)
		if not is_nan(floor_y):
			return true
	return false


func _step_snow_tier() -> int:
	# The new deck/stair floor is not the deep snow at the same X/Z below it.
	return 0 if _on_spatial_surface() else snow.tier_at(position.x, position.z)


func noise_radius() -> float:
	if not moving:
		return 0.0
	var r := NoiseBus.RADIUS_WALK
	if sprinting:
		r = NoiseBus.RADIUS_RUN
	elif crouching:
		r = NoiseBus.RADIUS_CROUCH
	var tier: int = _step_snow_tier()
	return r * (1.0 - 0.06 * tier)  # deep snow muffles steps


func zoom_step(s: int) -> void:
	zoom_i = clampi(zoom_i + s, 0, AIM_FOVS.size() - 1)


func _update_aim(delta: float) -> void:
	var want := aim_req and not dead and not sleeping and not struggling and not sprinting and not airborne
	aim_k = move_toward(aim_k, 1.0 if want else 0.0, delta * 5.0)
	_aim_fov = move_toward(_aim_fov, float(AIM_FOVS[zoom_i]), delta * 90.0)
	cam.fov = lerpf(HIP_FOV, _aim_fov, aim_k * aim_k * (3.0 - 2.0 * aim_k))
	_sway_t += delta
	var shift := Input.is_key_pressed(KEY_SHIFT)
	if not shift:
		_winded = false
	breath_held = aim_k > 0.8 and shift and not _winded and not dead
	_breath = clampf(_breath + (-delta if breath_held else delta * 0.6), 0.0, 4.0)
	if _breath <= 0.0:
		_winded = true  # out of air: release Shift to recover
		breath_held = false
	var amp := aim_k * (0.0016 if crouching else 0.0032) * (1.0 + (0.8 if sprinting else 0.0)) * (0.12 if breath_held else 1.0)
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
	reset_jump()
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
	# Bound each collision/slope query to a small displacement even on slow frames.
	# A frame hitch must not jump past a doorway, trunk or narrow stair landing.
	if delta > 1.0 / 60.0 + 0.00001:
		var count := mini(8, ceili(delta * 60.0))
		for i in count:
			_move(minf(delta, 8.0 / 60.0) / float(count))
		return
	if is_nan(_camera_ground):_camera_ground=position.y-eye_h
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
	var tier: int = _step_snow_tier()
	_snow_mult = lerpf(_snow_mult, SnowField.PLAYER_SPEED[tier], minf(1.0, delta * 2.5))
	var want := Vector2.ZERO
	if wish:
		want = Vector2(dir.x, dir.z).normalized() * base * _snow_mult * speed_mult * lerpf(1.0, 0.55, aim_k)
	var rate := ACCEL if want.length_squared() > _vel.length_squared() else DECEL
	if airborne:
		rate *= 0.35
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
			_vel=step/delta
			var prior_foot := Vector3(position.x, _surface_probe_y(), position.z)
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
			for ch in chests:
				var q3: Vector2 = ch.resolve_at(Vector3(position.x,_surface_probe_y(),position.z),eye_h,0.35)
				position.x = q3.x
				position.z = q3.y
			for structure in spatial_structures:
				var q4: Vector2 = structure.call("resolve_at", Vector3(position.x, _surface_probe_y(), position.z), prior_foot, 0.35)
				position.x = q4.x
				position.z = q4.y
			for ribbon in walk_ribbons:
				if ribbon.has_method("resolve_at"):
					var q5:Vector2=ribbon.call("resolve_at",Vector3(position.x,_surface_probe_y(),position.z),prior_foot,.35)
					position.x=q5.x;position.z=q5.y
			# A jump cannot enter a doorway/roof whose underside is below the head.
			if airborne and position.y + HEAD_CLEARANCE > _jump_ceiling() + 0.002:
				position.x = prior_foot.x
				position.z = prior_foot.z
			var push := Vector2(position.x - ax, position.z - az)
			if push.length_squared() < CONTACT_TOLERANCE*CONTACT_TOLERANCE:
				# Local/world round trips can differ by a few float ULPs at
				# distant coordinates. They are not a physical collision.
				position.x=ax;position.z=az
			elif push.length_squared() > 0.0:
				# slide: drop the velocity component pointing into whatever pushed us out
				var pn := push.normalized()
				_vel -= pn * minf(0.0, _vel.dot(pn))
	sp=_vel.length()
	speed_now=sp
	moving=sp>.3
	sprinting=want_sprint and wish and sp>1.0
	activity = 0
	if moving:
		activity = 2 if sprinting else 1
	var target_eye := EYE_CROUCH if crouching else EYE
	var old_feet := position.y - eye_h
	eye_h = lerpf(eye_h, target_eye, minf(1.0, delta * 8.0))
	if airborne:
		position.y = old_feet + eye_h
	var g: float = ground_at(position.x, position.z)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if airborne:
		_ground_offset*=exp(-delta*10.0)
		_jump_vertical(delta, g)
	elif not is_nan(g):
		# Feet remain on the floor; only the camera absorbs ground corrugation.
		position.y = g + eye_h
		_smooth_ground(delta,_eye_ground(position.x,position.z),g)
	_head_bob(delta, 0.0 if airborne else sp)


## Preserve the requested heading. Small seams are steps, not steering obstacles.
func _slope_step(step: Vector2) -> Vector2:
	if step.length_squared()<1e-12:return step
	# A distant probe can extend past a stair landing into empty space. Judge
	# authored treads at the actual next foot position so turns stay traversable.
	var foot:=Vector3(position.x,_surface_probe_y(),position.z)
	for structure in spatial_structures:
		var current:float=structure.call("floor_at_world",foot,NAN)
		var next:float=structure.call("floor_at_world",foot+Vector3(step.x,0,step.y),NAN)
		if not is_nan(current) and not is_nan(next) and absf(next-current)<=WALK_STEP_TOLERANCE:return step
	var d:=step.normalized()
	var h0:float=_eye_ground(position.x,position.z)
	var h1:float=_eye_ground(position.x+d.x*SLOPE_PROBE,position.z+d.y*SLOPE_PROBE)
	if is_nan(h0) or is_nan(h1):return step
	var allowed:=MAX_SLOPE*SLOPE_PROBE+WALK_STEP_TOLERANCE
	var brake:=smoothstep(allowed,allowed+.40,absf(h1-h0))
	return step*(1.0-brake)


## Camera ground height: structures exact, open terrain low-passed over ~1.5 m so lidar-scale bumps don't shake the view.
func _eye_ground(x: float, z: float) -> float:
	var th: float = _terrain_h(x, z)
	for cb in cabins:
		var f: float = cb.floor_at(x, z, th)
		if not is_nan(f):
			return f
	for structure in spatial_structures:
		var f: float = structure.call("floor_at_world", Vector3(x, _surface_probe_y(), z), th)
		if not is_nan(f):
			return f
	if is_nan(th):return th
	# Apply one footprint filter to terrain, snow/ice and road/trail triangles.
	# Changing the surface under a sample must not switch the camera algorithm.
	var sum:=0.0;var total:=0.0
	for dx in [-1,0,1]:
		for dz in [-1,0,1]:
			var weight:=float((2 if dx==0 else 1)*(2 if dz==0 else 1))
			var xx:float=x+float(dx)*.50;var zz:float=z+float(dz)*.50
			var h:=_terrain_h(xx,zz)
			for ribbon in walk_ribbons:
				var f:float=ribbon.call("floor_at_world",Vector3(xx,_surface_probe_y(),zz),h)
				if not is_nan(f) and (is_nan(h) or f>h):h=f
			if not is_nan(h):sum+=h*weight;total+=weight
	return th if total==0 else sum/total



func _smooth_ground(delta:float, height:float, support:float) -> void:
	if is_nan(height):height=support
	if is_nan(_camera_ground):
		_camera_ground=support;_ground_velocity=0.0;_ground_acceleration=0.0
	# A height seam changes the target, never the view in one frame. Bound both
	# vertical acceleration and its rate of change, including material borders.
	var acceleration:=clampf((height-_camera_ground)*100.0-_ground_velocity*20.0,-6.0,6.0)
	_ground_acceleration=move_toward(_ground_acceleration,acceleration,delta*40.0)
	_camera_ground+=_ground_velocity*delta+.5*_ground_acceleration*delta*delta
	_ground_velocity+=_ground_acceleration*delta
	_ground_offset=_camera_ground-support


func _head_bob(delta: float, sp: float) -> void:
	var amp := 0.0
	if sp > 0.3 and not sim_on:
		amp = head_bob_strength * clampf(sp / WALK, 0.0, 1.7) * (0.55 if crouching else 1.0)
	_bob_amp = lerpf(_bob_amp, amp, minf(1.0, delta * 6.0))
	_bob_t += delta * sp * 1.9
	_landing_dip = move_toward(_landing_dip, 0.0, delta * 0.26)
	cam.position = Vector3(0.0, (cos(_bob_t*2.0)-1.0)*0.004*_bob_amp - _landing_dip + _ground_offset, 0.0)

func _stamina(delta: float) -> void:
	var tier: int = _step_snow_tier()
	if sprinting:
		stamina -= STAMINA_DRAIN * SnowField.PLAYER_STAMINA_COST[tier] * delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
	elif not airborne:
		var regen := STAMINA_REGEN * body.stamina_penalty()
		if moving:
			regen *= 0.5
		stamina = minf(100.0, stamina + regen * delta)
		if exhausted and stamina > 25.0:
			exhausted = false


func _footsteps(delta: float) -> void:
	if airborne:
		_last_pos = position
		return
	if not moving:
		return
	_since_trample += position.distance_to(_last_pos)
	_last_pos = position
	if _since_trample >= TRAMPLE_STEP:
		_since_trample = 0.0
		var on_structure := _on_spatial_surface()
		if not on_structure:
			snow.trample(position.x, position.z, 0.5)
		stepped.emit(_step_snow_tier(), noise_radius())
		if footprints != null and not on_structure:
			var gy: float = ground_at(position.x, position.z)
			if not is_nan(gy):
				footprints.step(position.x, gy, position.z, yaw, snow.tier_at(position.x, position.z))
	_since_noise += delta
	if _since_noise >= NOISE_INTERVAL:
		_since_noise = 0.0
		noise.emit_noise(position, noise_radius(), self)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var ss: float = Settings.sensitivity * lerpf(1.0, 0.45 * _aim_fov / AIM_FOV, aim_k)
		yaw -= e.relative.x * ss
		pitch = clampf(pitch - e.relative.y * ss, -1.5, 1.5)
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("jump") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			request_jump()
		match e.keycode:
			KEY_G:
				fire_w = 0.0 if fire_w > 0.0 else 350.0


func _surface_probe_y() -> float:
	# Probe the supporting stair/deck level, never the elevated feet at the apex.
	return _air_support_y if airborne else position.y - eye_h


func reset_jump() -> void:
	airborne = false
	_camera_ground=NAN
	_ground_velocity=0.0;_ground_acceleration=0.0
	_ground_offset=0.0
	_vertical_speed = 0.0
	_jump_cooldown = 0.0
	_landing_dip = 0.0
	_since_trample = 0.0
	_last_pos = position


func request_jump() -> bool:
	if not _ready_ground or airborne or _jump_cooldown > 0.0 or stamina < JUMP_COST or exhausted:
		return false
	if dead or sleeping or struggling or ui_open or frozen or noclip or crouching or Input.is_key_pressed(KEY_C):
		return false
	var floor_y := ground_at(position.x, position.z)
	if is_nan(floor_y) or absf(position.y - eye_h - floor_y) > 0.25:
		return false
	if _jump_ceiling() < position.y + HEAD_CLEARANCE + 0.06:
		return false
	_air_support_y = floor_y
	position.y = floor_y + eye_h
	_vertical_speed = JUMP_SPEED * clampf(speed_mult, 0.65, 1.0)
	stamina -= JUMP_COST
	airborne = true
	_since_trample = 0.0
	_last_pos = position
	return true


func _jump_ceiling() -> float:
	var ceiling := INF
	for cabin in cabins:
		if cabin.has_method("ceiling_at_world"):
			ceiling = minf(ceiling, float(cabin.call("ceiling_at_world", position)))
	for structure in spatial_structures:
		if structure.has_method("ceiling_at_world"):
			ceiling = minf(ceiling, float(structure.call("ceiling_at_world", position)))
	return ceiling


func _jump_vertical(delta: float, floor_y: float) -> void:
	var feet := position.y - eye_h
	var next_feet := feet + _vertical_speed * delta - 0.5 * JUMP_GRAVITY * delta * delta
	_vertical_speed -= JUMP_GRAVITY * delta
	var ceiling := _jump_ceiling() - eye_h - HEAD_CLEARANCE
	if next_feet > ceiling and _vertical_speed > 0.0:
		next_feet = maxf(feet, ceiling)
		_vertical_speed = 0.0
	if not is_nan(floor_y):
		_air_support_y = floor_y
		if next_feet <= floor_y and (_vertical_speed <= 0.0 or floor_y > feet + 0.015):
			position.y = floor_y + eye_h
			airborne = false
			_camera_ground=floor_y+_ground_offset
			_ground_velocity=0.0;_ground_acceleration=0.0
			_vertical_speed = 0.0
			_jump_cooldown = 0.15
			_landing_dip = 0.025
			_last_pos = position
			_since_trample = 0.0
			var radius := maxf(noise_radius(), NoiseBus.RADIUS_WALK) * 1.1
			stepped.emit(_step_snow_tier(), radius)
			noise.emit_noise(position, radius, self)
			if not _on_spatial_surface():
				snow.trample(position.x, position.z, 0.5)
				if footprints != null:
					footprints.step(position.x, ground_at(position.x, position.z), position.z, yaw, _step_snow_tier())
			return
	position.y = next_feet + eye_h
