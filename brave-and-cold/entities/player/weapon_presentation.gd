class_name WeaponPresentation
extends Node3D
## Visual component clips and wrist sockets. Inventory owns ammunition and damage.
## Weapon kit v3 rifles (RifleDB.is_v3) are modular: the base rifle GLB plus the fitted optic and
## light GLBs, each attached socket-to-socket; kit v2 rifles load their single sheet GLB.
const IDS := ["ridge_scout_rifle", "timber_bolt_carbine", "ranger_box_rifle", "brush_lever_rifle", "frontier_vented_rifle", "north_service_rifle", "compact_patrol_rifle", "expedition_rifle"]
const SURFACE := preload("res://world/shaders/weapon_surface.gdshader")
const LENS := preload("res://world/shaders/weapon_lens.gdshader")
# kit v3 material keys -> (shader family, roughness, metallic); see gen_weapon_kit_v3.py PROPS
const FAMILY := {
	"walnut": [0, .62, 0.0], "birch": [0, .66, 0.0], "birch_dark": [0, .64, 0.0], "laminate": [0, .55, 0.0],
	"blued": [1, .38, .75], "parkerized": [1, .62, .55], "alloy_black": [1, .55, .2], "stainless": [1, .42, .8], "case_colour": [1, .40, .7], "hardwood_red": [0, .60, 0.0], "steel_bright": [1, .30, .85],
	"brass": [1, .32, .9], "synthetic_black": [2, .72, 0.0], "camo_dip": [2, .70, 0.0], "rubber": [2, .85, 0.0],
	"sling_canvas": [3, .9, 0.0], "tape_grey": [3, .6, 0.0], "lamp_lens": [2, .1, 0.0]}
var weapon_id := ""
var fit_sig := ""
var model: Node3D
var animation_player: AnimationPlayer
var rest: Dictionary = {}
var sockets: Dictionary = {}
var current_clip := "idle"
var current_time := 0.0
var contact_profiles: Dictionary = {}
var lens: MeshInstance3D          # kit v2: amber sight glass (opaque)
var _lens_glass: StandardMaterial3D
var optic_node: Node3D            # kit v3 fitted optic
var light_node: Node3D            # kit v3 fitted light
var mount_node: Node3D            # kit v3 adapter (clamp-on scout rail)
var muzzle_node: Node3D           # kit v3 muzzle device
var lamp: SpotLight3D
var dot_mats: Array[ShaderMaterial] = []
var _eye_y := NAN
var _iron_y := NAN

func _init() -> void:
	contact_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/north_ridge/contact_profiles.json"))
## Kit v3 rifles share one hand-contact profile: their HandL/HandR sockets are placed on the wood by
## the generator (palm under the fore-end, wrist at the grip), not tuned per gun afterwards.
const V3_CONTACT := {"hold_right": [-0.0005, 0.003, 0], "hold_left": [-0.0035, -0.017, 0], "magazine_left": [0.012, -0.0211, 0.0016]}
func contact_offset(state: String, side: String) -> Vector3:
	var value: Array = (V3_CONTACT if RifleDB.is_v3(weapon_id) else contact_profiles.get(weapon_id,{})).get(state+"_"+side,[0,0,0])
	return Vector3(value[0],value[1],value[2])
func is_v3() -> bool: return RifleDB.is_v3(weapon_id)
var fit_override: Dictionary = {}   # a specific rifle's fit (ground pickup, gunsmith spare); {} = the player's top rifle
func _fit() -> Dictionary:
	return fit_override if not fit_override.is_empty() else RifleDB.fitted(weapon_id)
func set_weapon(id: String, fit: Dictionary = {}) -> void:
	assert(id in IDS, "Unknown weapon art: " + id)
	var sig := (RifleDB.fit_sig(id) if fit.is_empty() else "%s|%s" % [id, str(fit)]) if RifleDB.is_v3(id) else id
	fit_override = fit
	if weapon_id == id and fit_sig == sig: return
	if model != null: remove_child(model); model.free()
	weapon_id = id; fit_sig = sig
	_sections.clear()
	optic_node = null; light_node = null; mount_node = null; muzzle_node = null; lamp = null; dot_mats.clear(); _eye_y = NAN; _iron_y = NAN; lens = null
	var path := ("res://assets/weapons/v3/rifles/%s.glb" if RifleDB.is_v3(id) else "res://assets/weapons/north_ridge/%s.glb") % id
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false)
	assert(animation_player != null)
	rest.clear(); sockets.clear()
	if not RifleDB.is_v3(id):
		lens = model.find_child(id + "__Sheet_lens_orange", true, false) as MeshInstance3D
	for name: String in ["HandR","HandL","BoltHand","MagazineHand","Muzzle","Aim","TriggerFinger","LoadingGate","Scope","OpticMount","IronAim","LightMount","ScoutMount","MuzzleThread"]:
		var target := model.find_child(id+"__Socket_"+name,true,false) as Node3D
		if target != null: sockets[name] = target
	if RifleDB.is_v3(id): _build_v3()
	remember(model)
	# Semi-automatic receivers use the moving charging tab. The art kit's
	# BoltHand marker is for the bolt carbine's round handle only.
	if not is_bolt_action() and not is_lever_action() and not RifleDB.is_v3(id):
		var charging := model.find_child(id+"__Pivot_ChargingHandle",true,false) as Node3D
		var action_hand := Node3D.new();charging.add_child(action_hand)
		action_hand.position=Vector3(.009,0,0);sockets["BoltHand"]=action_hand
		rest[action_hand]=action_hand.transform
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample("idle",0)

## v3: shaders on every surface, then the fitted optic and light at their sockets.
func _build_v3() -> void:
	_apply_materials(model)
	var f := _fit()
	if sockets.has("IronAim"): _iron_y = _local_chain(sockets["IronAim"]).origin.y
	var oid := String(f.get("optic", ""))
	var optic_sock: Node3D = sockets.get("OpticMount")
	var mid := String(f.get("mount", ""))
	if mid != "" and sockets.has("ScoutMount"):
		mount_node = _attach(String(RifleDB.attachment(mid).get("glb", "")), sockets["ScoutMount"])
		if mount_node != null: optic_sock = mount_node.find_child("*Socket_OpticMount", true, false) as Node3D
	var zid := String(f.get("muzzle", ""))
	if zid != "" and sockets.has("MuzzleThread"):
		muzzle_node = _attach(String(RifleDB.attachment(zid).get("glb", "")), sockets["MuzzleThread"])
		var mz := muzzle_node.find_child("*Socket_Muzzle", true, false) as Node3D if muzzle_node != null else null
		if mz != null: sockets["Muzzle"] = mz   # flash and smoke leave the end of the can
	if oid != "" and optic_sock != null:
		optic_node = _attach(String(RifleDB.attachment(oid).get("glb", "")), optic_sock)
		var eye := optic_node.find_child("*Socket_Eye", true, false) as Node3D if optic_node != null else null
		if eye != null: _eye_y = _local_chain(eye).origin.y
		var o := RifleDB.optic_for(weapon_id, f)
		var dotted := String(o.get("type", "")) in ["reflex", "tube_dot"]
		for mi: MeshInstance3D in optic_node.find_children("*", "MeshInstance3D", true, false):
			if not String(mi.name).contains("Lens"): continue
			var m := ShaderMaterial.new(); m.shader = LENS
			if String(mi.name).contains("DotLens") and dotted:
				m.set_shader_parameter("dot_on", 1.0); m.set_shader_parameter("dot_mrad", float(o.get("dot_mrad", 4.0)))
				dot_mats.append(m)
			elif String(o.get("type", "")) == "scope":
				m.set_shader_parameter("dark", 1.0)
			mi.material_override = m
	var lid := String(f.get("light", ""))
	var lsock: Node3D = sockets.get("LightMount", sockets.get("Muzzle"))
	if lid != "" and lsock != null:
		light_node = _attach(String(RifleDB.attachment(lid).get("glb", "")), lsock)
		var beam := light_node.find_child("*Socket_Beam", true, false) as Node3D if light_node != null else null
		if beam != null:
			var spec: Dictionary = RifleDB.attachment(lid).get("light", {})
			lamp = SpotLight3D.new(); lamp.name = "WeaponLamp"
			lamp.spot_range = float(spec.get("range_m", 30.0)); lamp.spot_angle = float(spec.get("angle_deg", 20.0)) * 0.5
			lamp.spot_angle_attenuation = 1.4; lamp.spot_attenuation = 0.9
			lamp.light_energy = float(spec.get("energy", 6.0)); lamp.light_color = Color(1.0, 0.95, 0.86)
			lamp.shadow_enabled = true; lamp.shadow_bias = 0.06; lamp.light_specular = 0.4
			var off := float(spec.get("offset_mrad", 0.0)) / 1000.0
			lamp.rotation = Vector3(off * 0.6, off, 0.0)   # taped lights point a little off the bore
			lamp.visible = false
			beam.add_child(lamp)
			add_beam(lamp)

func _local_chain(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY; var c: Node = n
	while c != null and c != model:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

## Instance an attachment GLB so its Socket_Mount lands on `sock` (it rides that socket's parent).
func _attach(glb: String, sock: Node3D) -> Node3D:
	if glb == "" or not ResourceLoader.exists(glb): return null
	var a := (load(glb) as PackedScene).instantiate() as Node3D
	var holder := Node3D.new(); holder.name = "Attach_" + String(a.name)
	sock.get_parent().add_child(holder); holder.transform = sock.transform
	holder.add_child(a)
	var mount := a.find_child("*Socket_Mount", true, false) as Node3D
	if mount != null: a.transform = _chain_to(mount, a).affine_inverse()
	_apply_materials(a)
	return holder

func _chain_to(n: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY; var c: Node = n
	while c != null and c != top:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _apply_materials(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).contains("Lens"):
			if mi.material_override == null:
				var g := ShaderMaterial.new(); g.shader = LENS; mi.material_override = g
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null: continue
			var key := String(src.resource_name).trim_prefix("W3_")
			var fam: Array = FAMILY.get(key, [1, .5, .5])
			var m := ShaderMaterial.new(); m.shader = SURFACE
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
			m.set_shader_parameter("family", int(fam[0])); m.set_shader_parameter("roughness_base", float(fam[1])); m.set_shader_parameter("metallic_base", float(fam[2]))
			if key == "brass" or key == "steel_bright": m.set_shader_parameter("wear", 0.2)
			if int(fam[0]) == 0 and root == model:
				var chk: Array = RifleDB.spec(weapon_id).get("checkering", [])
				if chk.size() > 0: m.set_shader_parameter("chk_a", Vector4(chk[0][0], chk[0][1], chk[0][2], 1.0))
				if chk.size() > 1: m.set_shader_parameter("chk_b", Vector4(chk[1][0], chk[1][1], chk[1][2], 1.0))
			if key == "lamp_lens":
				m = ShaderMaterial.new(); m.shader = LENS; m.set_shader_parameter("tint", Color(1, .97, .9, .9))
			mi.set_surface_override_material(s, m)

## Every frame (viewmodel): the dot's collimation axis (world) and the lamp state.
func update_sight(axis_world: Vector3, night: float) -> void:
	for m in dot_mats:
		m.set_shader_parameter("axis_world", axis_world)
		m.set_shader_parameter("brightness", lerpf(2.4, 0.35, night))   # daylight needs ~2.4x to read over bright snow
func set_lamp(on: bool) -> void:
	if lamp != null: lamp.visible = on
	set_lens_glow(light_node, on)

## Lit lamp lens + the beam shaft (weather-driven intensity is set by GameWorld via beam_k).
static func set_lens_glow(root: Node, on: bool) -> void:
	if root == null: return
	for mi: MeshInstance3D in root.find_children("*LampLens*", "MeshInstance3D", true, false):
		for s in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m != null: m.set_shader_parameter("glow", 6.0 if on else 0.0)
		var mo := mi.material_override as ShaderMaterial
		if mo != null: mo.set_shader_parameter("glow", 6.0 if on else 0.0)

const BEAM_SHADER := preload("res://world/shaders/light_beam.gdshader")
## A soft shaft along a SpotLight (only visible in snow / fog / haze; intensity driven each frame).
static func add_beam(spot: SpotLight3D) -> MeshInstance3D:
	var L := spot.spot_range * 0.85
	var cm := CylinderMesh.new(); cm.height = L; cm.top_radius = 0.02; cm.bottom_radius = L * tan(deg_to_rad(spot.spot_angle)) * 0.8
	cm.radial_segments = 24; cm.rings = 1; cm.cap_top = false; cm.cap_bottom = false
	var mi := MeshInstance3D.new(); mi.name = "BeamShaft"; mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new(); m.shader = BEAM_SHADER; m.set_shader_parameter("length_m", L); mi.material_override = m
	mi.rotation = Vector3(PI * 0.5, 0, 0); mi.position = Vector3(0, 0, -L * 0.5)
	spot.add_child(mi)
	return mi
## Through a scope the model steps aside but a fitted light must keep shining: hide meshes only.
var _meshes_shown := true
func set_meshes_visible(on: bool) -> void:
	if on == _meshes_shown or model == null: return
	_meshes_shown = on
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false): mi.visible = on
func has_lamp() -> bool: return lamp != null

## Socket position in model space at rest (z along the gun).
func socket_model(name: String) -> Vector3:
	var s: Node3D = sockets[name]
	return (_local_chain(s.get_parent() as Node3D) * (rest[s] as Transform3D)).origin if s.get_parent() != model else (rest[s] as Transform3D).origin

## Cross-section of the wood / synthetic (stock, fore-end, handguard) at model z, from the actual mesh:
## {c: centre (model space), hw, hh}. Used by the hand solver so palms and fingers sit on this gun's wood.
var _sections: Dictionary = {}
func section_at(z: float) -> Dictionary:
	var key := snappedf(z, .005)
	if _sections.has(key): return _sections[key]
	var pts: Array[Vector3] = []
	if model != null:
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null: continue
			var chain := _local_chain(mi)
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
				var mk := String(mat.resource_name).trim_prefix("W3_") if mat != null else ""
				if int(FAMILY.get(mk, [1])[0]) not in [0, 2] or mk == "rubber": continue
				var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for v in verts:
					var p := chain * v
					if absf(p.z - z) < .06: pts.append(p)
	# loft rings are a few cm apart: take the nearest rings (window grows until one is found)
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for win in [.012, .025, .04, .06]:
		for p in pts:
			if absf(p.z - z) > win: continue
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y)); hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		if lo.x < INF: break
	var out := {}
	if lo.x < INF:
		out = {"c": Vector3((lo.x + hi.x) * .5, (lo.y + hi.y) * .5, z), "hw": (hi.x - lo.x) * .5, "hh": (hi.y - lo.y) * .5}
	_sections[key] = out
	return out

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
	return weapon_id in ["north_service_rifle","expedition_rifle"] or (weapon_id == "compact_patrol_rifle" and not RifleDB.is_v3(weapon_id))
## Optic present (kit v2: Socket_Scope on the receiver; v3: a fitted scope).
func has_scope() -> bool:
	if RifleDB.is_v3(weapon_id): return String(RifleDB.optic(weapon_id).get("type", "")) == "scope"
	return sockets.has("Scope")
## Kit v2 aimed reflex sights: the painted lens becomes faintly tinted glass so the dot sits over the world.
func set_lens_see_through(on: bool) -> void:
	if lens == null: return
	if on and _lens_glass == null:
		_lens_glass = StandardMaterial3D.new(); _lens_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lens_glass.albedo_color = Color(1.0, .62, .25, .14); _lens_glass.roughness = .08; _lens_glass.metallic_specular = .9
	lens.material_override = _lens_glass if on else null
## Height of the sight line the eye looks along (rifle model space): optic eye axis, else irons.
func aim_height() -> float:
	if RifleDB.is_v3(weapon_id):
		if not is_nan(_eye_y): return _eye_y
		if not is_nan(_iron_y): return _iron_y
	if not sockets.has("Aim"): return .127
	return (rest[sockets["Aim"]] as Transform3D).origin.y
func is_bolt_action() -> bool: return RifleDB.action(weapon_id) == "bolt"
func is_lever_action() -> bool: return RifleDB.action(weapon_id) == "lever"
