class_name Viewmodel
extends Node3D
## First-person tools with an articulated Blender hand rig. Grip changes blend
## bone rotations on the same skin, keeping wrists attached through bolt operation.

const HANDS := "res://assets/models/viewmodel/survivor_hand_rig.glb"
const AXE := "res://assets/models/viewmodel/vm_axe.glb"
const RIFLE := "res://assets/models/viewmodel/vm_rifle.glb"
const SWING_LEN := 0.82
const FIRE_LEN := 1.05
const AXE_WRIST := Vector3(0.106, 0.006, -0.032)
const RIFLE_WRIST_R := Vector3(0.070, -0.005, 0.175)
const RIFLE_WRIST_L := Vector3(-0.059, -0.041, -0.266)
const BOLT_WRIST := Vector3(0.148, 0.004, 0.149)
const SLEEVE_LENGTH := 0.52
const SLEEVE_R := Vector3.BACK
const SLEEVE_L := Vector3.BACK
const FIST_ROLL := -12.0
const AIM_POS := Vector3(0.0, -0.098, -0.16)   # rear sight 0.35 m ahead of the eye, sight line on the view axis
const BOLT_ORIGIN := Vector3(0.0, 0.046, 0.06)

var detail_enabled := false
var player: Player
var mode := "fists"  # fists | axe | rifle
var glove_item := ""  # Existing inventory hands slot; bare when no mitts are worn.
var _right: SurvivorHandRig
var _left: SurvivorHandRig
var freeze_t := -1.0  # debug: hold animation at this time
var _axe: MeshInstance3D
var _rifle: MeshInstance3D
var _bolt: MeshInstance3D
var _sl_r: MeshInstance3D
var _sl_l: MeshInstance3D
var _cur := ""
var _equip := 0.0
var _swing_t := -1.0
var _swing_axe := true
var _swing_speed := 1.0
var _fire_t := -1.0
var _kick := 1.0
var _bob := 0.0
var _clock := 0.0
var _prev_yaw := 0.0
var _prev_pitch := 0.0
var _sway := Vector2.ZERO
var _sprint_k := 0.0
var _flash: OmniLight3D
var _push := 0.0
var _was_dead := false


func _ready() -> void:
	_right = SurvivorHandRig.new()
	_right.name = "RightHand"
	_right.detail_enabled = detail_enabled
	add_child(_right)
	_left = SurvivorHandRig.new()
	_left.name = "LeftHand"
	_left.detail_enabled = detail_enabled
	_left.mirrored = true
	add_child(_left)
	var sleeves := "res://assets/environment_detail/viewmodel/winter_sleeves.glb" if detail_enabled else HANDS
	_sl_r = _pick(sleeves, "vm_sleeve_r")
	_sl_l = _pick(sleeves, "vm_sleeve_l")
	_axe = _pick(AXE, "vm_axe")
	_rifle = _pick(RIFLE, "vm_rifle")
	_bolt = _pick(RIFLE, "vm_bolt")
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.72, 0.38)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.position = Vector3(0.0, 0.040, -0.76)
	_rifle.add_child(_flash)


func _pick(path: String, node_name: String) -> MeshInstance3D:
	var root := (load(path) as PackedScene).instantiate()
	var found := _take_part(root, node_name)
	root.free()
	return found


func _take_part(root: Node, node_name: String) -> MeshInstance3D:
	var found := root.find_child(node_name, true, false) as MeshInstance3D
	assert(found != null, "Missing viewmodel mesh: " + node_name)
	found.owner = null
	found.get_parent().remove_child(found)
	for i in found.mesh.get_surface_count():
		var m := found.mesh.surface_get_material(i) as StandardMaterial3D
		if m != null:
			m = m.duplicate() as StandardMaterial3D
			found.set_surface_override_material(i, m)
			m.vertex_color_use_as_albedo = true
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			# Weathered wood and subdued blued steel fit the pale winter palette.
			# Preserve existing item geometry and texture resources.
			if m.resource_name == "vm_beech":
				m.albedo_color = Color(0.68, 0.60, 0.52)
				m.roughness = 0.78
			elif m.resource_name in ["vm_blued", "vm_steel"]:
				m.albedo_color = Color(0.55, 0.58, 0.62)
				m.roughness = 0.65
			elif m.resource_name == "survivor_cloth":
				m.albedo_texture = load("res://assets/models/viewmodel/parka_fabric.png")
				m.uv1_triplanar = true
				m.uv1_scale = Vector3.ONE * 5.0
			if detail_enabled:
				if m.resource_name in ["vm_beech", "vm_ash", "vm_walnut"]:
					m.normal_enabled = true
					m.normal_texture = preload("res://assets/environment_detail/textures/timber_nrm.png")
					m.normal_scale = 0.35
					m.roughness_texture = m.normal_texture
					m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
				elif m.resource_name in ["vm_blued", "vm_steel"]:
					m.roughness = 0.48
					m.metallic = 0.65
				elif m.resource_name == "survivor_cloth":
					m.roughness = 0.96
					m.metallic_specular = 0.15
	found.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(found)
	return found


func swing(has_axe: bool, speed := 1.0) -> void:
	_swing_axe = has_axe
	_swing_speed = speed
	_swing_t = 0.0


func fire() -> void:
	_kick = 1.0
	_fire_t = 0.0


func dry() -> void:
	_kick = 0.25
	_fire_t = 0.0


static func _sstep(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Swing angles over time: x = hand pitch about the shoulder (deg), y = sweep (deg). Windup, hold, chop, recover.
func _swing_curve(t: float) -> Vector2:
	if t < 0.16:
		var k := _sstep(t / 0.16)
		return Vector2(34.0 * k, 10.0 * k)
	if t < 0.25:
		return Vector2(34.0 + 4.0 * _sstep((t - 0.16) / 0.09), 10.0)
	if t < 0.35:
		var k2 := (t - 0.25) / 0.10
		k2 *= k2
		return Vector2(lerpf(38.0, -14.0, k2), lerpf(10.0, -10.0, k2))
	if t < 0.45:
		return Vector2(lerpf(-14.0, -17.0, (t - 0.35) / 0.10), -10.0)
	var k3 := _sstep((t - 0.45) / (SWING_LEN - 0.45))
	return Vector2(lerpf(-17.0, 0.0, k3), lerpf(-10.0, 0.0, k3))


static func _about(pivot: Vector3, b: Basis) -> Transform3D:
	return Transform3D(b, pivot) * Transform3D(Basis.IDENTITY, -pivot)


func _process(delta: float) -> void:
	if player == null:
		return
	_clock += delta
	if player.dead:
		visible = false
		_was_dead = true
		return
	if _was_dead:  # revived: the old code never un-hid the hands/gun
		_was_dead = false
		visible = true
		_cur = ''
		_equip = 0.0
	_right.set_gloved(glove_item in ["hide_mitts", "wolf_mitts"])
	_left.set_gloved(glove_item in ["hide_mitts", "wolf_mitts"])
	# equip / mode switching: lower the old thing, raise the new
	if mode != _cur:
		_equip -= delta * 3.2
		if _equip <= 0.0:
			_equip = 0.0
			_cur = mode
			_swing_t = -1.0
			_fire_t = -1.0
	else:
		_equip = minf(1.0, _equip + delta * 2.6)
	if freeze_t >= 0.0:
		if _swing_t >= 0.0:
			_swing_t = freeze_t
		if _fire_t >= 0.0:
			_fire_t = freeze_t
	else:
		if _swing_t >= 0.0:
			_swing_t += delta * _swing_speed
			if _swing_t > SWING_LEN:
				_swing_t = -1.0
		if _fire_t >= 0.0:
			_fire_t += delta
			if _fire_t > FIRE_LEN:
				_fire_t = -1.0
	# bob / sway / sprint
	var spd := player.speed_now if player.moving else 0.0
	_bob += delta * (2.2 + spd * 1.5)
	var bk := clampf(spd / 3.0, 0.0, 1.6)
	var off := Vector3(sin(_bob) * 0.009 * bk, -absf(sin(_bob)) * 0.011 * bk, 0.0)
	off.y += sin(_clock * 1.7) * 0.0025
	off.x += sin(_clock * 0.9) * 0.0015
	var dyaw := wrapf(player.yaw - _prev_yaw, -PI, PI)
	var dpitch := player.pitch - _prev_pitch
	_prev_yaw = player.yaw
	_prev_pitch = player.pitch
	var want := Vector2(clampf(-dyaw * 0.9, -0.05, 0.05), clampf(-dpitch * 0.9, -0.04, 0.04))
	_sway = _sway.lerp(want, clampf(delta * 9.0, 0.0, 1.0))
	off += Vector3(_sway.x, _sway.y, 0.0)
	_sprint_k = move_toward(_sprint_k, 1.0 if player.sprinting else 0.0, delta * 4.0)
	# wall clip pullback: short ray along the view, ignore ground-ish normals
	var want_push := 0.0
	if freeze_t < 0.0:
		var from := global_position
		var to := from - global_basis.z * 1.1
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.6:
			want_push = clampf(1.1 - from.distance_to(hit["position"] as Vector3), 0.0, 0.55)
	_push = lerpf(_push, want_push, clampf(delta * 14.0, 0.0, 1.0))
	off += Vector3(0.0, -0.06 * _push, _push)
	_flash.light_energy = 0.0
	if _fire_t >= 0.0 and _fire_t < 0.09 and _kick > 0.5:
		_flash.light_energy = 7.0 * (1.0 - _fire_t / 0.09)
	var e := _sstep(_equip)
	off.y -= (1.0 - e) * 0.5
	off += Vector3(0.025, -0.045, 0.0) * _sprint_k
	var base := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0) * _sprint_k) * Basis(Vector3.UP, deg_to_rad(_sway.x * 60.0)), off)
	var shown := _cur if _equip > 0.0 else ""
	_axe.visible = shown == "axe"
	_rifle.visible = shown == "rifle"
	_bolt.visible = shown == "rifle"
	_right.visible = shown != ""
	_left.visible = shown in ["rifle", "fists"]
	_sl_r.visible = shown != ""
	_sl_l.visible = shown != "" and shown != "axe"
	if shown == "axe":
		_pose_axe(base)
	elif shown == "rifle":
		_pose_rifle(base)
	elif shown == "fists":
		_pose_fists(base)


func _aim_sleeve(sl: MeshInstance3D, hand: Transform3D, wrist: Vector3, elbow: Vector3) -> void:
	var wp := hand * wrist
	var along := elbow - wp
	var q := Quaternion(Vector3.BACK, along.normalized())
	var b := Basis(q).scaled_local(Vector3(1.0, 1.0, along.length() / SLEEVE_LENGTH))
	sl.transform = Transform3D(b, wp)


## Hand whose forearm axis points at a hidden elbow (so cuff and sleeve always line up), twisted about that axis.
func _free_hand(sx: float, wrist_t: Vector3, elbow: Vector3, twist: float, base: Transform3D) -> Transform3D:
	var nat := (SLEEVE_R if sx > 0.0 else SLEEVE_L).normalized()
	var dir := (elbow - wrist_t).normalized()
	var b := Basis(dir, deg_to_rad(twist)) * Basis(Quaternion(nat, dir))
	return base * Transform3D(b, wrist_t)


func _pose_axe(base: Transform3D) -> void:
	var a := Vector2.ZERO if _swing_t < 0.0 else _swing_curve(_swing_t)
	var rest := Basis(Vector3.BACK, deg_to_rad(10.0)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0 + a.x * 0.9))
	var shoulder := Vector3(0.20, -0.30, 0.12)
	var rot := Basis(Vector3.RIGHT, deg_to_rad(a.x)) * Basis(Vector3.UP, deg_to_rad(a.y)) * Basis(Vector3.BACK, deg_to_rad(-a.y * 0.8))
	var w := base * _about(shoulder, rot) * Transform3D(rest, Vector3(0.24, -0.13, -0.40))
	_axe.transform = w.scaled_local(Vector3.ONE * 1.2)
	_right.transform = w * Transform3D(Basis(Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT), AXE_WRIST)
	_right.pose("Shaft")
	var arm := base * _about(shoulder, rot)
	_aim_sleeve(_sl_r, _right.transform, Vector3.ZERO, arm * Vector3(0.48, -0.56, 0.30))


func _pose_rifle(base: Transform3D) -> void:
	var kick := 0.0
	var bolt_roll := 0.0
	var bolt_slide := 0.0
	if _fire_t >= 0.0:
		var t := _fire_t
		kick = (t / 0.05) if t < 0.05 else exp(-(t - 0.05) * 7.0)
		kick *= _kick
		if _kick > 0.5:
			if t > 0.45 and t < 0.56:
				bolt_roll = 70.0 * _sstep((t - 0.45) / 0.11)
			elif t >= 0.56 and t < 0.68:
				bolt_roll = 70.0
				bolt_slide = 0.055 * _sstep((t - 0.56) / 0.12)
			elif t >= 0.68 and t < 0.78:
				bolt_roll = 70.0
				bolt_slide = 0.055 * (1.0 - _sstep((t - 0.68) / 0.10))
			elif t >= 0.78 and t < 0.9:
				bolt_roll = 70.0 * (1.0 - _sstep((t - 0.78) / 0.12))
	var ak := player.aim_k
	# The narrow aim FOV magnifies the gun along with the world. Slide it away along the view axis (the sight line IS the axis,
	# so the sight picture stays true) so the receiver does not swallow the bottom of the screen: farther the more you zoom.
	var mag := tan(deg_to_rad(Player.AIM_FOV * 0.5)) / tan(deg_to_rad(player.cam.fov * 0.5))
	var apos := Vector3(AIM_POS.x, AIM_POS.y, AIM_POS.z - 0.12 - 0.17 * clampf(mag - 1.0, 0.0, 1.8))
	var rpos := Vector3(0.075, -0.105, -0.45).lerp(apos, ak)
	var rb := Basis(Vector3.UP, deg_to_rad(30.0 * (1.0 - ak))) * Basis(Vector3.RIGHT, deg_to_rad(lerpf(-2.0, 2.7, ak)))   # +2.7 deg levels the sight line (rear->front slopes down 2.7 deg in the model)
	var butt := rpos + Vector3(0.0, 0.0, 0.4)
	var kb := Basis(Vector3.RIGHT, deg_to_rad(lerpf(9.0, 5.0, ak) * kick))
	var w := base * _about(butt, kb) * Transform3D(rb, rpos + Vector3(0.0, 0.01 * kick, 0.0))
	_rifle.transform = w
	_bolt.transform = w * Transform3D(Basis(Vector3.BACK, deg_to_rad(bolt_roll)), BOLT_ORIGIN + Vector3(0.0, 0.0, bolt_slide))
	# Dorsum faces outward at the stock; fingers curl under it, thumb opposes.
	var rz := Vector3(0.40, 0.60, 0.693).normalized()
	var ry := (Vector3.RIGHT - rz * Vector3.RIGHT.dot(rz)).normalized()
	var rx := ry.cross(rz).normalized()
	var trigger := w * Transform3D(Basis(rx, ry, rz), RIFLE_WRIST_R)
	var bz := Vector3(0.55, 0.0, 0.835).normalized()
	var bx := Vector3.DOWN
	var by := bz.cross(bx)
	var bw := _bolt.transform * Transform3D(Basis.IDENTITY, -BOLT_ORIGIN)
	var bolt_grip := bw * Transform3D(Basis(bx, by, bz), BOLT_WRIST)
	var reach := 0.0
	if _fire_t >= 0.40 and _fire_t < FIRE_LEN and _kick > 0.5:
		if _fire_t < 0.50:
			reach = _sstep((_fire_t - 0.40) / 0.10)
		elif _fire_t < 0.90:
			reach = 1.0
		else:
			reach = 1.0 - _sstep((_fire_t - 0.90) / (FIRE_LEN - 0.90))
	_right.transform = trigger.interpolate_with(bolt_grip, reach)
	_right.pose("Trigger", "Bolt", reach)
	_left.transform = w * Transform3D(Basis(Vector3.FORWARD, Vector3.DOWN, Vector3.LEFT), RIFLE_WRIST_L)
	_left.pose("Support")
	var arm := base * _about(butt, kb)
	_aim_sleeve(_sl_r, _right.transform, Vector3.ZERO, arm * Vector3(0.46, -0.56, 0.32))
	_aim_sleeve(_sl_l, _left.transform, Vector3.ZERO, arm * Vector3(-0.46, -0.58, 0.28))


func _pose_fists(base: Transform3D) -> void:
	var jab := 0.0
	if _swing_t >= 0.0 and not _swing_axe:
		jab = sin(clampf(_swing_t / 0.38, 0.0, 1.0) * PI)
	var er := Vector3(0.48, -0.65, 0.40)
	var el := Vector3(-0.48, -0.65, 0.40)
	var tr := _free_hand(1.0, Vector3(0.22, -0.24 + 0.05 * jab, -0.34 - 0.24 * jab), er, FIST_ROLL, base)
	var tl := _free_hand(-1.0, Vector3(-0.22, -0.25, -0.34), el, -FIST_ROLL, base)
	_right.transform = tr
	_right.pose("Fist")
	_left.transform = tl
	_left.pose("Fist")
	_aim_sleeve(_sl_r, tr, Vector3.ZERO, base * er)
	_aim_sleeve(_sl_l, tl, Vector3.ZERO, base * el)
