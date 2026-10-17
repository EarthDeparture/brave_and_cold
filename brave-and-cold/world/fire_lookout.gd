class_name FireLookout
extends Node3D
## Additive lookout. Upper surfaces are selected using the actor's foot height,
## so sharing an X/Z with the cabin never pulls ground actors upstairs.
## The existing cabin/collider arrays deliberately do not contain this building.

const MODEL_PATH := "res://assets/models/buildings/fire_lookout.glb"
const GEOMETRY_PATH := "res://data/fire_lookout_geometry.json"
const SITE_PATH := "res://data/lookout_site.json"
const DECK_Y := 21.41
const FLIGHT_COUNT := 10
const STEPS_PER_FLIGHT := 12
const LEGACY_DECK_Y := 8.64
const LEGACY_FLIGHT_COUNT := 4
const ROOM := Rect2(-2.7, -2.2, 5.4, 4.4)
const DECK := Rect2(-3.8, -3.3, 7.6, 6.6)
const CONNECTOR := Rect2(3.55, 1.8, 1.3, 1.0)
const STEP_RISE := DECK_Y / float(FLIGHT_COUNT * STEPS_PER_FLIGHT)
const STEP_RUN := 0.30
const FLIGHT_RISE := DECK_Y / float(FLIGHT_COUNT)
const FLIGHT_RUN := 3.60
const FLIGHT_WIDTH := 1.10
const RAIL_END_INSET := .32
const STAIR_LANES: Array[float] = [4.45, 5.80]
const SURFACE_REACH := 0.95
const SUPPORTS: Array[Vector2] = [Vector2(-2.95, -2.45), Vector2(2.95, -2.45), Vector2(-2.95, 2.45), Vector2(2.95, 2.45), Vector2(3.40, -2.90), Vector2(6.80, -2.90), Vector2(3.40, 2.90), Vector2(6.80, 2.90)]

signal event(kind: String, point: Vector3)
static var instances: Array[FireLookout] = []
const STOVE_CENTER := Vector3(-1.65, 0, 1.20)
const STOVE_YAW := 2.199592613210329
var door_open := false
var door_broken := false
var door_hp := 100.0
var door_boards := 0
var door_plank_hp := 40.0
var _door_pivot: Node3D
var _door_planks: Node3D
var _door_tween: Tween

var detail_enabled := false
var route_dressing_enabled := false
var site: Dictionary = {}
var access_ribbon:WalkRibbon3D
var model: Node3D
var geometry: Dictionary = {}
var _glass_mats: Array[BaseMaterial3D] = []
var _window_fill: OmniLight3D
var window_glow := 0.0   # last applied glow (tests / captures)
const WINDOW_GLOW := Color(1.0, 0.64, 0.36)


func build(site_data: Dictionary, with_model: bool = true) -> void:
	site = site_data
	if not instances.has(self): instances.append(self)
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
	_build_door()
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
		# Wide warm fill near the ceiling: lights the cab walls so the windows read as
		# lit squares from the valley at dusk (only on while the eye is outside the cab).
		_window_fill = OmniLight3D.new(); _window_fill.name = "LookoutWindowFill"
		_window_fill.position = Vector3(0.0, DECK_Y + 2.1, 0.0)
		_window_fill.light_color = Color(1.0, 0.72, 0.45); _window_fill.light_energy = 0.0
		_window_fill.omni_range = 4.6; _window_fill.shadow_enabled = false
		add_child(_window_fill)
		if detail_enabled:
			var panel:Node3D=(load("res://assets/route_detail/field_power_panel.glb") as PackedScene).instantiate()
			panel.name="TechnicianPowerPanel"
			panel.position=Vector3(0,DECK_Y+.12,-2.08)
			add_child(panel)
			for mesh:MeshInstance3D in panel.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=140.0

		if detail_enabled and route_dressing_enabled:
			var bench:Node3D=(load("res://assets/route_detail/lookout_workbench.glb") as PackedScene).instantiate()
			bench.name="TechnicianWorkbench";bench.position.y=DECK_Y;add_child(bench)
			for mesh:MeshInstance3D in bench.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=90


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
			if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				material.emission_enabled = true; material.emission = WINDOW_GLOW
				material.emission_energy_multiplier = 0.0
				_glass_mats.append(material)
			if detail_enabled and mesh.name in ["lookout_boards", "lookout_timber", "lookout_interior", "lookout_trim", "lookout_door"]:
				var wood := ShaderMaterial.new()
				wood.shader = preload("res://world/shaders/winter_timber.gdshader")
				wood.set_shader_parameter("grain", preload("res://assets/environment_detail/textures/timber_alb.png"))
				mesh.set_surface_override_material(surface, wood)


## Warm cab windows from outside at dusk / night: desk lamp always, stronger with the
## stove lit. Zero while `eye` is inside the cab so the view out stays clear glass.
func set_night(night: float, fire_lit: bool, eye: Vector3) -> void:
	var k := 0.0 if contains_room(eye) else clampf(night, 0.0, 1.0) * (0.6 + (0.4 if fire_lit else 0.0))
	if is_equal_approx(k, window_glow): return
	window_glow = k
	for m in _glass_mats: m.emission_energy_multiplier = 1.8 * k
	if _window_fill != null: _window_fill.light_energy = 1.1 * k


## Height-aware floor query, in world space. Missing means leave existing terrain alone.
func floor_at_world(foot: Vector3, _terrain_height: float = NAN) -> float:
	var p := to_local(foot)
	var h := _floor_local(Vector2(p.x, p.z), p.y)
	return NAN if is_nan(h) else global_position.y + h


func _floor_local(p: Vector2, foot_y: float, deck_y: float = DECK_Y, flight_count: int = FLIGHT_COUNT, surface_reach: float = SURFACE_REACH) -> float:
	var best := NAN
	var flight_rise := deck_y / float(flight_count)
	var step_rise := flight_rise / float(STEPS_PER_FLIGHT)
	if (DECK.has_point(p) or CONNECTOR.has_point(p)) and absf(foot_y - deck_y) <= surface_reach:
		best = deck_y
	for flight in range(flight_count):
		var lane := STAIR_LANES[flight % 2]
		if absf(p.x - lane) > FLIGHT_WIDTH * 0.5 or p.y < -1.8 or p.y > 1.8:
			continue
		var progress := 1.8 - p.y if flight % 2 == 0 else p.y + 1.8
		var step := clampi(int(ceil(progress / STEP_RUN)), 1, STEPS_PER_FLIGHT)
		var h := float(flight) * flight_rise + float(step) * step_rise
		if absf(h - foot_y) <= surface_reach and (is_nan(best) or absf(h - foot_y) < absf(best - foot_y)):
			best = h
	for landing in range(1, flight_count + 1):
		var z0 := -2.6 if landing % 2 == 1 else 1.8
		var bounds := Rect2(3.7, z0, 2.8, 0.8)
		var h := float(landing) * flight_rise
		if bounds.has_point(p) and absf(h - foot_y) <= surface_reach and (is_nan(best) or absf(h - foot_y) < absf(best - foot_y)):
			best = h
	return best


## Eye-height surface: identical to floor_at_world except on a flight, where the
## 12 treads become one eased ramp (C1 at both landings). The camera follows this;
## feet, footsteps and dropped items keep the real stepped treads.
const CAMERA_EASE_RUN := 0.45
func camera_floor_at_world(foot: Vector3, _terrain_height: float = NAN) -> float:
	var p := to_local(foot)
	var stepped := _floor_local(Vector2(p.x, p.z), p.y)
	if is_nan(stepped): return NAN
	if p.z >= -1.8 and p.z <= 1.8:
		for flight in range(FLIGHT_COUNT):
			if absf(p.x - STAIR_LANES[flight % 2]) > FLIGHT_WIDTH * 0.5: continue
			var base := float(flight) * FLIGHT_RISE
			if stepped < base + STEP_RISE * 0.5 or stepped > base + FLIGHT_RISE + 0.001: continue
			var x := clampf(1.8 - p.z if flight % 2 == 0 else p.z + 1.8, 0.0, FLIGHT_RUN)
			# Shift half a tread so the ramp runs through the tread centres (camera within
			# +/-0.20 m of the stepped floor); the 1.7 cm entry offset is below perception.
			return global_position.y + base + FLIGHT_RISE * eased_run(x + STEP_RUN * 0.5)
	return global_position.y + stepped

## 0..1 along a flight: linear middle, quadratic ease over CAMERA_EASE_RUN at each end.
static func eased_run(x: float) -> float:
	var b := CAMERA_EASE_RUN; var l := FLIGHT_RUN
	x = clampf(x, 0.0, l)
	if x < b: return x * x / (2.0 * b * (l - b))
	if x > l - b: return 1.0 - (l - x) * (l - x) / (2.0 * b * (l - b))
	return (x - b * 0.5) / (l - b)

## Heavy-boot pace on the flights only; landings, deck and ground keep full speed.
## Applies to walking and sprinting alike (Player blends it so entry is not a step).
const STAIR_SPEED_MULT := 0.75
func speed_mult_at(foot: Vector3) -> float:
	var p := to_local(foot)
	if p.z < -1.8 or p.z > 1.8: return 1.0
	var stepped := _floor_local(Vector2(p.x, p.z), p.y)
	if is_nan(stepped): return 1.0
	for flight in range(FLIGHT_COUNT):
		if absf(p.x - STAIR_LANES[flight % 2]) > FLIGHT_WIDTH * 0.5: continue
		var base := float(flight) * FLIGHT_RISE
		if stepped > base + STEP_RISE * 0.5 and stepped < base + FLIGHT_RISE - STEP_RISE * 0.5: return STAIR_SPEED_MULT
	return 1.0


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
	var original:=q
	if old.y < DECK_Y - 0.8:
		for center in SUPPORTS:
			var delta := q - center
			var rr := radius + 0.24
			if delta.length_squared() < rr * rr:
				q = center + (delta.normalized() if delta.length_squared() > 0.00001 else Vector2.RIGHT) * rr
	if absf(old.y - DECK_Y) < SURFACE_REACH:
		# Room walls stay solid; the moving door uses its actual hinge angle below.
		var walls: Array[Rect2] = [
			Rect2(-2.79, -2.29, 0.18, 4.58), Rect2(2.61, -2.29, 0.18, 4.58),
			Rect2(-2.79, -2.29, 5.58, 0.18),
			Rect2(-2.79, 2.11, 2.24, 0.18), Rect2(0.55, 2.11, 2.24, 0.18),
			# Furniture bounds mirror the source asset (bed, desk, chair, stove,
			# provisions rack and inward-open door leaf).
			Rect2(-2.225, -2.0, 1.25, 2.0), Rect2(0.50, -1.70, 1.80, 0.70),
			Rect2(1.12, -1.00, 0.46, 0.08), # tucked chair: only the backrest stands proud of the desk
			Rect2(1.375, 1.47, 1.05, 0.36),
		]
		for wall in walls:
			q = _push_rect(q, wall.grow(radius), Vector2(old.x, old.z))
		var turn := Basis(Vector3.UP, STOVE_YAW)
		var stove_p := turn.inverse() * (Vector3(q.x,0,q.y)-STOVE_CENTER)
		var stove_old := turn.inverse() * (Vector3(old.x,0,old.z)-STOVE_CENTER)
		var stove_q := _push_rect(Vector2(stove_p.x,stove_p.z),Rect2(-.30,-.275,.60,.55).grow(radius),Vector2(stove_old.x,stove_old.z))
		if stove_q != Vector2(stove_p.x,stove_p.z):
			var moved := STOVE_CENTER+turn*Vector3(stove_q.x,0,stove_q.y)
			q=Vector2(moved.x,moved.z)
		var door_q := resolve_door_at(to_global(Vector3(q.x,p.y,q.y)),previous,radius)
		var door_local := to_local(Vector3(door_q.x,candidate.y,door_q.y))
		q=Vector2(door_local.x,door_local.z)
	# Resolve the actual deck rails with a 1 mm contact skin. This prevents
	# sub-tolerance input steps accumulating through a rail over many frames.
	# The bridge aperture remains open; distant/free movement stays exact.
	if absf(old.y-DECK_Y)<SURFACE_REACH:
		var rails: Array = [
			[Vector2(-3.8,-3.3),Vector2(3.8,-3.3)],
			[Vector2(-3.8,-3.3),Vector2(-3.8,3.3)],
			[Vector2(-3.8,3.3),Vector2(3.8,3.3)],
			[Vector2(3.8,-3.3),Vector2(3.8,1.8)],
			[Vector2(3.8,2.8),Vector2(3.8,3.3)]]
		for rail: Array in rails:
			var clipped := RoadNet._rail_contact(Vector2(old.x,old.z),q,rail[0],rail[1],radius)
			if clipped.distance_squared_to(q)>.0000000001:
				q=clipped+(clipped-q).normalized()*.001
	# Match the authored handrails, not an eroded rectangle of floor. Requiring
	# the whole capsule footprint to have floor made the turn's open inner edge
	# an invisible wall and cancelled even tangential input.
	q = _stair_rail_slide(Vector2(old.x,old.z), q, old.y, radius)
	if old.y > .85 and not is_nan(_floor_local(Vector2(old.x,old.z),old.y)):
		q = _floor_slide(Vector2(old.x,old.z),q,old.y)
	if q==original:return Vector2(candidate.x,candidate.z)
	var result := to_global(Vector3(q.x, p.y, q.y))
	return Vector2(result.x, result.z)


func _stair_rail_slide(old: Vector2, candidate: Vector2, y: float, radius: float) -> Vector2:
	var rails: Array = []
	# Join the two close inner rail ends into one nose. Separate overlapping
	# rounded caps form a pocket that can cancel both components of a turn.
	for landing in range(1,FLIGHT_COUNT):
		if absf(y-landing*FLIGHT_RISE)>SURFACE_REACH: continue
		var z: float = (-1 if landing%2==1 else 1)*(1.8-RAIL_END_INSET)
		rails.append([Vector2(STAIR_LANES[0]+.56,z),Vector2(STAIR_LANES[1]-.56,z)])
	for flight in FLIGHT_COUNT:
		var lane: float = STAIR_LANES[flight%2]
		var progress := clampf(1.8-old.y if flight%2==0 else old.y+1.8,0,FLIGHT_RUN)
		var h := flight*FLIGHT_RISE+progress/FLIGHT_RUN*FLIGHT_RISE
		if absf(y-h)>SURFACE_REACH: continue
		for side: float in [-.56,.56]:
			rails.append([Vector2(lane+side,-1.8+RAIL_END_INSET),Vector2(lane+side,1.8-RAIL_END_INSET)])
	for landing in range(1,FLIGHT_COUNT+1):
		if absf(y-landing*FLIGHT_RISE)>SURFACE_REACH: continue
		var z: float = -2.20 if landing%2==1 else 2.20
		rails.append([Vector2(3.63,z+signf(z)*.44),Vector2(6.57,z+signf(z)*.44)])
		rails.append([Vector2(6.57,z-.44),Vector2(6.57,z+.44)])
		if landing<FLIGHT_COUNT:
			rails.append([Vector2(3.63,z-.44),Vector2(3.63,z+.44)])
	var q := candidate
	for rail: Array in rails:
		var clipped := RoadNet._rail_contact(old,q,rail[0],rail[1],radius+.0375)
		if clipped.distance_squared_to(q)>1e-10:
			q=clipped+(clipped-q).normalized()*.001
	return q


## Feet need support; the body is constrained by the actual rails. When a
## corner has no floor, keep the component along its edge rather than stopping.
func _floor_slide(old: Vector2, candidate: Vector2, y: float) -> Vector2:
	if not is_nan(_floor_local(candidate,y)): return candidate
	var best := old
	for x_first: bool in [true,false]:
		var q := old
		for axis: int in ([0,1] if x_first else [1,0]):
			var target := q; target[axis]=candidate[axis]
			if not is_nan(_floor_local(target,y)):
				q=target
			else:
				var lo := 0.0; var hi := 1.0
				for iteration in 12:
					var mid := (lo+hi)*.5
					if is_nan(_floor_local(q.lerp(target,mid),y)): hi=mid
					else: lo=mid
				q=q.lerp(target,lo)
		if q.distance_squared_to(candidate)<best.distance_squared_to(candidate): best=q
	return best


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
var access_material:ShaderMaterial
func build_access_path(terrain: Terrain3D) -> void:
	var path_data: Dictionary = site.get('path', {})
	var points: Array = path_data.get('points_world_xyz', path_data.get('points', [])).duplicate()
	# The survey's final sample overshoots the compound and doubles back 0.85m.
	# Trim that redundant endpoint only in the ribbon to prevent folded faces.
	if points.size()>2:
		var a:Array=points[-3];var b:Array=points[-2];var c:Array=points[-1]
		if Vector2(b[0]-a[0],b[2]-a[2]).dot(Vector2(c[0]-b[0],c[2]-b[2]))<0 and Vector2(c[0]-b[0],c[2]-b[2]).length()<1.0:points.remove_at(points.size()-2)
	if points.size() < 2:
		return
	var half_width := float(path_data.get('width_m', 2.4)) * 0.5
	var profile: Array[float] = [-half_width, -half_width*.85, -half_width*.62, -half_width*.34, 0.0, half_width*.34, half_width*.62, half_width*.85, half_width]
	var distances:Array[float]=[0.0]
	for i in range(1,points.size()):
		var a:Array=points[i-1];var b:Array=points[i]
		distances.append(distances[-1]+Vector2(b[0]-a[0],b[2]-a[2]).length())
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
			var lift:=lerpf(.075,.005,smoothstep(.55,1.0,absf(offset)/half_width))
			cross.append(to_local(Vector3(xz.x, y + lift, xz.y)))
		vertices.append(cross)
	access_ribbon=WalkRibbon3D.new()
	access_ribbon.name="LookoutAccessSurface"
	add_child(access_ribbon)
	var world_rows:Array=[]
	for row in vertices:
		var points_world:Array=[]
		for point in row:points_world.append(to_global(point))
		world_rows.append(points_world)
	access_ribbon.walk_surface.build(world_rows)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size() - 1):
		for j in range(profile.size() - 1):
			for pair: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1)]:
				st.set_uv(Vector2(profile[pair.y],distances[pair.x]))
				st.add_vertex(vertices[pair.x][pair.y])
	st.index();st.generate_normals();st.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.name = 'LookoutAccessTrack'
	mesh.mesh = st.commit()
	access_material=WinterPathMaterial.create(half_width,distances[-1])
	mesh.material_override=access_material
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
	return {"structure": "mountain_fire_lookout", "eye_y": eye.y, "floor_y": surface_y, "deck_height": DECK_Y}


func restore_location(player: Player, location: Dictionary) -> bool:
	if String(location.get("structure", "")) != "mountain_fire_lookout":
		return false
	var foot_y := float(location.get("floor_y", float(location.get("eye_y", player.position.y)) - player.eye_h))
	var saved_deck := float(location.get("deck_height", LEGACY_DECK_Y))
	var h := NAN
	if is_equal_approx(saved_deck, LEGACY_DECK_Y):
		# The original tower had four flights and no height metadata in saves.
		# Validate that old surface, then choose the new surface closest to the
		# normalized elevation at the same X/Z. Overlapping stair lanes must
		# choose a real tread, not an arbitrary scaled height between flights.
		var local := to_local(Vector3(player.position.x, foot_y, player.position.z))
		var xz := Vector2(local.x, local.z)
		var old_floor := _floor_local(xz, local.y, LEGACY_DECK_Y, LEGACY_FLIGHT_COUNT, 0.10)
		if not is_nan(old_floor):
			var new_floor := _floor_local(xz, old_floor * DECK_Y / LEGACY_DECK_Y, DECK_Y, FLIGHT_COUNT, INF)
			if not is_nan(new_floor):
				h = global_position.y + new_floor
	elif is_equal_approx(saved_deck, DECK_Y):
		h = floor_at_world(Vector3(player.position.x, foot_y, player.position.z))
	if is_nan(h):
		return false
	player.position.y = h + player.eye_h
	player._ready_ground = true
	player._last_pos = player.position
	return true


## Head clearance for the custom controller; does not affect the walking floor.
func ceiling_at_world(eye: Vector3) -> float:
	var p := to_local(eye)
	if not ROOM.has_point(Vector2(p.x, p.z)) or p.y < DECK_Y: return INF
	# Lowest rafter/header underside; conservative full-room head clearance.
	return global_position.y + DECK_Y + 2.505


func bed_world_pos() -> Vector3:
	return to_global(Vector3(-1.60, DECK_Y + .75, -1.0))
func bed_lie_pos() -> Vector3:
	return to_global(Vector3(-1.60, DECK_Y + .90, -1.0))


func _exit_tree() -> void:
	instances.erase(self)

func _build_door() -> void:
	_door_pivot=Node3D.new();_door_pivot.name="LookoutDoorHinge"
	_door_pivot.position=Vector3(-.55,DECK_Y,2.19);add_child(_door_pivot)
	if model != null:
		var leaf:=model.find_child("lookout_door",true,false) as MeshInstance3D
		if leaf != null:leaf.reparent(_door_pivot,true)
	_door_planks=Node3D.new();_door_planks.name="LookoutDoorBoards";add_child(_door_planks)

func door_world_pos() -> Vector3:
	return to_global(Vector3(0,DECK_Y+1.15,2.19))

func door_inside_pos() -> Vector3:
	return to_global(Vector3(0,DECK_Y+1,1.29))

func toggle_door() -> void:
	if door_broken or door_boards>0:return
	door_open=not door_open
	if _door_tween != null and _door_tween.is_valid():_door_tween.kill()
	_door_tween=create_tween()
	_door_tween.tween_property(_door_pivot,"rotation:y",deg_to_rad(105) if door_open else 0.0,.5).set_trans(Tween.TRANS_SINE)

func add_door_board() -> bool:
	if door_open or door_broken or door_boards>=3:return false
	door_boards+=1;door_plank_hp=40;_build_door_planks();return true

func remove_door_board() -> bool:
	if door_boards<=0:return false
	door_boards-=1;door_plank_hp=40;_build_door_planks();return true

func _build_door_planks() -> void:
	for child:Node in _door_planks.get_children():child.free()
	for index:int in door_boards:
		var board:=MeshInstance3D.new();var box:=BoxMesh.new()
		box.size=Vector3(1.5,.17,.045);board.mesh=box;board.material_override=Opening.wood_material()
		board.position=Vector3(0,DECK_Y+.55+.60*index,1.97)
		board.rotation.z=deg_to_rad(float((index*5)%7)-3);_door_planks.add_child(board)

func bash_door(damage: float) -> void:
	if door_open or door_broken:return
	if door_boards>0:
		door_plank_hp-=damage
		if door_plank_hp<=0:
			door_boards-=1;door_plank_hp=40;_build_door_planks();event.emit("board_break",door_world_pos())
		return
	door_hp=maxf(0,door_hp-damage)
	if door_hp<=0:
		door_broken=true;door_open=true
		if _door_tween != null and _door_tween.is_valid():_door_tween.kill()
		_door_pivot.rotation.y=deg_to_rad(120)

func door_to_dict() -> Dictionary:
	return {"open":door_open,"broken":door_broken,"hp":door_hp,"boards":door_boards,"plank_hp":door_plank_hp}

func restore_door(saved: Dictionary) -> void:
	if _door_tween != null and _door_tween.is_valid():_door_tween.kill()
	door_hp=clampf(float(saved.get("hp",100)),0,100)
	door_broken=bool(saved.get("broken",false)) or door_hp<=0
	door_boards=0 if door_broken else clampi(int(saved.get("boards",0)),0,3)
	door_open=door_broken or (bool(saved.get("open",false)) and door_boards==0)
	door_plank_hp=clampf(float(saved.get("plank_hp",40)),.01,40)
	_door_pivot.rotation.y=deg_to_rad(120 if door_broken else (105 if door_open else 0))
	_build_door_planks()

func door_sweep_contains(foot: Vector3, radius: float) -> bool:
	var local:=to_local(foot)
	return absf(local.y-DECK_Y)<.8 and Rect2(-.89,1.10,1.45,1.13).grow(radius).has_point(Vector2(local.x,local.z))

func resolve_door_at(candidate: Vector3, previous: Vector3, radius: float) -> Vector2:
	var local:=to_local(previous)
	if local.y<DECK_Y-.8 or local.y>DECK_Y+2.05:return Vector2(candidate.x,candidate.z)
	# Door motion never refuses an action or shoves an occupying capsule.
	if _door_tween!=null and _door_tween.is_running():return Vector2(candidate.x,candidate.z)
	var a:=_door_pivot.global_position
	var b:=_door_pivot.to_global(Vector3(1.10,0,0))
	var q:=Vector2(candidate.x,candidate.z)
	var old:=Vector2(previous.x,previous.z)
	var aa:=Vector2(a.x,a.z);var bb:=Vector2(b.x,b.z)
	var edge:=bb-aa
	var closest:=aa+edge*clampf((old-aa).dot(edge)/edge.length_squared(),0,1)
	# Only genuinely embedded capsules may leave through the leaf. The normal
	# outside contact skin lies beyond this threshold and stays solid.
	if old.distance_to(closest)<radius+.04-.002:return q
	var clipped:=RoadNet._rail_contact(Vector2(previous.x,previous.z),q,Vector2(a.x,a.z),Vector2(b.x,b.z),radius+.04)
	return clipped+(clipped-q).normalized()*.001 if clipped.distance_squared_to(q)>1e-10 else q

static func resolve_doors(candidate: Vector3, previous: Vector3, radius: float) -> Vector2:
	var q:=Vector2(candidate.x,candidate.z)
	for tower:FireLookout in instances:
		q=tower.resolve_door_at(Vector3(q.x,candidate.y,q.y),previous,radius)
	return q

func door_ray_block(eye: Vector3, direction: Vector3, reach: float) -> float:
	var p:=_door_pivot.to_local(eye)
	var d:=_door_pivot.global_basis.inverse()*direction
	var near:=0.0;var far:=reach
	var lo:=Vector3(0,0,-.06);var hi:=Vector3(1.10,2.05,.06)
	for axis:int in 3:
		if absf(d[axis])<.00001:
			if p[axis]<lo[axis] or p[axis]>hi[axis]:return INF
		else:
			var t0:float=(lo[axis]-p[axis])/d[axis];var t1:float=(hi[axis]-p[axis])/d[axis]
			near=maxf(near,minf(t0,t1));far=minf(far,maxf(t0,t1))
			if near>far:return INF
	return near
