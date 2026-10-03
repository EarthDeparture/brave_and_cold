class_name SurvivorHandRig
extends Node3D
## One anatomical mesh and skeleton, with Blender-authored grip rotations.
## Blender exports both sides with outward winding; gloves share their skin bones.

const ASSET := preload("res://assets/models/viewmodel/survivor_hand_rig.glb")
var skeleton: Skeleton3D
var bare: MeshInstance3D
var glove: MeshInstance3D
var grips: Dictionary = {}
var mirrored := false

func _ready() -> void:
	var asset := ASSET.instantiate()
	add_child(asset)
	var arm := asset.find_child("LeftHandRig" if mirrored else "HandRig", true, false)
	skeleton = arm.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	bare = asset.find_child("BareHandLeft" if mirrored else "BareHand", true, false)
	glove = asset.find_child("LeatherGloveLeft" if mirrored else "LeatherGlove", true, false)
	var unused := asset.find_child("HandRig" if mirrored else "LeftHandRig", true, false)
	for mesh in [bare, glove]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mesh.set_surface_override_material(i, mat)
	for sleeve_name in ["vm_sleeve_r", "vm_sleeve_l"]:
		asset.find_child(sleeve_name, true, false).queue_free()
	var player := asset.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.stop()
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		var rotations: Array[Quaternion] = []
		rotations.resize(skeleton.get_bone_count())
		# Godot removes constant animation tracks. Missing tracks keep their rest
		# rotation, including the wrist's Blender-to-Godot orientation.
		for bone in skeleton.get_bone_count():
			rotations[bone] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
			var path := animation.track_get_path(track)
			if path.get_subname_count() == 0: continue
			var target := player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
			if target != skeleton: continue
			var bone := skeleton.find_bone(path.get_subname(0))
			if bone >= 0 and animation.track_get_key_count(track) > 0:
				rotations[bone] = animation.track_get_key_value(track, 0)
		grips[String(name)] = rotations
	unused.queue_free()
	assert(grips.has("Shaft") and grips.has("Fist") and grips.has("Trigger"), str(grips.keys()))
	set_gloved(false)
	pose("Open")

func set_gloved(worn: bool) -> void:
	bare.visible = not worn
	glove.visible = worn

func pose(grip: String, second := "", blend := 0.0) -> void:
	var first: Array = grips[grip]
	var other: Array = grips[second] if second != "" else first
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(i, (first[i] as Quaternion).slerp(other[i], blend))
