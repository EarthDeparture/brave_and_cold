class_name WeaponPresentation
extends Node3D
## Visual component clips and wrist sockets. Inventory owns ammunition and damage.
const IDS := ["ridge_scout_rifle", "timber_bolt_carbine", "ranger_box_rifle", "brush_lever_rifle", "frontier_vented_rifle", "north_service_rifle", "compact_patrol_rifle", "expedition_rifle"]
var weapon_id := ""
var model: Node3D
var animation_player: AnimationPlayer
var rest: Dictionary = {}
var sockets: Dictionary = {}
var current_clip := "idle"
var current_time := 0.0
var contact_profiles: Dictionary = {}
var lens: MeshInstance3D          # amber sight glass (reflex sights look through it)
var _lens_glass: StandardMaterial3D
func _init() -> void:
	contact_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/north_ridge/contact_profiles.json"))
func contact_offset(state: String, side: String) -> Vector3:
	var value: Array = contact_profiles.get(weapon_id,{}).get(state+"_"+side,[0,0,0])
	return Vector3(value[0],value[1],value[2])
func set_weapon(id: String) -> void:
	assert(id in IDS, "Unknown weapon art: " + id)
	if weapon_id == id: return
	if model != null: remove_child(model); model.free()
	weapon_id = id
	model = (load("res://assets/weapons/north_ridge/"+id+".glb") as PackedScene).instantiate()
	add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false)
	assert(animation_player != null)
	rest.clear(); sockets.clear(); remember(model)
	lens = model.find_child(id + "__Sheet_lens_orange", true, false) as MeshInstance3D
	for name: String in ["HandR","HandL","BoltHand","MagazineHand","Muzzle","Aim","TriggerFinger","LoadingGate","Scope"]:
		var target := model.find_child(id+"__Socket_"+name,true,false) as Node3D
		if target != null: sockets[name] = target
	# Semi-automatic receivers use the moving charging tab. The art kit's
	# BoltHand marker is for the bolt carbine's round handle only.
	if not is_bolt_action() and not is_lever_action():
		var charging := model.find_child(id+"__Pivot_ChargingHandle",true,false) as Node3D
		var action_hand := Node3D.new();charging.add_child(action_hand)
		action_hand.position=Vector3(.009,0,0);sockets["BoltHand"]=action_hand
		rest[action_hand]=action_hand.transform
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample("idle",0)
func remember(node: Node) -> void:
	if node is Node3D: rest[node] = node.transform
	for child in node.get_children(): remember(child)
func sample(clip: String, time: float) -> void:
	assert(animation_player.has_animation(clip), "Missing weapon clip: "+weapon_id+" / "+clip)
	animation_player.stop()
	for node: Node3D in rest: node.transform = rest[node]
	animation_player.play(clip)
	animation_player.seek(clampf(time,0,animation_player.get_animation(clip).length),true)
	animation_player.advance(0); animation_player.pause()
	current_clip = clip; current_time = time
func socket_transform(name: String) -> Transform3D:
	assert(sockets.has(name), "Missing wrist/weapon socket: "+name)
	return get_parent().global_transform.affine_inverse() * (sockets[name] as Node3D).global_transform
func resting_socket_transform(name: String) -> Transform3D:
	var socket: Node3D = sockets[name]
	return get_parent().global_transform.affine_inverse() * socket.get_parent().global_transform * (rest[socket] as Transform3D)
func clip_length(clip: String) -> float:
	return animation_player.get_animation(clip).length if animation_player.has_animation(clip) else 0.0
func is_pistol_grip() -> bool:
	return weapon_id in ["north_service_rifle","compact_patrol_rifle","expedition_rifle"]
## Rifle-sheet art (2026-10-08): optics carry a Socket_Scope at the eyepiece; Aim sits on the optical axis.
func has_scope() -> bool: return sockets.has("Scope")
## Aimed reflex sights: the painted lens becomes faintly tinted glass so the dot sits over the world.
func set_lens_see_through(on: bool) -> void:
	if lens == null: return
	if on and _lens_glass == null:
		_lens_glass = StandardMaterial3D.new(); _lens_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lens_glass.albedo_color = Color(1.0, .62, .25, .14); _lens_glass.roughness = .08; _lens_glass.metallic_specular = .9
	lens.material_override = _lens_glass if on else null
func aim_height() -> float:
	if not sockets.has("Aim"): return .127
	return (rest[sockets["Aim"]] as Transform3D).origin.y
func is_bolt_action() -> bool: return weapon_id == "timber_bolt_carbine"
func is_lever_action() -> bool: return weapon_id == "brush_lever_rifle"
