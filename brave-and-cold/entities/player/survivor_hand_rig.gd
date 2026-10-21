class_name SurvivorHandRig
extends Node3D
## Approved anatomy, curved nails and leather shells on matching 17-bone rigs.
const ASSET := preload("res://assets/models/viewmodel/anatomical_hand_rig.glb")
var skeleton: Skeleton3D
var bare: MeshInstance3D
var glove: MeshInstance3D
var nails: MeshInstance3D
var grips: Dictionary = {}
var mirrored := false
var detail_enabled := false
var rest_positions: Array[Vector3] = []
func _ready() -> void:
	var asset := ASSET.instantiate(); add_child(asset)
	var arm := asset.find_child("LeftHandRig" if mirrored else "HandRig",true,false)
	skeleton = arm.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for bone in skeleton.get_bone_count(): rest_positions.append(skeleton.get_bone_pose_position(bone))
	bare = asset.find_child("BareHandLeft" if mirrored else "BareHand",true,false)
	glove = asset.find_child("LeatherGloveLeft" if mirrored else "LeatherGlove",true,false)
	nails = asset.find_child("NailsLeft" if mirrored else "NailsRight",true,false)
	for mesh in [bare,glove,nails]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			if mesh == bare:
				# snow light washed the skin to white plastic: weathered, a touch darker and matte
				# (blue snow ambient on a pale texture read grey-blue: warmer tint + a little red light through the skin)
				mat.albedo_color = Color(0.84, 0.64, 0.52)
				mat.roughness = 0.72; mat.metallic_specular = 0.3
				mat.backlight_enabled = true; mat.backlight = Color(0.32, 0.10, 0.06)
			mesh.set_surface_override_material(i,mat)
	var player := asset.find_child("AnimationPlayer",true,false) as AnimationPlayer
	player.stop()
	for name in player.get_animation_list():
		if String(name) == "FlexCycle" or String(name) == "RESET": continue
		var animation := player.get_animation(name)
		var rotations: Array[Quaternion] = []; rotations.resize(skeleton.get_bone_count())
		for bone in skeleton.get_bone_count(): rotations[bone] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
			var path := animation.track_get_path(track)
			if path.get_subname_count() == 0: continue
			var target := player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			if target != skeleton: continue
			var bone := skeleton.find_bone(path.get_subname(0))
			if bone >= 0 and animation.track_get_key_count(track) > 0: rotations[bone] = animation.track_get_key_value(track,0)
		grips[String(name)] = rotations
	var unused := asset.find_child("HandRig" if mirrored else "LeftHandRig",true,false)
	unused.queue_free()
	assert(skeleton.get_bone_count() == 17 and grips.has("Relaxed") and grips.has("Magazine"))
	set_gloved(false); pose("Relaxed")
func set_gloved(worn: bool) -> void:
	bare.visible = not worn; nails.visible = not worn; glove.visible = worn
func pose(grip: String, second := "", blend := 0.0, release := 0.0) -> void:
	assert(grips.has(grip) and (second == "" or grips.has(second)),"Unknown anatomical grip")
	var first: Array = grips[grip]
	var other: Array = grips[second] if second != "" else first
	var open: Array = grips["Open"]
	var mix := clampf(blend,0,1); var relaxed := clampf(release,0,1)
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(i,rest_positions[i])
		var rotation := (first[i] as Quaternion).slerp(other[i],mix)
		skeleton.set_bone_pose_rotation(i,rotation.slerp(open[i],relaxed))
	for mesh in [bare,glove]:
		for i in mesh.mesh.get_blend_shape_count():
			var name := String(mesh.mesh.get_blend_shape_name(i))
			var weight := (1.0-mix if name == "corrective_"+grip else 0.0) + (mix if second != "" and name == "corrective_"+second else 0.0)
			mesh.set_blend_shape_value(i,weight*(1.0-relaxed))

## ---- Finger-curl grip solver. After pose(grip), close each finger (and the thumb) from Open toward
## the grip's curl - and past it - until it touches an elliptical section (a fore-end, a stock wrist):
## the hand wraps the real wood instead of a fixed, guessed fist. Section given in world space:
## centre, axis (along the gun), up (gun up), half-width hw, half-height hh.
const FINGERS := {"index": ["index_01", "index_02", "index_03"], "middle": ["middle_01", "middle_02", "middle_03"],
	"ring": ["ring_01", "ring_02", "ring_03"], "little": ["little_01", "little_02", "little_03"], "thumb": ["thumb_01", "thumb_02", "thumb_03"]}
const PAD := 0.0085          # finger half-thickness (glove adds a little)
var last_wrap: Dictionary = {}   # finger -> curl t used (debug / tests)
func wrap(grip: String, centre: Vector3, axis: Vector3, up: Vector3, hw: float, hh: float, fingers: Array = ["index", "middle", "ring", "little", "thumb"], max_t := 1.35) -> void:
	var inv := skeleton.global_transform.affine_inverse()
	var c := inv * centre; var a := (inv.basis * axis).normalized(); var u := (inv.basis * up).normalized()
	u = (u - a * a.dot(u)).normalized(); var r := a.cross(u).normalized()
	var hand := skeleton.find_bone("hand")
	var hand_g := skeleton.get_bone_global_pose(hand)
	var open: Array = grips["Open"]; var g: Array = grips[grip]
	var pad := PAD + (0.003 if glove.visible else 0.0)
	last_wrap.clear()
	for f: String in fingers:
		var chain: Array = FINGERS[f]
		var ids: Array[int] = []; var logs: Array = []
		for n: String in chain:
			var b := skeleton.find_bone(n); ids.append(b)
			logs.append(((open[b] as Quaternion).inverse() * (g[b] as Quaternion)).log())
		var tip_off := (rest_positions[ids[2]] as Vector3) * 0.95   # last segment continues roughly as the one before
		var best := max_t
		var t := 0.0
		while t <= max_t + 0.001:
			var x := hand_g
			var hit := false
			for k in 3:
				var b := ids[k]
				var q := (open[b] as Quaternion) * Quaternion((logs[k] as Quaternion).x * t, (logs[k] as Quaternion).y * t, (logs[k] as Quaternion).z * t, 0.0).exp()
				x = x * Transform3D(Basis(q), rest_positions[b])
				if k > 0 and _inside(x.origin, c, r, u, hw + pad, hh + pad): hit = true
			var tip := x * tip_off
			if hit or _inside(tip, c, r, u, hw + pad, hh + pad):
				# touching before the finger has really closed = it starts inside the section (a tall
				# pistol grip): keep the authored grip curl rather than leaving it straight
				best = maxf(0.0, t - 0.04) if t >= 0.35 else 1.0
				break
			t += 0.05
		last_wrap[f] = best
		for k in 3:
			var b := ids[k]
			var lq := logs[k] as Quaternion
			skeleton.set_bone_pose_rotation(b, (open[b] as Quaternion) * Quaternion(lq.x * best, lq.y * best, lq.z * best, 0.0).exp())

func _inside(p: Vector3, c: Vector3, r: Vector3, u: Vector3, hw: float, hh: float) -> bool:
	var d := p - c
	var x := d.dot(r) / hw; var y := d.dot(u) / hh
	return x * x + y * y < 1.0

## Bend the independent forearm toward the sleeve without moving finger contact.
func align_forearm(elbow_local: Vector3) -> void:
	var forearm := skeleton.find_bone("forearm")
	var wrist := skeleton.find_bone("hand")
	var hand_global := skeleton.get_bone_global_pose(wrist)
	var turn := Transform3D(Basis(Quaternion(Vector3.BACK,elbow_local.normalized())),Vector3.ZERO)
	skeleton.set_bone_global_pose(forearm,turn*skeleton.get_bone_global_pose(forearm))
	skeleton.set_bone_global_pose(wrist,hand_global)
