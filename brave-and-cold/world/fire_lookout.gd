class_name FireLookout
extends Node3D
## Additive lookout. Upper surfaces are selected using the actor's foot height,
## so sharing an X/Z with the cabin never pulls ground actors upstairs.
## The existing cabin/collider arrays deliberately do not contain this building.

const MODEL_PATH := "res://assets/models/buildings/fire_lookout.glb"
const GEOMETRY_PATH := "res://data/fire_lookout_geometry.json"
const SITE_PATH := "res://data/lookout_site.json"
const DECK_Y := 8.64
const ROOM := Rect2(-2.7, -2.2, 5.4, 4.4)
const DECK := Rect2(-3.8, -3.3, 7.6, 6.6)
const CONNECTOR := Rect2(3.55, 1.8, 1.3, 1.0)
const STEP_RISE := 0.18
const STEP_RUN := 0.30
const FLIGHT_RISE := 2.16
const FLIGHT_RUN := 3.60
const FLIGHT_WIDTH := 1.10
const STAIR_LANES: Array[float] = [4.45, 5.80]
const SURFACE_REACH := 0.95
const SUPPORTS: Array[Vector2] = [Vector2(-2.95, -2.45), Vector2(2.95, -2.45), Vector2(-2.95, 2.45), Vector2(2.95, 2.45), Vector2(3.74, -2.2), Vector2(6.44, -2.2), Vector2(3.74, 2.2), Vector2(6.44, 2.2)]

var site: Dictionary = {}
var model: Node3D
var geometry: Dictionary = {}


func build(site_data: Dictionary, with_model: bool = true) -> void:
	site = site_data
	name = "FireLookout"
	var origin: Dictionary = site_data.get("origin", {})
	position = Vector3(float(origin.get("x", 0.0)), float(origin.get("y", 0.0)), float(origin.get("z", 0.0)))
	rotation.y = deg_to_rad(float(site_data.get("yaw_degrees", 0.0)))
	if FileAccess.file_exists(GEOMETRY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
		if parsed is Dictionary:
			geometry = parsed
	if with_model and ResourceLoader.exists(MODEL_PATH):
		var packed := load(MODEL_PATH) as PackedScene
		if packed != null:
			model = packed.instantiate() as Node3D
			add_child(model)
			_enable_model_vertex_colors()
	elif with_model:
		push_error("FireLookout: missing imported model at " + MODEL_PATH)
	set_meta("lookout_site_id", "mountain_fire_lookout")
	if with_model:
		var lamp := OmniLight3D.new()
		lamp.name = 'LookoutDeskLamp'
		lamp.position = Vector3(0.68, DECK_Y + 1.35, -1.50)
		lamp.light_color = Color(1.0, 0.78, 0.50)
		lamp.light_energy = 0.65
		lamp.omni_range = 4.0
		lamp.shadow_enabled = false
		add_child(lamp)


## Match the project's vertex-coloured building pipeline without modifying
## shared imported resources. Keep the GLB glass alpha/depth-prepass settings.
func _enable_model_vertex_colors() -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var imported := mesh.get_active_material(surface) as BaseMaterial3D
			if imported == null:
				continue
			var material := imported.duplicate() as BaseMaterial3D
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = false
			mesh.set_surface_override_material(surface, material)


## Height-aware floor query, in world space. Missing means leave existing terrain alone.
func floor_at_world(foot: Vector3, _terrain_height: float = NAN) -> float:
	var p := to_local(foot)
	var h := _floor_local(Vector2(p.x, p.z), p.y)
	return NAN if is_nan(h) else global_position.y + h


func _floor_local(p: Vector2, foot_y: float) -> float:
	var best := NAN
	if (DECK.has_point(p) or CONNECTOR.has_point(p)) and absf(foot_y - DECK_Y) <= SURFACE_REACH:
		best = DECK_Y
	for flight in range(4):
		var lane := STAIR_LANES[flight % 2]
		if absf(p.x - lane) > FLIGHT_WIDTH * 0.5 or p.y < -1.8 or p.y > 1.8:
			continue
		var progress := 1.8 - p.y if flight % 2 == 0 else p.y + 1.8
		var step := clampi(int(ceil(progress / STEP_RUN)), 1, 12)
		var h := float(flight) * FLIGHT_RISE + float(step) * STEP_RISE
		if absf(h - foot_y) <= SURFACE_REACH and (is_nan(best) or absf(h - foot_y) < absf(best - foot_y)):
			best = h
	for landing in range(1, 5):
		var z0 := -2.6 if landing % 2 == 1 else 1.8
		var bounds := Rect2(3.7, z0, 2.8, 0.8)
		var h := float(landing) * FLIGHT_RISE
		if bounds.has_point(p) and absf(h - foot_y) <= SURFACE_REACH and (is_nan(best) or absf(h - foot_y) < absf(best - foot_y)):
			best = h
	return best


func contains_room(eye: Vector3) -> bool:
	var p := to_local(eye)
	return ROOM.grow(-0.08).has_point(Vector2(p.x, p.z)) and p.y >= DECK_Y + 0.30 and p.y < DECK_Y + 2.65


## Point-based shelter API keeps under-tower actors outdoors.
func is_sheltered_at(eye: Vector3) -> bool:
	return contains_room(eye)


## The custom player controller does not use physics shapes. Resolve only the
## relevant elevation here; supports do not turn into walls around the footprint.
func resolve_at(candidate: Vector3, previous: Vector3, radius: float) -> Vector2:
	var p := to_local(candidate)
	var old := to_local(previous)
	var q := Vector2(p.x, p.z)
	if old.y < DECK_Y - 0.8:
		for center in SUPPORTS:
			var delta := q - center
			var rr := radius + 0.24
			if delta.length_squared() < rr * rr:
				q = center + (delta.normalized() if delta.length_squared() > 0.00001 else Vector2.RIGHT) * rr
	if absf(old.y - DECK_Y) < SURFACE_REACH:
		# Room walls stay solid at window height; the centered front doorway is open.
		var walls: Array[Rect2] = [
			Rect2(-2.79, -2.29, 0.18, 4.58), Rect2(2.61, -2.29, 0.18, 4.58),
			Rect2(-2.79, -2.29, 5.58, 0.18),
			Rect2(-2.79, 2.11, 2.24, 0.18), Rect2(0.55, 2.11, 2.24, 0.18),
			# Furniture bounds mirror the source asset (bed, desk, chair, stove,
			# provisions rack and inward-open door leaf).
			Rect2(-2.225, -2.0, 1.25, 2.0), Rect2(0.50, -1.70, 1.80, 0.70),
			Rect2(1.12, -0.85, 0.46, 0.65), Rect2(-1.94, 0.94, 0.58, 0.52),
			Rect2(1.375, 1.47, 1.05, 0.36), Rect2(-0.63, 1.13, 0.08, 1.10),
		]
		for wall in walls:
			q = _push_rect(q, wall.grow(radius), Vector2(old.x, old.z))
	# Guardrails: never allow the controller's terrain snap to make a player fall
	# through a stair side or deck edge. The base remains freely accessible.
	if old.y > 0.85 and not is_nan(_floor_local(Vector2(old.x, old.z), old.y)):
		if not _walkable_circle(q, old.y, radius * 0.8):
			q = Vector2(old.x, old.z)
	var result := to_global(Vector3(q.x, p.y, q.y))
	return Vector2(result.x, result.z)


func _walkable_circle(p: Vector2, y: float, radius: float) -> bool:
	if is_nan(_floor_local(p, y)):
		return false
	for offset: Vector2 in [Vector2(radius, 0.0), Vector2(-radius, 0.0), Vector2(0.0, radius), Vector2(0.0, -radius)]:
		if is_nan(_floor_local(p + offset, y)):
			return false
	return true


func _push_rect(p: Vector2, rect: Rect2, old: Vector2) -> Vector2:
	if not rect.has_point(p):
		return p
	var q := p
	if old.x <= rect.position.x:
		q.x = rect.position.x - 0.001
	elif old.x >= rect.end.x:
		q.x = rect.end.x + 0.001
	elif old.y <= rect.position.y:
		q.y = rect.position.y - 0.001
	elif old.y >= rect.end.y:
		q.y = rect.end.y + 0.001
	else:
		var distances: Array[float] = [p.x - rect.position.x, rect.end.x - p.x, p.y - rect.position.y, rect.end.y - p.y]
		var nearest := distances.find(distances.min())
		match nearest:
			0: q.x = rect.position.x - 0.001
			1: q.x = rect.end.x + 0.001
			2: q.y = rect.position.y - 0.001
			3: q.y = rect.end.y + 0.001
	return q


func deck_point() -> Vector3:
	return to_global(Vector3(0.0, DECK_Y, 2.75))


func approach_point(distance_m: float = 17.0) -> Vector3:
	return to_global(Vector3(10.0, 0.0, distance_m))


## A new snow-covered service track, draped on existing terrain after forest
## scatter. It never changes terrain, RoadNet, TrailNet or tree exclusions.
func build_access_path(terrain: Terrain3D) -> void:
	var path_data: Dictionary = site.get('path', {})
	var points: Array = path_data.get('points_world_xyz', path_data.get('points', []))
	if points.size() < 2:
		return
	var half_width := float(path_data.get('width_m', 2.4)) * 0.5
	var profile: Array[float] = [-half_width, -half_width * 0.62, -half_width * 0.36, half_width * 0.36, half_width * 0.62, half_width]
	var colors: Array[Color] = [Color(0.73, 0.79, 0.88), Color(0.45, 0.50, 0.57), Color(0.66, 0.70, 0.77), Color(0.66, 0.70, 0.77), Color(0.45, 0.50, 0.57), Color(0.73, 0.79, 0.88)]
	var vertices: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var row: Array = points[i]
		var p := Vector2(float(row[0]), float(row[2]))
		var a: Array = points[maxi(0, i - 1)]
		var b: Array = points[mini(points.size() - 1, i + 1)]
		var direction := Vector2(float(b[0]) - float(a[0]), float(b[2]) - float(a[2])).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		var cross := PackedVector3Array()
		for offset in profile:
			var xz := p + perpendicular * offset
			var y: float = terrain.data.get_height(Vector3(xz.x, 0.0, xz.y))
			if is_nan(y):
				y = float(row[1])
			cross.append(to_local(Vector3(xz.x, y + 0.075, xz.y)))
		vertices.append(cross)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size() - 1):
		for j in range(profile.size() - 1):
			for pair: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1)]:
				st.set_color(colors[pair.y])
				st.add_vertex(vertices[pair.x][pair.y])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = 'LookoutAccessTrack'
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


## Foundations adapt to the surveyed hillside rather than flattening it.
## All eight short piers share a single mesh/material draw.
func build_foundations(terrain: Terrain3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pier_count := 0
	for support in SUPPORTS:
		var point := to_global(Vector3(support.x, 0.0, support.y))
		var h: float = terrain.data.get_height(point)
		if is_nan(h):
			continue
		var bottom := h - global_position.y - 0.18
		var top := -0.25
		if top - bottom < 0.05:
			continue
		var pier := BoxMesh.new()
		pier.size = Vector3(0.60, top - bottom, 0.60)
		st.append_from(pier, 0, Transform3D(Basis(), Vector3(support.x, (bottom + top) * 0.5, support.y)))
		pier_count += 1
	if pier_count == 0:
		return
	var mesh := MeshInstance3D.new()
	mesh.name = 'SurveyedFoundationPiers'
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.43, 0.46, 0.49)
	material.roughness = 1.0
	mesh.material_override = material
	add_child(mesh)


## Surface identity plus Y is only stored for the new lookout. Old saves keep
## their original ground placement contract.
func saved_location(eye: Vector3, eye_height: float) -> Dictionary:
	var foot := eye - Vector3.UP * eye_height
	var surface_y := floor_at_world(foot)
	if is_nan(surface_y):
		return {}
	return {"structure": "mountain_fire_lookout", "eye_y": eye.y, "floor_y": surface_y}


func restore_location(player: Player, location: Dictionary) -> bool:
	if String(location.get("structure", "")) != "mountain_fire_lookout":
		return false
	var foot_y := float(location.get("floor_y", float(location.get("eye_y", player.position.y)) - player.eye_h))
	var h := floor_at_world(Vector3(player.position.x, foot_y, player.position.z))
	if is_nan(h):
		return false
	player.position.y = h + player.eye_h
	player._ready_ground = true
	player._last_pos = player.position
	return true
