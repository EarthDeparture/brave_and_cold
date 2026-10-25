class_name Opening
extends Node3D
## Window (or later door) of a building. Local +Z points OUTSIDE, -Z inside.
## Layers outside->in: glass (10 hp, see-through, cracks, breaks) -> up to 4 planks (inside) -> curtain (inside).
## Gameplay reads: passable(), open_fraction() (sight + light through it), blocks_sight().

const GLASS_HP := 10.0
const PLANK_HP := 40.0
const MAX_BOARDS := 4
const CURTAIN_HP := 15.0

signal event(name: String, pos: Vector3)

static var _glass_mat: ShaderMaterial
static var _wood_mat: StandardMaterial3D
static var _cloth_mat: ShaderMaterial
static var _grain: ImageTexture
static var _nail_mat: StandardMaterial3D

var kind := "window"
var w := 1.0
var h := 0.8
var glass_hp := GLASS_HP
var glass_broken := false
var cracked := false
var shards := false       # loose glass on the sill: cuts anyone climbing through until cleared
var boards := 0
var plank_hp := PLANK_HP
var curtain := false
var curtain_hp := CURTAIN_HP
var glow := 0.0          # interior light energy 0..~2 (set by the building)
var glow_col := Color(1.0, 0.62, 0.28)

var slots: Array = [null, null, null]   # zombies attacking from outside (3 max)

var _glass: MeshInstance3D
var _boards_root: Node3D
var _curtain_mi: MeshInstance3D
var _cloth_inst: ShaderMaterial
var _shards: Node3D
var _gmat: ShaderMaterial


const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base = vec3(0.42, 0.17, 0.14);
uniform float glow = 0.0;
void vertex() {
	VERTEX.z += sin(UV.x * 12.0 + TIME * 0.7) * 0.012 * (1.0 - UV.y * 0.5) + sin(UV.x * 31.0) * 0.006;
}
void fragment() {
	float fold = 0.5 + 0.5 * sin(UV.x * 34.0 + sin(UV.y * 2.5) * 1.2);
	float weave = 0.95 + 0.05 * sin(UV.x * 240.0) * sin(UV.y * 170.0);
	float top = 0.75 + 0.25 * smoothstep(0.0, 0.12, UV.y);   // gathered, darker at the rod
	ALBEDO = base * (0.62 + 0.5 * fold) * weave * top;
	ROUGHNESS = 1.0;
	NORMAL = normalize(NORMAL + vec3(cos(UV.x * 34.0) * 0.28, 0.0, 0.0));
	EMISSION = vec3(1.0, 0.55, 0.25) * glow * 0.03;
}
"""


const GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;
uniform vec3 tint = vec3(0.45, 0.55, 0.62);
uniform vec3 glow_col = vec3(1.0, 0.62, 0.28);
uniform float glow = 0.0;
uniform float crack = 0.0;
void fragment() {
	float f = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 3.0);
	vec2 p = UV - 0.5;
	float a = atan(p.y, p.x);
	float r = length(p * vec2(1.0, 0.8));
	float c = smoothstep(0.05, 0.0, abs(sin(a * 6.0))) * step(r, 0.46) + smoothstep(0.07, 0.0, abs(sin(r * 38.0 + a * 3.0))) * step(r, 0.30);
	c = clamp(c, 0.0, 1.0) * crack;
	ALBEDO = mix(mix(tint, glow_col * 0.45, clamp(glow * 0.6, 0.0, 0.9)), vec3(0.9), c);
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	float lit = FRONT_FACING ? glow : 0.0;  // lamp glow is only visible from outside
	vec2 q = (UV - vec2(0.5, 0.55)) * vec2(1.0, 1.4);
	float vig = 1.0 - 0.45 * smoothstep(0.1, 0.65, length(q));   // room is brightest in the middle, falls off at the frame
	vec3 warm = mix(glow_col, vec3(1.0, 0.8, 0.45), vig * 0.22);
	EMISSION = warm * lit * 0.3 * vig * (0.7 + 0.5 * UV.y);
	ALPHA = clamp(mix(0.10, 0.70, f) + c * 0.6 + min(0.7, lit * 0.28), 0.0, 0.92);
}
"""



## Shared weathered-plank material (procedural grain, no asset needed). Also used for door barricades.
static func wood_material() -> StandardMaterial3D:
	if _wood_mat == null:
		var img := Image.create(128, 16, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for y in 16:
			var row := 0.82 + 0.1 * sin(float(y) * 1.9) + rng.randf_range(-0.05, 0.05)
			for x in 128:
				var v := row + 0.08 * sin(float(x) * 0.09 + sin(float(y) * 0.6) * 2.0) + rng.randf_range(-0.03, 0.03)
				img.set_pixel(x, y, Color(v * 0.36, v * 0.26, v * 0.17))
		_grain = ImageTexture.create_from_image(img)
		_wood_mat = StandardMaterial3D.new()
		_wood_mat.albedo_texture = _grain
		_wood_mat.roughness = 0.95
	return _wood_mat


static func _nail_material() -> StandardMaterial3D:
	if _nail_mat == null:
		_nail_mat = StandardMaterial3D.new()
		_nail_mat.albedo_color = Color(0.16, 0.16, 0.17)
		_nail_mat.metallic = 0.8
		_nail_mat.roughness = 0.5
	return _nail_mat


static func make(parent: Node3D, p_kind: String, p_w: float, p_h: float, local_pos: Vector3, yaw_deg: float) -> Opening:
	var o := Opening.new()
	o.kind = p_kind
	o.w = p_w
	o.h = p_h
	o.position = local_pos
	o.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(o)
	o._build()
	return o


func _build() -> void:
	wood_material()
	if _glass_mat == null:
		_glass_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = GLASS_SHADER
		_glass_mat.shader = sh
		_cloth_mat = ShaderMaterial.new()
		var csh := Shader.new()
		csh.code = CLOTH_SHADER
		_cloth_mat.shader = csh
	_gmat = _glass_mat.duplicate() as ShaderMaterial
	_glass = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	_glass.mesh = q
	_glass.material_override = _gmat
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)
	_boards_root = Node3D.new()
	add_child(_boards_root)
	_shards = Node3D.new()
	add_child(_shards)
	_apply()


func inside_pos() -> Vector3:
	return to_global(Vector3(0, -h * 0.5, -0.9))


func outside_pos() -> Vector3:
	return to_global(Vector3(0, -h * 0.5, 0.9))


func center_world() -> Vector3:
	return global_position


## Attack slot bookkeeping: returns slot index 0..2 or -1 when all are taken by other zombies.
func reserve(z: Object) -> int:
	for i in slots.size():
		if slots[i] == z:
			return i
	for i in slots.size():
		var s = slots[i]
		if s == null or not is_instance_valid(s) or s.is_dead():
			slots[i] = z
			return i
	return -1


func release(z: Object) -> void:
	for i in slots.size():
		if slots[i] == z:
			slots[i] = null


func has_slot(z: Object) -> bool:
	for i in slots.size():
		var s = slots[i]
		if s == z or s == null or not is_instance_valid(s) or s.is_dead():
			return true
	return false


func slot_pos(i: int) -> Vector3:
	return to_global(Vector3((float(i) - 1.0) * 0.6, -h * 0.5, 0.8))


## Does the world-space segment a->b pass through this opening's rectangle?
func segment_through(a: Vector3, b: Vector3) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	if (la.z > 0.0) == (lb.z > 0.0):
		return false
	var t := la.z / (la.z - lb.z)
	var p := la + (lb - la) * t
	return absf(p.x) < w * 0.5 and absf(p.y) < h * 0.5


func passable() -> bool:
	return glass_broken and boards == 0


## Fraction of light and sight that gets through (glass is transparent; boards leave gaps; cloth is opaque).
func open_fraction() -> float:
	if curtain:
		return 0.0
	return 1.0 - 0.2 * float(boards)


func blocks_sight() -> bool:
	return open_fraction() < 0.5


## Damage from the outside. Returns the event: glass_hit/glass_break/board_hit/board_break/open.
func hit(dmg: float) -> String:
	if not glass_broken:
		glass_hp -= dmg
		if glass_hp <= 0.0:
			glass_broken = true
			cracked = true
			shards = true
			_apply()
			event.emit("glass_break", global_position)
			return "glass_break"
		if glass_hp < GLASS_HP * 0.6 and not cracked:
			cracked = true
			_apply()
		return "glass_hit"
	if boards > 0:
		plank_hp -= dmg
		if plank_hp <= 0.0:
			boards -= 1
			plank_hp = PLANK_HP
			_apply()
			event.emit("board_break", global_position)
			return "board_break"
		return "board_hit"
	return "open"


func smash() -> bool:
	if glass_broken:
		return false
	hit(GLASS_HP * 2.0)
	return true


func clear_shards() -> bool:
	if not shards:
		return false
	shards = false
	_apply()
	return true


func add_board() -> bool:
	if boards >= MAX_BOARDS:
		return false
	boards += 1
	plank_hp = PLANK_HP
	_apply()
	return true


func remove_board() -> bool:
	if boards <= 0:
		return false
	boards -= 1
	plank_hp = PLANK_HP
	_apply()
	return true


func hang_curtain() -> bool:
	if curtain:
		return false
	curtain = true
	curtain_hp = CURTAIN_HP
	_apply()
	return true


func remove_curtain() -> bool:
	if not curtain:
		return false
	curtain = false
	_apply()
	return true


func set_glow(e: float, col: Color = Color(1.0, 0.62, 0.28)) -> void:
	glow = e
	glow_col = col
	_apply()


func to_dict() -> Dictionary:
	return {"g": glass_broken, "gh": glass_hp, "b": boards, "c": curtain, "s": shards}


func from_dict(d: Dictionary) -> void:
	glass_broken = bool(d.get("g", false))
	shards = bool(d.get("s", glass_broken))
	glass_hp = float(d.get("gh", GLASS_HP))
	cracked = glass_broken or glass_hp < GLASS_HP * 0.6
	boards = clampi(int(d.get("b", 0)), 0, MAX_BOARDS)
	curtain = bool(d.get("c", false))
	_apply()


func _apply() -> void:
	if _gmat == null:
		return
	_glass.visible = not glass_broken
	_gmat.set_shader_parameter("crack", 1.0 if cracked else 0.0)
	_gmat.set_shader_parameter("glow", glow * open_fraction())
	_gmat.set_shader_parameter("glow_col", Vector3(glow_col.r, glow_col.g, glow_col.b))
	for c in _boards_root.get_children():
		c.queue_free()
	for i in boards:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var pl := w + 0.26 + 0.06 * float(i % 3)
		var ph := 0.15 + 0.015 * float((i * 2) % 3)
		bm.size = Vector3(pl, ph, 0.04)
		mi.mesh = bm
		mi.material_override = _wood_mat
		var yy := -h * 0.5 + h * (float(i) + 0.5) / float(MAX_BOARDS)
		mi.position = Vector3(float(((i * 13) % 5) - 2) * 0.015, yy, -0.08)
		mi.rotation.z = deg_to_rad(float((i * 37) % 7) - 3.0)
		for sx in [-1.0, 1.0]:
			var nl := MeshInstance3D.new()
			var nm := BoxMesh.new()
			nm.size = Vector3(0.035, 0.035, 0.012)
			nl.mesh = nm
			nl.material_override = _nail_material()
			nl.position = Vector3(sx * (pl * 0.5 - 0.07), 0.0, -0.026)
			mi.add_child(nl)
		_boards_root.add_child(mi)
	if curtain and _curtain_mi == null:
		_curtain_mi = MeshInstance3D.new()
		var cq := QuadMesh.new()
		cq.size = Vector2(w + 0.2, h + 0.2)
		cq.subdivide_width = 24
		cq.subdivide_depth = 1
		_curtain_mi.mesh = cq
		_cloth_inst = _cloth_mat.duplicate() as ShaderMaterial
		_curtain_mi.material_override = _cloth_inst
		_curtain_mi.position = Vector3(0, 0, -0.15)
		_curtain_mi.rotation.y = PI
		add_child(_curtain_mi)
		var rod := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.015
		rm.bottom_radius = 0.015
		rm.height = w + 0.4
		rod.mesh = rm
		rod.rotation.z = PI * 0.5
		rod.position = Vector3(0.0, h * 0.5 + 0.12, 0.02)   # curtain is rotated PI about Y: +z here = further inside
		rod.material_override = _wood_mat
		_curtain_mi.add_child(rod)
	if _curtain_mi != null:
		_curtain_mi.visible = curtain
		_cloth_inst.set_shader_parameter("glow", glow)
	if glass_broken and shards and _shards.get_child_count() == 0:
		for i in 6:
			var s := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.08 + 0.03 * (i % 3), 0.2 + 0.05 * (i % 2), 0.01)
			s.mesh = sm
			s.material_override = _gmat
			s.position = Vector3(-w * 0.45 + w * 0.9 * float(i) / 5.0, -h * 0.5 + 0.1, 0.0)
			s.rotation.z = deg_to_rad(10.0 * float((i * 5) % 7) - 25.0)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_shards.add_child(s)
	elif not (glass_broken and shards):
		for c in _shards.get_children():
			c.queue_free()
