class_name TrailNet
extends Node3D
## Narrow trampled-snow footpaths (road -> huts / cabin). Polylines are smoothed, draped on terrain as a ribbon and
## registered so the forest scatter keeps a clear lane.

const XS: Array = [
	[-1.2, Color(0.70, 0.75, 0.86), 0.04],
	[-0.65, Color(0.50, 0.54, 0.65), 0.06],
	[0.0, Color(0.36, 0.40, 0.50), 0.07],
	[0.65, Color(0.50, 0.54, 0.65), 0.06],
	[1.2, Color(0.70, 0.75, 0.86), 0.04],
]

var trails: Array = []            # Array of Array[Vector2]
var _hash: Dictionary = {}        # Vector2i(8 m cell) -> Array[Vector2]
var markers: Array = []           # [{pos: Vector2, yaw: float}]


## from_pt/to_pt are world xz. Adds a gently wandering path and a marker post at the start.
func add_trail(from_pt: Vector2, to_pt: Vector2, seed_v := 0) -> void:
	var d := to_pt - from_pt
	var len := d.length()
	if len < 3.0:
		return
	var nrm := Vector2(-d.y, d.x) / len
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + int(from_pt.x * 7.0) + int(from_pt.y * 13.0)
	var path: Array[Vector2] = [from_pt]
	var segs := maxi(2, int(len / 12.0))
	for k in range(1, segs):
		var f := float(k) / float(segs)
		path.append(from_pt.lerp(to_pt, f) + nrm * rng.randf_range(-1.8, 1.8) * sin(f * PI))
	path.append(to_pt)
	for _k in range(3):
		path = _chaikin(path)
	var pts: Array[Vector2] = _resample(path, 1.5)
	trails.append(pts)
	for p in pts:
		var key := Vector2i(int(floor(p.x / 8.0)), int(floor(p.y / 8.0)))
		if not _hash.has(key):
			_hash[key] = []
		(_hash[key] as Array).append(p)
	markers.append({"pos": from_pt + (to_pt - from_pt).normalized() * 0.4 + nrm * 1.6, "yaw": atan2(-d.x, -d.y)})


func is_near(x: float, z: float, margin := 1.8) -> bool:
	var cx := int(floor(x / 8.0))
	var cz := int(floor(z / 8.0))
	var p := Vector2(x, z)
	for ox in [-1, 0, 1]:
		for oz in [-1, 0, 1]:
			var key := Vector2i(cx + ox, cz + oz)
			if _hash.has(key):
				for q in _hash[key]:
					if p.distance_squared_to(q) < margin * margin:
						return true
	return false


func _chaikin(p: Array[Vector2]) -> Array[Vector2]:
	if p.size() < 3:
		return p
	var o: Array[Vector2] = [p[0]]
	for i in range(p.size() - 1):
		o.append(p[i] * 0.75 + p[i + 1] * 0.25)
		o.append(p[i] * 0.25 + p[i + 1] * 0.75)
	o.append(p[p.size() - 1])
	return o


func _resample(p: Array[Vector2], step: float) -> Array[Vector2]:
	var o: Array[Vector2] = [p[0]]
	var acc := 0.0
	for i in range(1, p.size()):
		var a := p[i - 1]
		var b := p[i]
		var sl := a.distance_to(b)
		var pos := step - acc
		while pos <= sl:
			o.append(a.lerp(b, pos / sl))
			pos += step
		acc = sl - (pos - step)
	if o[o.size() - 1].distance_to(p[p.size() - 1]) > 0.2:
		o.append(p[p.size() - 1])
	return o


func build_mesh(terrain: Terrain3D) -> void:
	if trails.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := 0
	for pts in trails:
		var rows: Array = []
		for i in range(pts.size()):
			var a: Vector2 = pts[maxi(i - 1, 0)]
			var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
			var t := (b - a).normalized()
			var nrm := Vector2(-t.y, t.x)
			var wob := 0.93 + 0.07 * sin(float(i) * 1.7)
			var edge_fade := clampf(minf(float(i), float(pts.size() - 1 - i)) / 4.0, 0.0, 1.0)  # taper ends into the snow
			var row: Array = []
			for xs in XS:
				var q: Vector2 = pts[i] + nrm * float(xs[0]) * (0.4 + 0.6 * edge_fade)
				var h: float = terrain.data.get_height(Vector3(q.x, 0.0, q.y))
				if is_nan(h):
					h = 0.0
				var c: Color = xs[1]
				row.append([Vector3(q.x, h + float(xs[2]), q.y), Color(c.r * wob, c.g * wob, c.b * wob)])
			rows.append(row)
		for i in range(rows.size() - 1):
			for j in range(XS.size() - 1):
				var v0: Array = rows[i][j]
				var v1: Array = rows[i][j + 1]
				var v2: Array = rows[i + 1][j]
				var v3: Array = rows[i + 1][j + 1]
				for tri in [[v0, v2, v1], [v1, v2, v3]]:
					for vtx in tri:
						st.set_normal(Vector3.UP)
						st.set_color(vtx[1])
						st.add_vertex(vtx[0])
					tris += 1
	var mi := MeshInstance3D.new()
	mi.name = "TrailMesh"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 400.0
	add_child(mi)
	# marker posts (dark wood + orange tag)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.18, 0.13, 0.09)
	wood.roughness = 1.0
	var tag := StandardMaterial3D.new()
	tag.albedo_color = Color(0.85, 0.35, 0.08)
	tag.roughness = 0.9
	for m in markers:
		var mp: Vector2 = m["pos"]
		var h: float = terrain.data.get_height(Vector3(mp.x, 0.0, mp.y))
		if is_nan(h):
			continue
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 1.5, 0.1)
		post.mesh = bm
		post.material_override = wood
		post.position = Vector3(mp.x, h + 0.7, mp.y)
		add_child(post)
		var tg := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.14, 0.26, 0.02)
		tg.mesh = tm
		tg.material_override = tag
		tg.position = Vector3(mp.x, h + 1.25, mp.y)
		tg.rotation.y = float(m["yaw"])
		add_child(tg)
	print("TRAIL_MESH trails ", trails.size(), " tris ", tris)
