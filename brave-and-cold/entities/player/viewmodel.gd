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
const RIFLE_WRIST_R := Vector3(0.070, 0.026, 0.175)
const RIFLE_WRIST_L := Vector3(-0.059, -0.041, -0.266)
const BOLT_WRIST := Vector3(0.148, 0.004, 0.155)
const SLEEVE_LENGTH := 0.52
const SLEEVE_R := Vector3.BACK
const SLEEVE_L := Vector3.BACK
const FIST_ROLL := -12.0
const AIM_POS := Vector3(0.0, -0.098, -0.16)   # rear sight 0.35 m ahead of the eye, sight line on the view axis
const BOLT_ORIGIN := Vector3(0.0, 0.046, 0.06)

var detail_enabled := false
var player: Player
var game_clock:GameClock
var watch:Node3D
var watch_hour:Node3D
var watch_minute:Node3D
var treatment_pending:=""
var _cosmetic:=false
var _roll:Node3D
var _bottle:Node3D
var watch_override:=false # deterministic render/test fixture
var _watch_k:=0.0
var mode := "fists"  # fists | axe | rifle
const GLOVES := ["hide_mitts", "wolf_mitts", "work_gloves"]
const GLOVE_TINT := {"hide_mitts": Color(0.58, 0.42, 0.27), "wolf_mitts": Color(0.50, 0.47, 0.44), "work_gloves": Color(0.46, 0.33, 0.22)}
var hand_cold := 0.0    # GameWorld: 0 warm .. 1 numb (hand frostbite risk + air) -> bare skin colour
var glove_item := ""  # Existing inventory hands slot; bare when no mitts are worn.
var _right: SurvivorHandRig
var _left: SurvivorHandRig
var freeze_t := -1.0  # debug: hold animation at this time
var _axe: MeshInstance3D
var _hammer: MeshInstance3D
var work_kind := ""
var work_elapsed := 0.0
var work_duration := 0.0
var work_period := 1.0
var _work_tail := -1.0
var _work_offset := 0.0
var _hammer_entry:=Transform3D.IDENTITY
var _rifle: WeaponPresentation
var _bolt: Node3D
var weapon_id := "timber_bolt_carbine"
var scoped_view := false
var light_on := false   # weapon light switched on (GameWorld: L key, battery)
var torch_on := false   # handheld flashlight in the left hand (GameWorld: L with the rifle lowered)
var torch_beam: Node3D  # lamp face of the held flashlight (GameWorld parents its SpotLight here)
var _torch: Node3D
var _torch_spill: OmniLight3D
const TORCH_GLB := "res://assets/weapons/v3/lights/flashlight_hand.glb"
var _weapon_clip := ""
var _weapon_clip_t := 0.0
var _guard_k := 0.0
var _combat_hold := 0.0
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
	_roll=(load("res://assets/maintenance/dressing_roll.glb") as PackedScene).instantiate();add_child(_roll);_roll.visible=false
	_bottle=(load("res://assets/opening_props/field_flask.glb") as PackedScene).instantiate();add_child(_bottle);_bottle.visible=false
	# Uncapped field flask during the sip; inventory retains its reusable container.
	for part:String in ["FlaskCap"]:
		var n:=_bottle.find_child(part,true,false) as Node3D
		if n!=null:n.visible=false
	watch=(load("res://assets/wristwatch/field_watch.glb") as PackedScene).instantiate()
	add_child(watch);watch.visible=false
	watch_hour=watch.find_child("HourHand",true,false)
	watch_minute=watch.find_child("MinuteHand",true,false)
	# Seat the existing bracelet on the narrower anatomical forearm. Keep the
	# dial circular; only the leather loop needs a different cross-section.
	var band := watch.find_child("Surface_rubber",true,false) as Node3D
	if band != null: band.scale=Vector3(.82,.57,1)
	for part:Node3D in watch.get_children():
		if part != band: part.position.y-=.012
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
	_hammer = _pick("res://assets/survival_props/work_hammer.glb", "work_hammer")
	_hammer.visible = false
	_rifle = WeaponPresentation.new(); add_child(_rifle); _rifle.set_weapon(weapon_id)
	_bolt = _rifle.model.find_child(weapon_id+"__Pivot_Bolt",true,false)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.72, 0.38)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.position = Vector3(0.0, 0.040, -0.76)
	add_child(_flash)


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
	if not has_axe: _combat_hold = .8


var flash_mult := 1.0   # GameWorld: 0 with a moderator, 1.4 with a muzzle brake
signal mech(event: String)   # action foley (bolt / lever) at fixed points of the cycle clip -> GameAudio.mech
var _cycle_prev := -1.0
## Fractions of the 0..0.9 cycle clip where each part moves (probed on the v3 clips: ranger bolt back .18-.36, forward .62-.76; lever open .0-.30, closes ~.86).
const BOLT_EVENTS := [[0.04, "bolt_up"], [0.22, "bolt_back"], [0.62, "bolt_fwd"], [0.79, "bolt_down"]]
const LEVER_EVENTS := [[0.03, "lever_open"], [0.80, "lever_close"]]
## Reload foley (probed on the v3 clips: magazine out .36-1.04, in 1.28-1.88; empty reloads then work the
## action 1.92-2.68; lever loading gate .12-.28, round in by .56). [time, event, who: all|bolt|semi|lever]
const RELOAD_EVENTS := {
	"reload_tactical": [[0.32, "mag_release", "all"], [0.40, "mag_out", "all"], [1.30, "mag_in", "all"], [1.84, "mag_seat", "all"]],
	"reload_empty": [[0.32, "mag_release", "all"], [0.40, "mag_out", "all"], [1.30, "mag_in", "all"], [1.84, "mag_seat", "all"],
		[1.94, "bolt_up", "bolt"], [2.00, "bolt_back", "bolt"], [2.42, "bolt_fwd", "bolt"], [2.74, "bolt_down", "bolt"],
		[1.94, "charge_back", "semi"], [2.40, "bolt_release", "semi"]],
	"reload_insert": [[0.10, "round_insert", "lever"], [0.30, "gate_close", "lever"]],
}
var _clip_prev := -1.0

func fire() -> void:
	_kick = 1.0
	_fire_t = 0.0
	_cycle_prev = -1.0


func dry() -> void:
	mech.emit("dry_click")
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
	_combat_hold = maxf(0,_combat_hold-delta)
	var guarding := not player.ui_open and (_combat_hold > 0 or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	_guard_k = move_toward(_guard_k,1.0 if guarding else 0.0,delta*5.0)
	if _weapon_clip != "":
		if player.dead or player.ui_open or mode != "rifle" or work_kind != "": cancel_weapon_clip()
		elif freeze_t < 0:
			var t0 := _weapon_clip_t if _clip_prev >= 0.0 else -1.0
			_weapon_clip_t += delta
			var who := "lever" if _rifle.is_lever_action() else ("bolt" if _rifle.is_bolt_action() else "semi")
			for ev in RELOAD_EVENTS.get(_weapon_clip, []):
				if (ev[2] == "all" or ev[2] == who) and t0 < float(ev[0]) and _weapon_clip_t >= float(ev[0]): mech.emit(String(ev[1]))
			_clip_prev = _weapon_clip_t
			if _weapon_clip_t >= _rifle.clip_length(_weapon_clip): cancel_weapon_clip()
	_roll.visible=false;_bottle.visible=false
	if treatment_pending!="" and not player.ui_open and not player.dead and work_kind=="":
		var kind:=treatment_pending;treatment_pending="";begin_work(kind,1.7);_cosmetic=true
	if _cosmetic:
		if player.aim_k>.1 or _swing_t>=0 or _fire_t>=0 or player.struggling or player.ui_open:end_work(false)
		else:
			work_elapsed+=delta
			if work_elapsed>=work_duration:end_work(false)
	if player.ui_open and work_kind != "": end_work(false)
	if player.dead:
		end_work(false)
		visible = false
		_was_dead = true
		return
	if _was_dead:  # revived: the old code never un-hid the hands/gun
		_was_dead = false
		visible = true
		_cur = ''
		_equip = 0.0
	var gt: Color = GLOVE_TINT.get(glove_item, Color(0.52, 0.38, 0.26))
	var mitts := glove_item in ["hide_mitts", "wolf_mitts"]
	_right.set_gloved(glove_item in GLOVES, gt, mitts)
	_left.set_gloved(glove_item in GLOVES, gt, mitts)
	_right.set_cold(hand_cold); _left.set_cold(hand_cold)
	# equip / mode switching: lower the old thing, raise the new
	if mode != _cur:
		cancel_weapon_clip()
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
	var off := Vector3(sin(_bob) * 0.004 * bk, (cos(_bob*2.0)-1.0) * 0.003 * bk, 0.0)
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
		_flash.light_energy = 7.0 * flash_mult * (1.0 - _fire_t / 0.09)
	var e := _sstep(_equip)
	off.y -= (1.0 - e) * 0.5
	off += Vector3(0.025, -0.045, 0.0) * _sprint_k
	var base := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0) * _sprint_k) * Basis(Vector3.UP, deg_to_rad(_sway.x * 60.0)), off)
	if _work_tail >= 0:
		_work_tail -= delta
		work_elapsed += delta
		if _work_tail <= 0: end_work(false)
	var working := work_kind != ""
	var inspecting:bool=(watch_override or Input.is_physical_key_pressed(KEY_T)) and not player.ui_open and not working and player.aim_k<.1 and _swing_t<0 and _fire_t<0
	_watch_k=move_toward(_watch_k,1.0 if inspecting else 0.0,delta*3.5)
	base.origin.y-=_watch_k*.52
	var shown := work_kind if working else (_cur if _equip > 0.0 else "")
	_hammer.visible = shown == "hammer"
	_axe.visible = shown in ["axe", "split", "chop"]
	_rifle.visible = shown == "rifle"
	# Bolt and magazines remain children of the complete animated weapon.
	_right.visible = shown != ""
	_left.visible = shown in ["rifle", "fists"]
	_sl_r.visible = shown != ""
	_sl_l.visible = shown != "" and shown != "axe"
	# Looking through optics: the HUD draws the scope picture, the model and hands step aside.
	scoped_view = shown == "rifle" and not working and RifleDB.is_scoped(weapon_id) and player.aim_k > .92 and _weapon_clip == ""
	# Kit v3 reflex / red-dot tubes stay visible: their lens shader draws the collimated dot.
	# Scoped: the model's meshes step aside, the node stays (a fitted light keeps shining).
	_rifle.set_meshes_visible(not scoped_view)
	_rifle.set_lamp(light_on and shown == "rifle" and not working)
	if scoped_view:
		_right.visible = false; _left.visible = false; _sl_r.visible = false; _sl_l.visible = false
	if working:
		# Keep normal arm reach, without moving the player toward distant targets.
		_pose_work(base)
	elif shown == "axe":
		_pose_axe(base)
	elif shown == "rifle":
		_pose_rifle(base)
	elif shown == "fists":
		_pose_fists(base)

	var holding_torch := torch_on and shown != "rifle" and not working and _watch_k < .01 and not player.ui_open
	if _torch != null: _torch.visible = holding_torch
	if holding_torch: _pose_torch(base)
	elif torch_beam != null and not torch_on: pass
	watch.visible=_watch_k>.01 and not player.ui_open
	if watch.visible:
		_pose_watch(_watch_k)

## Left hand holding the flashlight low and forward, beam toward the view centre; the fist's
## knuckle line is tilted down from the beam (wrist bent), forearm runs down and back to the elbow.
func _pose_torch(base: Transform3D) -> void:
	if _torch == null:
		if not ResourceLoader.exists(TORCH_GLB): return
		_torch = (load(TORCH_GLB) as PackedScene).instantiate(); add_child(_torch)
		var wp := WeaponPresentation.new(); wp._apply_materials(_torch); wp.free()
		for mi: MeshInstance3D in _torch.find_children("*", "MeshInstance3D", true, false): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		torch_beam = _torch.find_child("*Socket_Beam", true, false) as Node3D
		# spill: a real torch leaks light out of the bezel and off the reflector rim onto the hand and sleeve
		_torch_spill = OmniLight3D.new(); _torch_spill.omni_range = 0.55; _torch_spill.light_energy = 0.22
		_torch_spill.light_color = Color(1.0, 0.93, 0.80); _torch_spill.shadow_enabled = false; _torch_spill.light_specular = 0.2
		(torch_beam if torch_beam != null else _torch).add_child(_torch_spill); _torch_spill.position = Vector3(0, 0, 0.05)
	if _torch_spill != null: _torch_spill.visible = torch_on
	var fist := Vector3(-.135, -.185, -.43)   # 2 cm higher than W6: the fist read too low at night
	var beam := Vector3(.10, .045, -1.0).normalized()
	var x := (Basis(Vector3.RIGHT, deg_to_rad(-35.0)) * beam).normalized()
	var y := (Vector3.RIGHT - x * x.dot(Vector3.RIGHT)).normalized()
	var hb := Basis(x, y, x.cross(y))
	var hand := Transform3D(hb, fist - hb * Vector3(0, -.028, -.072))
	_left.visible = true; _sl_l.visible = true
	_left.transform = base * hand; _left.pose("Shaft")
	var tz := -beam; var ty := (Vector3.UP - tz * tz.dot(Vector3.UP)).normalized()
	var tb := Basis(ty.cross(tz), ty, tz)
	_torch.transform = base * Transform3D(tb, fist - tb * Vector3(0, 0, .040))
	_aim_sleeve(_sl_l, _left.transform, Vector3.ZERO, base * Vector3(-.40, -.62, .16))

func _pose_watch(k:float)->void:
	_left.visible=true;_sl_l.visible=true
	var wrist:=Vector3(.04,-.10-(1-k)*.55,-.36)
	var elbow:=Vector3(-.50,-.35,.12)
	var z:=(elbow-wrist).normalized()
	var y:=(Vector3.BACK-z*Vector3.BACK.dot(z)).normalized()
	var x:=y.cross(z).normalized()
	var target:=Transform3D(Basis(x,z.cross(x),z),wrist)
	_left.transform=target;_left.pose("Fist","Open",.20)
	_aim_sleeve(_sl_l,target,Vector3.ZERO,elbow)
	watch.transform=target*Transform3D(Basis.IDENTITY,Vector3(0,0,.026))
	if game_clock!=null:
		watch_hour.rotation.y=-TAU*fposmod(game_clock.hour,12)/12
		watch_minute.rotation.y=-TAU*fposmod(game_clock.hour,1)

func _aim_sleeve(sl: MeshInstance3D, hand: Transform3D, wrist: Vector3, elbow: Vector3) -> void:
	var wp := hand * wrist
	var along := elbow - wp
	var rig := _right if sl == _sl_r else _left
	rig.align_forearm(hand.affine_inverse()*elbow)
	var cuff := wp+along.normalized()*.050
	along = elbow-cuff
	var q := Quaternion(Vector3.BACK, along.normalized())
	var b := Basis(q).scaled_local(Vector3(1.28, 1.28, along.length() / SLEEVE_LENGTH))
	sl.transform = Transform3D(b, cuff)


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
	_right.pose("ToolGrip")
	var arm := base * _about(shoulder, rot)
	_aim_sleeve(_sl_r, _right.transform, Vector3.ZERO, arm * Vector3(0.48, -0.56, 0.30))


func equip_weapon(id: String) -> void:
	assert(id in WeaponPresentation.IDS)
	cancel_weapon_clip(); weapon_id = id
	_fire_t = -1.0
	if _rifle != null:
		_rifle.set_weapon(id)
		_bolt = _rifle.model.find_child(id+"__Pivot_Bolt",true,false)

func weapon_busy() -> bool:
	return _weapon_clip != ""

## Presentation only: existing inventory remains the owner of each fired round.
func play_weapon_clip(clip: String) -> bool:
	if mode != "rifle" or work_kind != "" or _fire_t >= 0 or player.dead or player.ui_open: return false
	if _rifle.clip_length(clip) <= 0: return false
	_weapon_clip = clip; _weapon_clip_t = 0.0; _clip_prev = 0.0
	return true

func cancel_weapon_clip() -> void:
	_weapon_clip = ""; _weapon_clip_t = 0.0

func _right_weapon_basis() -> Basis:
	var z := Vector3(.22,0,.975).normalized() if _rifle.is_pistol_grip() else Vector3(.40,.60,.693).normalized()
	var y := z.cross(Vector3.DOWN).normalized() if _rifle.is_pistol_grip() else (Vector3.RIGHT-z*z.x).normalized()
	return Basis(y.cross(z).normalized(),y,z)

func _bolt_weapon_basis() -> Basis:
	var z := Vector3(.55,0,.835).normalized()
	var x := Vector3.UP
	return Basis(x,z.cross(x),z)

func _pose_rifle(base: Transform3D) -> void:
	if _rifle.weapon_id != weapon_id or (_rifle.is_v3() and _rifle.fit_sig != RifleDB.fit_sig(weapon_id)): equip_weapon(weapon_id)
	var ak := player.aim_k
	var kick := 0.0
	if _fire_t >= 0:
		kick = ((_fire_t/.05) if _fire_t < .05 else exp(-(_fire_t-.05)*7.0))*_kick
	var clip := "idle"; var time := fposmod(_clock,1.2); var cycle := -1.0
	if _weapon_clip != "":
		clip = _weapon_clip; time = _weapon_clip_t
	elif _fire_t >= 0 and _kick > .5:
		if _fire_t < .30: clip = "fire"; time = _fire_t
		elif _rifle.is_bolt_action() or _rifle.is_lever_action():
			clip = "cycle"; cycle = clampf((_fire_t-.30)/.75*.9,0,.9); time = cycle
			for ev in (LEVER_EVENTS if _rifle.is_lever_action() else BOLT_EVENTS):
				if _cycle_prev < float(ev[0]) and cycle >= float(ev[0]): mech.emit(String(ev[1]))
			_cycle_prev = cycle
	# Socket_Aim belongs to the complete imported model, including inspect tilt.
	_rifle.sample(clip,time)
	var mag := tan(deg_to_rad(Player.AIM_FOV*.5))/tan(deg_to_rad(player.cam.fov*.5))
	# v3: cheek on the comb, eye ~22 cm behind the trigger (v2 art sat 30 cm out, stock ahead of the eye)
	var aimed := Vector3(0,-_rifle.aim_height(),(-.22 if _rifle.is_v3() else -.30)-.17*clampf(mag-1,0,1.8))
	var hip := Vector3(.14,-.20,-.40) if _rifle.is_v3() else Vector3(.10,-.17,-.42)
	var rpos := hip.lerp(aimed,ak)
	var rb := Basis(Vector3.UP,deg_to_rad((8.0 if _rifle.is_v3() else 24.0)*(1-ak)))
	var butt := rpos+Vector3(0,0,.38)
	var recoil := _about(butt,Basis(Vector3.RIGHT,deg_to_rad(lerpf(7,4,ak)*kick)))
	var w := base*recoil*Transform3D(rb,rpos)
	_rifle.transform = w
	if _rifle.is_v3():
		# collimated dot: along the bore, settling onto the shot line (camera axis) as the rifle comes up
		var gun_fwd := -(global_transform * w).basis.z.normalized()
		var cam_fwd := -player.cam.global_transform.basis.z.normalized()
		var h := fposmod(game_clock.hour, 24.0) if game_clock != null else 12.0
		var night := 1.0 - clampf(minf(h - 5.5, 19.5 - h) / 1.5, 0.0, 1.0)
		_rifle.update_sight(gun_fwd.lerp(cam_fwd, ak * ak).normalized(), night)
	var right_offset := Vector3(.024,.054,.0585) if not _rifle.is_pistol_grip() else Vector3(.057,-.037,.050)
	var trigger := _rifle.resting_socket_transform("HandR")*Transform3D(_right_weapon_basis(),right_offset)
	var support := _rifle.resting_socket_transform("HandL")*Transform3D(Basis(Vector3.FORWARD,Vector3.DOWN,Vector3.LEFT),Vector3(-.042,-.035,.030))
	var fe := {}; var wr := {}
	if _rifle.is_v3():
		fe = _rifle.section_at(_rifle.socket_model("HandL").z)
		wr = _rifle.section_at(_rifle.socket_model("HandR").z + .012)
		if not fe.is_empty(): support = _model_vm() * _support_on(fe)
	trigger.origin += _rifle.resting_socket_transform("HandR").basis*_rifle.contact_offset("hold","right")
	support.origin += _rifle.resting_socket_transform("HandL").basis*_rifle.contact_offset("hold","left")
	var right := trigger; var left := support; var reach := 0.0
	var left_grip := "ForeGrip"; var left_mix := 0.0
	if cycle >= 0 and not _rifle.is_lever_action():
		reach = _sstep(cycle/.16) if cycle < .16 else (1.0-_sstep((cycle-.78)/.12) if cycle > .78 else 1.0)
	if clip in ["reload_tactical","reload_empty"]:
		var duration := _rifle.clip_length(clip)
		left_mix = _sstep(time/.30) if time < .30 else (1.0-_sstep((time-1.85)/(duration-1.85)) if time > 1.85 else 1.0)
		var mag_hand := _rifle.socket_transform("MagazineHand")
		# Keep the fingers at the actual moving magazine, including withdrawal.
		var mag_pose := mag_hand*Transform3D(Basis(Vector3.FORWARD,Vector3.LEFT,Vector3.UP),Vector3(-.061,.045,.018))
		mag_pose.origin += mag_hand.basis*_rifle.contact_offset("magazine","left")
		left = support.interpolate_with(mag_pose,left_mix)
		left.origin += w.basis*Vector3(-.10,-.035,0)*sin(PI*left_mix)
		left_grip = "Magazine"
		if clip == "reload_empty" and time > 1.85:
			reach = _sstep((time-1.85)/.28) if time < 2.13 else (1.0-_sstep((time-2.63)/.37) if time > 2.63 else 1.0)
	elif clip in ["reload_start","reload_insert","reload_end"] and _rifle.is_lever_action():
		left_mix = _sstep(time/.45) if clip == "reload_start" else (1.0-_sstep(time/.45) if clip == "reload_end" else 1.0)
		var gate := _rifle.socket_transform("LoadingGate")*Transform3D(Basis(Vector3.FORWARD,Vector3.LEFT,Vector3.UP),Vector3(-.060,.04,.015))
		left = support.interpolate_with(gate,left_mix); left_grip = "PinchReady"
	if reach > 0:
		var bolt := _rifle.socket_transform("BoltHand")*Transform3D(_bolt_weapon_basis(),Vector3(.066,.047,.043))
		bolt.origin += _rifle.socket_transform("BoltHand").basis*_rifle.contact_offset("bolt","right")
		right = trigger.interpolate_with(bolt,reach)
		right.origin += w.basis*Vector3(.115,.035,.025)*sin(PI*reach)
	_right.transform = right
	_right.pose("Trigger" if _rifle.is_pistol_grip() else "StockGrip","PinchReady",reach,.55*sin(PI*reach))
	if reach == 0 and _fire_t >= 0 and _fire_t < .22 and _kick > .5:
		var press := sin(PI*_fire_t/.22)
		_right.pose("Trigger" if _rifle.is_pistol_grip() else "StockGrip","PistolFire" if _rifle.is_pistol_grip() else "StockFire",press)
	if _rifle.is_lever_action() and cycle >= 0:
		_right.transform = _rifle.socket_transform("HandR")*Transform3D(_right_weapon_basis(),right_offset)
		_right.position += _rifle.socket_transform("HandR").basis*_rifle.contact_offset("hold","right")
		_right.pose("StockGrip","ToolGrip",sin(PI*cycle/.9)*.6)
	_left.transform = left; _left.pose("ForeGrip",left_grip,left_mix,.45*sin(PI*left_mix))
	if not fe.is_empty() and left_mix < .02:
		_wrap(_left, "ForeGrip", fe, ["index", "middle", "ring", "little", "thumb"])
	if not wr.is_empty() and reach < .02 and not (_rifle.is_lever_action() and cycle >= 0):
		_wrap(_right, "Trigger" if _rifle.is_pistol_grip() else "StockGrip", wr, ["middle", "ring", "little", "thumb"])
	_aim_sleeve(_sl_r,_right.transform,Vector3.ZERO,base*Vector3(.46,-.56,.32))
	_aim_sleeve(_sl_l,left,Vector3.ZERO,base*Vector3(-.46,-.58,.28))
	_flash.position = _rifle.socket_transform("Muzzle").origin

## ---- v3 hand placement on the real wood (weapon mesh cross-sections) + finger-curl wrap.
func _model_vm() -> Transform3D:
	return _rifle.transform * _rifle.model.transform

## Support hand on a fore-end section (model space): palm against the lower-left of the wood, turned
## ~38 deg up toward the gun, fingers pointing across under it and a little forward (they wrap the far side),
## thumb along the near side. Returns the hand transform in model space.
const SUPPORT_PHI := 38.0
const SUPPORT_YAW := 24.0
func _support_on(sec: Dictionary) -> Transform3D:
	var phi := deg_to_rad(SUPPORT_PHI); var psi := deg_to_rad(SUPPORT_YAW)
	var c: Vector3 = sec.c; var hw: float = sec.hw; var hh: float = sec.hh
	var n_out := Vector3(-sin(phi) * hh, -cos(phi) * hw, 0).normalized()   # ellipse normal at the contact
	var p := c + Vector3(-hw * sin(phi), -hh * cos(phi), 0)
	var tdir := Vector3(-n_out.y, n_out.x, 0)                               # around under the wood, to the right
	var fing := (tdir * cos(psi) + Vector3.FORWARD * sin(psi)).normalized()
	var y := n_out
	var z := -(fing - y * y.dot(fing)).normalized()
	var b := Basis(y.cross(z), y, z)
	return Transform3D(b, p - b * Vector3(0, -0.013, -0.050))

func _wrap(rig: SurvivorHandRig, grip: String, sec: Dictionary, fingers: Array) -> void:
	var m := global_transform * _model_vm()
	rig.wrap(grip, m * (sec.c as Vector3), m.basis * Vector3.FORWARD, m.basis * Vector3.UP, float(sec.hw), float(sec.hh), fingers)

func _pose_fists(base: Transform3D) -> void:
	var jab := 0.0
	if _swing_t >= 0.0 and not _swing_axe:
		jab = sin(clampf(_swing_t / 0.38, 0.0, 1.0) * PI)
	var guard := _guard_k
	if _swing_t >= 0 and not _swing_axe: guard = maxf(guard,_sstep(_swing_t/.07))
	var er := Vector3(0.48, -0.65, 0.40)
	var el := Vector3(-0.48, -0.65, 0.40)
	var wr := Vector3(.23,-.29,-.40).lerp(Vector3(.22,-.24,-.34),guard)+Vector3(0,.05*jab,-.24*jab)
	var wl := Vector3(-.23,-.30,-.40).lerp(Vector3(-.22,-.25,-.34),guard)
	var tr := _free_hand(1.0, wr, er, FIST_ROLL, base)
	var tl := _free_hand(-1.0, wl, el, -FIST_ROLL, base)
	_right.transform = tr
	_right.pose("Relaxed","Fist",guard)
	_left.transform = tl
	_left.pose("Relaxed","Fist",guard)
	_aim_sleeve(_sl_r, tr, Vector3.ZERO, base * er)
	_aim_sleeve(_sl_l, tl, Vector3.ZERO, base * el)

## Action-owned presentation: no timers or gameplay resource mutations here.
func begin_work(kind: String, duration: float, repeating := false) -> void:
	# Recover the tool frame from the current wrist; keep the fitted socket
	# invariant while easing into a repeated service stroke.
	if kind=="hammer" and _right!=null:
		_hammer_entry=_right.transform*Transform3D(Basis(Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT),AXE_WRIST).affine_inverse()
	cancel_weapon_clip()
	end_work(false)
	if kind not in ["split", "chop", "hammer", "reach","treat","drink"]: return
	work_kind = kind; work_duration = maxf(duration,.01); work_elapsed = 0
	var cycles := 1 if kind in ["chop","reach"] else maxi(1,int(ceil(duration/.85)))
	# Final stroke reaches impact at completion; earlier strokes give rhythm.
	work_period = work_duration/(float(cycles-1)+.35/SWING_LEN)
	_work_offset = 0
	if repeating and kind == "chop":
		work_period = work_duration
		_work_offset = .35/SWING_LEN*work_period
	_swing_t = -1; _fire_t = -1
func update_work(elapsed: float) -> void:
	if work_kind != "" and _work_tail<0: work_elapsed = clampf(elapsed,0,work_duration)
func end_work(completed: bool) -> void:
	if completed and work_kind != "":
		work_elapsed = work_duration
		_work_tail = .47/SWING_LEN*work_period if work_kind != "reach" else .15
		return
	work_kind = ""; _work_tail = -1; work_elapsed = 0;_cosmetic=false
func work_impacts(elapsed: float) -> int:
	if work_kind not in ["split","hammer"]: return 0
	return maxi(0,int(floor(elapsed/work_period-.35/SWING_LEN+.00001))+1)
func _hammer_curve(phase:float)->Vector2:
	var impact:=.35/SWING_LEN
	if phase<.25:return Vector2(15,4)*_sstep(phase/.25)
	if phase<impact:return Vector2(15,4).lerp(Vector2(-9,-2),_sstep((phase-.25)/(impact-.25)))
	if phase<.50:return Vector2(-9,-2)
	return Vector2(-9,-2)*(1-_sstep((phase-.50)/.50))
func _pose_work(base: Transform3D) -> void:
	_left.visible = false; _sl_l.visible = false
	if work_kind in ["treat","drink"]:
		_pose_consumable(base);return
	if work_kind == "reach":
		var progress := clampf(work_elapsed/work_duration,0,1)
		var reach := sin(progress*PI)
		_right.transform = _free_hand(1,Vector3(.18,-.23,-.42-.14*reach),Vector3(.48,-.56,.26),-25,base)
		_right.pose("Open","Support",reach*.20)
		_aim_sleeve(_sl_r,_right.transform,Vector3.ZERO,base*Vector3(.48,-.56,.26))
		return
	var phase := fposmod(work_elapsed+_work_offset,work_period)/work_period
	var a := _swing_curve(phase*SWING_LEN)
	if work_kind == "hammer": a = _hammer_curve(phase)
	var rest := Basis(Vector3.BACK,deg_to_rad(10))*Basis(Vector3.RIGHT,deg_to_rad(-30+a.x*.9))
	var shoulder := Vector3(.20,-.30,.12)
	var rot := Basis(Vector3.RIGHT,deg_to_rad(a.x))*Basis(Vector3.UP,deg_to_rad(a.y))*Basis(Vector3.BACK,deg_to_rad(-a.y*.8))
	var w := base*_about(shoulder,rot)*Transform3D(rest,Vector3(.24,-.13,-.40))
	if work_kind=="hammer":
		w=_hammer_entry.interpolate_with(w,_sstep(work_elapsed/minf(.14,work_duration*.15)))
	var tool := _hammer if work_kind == "hammer" else _axe
	tool.transform = w.scaled_local(Vector3.ONE*1.2)
	_right.transform = w*Transform3D(Basis(Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT),AXE_WRIST)
	_right.pose("ToolGrip")
	_aim_sleeve(_sl_r,_right.transform,Vector3.ZERO,base*_about(shoulder,rot)*Vector3(.48,-.56,.30))

func queue_treatment(id:String)->void:
	if id=="bandage":treatment_pending="treat"
	elif id=="clean_water":treatment_pending="drink"
func _pose_consumable(base:Transform3D)->void:
	var t:=clampf(work_elapsed/work_duration,0,1)
	var lift:=sin(t*PI)
	if work_kind=="drink":
		_right.transform=_free_hand(1,Vector3(.15,-.29+.25*lift,-.43+.15*lift),Vector3(.49,-.57,.25),-65,base)
		# Tilt the wrist and flask together; the flask must not rotate through
		# fingers whose grip stays fixed during a sip.
		_right.transform.basis*=Basis(Vector3.RIGHT,-.15-.65*lift)
		# Loosen the fingers around the actual 84mm flask body, including gloves.
		# The 2mm socket adjustment and release were fitted to deformed vertices.
		_right.pose("BottleGrip","",0,.24)
		_bottle.visible=true;_bottle.transform=_right.transform*Transform3D(Basis(Vector3.BACK,PI*.5),Vector3(.12,-.064,-.095))
	else:
		_left.visible=true;_sl_l.visible=true
		_left.transform=_free_hand(-1,Vector3(-.12,-.26,-.44),Vector3(-.46,-.57,.22),35,base);_left.pose("Open","Support",.35)
		_aim_sleeve(_sl_l,_left.transform,Vector3.ZERO,base*Vector3(-.46,-.57,.22))
		_right.transform=_free_hand(1,Vector3(.11-.07*lift,-.25+.025*sin(t*TAU*2),-.43),Vector3(.46,-.57,.25),-35,base);_right.pose("Shaft","Support",.2)
		_roll.visible=true;_roll.transform=_right.transform*Transform3D(Basis.IDENTITY,Vector3(0,-.075,-.075))
	_aim_sleeve(_sl_r,_right.transform,Vector3.ZERO,base*Vector3(.49,-.57,.25))
