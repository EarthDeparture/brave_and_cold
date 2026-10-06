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

## Bend the independent forearm toward the sleeve without moving finger contact.
func align_forearm(elbow_local: Vector3) -> void:
	var forearm := skeleton.find_bone("forearm")
	var wrist := skeleton.find_bone("hand")
	var hand_global := skeleton.get_bone_global_pose(wrist)
	var turn := Transform3D(Basis(Quaternion(Vector3.BACK,elbow_local.normalized())),Vector3.ZERO)
	skeleton.set_bone_global_pose(forearm,turn*skeleton.get_bone_global_pose(forearm))
	skeleton.set_bone_global_pose(wrist,hand_global)
