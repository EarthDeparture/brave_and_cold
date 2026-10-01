class_name Store
extends Node3D
## Roadside general store: bigger than the hut, door + 4 windows, three searchable spots (shelves, counter, crates).
## Same collider API as Cabin/Hut. Local frame: +Z is the door side.

const MODEL := "res://assets/models/buildings/store.glb"
const FLOOR_LOCAL_Y := 0.3
const HX := 3.2
const HZ := 2.3
const WALL_T := 0.12
const DOOR_HALF := 0.5
const RAMP_LEN := 1.4
## Standing spots (local xz) for the three searches.
const LOOT_SPOTS := [Vector3(-1.5, 0.0, -1.5), Vector3(0.95, 0.0, 0.2), Vector3(-1.8, 0.0, -0.5)]
const LOOT_NAMES := ["Search shelves", "Search counter", "Search crates"]

var floor_y := 0.0
var door_open := true
var door_boards := 0
var door_hp := 90.0
var door_broken := false
var looted := [false, false, false]
var _walls: Array[Rect2] = []
var openings: Array[Opening] = []
var _door_pivot: Node3D
var _fill: OmniLight3D
var _door_rect := Rect2(-DOOR_HALF, HZ - 0.04, 2 * DOOR_HALF, 0.08)


## Footprint test for planning (half extents incl. porch).
static func footprint() -> Vector2:
	return Vector2(HX + 0.5, HZ + 1.6)


func setup(terrain: Terrain3D, x: float, z: float, yaw_deg: float) -> bool:
	var hmax := -1e9
	for cx in [-HX, 0.0, HX]:
		for cz in [-HZ, 0.0, HZ]:
			var p := Vector3(x, 0, z) + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(cx, 0, cz)
			var h: float = terrain.data.get_height(p)
			if is_nan(h):
				return false
			hmax = maxf(hmax, h)
	position = Vector3(x, hmax - 0.1, z)
	rotation_degrees = Vector3(0, yaw_deg, 0)
	floor_y = position.y + FLOOR_LOCAL_Y
	var model := (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	var t := WALL_T
	_walls = [
		Rect2(-HX - t, -HZ - t, 2 * HX + 2 * t, 2 * t),
		Rect2(-HX - t, HZ - t, HX + t - DOOR_HALF, 2 * t),
		Rect2(DOOR_HALF, HZ - t, HX + t - DOOR_HALF, 2 * t),
		Rect2(-HX - t, -HZ - t, 2 * t, 2 * HZ + 2 * t),
		Rect2(HX - t, -HZ - t, 2 * t, 2 * HZ + 2 * t),
	]
	_fill = OmniLight3D.new()   # window daylight fill, faded out at night by set_night()
	_fill.position = Vector3(0.0, FLOOR_LOCAL_Y + 2.0, 0.0)
	_fill.light_color = Color(0.82, 0.88, 1.0)
	_fill.light_energy = 0.9
	_fill.omni_range = 6.5
	_fill.shadow_enabled = false
	add_child(_fill)
	_build_door()
	openings.append(Opening.make(self, "window", 1.0, 0.8, Vector3(-1.9, 1.5, HZ), 0.0))
	openings.append(Opening.make(self, "window", 1.0, 0.8, Vector3(1.9, 1.5, HZ), 0.0))
	openings.append(Opening.make(self, "window", 1.0, 0.8, Vector3(HX, 1.5, 0.0), 90.0))
	openings.append(Opening.make(self, "window", 1.0, 0.8, Vector3(-HX, 1.5, 0.0), -90.0))
	return true


func _build_door() -> void:
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-DOOR_HALF, FLOOR_LOCAL_Y, HZ)
	add_child(_door_pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2 * DOOR_HALF, 2.0, 0.07)
	mi.mesh = bm
	mi.position = Vector3(DOOR_HALF, 1.0, 0.0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.20, 0.15, 0.11)
	dm.roughness = 0.95
	mi.material_override = dm
	_door_pivot.add_child(mi)
	_door_pivot.rotation.y = deg_to_rad(105.0)


func set_night(f: float) -> void:
	if _fill != null:
		_fill.light_energy = 0.9 * clampf(1.0 - f, 0.0, 1.0)


func toggle_door() -> void:
	if door_broken:
		return
	door_open = not door_open
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(105.0) if door_open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func state_dict() -> Dictionary:
	return {'looted': looted.duplicate(), 'open': door_open, 'broken': door_broken, 'hp': door_hp}


func restore_state(d: Dictionary) -> void:
	var lv: Array = d.get('looted', [])
	for i in range(mini(lv.size(), looted.size())):
		looted[i] = bool(lv[i])
	door_broken = bool(d.get('broken', false))
	door_open = bool(d.get('open', true)) or door_broken
	door_hp = float(d.get('hp', 90.0))
	if _door_pivot != null:
		_door_pivot.rotation.y = deg_to_rad(120.0 if door_broken else (105.0 if door_open else 0.0))


func loot_world_pos(i: int) -> Vector3:
	var s: Vector3 = LOOT_SPOTS[i]
	return to_global(Vector3(s.x, FLOOR_LOCAL_Y, s.z))


func noise_leak() -> float:
	return 1.0 if door_open else 0.45


func sight_line_open(a: Vector3, b: Vector3) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	if door_open and (la.z > HZ) != (lb.z > HZ):
		var t := (HZ - la.z) / (lb.z - la.z)
		var p := la + (lb - la) * t
		if absf(p.x) < DOOR_HALF and p.y > FLOOR_LOCAL_Y and p.y < 2.3:
			return true
	for o in openings:
		if o.open_fraction() >= 0.5 and o.segment_through(a, b):
			return true
	return false


func door_world_pos() -> Vector3:
	return to_global(Vector3(0.0, 0.0, HZ + 0.7))


func bash_door(dmg: float) -> void:
	if door_broken or door_open:
		return
	door_hp -= dmg
	_door_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.06) * 0.03
	if door_hp <= 0.0:
		door_broken = true
		door_open = true
		var tw := create_tween()
		tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(120.0), 0.25)


func to_local_xz(x: float, z: float) -> Vector2:
	var l := to_local(Vector3(x, position.y, z))
	return Vector2(l.x, l.z)


func contains_xz(x: float, z: float) -> bool:
	var l := to_local_xz(x, z)
	return absf(l.x) < HX - 0.2 and absf(l.y) < HZ - 0.2


func resolve(x: float, z: float, r: float) -> Vector2:
	var l := to_local_xz(x, z)
	var moved := false
	var rects := _walls.duplicate()
	if not door_open:
		rects.append(_door_rect)
	for w in rects:
		var cx := clampf(l.x, w.position.x, w.end.x)
		var cz := clampf(l.y, w.position.y, w.end.y)
		var d := l - Vector2(cx, cz)
		var dl := d.length()
		if dl < r:
			moved = true
			if dl > 0.0001:
				l = Vector2(cx, cz) + d / dl * r
			else:
				l.x += r
	if not moved:
		return Vector2(x, z)
	var wv := to_global(Vector3(l.x, 0.0, l.y))
	return Vector2(wv.x, wv.z)


func floor_at(x: float, z: float, terrain_h: float) -> float:
	var l := to_local_xz(x, z)
	if absf(l.x) < HX - 0.2 and l.y > -HZ + 0.2 and l.y <= HZ - 0.2:
		return floor_y
	if absf(l.x) < HX - 0.4 and l.y > HZ - 0.2 and l.y <= HZ + 1.5:
		return floor_y   # covered porch deck
	if absf(l.x) < DOOR_HALF + 0.2 and l.y > HZ - 0.2 and l.y <= HZ + 0.4:
		return floor_y
	if absf(l.x) < DOOR_HALF + 0.35 and l.y > HZ + 0.4 and l.y < HZ + 0.4 + RAMP_LEN:
		var t := (l.y - (HZ + 0.4)) / RAMP_LEN
		return lerpf(floor_y, terrain_h, t)
	return NAN
