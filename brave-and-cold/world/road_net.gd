class_name RoadNet
extends Node3D
## One plowed two-lane road through the valley. Route is planned with AStarGrid2D over the lidar slope/water/canopy
## masks (8 m cells), smoothed, then draped on the terrain as a ribbon (snow banks, slush, wheel ruts).
## Forest scatter asks is_near() to keep a clear corridor.

const CELL := 8
const STEP := 2.5
const CORRIDOR_HW := 12.0
# world-space waypoints (x, z); each is snapped to the nearest walkable cell
const WAYPOINTS: Array[Vector2] = [Vector2(-760, 420), Vector2(-420, 330), Vector2(-90, 205), Vector2(260, 40), Vector2(640, -240)]

# cross-section: lateral offset, vertex colour, lift above terrain
const XS: Array = [
	[-4.6, Color(0.74, 0.79, 0.90), 0.02],
	[-3.3, Color(0.80, 0.84, 0.93), 0.16],
	[-2.5, Color(0.50, 0.53, 0.60), 0.07],
	[-1.25, Color(0.15, 0.16, 0.20), 0.05],
	[0.0, Color(0.40, 0.42, 0.49), 0.06],
	[1.25, Color(0.15, 0.16, 0.20), 0.05],
	[2.5, Color(0.50, 0.53, 0.60), 0.07],
	[3.3, Color(0.80, 0.84, 0.93), 0.16],
	[4.6, Color(0.74, 0.79, 0.90), 0.02],
]

var map_dir := "res://data/maps/valley_b"
var half := 1024
var points: Array[Vector2] = []     # resampled centreline (world x, z)
var _hash: Dictionary = {}          # Vector2i(16 m cell) -> PackedVector2Array
var length_m := 0.0
var _water: Image
var _deck: Dictionary = {}   # point index -> deck height (bridge spans)
var bridges: Array = []      # [i0, i1] inclusive point-index ranges


func plan(dir: String = "res://data/maps/valley_b") -> void:
	map_dir = dir
	var meta = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/meta.json"))
	var size_m: int = int(meta["size_m"])
	half = size_m / 2
	var slope := MapIO.load_png(map_dir + "/slope.png")
	var canopy := MapIO.load_png(map_dir + "/canopy.png")
	var water := MapIO.load_png(map_dir + "/water_mask.png")
	slope.convert(Image.FORMAT_L8)
	canopy.convert(Image.FORMAT_L8)
	water.convert(Image.FORMAT_L8)
	_water = water
	var n := size_m / CELL
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, n, n)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cy in range(n):
		for cx in range(n):
			var px := cx * CELL + CELL / 2
			var py := cy * CELL + CELL / 2
			var sd := slope.get_pixel(px, py).r * 90.0
			var wet := false
			for d in [Vector2i(0, 0), Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, -4), Vector2i(0, 4)]:
				if water.get_pixel(clampi(px + d.x, 0, size_m - 1), clampi(py + d.y, 0, size_m - 1)).r > 0.5:
					wet = true
			if sd > 16.0:
				grid.set_point_solid(Vector2i(cx, cy), true)
				continue
			if wet:
				grid.set_point_weight_scale(Vector2i(cx, cy), 30.0)  # bridge only if there is no other way
				continue
			var w := 1.0 + pow(maxf(0.0, sd - 3.0), 2.0) * 0.18
			if canopy.get_pixel(px, py).r * 40.0 > 6.0:
				w += 1.2
			grid.set_point_weight_scale(Vector2i(cx, cy), w)
	var cells: Array[Vector2i] = []
	for wp in WAYPOINTS:
		cells.append(_snap(grid, Vector2i(int((wp.x + half) / CELL), int((wp.y + half) / CELL)), n))
	var path: Array[Vector2] = []
	for i in range(cells.size() - 1):
		var seg := grid.get_id_path(cells[i], cells[i + 1])
		if seg.is_empty():
			push_warning("RoadNet: no path %s -> %s" % [cells[i], cells[i + 1]])
			continue
		for c in seg:
			var wpos := Vector2(c.x * CELL + CELL / 2 - half, c.y * CELL + CELL / 2 - half)
			if path.is_empty() or path[path.size() - 1].distance_to(wpos) > 0.1:
				path.append(wpos)
	for _k in range(3):
		path = _chaikin(path)
	_resample(path)
	for p in points:
		var key := Vector2i(int(floor(p.x / 16.0)), int(floor(p.y / 16.0)))
		if not _hash.has(key):
			_hash[key] = []
		(_hash[key] as Array).append(p)
	_find_bridges()
	print("ROAD_PLAN points ", points.size(), " length_m ", int(length_m), " bridges ", bridges)


func _is_wet(x: float, z: float) -> bool:
	var px := clampi(int(x) + half, 0, _water.get_width() - 1)
	var py := clampi(int(z) + half, 0, _water.get_height() - 1)
	return _water.get_pixel(px, py).r > 0.5


func _find_bridges() -> void:
	bridges.clear()
	var i := 0
	while i < points.size():
		if _is_wet(points[i].x, points[i].y):
			var a := i
			while i < points.size() and _is_wet(points[i].x, points[i].y):
				i += 1
			bridges.append([maxi(a - 3, 0), mini(i + 2, points.size() - 1)])
		i += 1


func _snap(grid: AStarGrid2D, c: Vector2i, n: int) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, n - 1), clampi(c.y, 0, n - 1))
	for r in range(0, 40):
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue
				var q := Vector2i(c.x + ox, c.y + oy)
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				if not grid.is_point_solid(q):
					return q
	return c


func _chaikin(p: Array[Vector2]) -> Array[Vector2]:
	if p.size() < 3:
		return p
	var o: Array[Vector2] = [p[0]]
	for i in range(p.size() - 1):
		o.append(p[i] * 0.75 + p[i + 1] * 0.25)
		o.append(p[i] * 0.25 + p[i + 1] * 0.75)
	o.append(p[p.size() - 1])
	return o


func _resample(p: Array[Vector2]) -> void:
	points.clear()
	length_m = 0.0
	if p.size() < 2:
		return
	points.append(p[0])
	var carry := 0.0
	for i in range(p.size() - 1):
		var a := p[i]
		var b := p[i + 1]
		var seg := a.distance_to(b)
		var t := STEP - carry
		while t <= seg:
			points.append(a.lerp(b, t / seg))
			t += STEP
		carry = seg - (t - STEP)
		length_m += seg


func is_near(x: float, z: float, margin: float = CORRIDOR_HW) -> bool:
	var cx := int(floor(x / 16.0))
	var cz := int(floor(z / 16.0))
	var m2 := margin * margin
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var arr = _hash.get(Vector2i(cx + ox, cz + oz))
			if arr == null:
				continue
			for q: Vector2 in (arr as Array):
				if (q.x - x) * (q.x - x) + (q.y - z) * (q.y - z) < m2:
					return true
	return false


func build_mesh(terrain: Terrain3D) -> void:
	if points.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := XS.size()
	var rows: Array = []  # per point: Array of Vector3
	for br in bridges:
		var ha: float = terrain.data.get_height(Vector3(points[br[0]].x, 0.0, points[br[0]].y))
		var hb: float = terrain.data.get_height(Vector3(points[br[1]].x, 0.0, points[br[1]].y))
		var top := maxf(ha, hb) + 0.4
		for k in range(br[0], br[1] + 1):
			_deck[k] = lerpf(ha + 0.2, hb + 0.2, float(k - br[0]) / maxf(float(br[1] - br[0]), 1.0)) if false else top
	for i in range(points.size()):
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var row: Array = []
		for xs in XS:
			var q: Vector2 = points[i] + nrm * float(xs[0])
			var h: float = terrain.data.get_height(Vector3(q.x, 0.0, q.y))
			if is_nan(h):
				h = 0.0
			if _deck.has(i):
				h = float(_deck[i])
			row.append(Vector3(q.x, h + float(xs[2]), q.y))
		rows.append(row)
	for i in range(rows.size() - 1):
		for j in range(cols - 1):
			var v0: Vector3 = rows[i][j]
			var v1: Vector3 = rows[i][j + 1]
			var v2: Vector3 = rows[i + 1][j]
			var v3: Vector3 = rows[i + 1][j + 1]
			var c0: Color = XS[j][1]
			var c1: Color = XS[j + 1][1]
			# winding so normal faces up
			for tri in [[v0, c0, v2, c0, v1, c1], [v1, c1, v2, c0, v3, c1]]:
				for k in range(3):
					st.set_normal(Vector3.UP)
					st.set_color(tri[k * 2 + 1])
					st.add_vertex(tri[k * 2])
	var mi := MeshInstance3D.new()
	mi.name = "RoadMesh"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 900.0
	add_child(mi)
	for br in bridges:
		_build_bridge(int(br[0]), int(br[1]))
	print("ROAD_MESH tris ", (rows.size() - 1) * (cols - 1) * 2)


func _build_bridge(i0: int, i1: int) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.17, 0.12)
	wood.roughness = 1.0
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.45, 0.46, 0.5)
	concrete.roughness = 1.0
	var top: float = _deck[i0]
	for k in range(i0, i1):
		var a := points[k]
		var b := points[k + 1]
		var mid := (a + b) * 0.5
		var d := b - a
		var len := d.length()
		var yaw := atan2(-d.x, -d.y)
		var deck := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.6, 0.6, len + 0.05)
		deck.mesh = bm
		deck.position = Vector3(mid.x, top - 0.33, mid.y)
		deck.rotation.y = yaw
		deck.material_override = concrete
		add_child(deck)
		for sx in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.12, 0.14, len + 0.05)
			rail.mesh = rm
			rail.position = Vector3(mid.x, top + 1.0, mid.y) + Vector3(cos(yaw), 0.0, -sin(yaw)) * 3.2 * sx
			rail.rotation.y = yaw
			rail.material_override = wood
			add_child(rail)
			if k % 2 == 0:
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.14, 1.1, 0.14)
				post.mesh = pm
				post.position = Vector3(mid.x, top + 0.55, mid.y) + Vector3(cos(yaw), 0.0, -sin(yaw)) * 3.2 * sx
				post.material_override = wood
				add_child(post)
	# piers every ~10 m
	var kk := i0 + 2
	while kk < i1 - 1:
		var q := points[kk]
		var pier := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(5.0, 8.0, 0.9)
		pier.mesh = cm
		pier.position = Vector3(q.x, top - 4.6, q.y)
		var t := (points[kk + 1] - points[kk - 1])
		pier.rotation.y = atan2(-t.x, -t.y)
		pier.material_override = concrete
		add_child(pier)
		kk += 4


# ---------------------------------------------------------------- roadside props (poles, wires, signs)

const POLE_GAP := 45.0
const POLE_SIDE := 6.2
const POLE_H := 8.6


func build_props(terrain: Terrain3D) -> void:
	if points.size() < 4:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.20, 0.15, 0.11)
	wood.roughness = 1.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.45, 0.47, 0.5)
	steel.roughness = 0.6
	steel.metallic = 0.4
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.06, 0.06, 0.07)
	wire_mat.roughness = 0.8
	wire_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# ---- poles
	var pole_tops: Array[Vector3] = []
	var dist := 0.0
	var next_pole := 20.0
	for i in range(1, points.size() - 1):
		dist += points[i].distance_to(points[i - 1])
		if dist < next_pole:
			continue
		next_pole += POLE_GAP
		var t := (points[i + 1] - points[i - 1]).normalized()
		var nrm := Vector2(-t.y, t.x)
		var q := points[i] + nrm * POLE_SIDE
		var h: float = terrain.data.get_height(Vector3(q.x, 0.0, q.y))
		if is_nan(h):
			continue
		var pole := Node3D.new()
		pole.position = Vector3(q.x, h, q.y)
		pole.rotation.y = atan2(-t.x, -t.y)
		add_child(pole)
		var shaft := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.10
		cm.bottom_radius = 0.16
		cm.height = POLE_H
		cm.radial_segments = 8
		cm.rings = 1
		shaft.mesh = cm
		shaft.position.y = POLE_H * 0.5 - 0.3
		shaft.material_override = wood
		pole.add_child(shaft)
		for ay in [POLE_H - 0.9, POLE_H - 2.0]:
			var arm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.4 if ay > POLE_H - 1.5 else 1.8, 0.12, 0.12)
			arm.mesh = bm
			arm.position.y = ay
			arm.material_override = wood
			pole.add_child(arm)
			for sx in [-1.0, 1.0]:
				var ins := MeshInstance3D.new()
				var im := CylinderMesh.new()
				im.top_radius = 0.04
				im.bottom_radius = 0.07
				im.height = 0.18
				im.radial_segments = 6
				ins.mesh = im
				ins.position = Vector3(sx * (1.05 if ay > POLE_H - 1.5 else 0.8), ay + 0.14, 0.0)
				ins.material_override = steel
				pole.add_child(ins)
		pole_tops.append(pole.position)
		pole.set_meta("rot", pole.rotation.y)
	# ---- wires: catenary between consecutive poles, 3 conductors
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets := [[-1.05, POLE_H - 0.9 + 0.3], [1.05, POLE_H - 0.9 + 0.3], [0.0, POLE_H - 2.0 + 0.3]]
	for pi in range(pole_tops.size() - 1):
		var a: Vector3 = pole_tops[pi]
		var b: Vector3 = pole_tops[pi + 1]
		var dirn := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var span := dirn.length()
		if span > POLE_GAP * 1.8 or span < 1.0:
			continue
		dirn = dirn.normalized()
		var side := Vector3(-dirn.z, 0.0, dirn.x)
		for off in offsets:
			var prev := Vector3.ZERO
			for k in range(9):
				var u := float(k) / 8.0
				var p := a.lerp(b, u) + side * float(off[0]) + Vector3(0.0, float(off[1]) - 1.6 * 4.0 * u * (1.0 - u), 0.0)
				if k > 0:
					var w := 0.025
					st.set_normal(Vector3.UP)
					st.add_vertex(prev - Vector3(0, w, 0))
					st.add_vertex(prev + Vector3(0, w, 0))
					st.add_vertex(p + Vector3(0, w, 0))
					st.add_vertex(prev - Vector3(0, w, 0))
					st.add_vertex(p + Vector3(0, w, 0))
					st.add_vertex(p - Vector3(0, w, 0))
				prev = p
	var wm := MeshInstance3D.new()
	wm.mesh = st.commit()
	wm.material_override = wire_mat
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wm)
	# ---- signs every ~140 m, alternating sides, facing oncoming traffic from both directions (one-sided plates)
	var kinds := ["deer", "speed", "bear", "stop", "curve"]
	var sdist := 0.0
	var next_sign := 55.0
	var ki := 0
	for i in range(1, points.size() - 1):
		sdist += points[i].distance_to(points[i - 1])
		if sdist < next_sign:
			continue
		next_sign += 140.0
		var t2 := (points[i + 1] - points[i - 1]).normalized()
		var n2 := Vector2(-t2.y, t2.x)
		var side_s := -1.0 if ki % 2 == 0 else 1.0
		var q2 := points[i] + n2 * side_s * 5.4
		var h2: float = terrain.data.get_height(Vector3(q2.x, 0.0, q2.y))
		if is_nan(h2):
			continue
		_add_sign(kinds[ki % kinds.size()], Vector3(q2.x, h2, q2.y), atan2(-t2.x, -t2.y), wood, steel)
		ki += 1
	print("ROAD_PROPS poles ", pole_tops.size(), " signs ", ki)


func _add_sign(kind: String, pos: Vector3, yaw: float, wood: Material, steel: Material) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = yaw + (0.0 if randi() % 2 == 0 else PI)
	add_child(s)
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 2.6
	cm.radial_segments = 6
	cm.rings = 1
	post.mesh = cm
	post.position.y = 1.3
	post.material_override = steel
	s.add_child(post)
	var plate := MeshInstance3D.new()
	var pm: Mesh
	var col := Color(0.95, 0.78, 0.08)
	var txt := ""
	var fs := 90
	var rot_z := 0.0
	match kind:
		"stop":
			var c := CylinderMesh.new()
			c.top_radius = 0.38
			c.bottom_radius = 0.38
			c.height = 0.02
			c.radial_segments = 8
			c.rings = 1
			pm = c
			col = Color(0.72, 0.08, 0.07)
			txt = "STOP"
			fs = 110
		"speed":
			var b := BoxMesh.new()
			b.size = Vector3(0.6, 0.78, 0.02)
			pm = b
			col = Color(0.93, 0.93, 0.9)
			txt = "50"
			fs = 220
		_:
			var b := BoxMesh.new()
			b.size = Vector3(0.62, 0.62, 0.02)
			pm = b
			rot_z = PI * 0.25
			txt = {"deer": "DEER", "bear": "BEAR", "curve": "CURVE"}.get(kind, "")
			fs = 70
	plate.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.5
	plate.material_override = m
	plate.position = Vector3(0.0, 2.25, 0.0)
	if kind == "stop":
		plate.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	else:
		plate.rotation = Vector3(0.0, 0.0, rot_z)
	s.add_child(plate)
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = fs
	lb.pixel_size = 0.0022 if kind != "speed" else 0.0016
	lb.modulate = Color(0.95, 0.95, 0.95) if kind == "stop" else Color(0.06, 0.06, 0.06)
	lb.outline_size = 0
	lb.position = Vector3(0.0, 2.25, 0.015)
	lb.double_sided = false
	s.add_child(lb)
