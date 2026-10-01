class_name Hut
extends Node3D
## Small fishing hut. Open doorway (no door), same collision API as Cabin so player/zombies/wolves can use it.
## Local frame: +Z is the doorway side. Tackle box at TACKLE_LOCAL.

const MODEL := "res://assets/models/buildings/hut.glb"
const FLOOR_LOCAL_Y := 0.3
const HX := 1.6
const HZ := 1.3
const WALL_T := 0.12
const DOOR_HALF := 0.5
const RAMP_LEN := 1.2
const TACKLE_LOCAL := Vector3(1.15, 0.0, -0.9)

var floor_y := 0.0
var door_open := true       # starts open; the player can close it, zombies bash it (no boards on huts)
var door_boards := 0         # zombie code reads this; huts cannot be boarded
var door_hp := 60.0
var door_broken := false
var _door_pivot: Node3D
var _door_rect := Rect2(-DOOR_HALF, HZ - 0.04, 2 * DOOR_HALF, 0.08)
var crate_looted := false   # tackle box
var _walls: Array[Rect2] = []
var openings: Array[Opening] = []


## Candidate sites near the road: [{x, z, yaw}]. Terrain-only checks so it can run before the forest is built.
static func find_sites(terrain: Terrain3D, road: RoadNet, water: Image, count: int, min_gap := 140.0) -> Array:
	var out: Array = []
	var pts := road.points
	if pts.size() < 40:
		return out
	var i := 30
	while i < pts.size() - 10 and out.size() < count:
		var rp: Vector2 = pts[i]
		var rq: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var d := (rq - rp).normalized()
		var nrm := Vector2(-d.y, d.x)
		var best := {}
		var best_s := 1e9
		for off in [24.0, -24.0, 32.0, -32.0, 42.0, -42.0]:
			var c: Vector2 = rp + nrm * off
			var s := _score(terrain, road, water, c.x, c.y)
			if s < best_s:
				best_s = s
				best = {"x": c.x, "z": c.y, "yaw": rad_to_deg(atan2(rp.x - c.x, rp.y - c.y))}
		if not best.is_empty() and best_s < 1e8:
			var ok := true
			for o in out:
				if Vector2(o["x"], o["z"]).distance_to(Vector2(best["x"], best["z"])) < min_gap:
					ok = false
			if ok:
				out.append(best)
		i += 28
	return out


static func _score(terrain: Terrain3D, road: RoadNet, water: Image, x: float, z: float) -> float:
	if road.is_near(x, z, 6.0):
		return 1e9
	var hs: Array[float] = []
	for ox in [-3.0, 0.0, 3.0]:
		for oz in [-3.0, 0.0, 3.0]:
			var px: float = x + ox
			var pz: float = z + oz
			var wx := int(px) + 1024
			var wz := int(pz) + 1024
			if wx < 0 or wz < 0 or wx >= water.get_width() or wz >= water.get_height():
				return 1e9
			if water.get_pixel(wx, wz).r > 0.5:
				return 1e9
			var h: float = terrain.data.get_height(Vector3(px, 0, pz))
			if is_nan(h):
				return 1e9
			hs.append(h)
	var rng: float = float(hs.max()) - float(hs.min())
	if rng > 1.0:
		return 1e9
	# prefer lake shore: nearest water within 70 m
	var nearest := 70.0
	for r in [10.0, 20.0, 30.0, 45.0, 60.0]:
		for a in range(0, 360, 30):
			var wx2 := int(x + cos(deg_to_rad(a)) * r) + 1024
			var wz2 := int(z + sin(deg_to_rad(a)) * r) + 1024
			if wx2 >= 0 and wz2 >= 0 and wx2 < water.get_width() and wz2 < water.get_height():
				if water.get_pixel(wx2, wz2).r > 0.5:
					nearest = minf(nearest, r)
	return nearest + rng * 20.0


func setup(terrain: Terrain3D, x: float, z: float, yaw_deg: float) -> bool:
	var hmax := -1e9
	for cx in [-1.9, 0.0, 1.9]:
		for cz in [-1.6, 0.0, 1.6]:
			var p := Vector3(x, 0, z) + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(cx, 0, cz)
			var h: float = terrain.data.get_height(p)
			if is_nan(h):
				return false
			hmax = maxf(hmax, h)
	position = Vector3(x, hmax - 0.1, z)
	rotation_degrees = Vector3(0, yaw_deg, 0)
	floor_y = position.y + FLOOR_LOCAL_Y
	var scene := load(MODEL) as PackedScene
	var model := scene.instantiate()
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
	_build_door()
	openings.append(Opening.make(self, "window", 0.75, 0.7, Vector3(HX, 1.7, -0.275), 90.0))  # gen_hut.py WIN
	return true


func _build_door() -> void:
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-DOOR_HALF, FLOOR_LOCAL_Y, HZ)
	add_child(_door_pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2 * DOOR_HALF, 1.95, 0.06)
	mi.mesh = bm
	mi.position = Vector3(DOOR_HALF, 0.975, 0.0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.20, 0.17, 0.13)
	dm.roughness = 0.95
	mi.material_override = dm
	_door_pivot.add_child(mi)
	_door_pivot.rotation.y = deg_to_rad(105.0)   # starts open


func state_dict() -> Dictionary:
	return {'looted': crate_looted, 'open': door_open, 'broken': door_broken, 'hp': door_hp}


func restore_state(d: Dictionary) -> void:
	crate_looted = bool(d.get('looted', false))
	door_broken = bool(d.get('broken', false))
	door_open = bool(d.get('open', true)) or door_broken
	door_hp = float(d.get('hp', 60.0))
	if _door_pivot != null:
		_door_pivot.rotation.y = deg_to_rad(120.0 if door_broken else (105.0 if door_open else 0.0))


func toggle_door() -> void:
	if door_broken:
		return
	door_open = not door_open
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(105.0) if door_open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func tackle_world_pos() -> Vector3:
	return to_global(Vector3(TACKLE_LOCAL.x, FLOOR_LOCAL_Y, TACKLE_LOCAL.z))


func noise_leak() -> float:
	return 1.0 if door_open else 0.45


func sight_line_open(a: Vector3, b: Vector3) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	if door_open and (la.z > HZ) != (lb.z > HZ):
		var t := (HZ - la.z) / (lb.z - la.z)
		var p := la + (lb - la) * t
		if absf(p.x) < DOOR_HALF and p.y > FLOOR_LOCAL_Y and p.y < 2.2:
			return true
	for o in openings:
		if o.open_fraction() >= 0.5 and o.segment_through(a, b):
			return true
	return false


func door_world_pos() -> Vector3:
	return to_global(Vector3(0.0, 0.0, HZ + 0.6))


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
	return absf(l.x) < HX - 0.15 and absf(l.y) < HZ - 0.15


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
	if absf(l.x) < HX - 0.15 and l.y > -HZ + 0.15 and l.y <= HZ - 0.15:
		return floor_y
	if absf(l.x) < DOOR_HALF + 0.2 and l.y > HZ - 0.15 and l.y <= HZ + 0.4:
		return floor_y
	if absf(l.x) < DOOR_HALF + 0.35 and l.y > HZ + 0.4 and l.y < HZ + 0.4 + RAMP_LEN:
		var t := (l.y - (HZ + 0.4)) / RAMP_LEN
		return lerpf(floor_y, terrain_h, t)
	return NAN
