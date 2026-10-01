class_name Population
extends Node
## Zombie population as DATA; real Zombie nodes are a cache.
##   virtual  (anywhere)        : positions in a 64 m cell grid, no node, no AI. Far noise drags them toward the sound.
##   proxy    (85..240 m)       : virtual zombies drawn as ONE MultiMesh (shader sway), no scripts, no shadows.
##   active   (< 85 m, cap 60)  : real pooled Zombie nodes; returned to the cell data beyond 115 m.
## Kills are permanent: a dead zombie is simply never written back.

const CELL := 64.0
const HALF := 1024.0
const NC := 32
const SPAWN_R := 85.0
const DESPAWN_R := 115.0
const PROXY_R := 240.0
const T0_CAP := 60
const PROXY_CAP := 420
const SPAWNS_PER_TICK := 2
const NOISE_MIN_R := 20.0         # footsteps never drag the map; axe/gun/glass do
const DRAG_SPEED := 1.5

## A horde is a macro agent: members move together along the road polyline, respond to loud noise, absorb strays.
## Members are absolute positions (y = ground); near the player they materialise like any other virtual zombie.
class Horde:
	var pts := PackedVector3Array()
	var center := Vector2.ZERO
	var target := Vector2.ZERO
	var state := 0            # 0 wander, 1 respond, 2 search, 3 rest
	var t := 0.0
	var rest_len := 30.0
	var abs_t := 0.0
	var path: Array = []      # Vector2 waypoints still to walk


const HORDE_MAX := 120
const H_WANDER := 0.9
const H_RESPOND := 1.4

var hordes: Array = []
var road_pts: Array = []
var terrain: Terrain3D
var player: Player
var world_list: Array = []        # the world's `zombies` array (same reference); active + corpses
var bus: NoiseBus
var make_zombie: Callable         # (pos: Vector3, id: int) -> Zombie, sets up a NEW node (first use)
var cells: Dictionary = {}        # int key -> PackedVector3Array of virtual zombies (y = ground)
var active: Array = []            # pooled zombies owned by population (alive, from_pop)
var pool: Array = []              # parked nodes
var events: Array = []            # [x, z, radius, expires]
var enabled := true
var clock := 0.0
var spawned_total := 0
var _t_spawn := 0.0
var _t_slow := 0.0
var _t_drag := 0.0
var _next_id := 5000
var _mm: MultiMeshInstance3D
var proxy_n := 0
var last_tick_us := 0


func _ready() -> void:
	_build_proxy()


# ------------------------------------------------------------------ cell data
static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(int(floorf((x + HALF) / CELL)), 0, NC - 1), clampi(int(floorf((z + HALF) / CELL)), 0, NC - 1))


static func key_of(c: Vector2i) -> int:
	return c.x * 64 + c.y


func add_virtual(p: Vector3) -> void:
	var k := key_of(cell_of(p.x, p.z))
	var arr: PackedVector3Array = cells.get(k, PackedVector3Array())
	arr.append(p)
	cells[k] = arr


func count_virtual() -> int:
	var n := 0
	for k in cells:
		n += (cells[k] as PackedVector3Array).size()
	for h in hordes:
		n += (h as Horde).pts.size()
	return n


func count_alive() -> int:
	var n := count_virtual()
	for z in active:
		if is_instance_valid(z) and not z.is_dead():
			n += 1
	return n


## [x, z] of every living population member (virtual + active) for saving.
func all_alive() -> Array:
	var out: Array = []
	for k in cells:
		for v in (cells[k] as PackedVector3Array):
			out.append({"x": v.x, "z": v.z})
	for z in active:
		if is_instance_valid(z) and not z.is_dead():
			out.append({"x": z.global_position.x, "z": z.global_position.z})
	return out


## Seed `n` zombies: ~22 % in roaming hordes (12-45 each), the rest 40 % around buildings, 20 % along the road, 40 % forest
## scatter, in clumps of 1-4. Nothing within `safe_r` of `home` (the start cabin).
func generate(n: int, home: Vector2, anchors: Array, road_pts_in: Array, water: Image, rng_seed: int = 7, safe_r: float = 120.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if road_pts.is_empty():
		road_pts = road_pts_in
	var horde_budget := int(float(n) * 0.22) if not road_pts.is_empty() else 0
	var in_hordes := 0
	var htries := 0
	while in_hordes < horde_budget and htries < 200:
		htries += 1
		var rp0: Vector2 = road_pts[rng.randi() % road_pts.size()]
		if Vector2(rp0.x - home.x, rp0.y - home.y).length() < 220.0 or absf(rp0.x) > 930.0 or absf(rp0.y) > 930.0:
			continue
		var sz := mini(rng.randi_range(12, 45), horde_budget - in_hordes)
		if sz < 4:
			break
		in_hordes += spawn_horde(rp0, sz, rng)
	n -= in_hordes
	var road_pts_s: Array = road_pts_in
	var made := 0
	var tries := 0
	while made < n and tries < n * 30:
		tries += 1
		var roll := rng.randf()
		var cx := 0.0
		var cz := 0.0
		if roll < 0.4 and not anchors.is_empty():
			var a: Vector2 = anchors[rng.randi() % anchors.size()]
			var ang := rng.randf() * TAU
			var r := rng.randf_range(12.0, 70.0)
			cx = a.x + cos(ang) * r
			cz = a.y + sin(ang) * r
		elif roll < 0.6 and not road_pts_s.is_empty():
			var rp: Vector2 = road_pts_s[rng.randi() % road_pts_s.size()]
			cx = rp.x + rng.randf_range(-12.0, 12.0)
			cz = rp.y + rng.randf_range(-12.0, 12.0)
		else:
			cx = rng.randf_range(-930.0, 930.0)
			cz = rng.randf_range(-930.0, 930.0)
		var group := mini(rng.randi_range(1, 4), n - made)
		for g in group:
			var x := cx + rng.randf_range(-4.0, 4.0)
			var z := cz + rng.randf_range(-4.0, 4.0)
			if absf(x) > 940.0 or absf(z) > 940.0:
				continue
			if Vector2(x - home.x, z - home.y).length() < safe_r:
				continue
			if water != null and water.get_pixel(int(x + HALF), int(z + HALF)).r > 0.5:
				continue
			var h: float = terrain.data.get_height(Vector3(x, 0.0, z))
			if is_nan(h):
				continue
			add_virtual(Vector3(x, h, z))
			made += 1


# ------------------------------------------------------------------ pool
func acquire(p: Vector3, id: int = -1) -> Zombie:
	var sid := id if id >= 0 else _next_id
	if id < 0:
		_next_id += 1
	var z: Zombie = null
	while not pool.is_empty() and z == null:
		var c = pool.pop_back()
		if is_instance_valid(c):
			z = c
	if z != null:
		z.activate(p, sid)
	else:
		z = make_zombie.call(p, sid)
	return z


func park(z: Zombie) -> void:
	z.park()
	pool.append(z)


func prewarm(n: int) -> void:
	for i in n:
		var z: Zombie = make_zombie.call(Vector3(0, -500, 0), _next_id)
		_next_id += 1
		world_list.erase(z)
		park(z)


# ------------------------------------------------------------------ tick
func tick(delta: float) -> void:
	if not enabled or player == null or terrain == null:
		return
	var t0 := Time.get_ticks_usec()
	clock += delta
	_t_spawn += delta
	_t_slow += delta
	_t_drag += delta
	if _t_spawn >= 0.1:
		_t_spawn = 0.0
		_spawn_step()
	if _t_drag >= 3.0:
		_drag_step(_t_drag)
		_t_drag = 0.0
	if _t_slow >= 0.5:
		var dts := _t_slow
		_t_slow = 0.0
		_horde_step(dts)
		_despawn_step()
		_proxy_step()
	last_tick_us = Time.get_ticks_usec() - t0


func _spawn_step() -> void:
	if active.size() >= T0_CAP:
		return
	var pp := player.position
	var pc := cell_of(pp.x, pp.z)
	for n in SPAWNS_PER_TICK:
		if active.size() >= T0_CAP:
			return
		var best := SPAWN_R * SPAWN_R
		var bk := -1
		var bi := -1
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var cx := pc.x + dx
				var cz := pc.y + dz
				if cx < 0 or cz < 0 or cx >= NC or cz >= NC:
					continue
				var k := cx * 64 + cz
				if not cells.has(k):
					continue
				var arr: PackedVector3Array = cells[k]
				for i in arr.size():
					var v := arr[i]
					var d2 := (v.x - pp.x) * (v.x - pp.x) + (v.z - pp.z) * (v.z - pp.z)
					if d2 < best:
						best = d2
						bk = k
						bi = i
		var bh: Horde = null
		var bhi := -1
		for h in hordes:
			var hh := h as Horde
			if Vector2(hh.center.x - pp.x, hh.center.y - pp.z).length() > SPAWN_R + 40.0:
				continue
			for i in hh.pts.size():
				var v3 := hh.pts[i]
				var d3 := (v3.x - pp.x) * (v3.x - pp.x) + (v3.z - pp.z) * (v3.z - pp.z)
				if d3 < best:
					best = d3
					bh = hh
					bhi = i
					bk = -1
		if bh != null:
			var vh := bh.pts[bhi]
			bh.pts.remove_at(bhi)
			_materialize(vh, bh)
			continue
		if bk < 0:
			return
		var arr2: PackedVector3Array = cells[bk]
		var v2 := arr2[bi]
		arr2.remove_at(bi)
		if arr2.is_empty():
			cells.erase(bk)
		else:
			cells[bk] = arr2
		_materialize(v2)


func _materialize(v: Vector3, from_horde: Horde = null) -> void:
	var z := acquire(v)
	z.from_pop = true
	active.append(z)
	world_list.append(z)
	spawned_total += 1
	if from_horde != null and from_horde.state == 1:
		z.on_noise(Vector3(from_horde.target.x, v.y, from_horde.target.y), 150.0, null)
		return
	for ev in events:
		if clock < float(ev[3]) and Vector2(v.x - float(ev[0]), v.z - float(ev[1])).length() < float(ev[2]):
			z.on_noise(Vector3(float(ev[0]), v.y, float(ev[1])), float(ev[2]), null)
			break

func _despawn_step() -> void:
	var pp := player.position
	var lim := DESPAWN_R * DESPAWN_R
	for i in range(active.size() - 1, -1, -1):
		var z = active[i]
		if not is_instance_valid(z):
			active.remove_at(i)
			continue
		if z.is_dead():
			active.remove_at(i)       # corpse stays in the world list until it rots
			continue
		var dx: float = z.global_position.x - pp.x
		var dz: float = z.global_position.z - pp.z
		if dx * dx + dz * dz > lim and z.can_park():
			add_virtual(z.global_position)
			active.remove_at(i)
			world_list.erase(z)
			park(z)
	for i in range(world_list.size() - 1, -1, -1):
		if not is_instance_valid(world_list[i]):
			world_list.remove_at(i)


# ------------------------------------------------------------------ far noise
func on_noise(pos: Vector3, radius: float, _source: Object) -> void:
	if radius < NOISE_MIN_R:
		return
	if radius >= 40.0:
		for h in hordes:
			var hh := h as Horde
			if hh.center.distance_to(Vector2(pos.x, pos.z)) < radius * 2.0 and hh.center.distance_to(Vector2(pos.x, pos.z)) > 10.0:
				hh.state = 1
				hh.target = Vector2(pos.x, pos.z)
				hh.t = 0.0
				_plan(hh, hh.target)
	for ev in events:
		if Vector2(float(ev[0]) - pos.x, float(ev[1]) - pos.z).length() < 25.0:
			ev[2] = maxf(float(ev[2]), radius)
			ev[3] = clock + 90.0
			return
	events.append([pos.x, pos.z, radius, clock + 90.0])
	if events.size() > 8:
		events.pop_front()


func _drag_step(dt: float) -> void:
	for i in range(events.size() - 1, -1, -1):
		if clock >= float(events[i][3]):
			events.remove_at(i)
	if events.is_empty():
		return
	var moves: Array = []   # [from_key, idx_marker(Vector3), to Vector3]
	for ev in events:
		var ex: float = ev[0]
		var ez: float = ev[1]
		var r: float = ev[2]
		var c0 := cell_of(ex - r, ez - r)
		var c1 := cell_of(ex + r, ez + r)
		for cx in range(c0.x, c1.x + 1):
			for cz in range(c0.y, c1.y + 1):
				var k := cx * 64 + cz
				if not cells.has(k):
					continue
				var arr: PackedVector3Array = cells[k]
				for i in arr.size():
					var v := arr[i]
					var to := Vector2(ex - v.x, ez - v.z)
					var d := to.length()
					if d > r or d < 6.0:
						continue
					var step := minf(DRAG_SPEED * dt, d - 5.0)
					var nx := v.x + to.x / d * step
					var nz := v.z + to.y / d * step
					moves.append([k, v, Vector3(nx, 0.0, nz)])
	for m in moves:
		var k: int = m[0]
		if not cells.has(k):
			continue
		var arr: PackedVector3Array = cells[k]
		var idx := -1
		for i in arr.size():
			if arr[i] == (m[1] as Vector3):
				idx = i
				break
		if idx < 0:
			continue
		arr.remove_at(idx)
		if arr.is_empty():
			cells.erase(k)
		else:
			cells[k] = arr
		var np: Vector3 = m[2]
		var h: float = terrain.data.get_height(Vector3(np.x, 0.0, np.z))
		np.y = h if not is_nan(h) else (m[1] as Vector3).y
		add_virtual(np)


# ------------------------------------------------------------------ proxies (one draw call)
func _build_proxy() -> void:
	var root := (load(Zombie.MODEL) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for s in m.mesh.get_surface_count():
			st.append_from(m.mesh, s, xf)
	var mesh := st.commit()
	root.free()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float ph = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.53;
	float k = clamp(VERTEX.y, 0.0, 2.0);
	VERTEX.x += sin(TIME * 1.1 + ph) * 0.05 * k;
	VERTEX.z += cos(TIME * 0.8 + ph * 1.7) * 0.03 * k;
}
void fragment() {
	float t = 0.78 + 0.3 * fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = COLOR.rgb * vec3(t, t * 0.97, t * 0.95);
	ROUGHNESS = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = PROXY_CAP
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.custom_aabb = AABB(Vector3(-1100, -100, -1100), Vector3(2200, 400, 2200))
	add_child(_mm)
	_mm.top_level = true


func _proxy_step() -> void:
	if _mm == null:
		return
	var mm := _mm.multimesh
	var pp := player.position
	var pc := cell_of(pp.x, pp.z)
	var n := 0
	var lim := PROXY_R * PROXY_R
	var rc := int(ceilf(PROXY_R / CELL))
	for h in hordes:
		for v in (h as Horde).pts:
			var dd2 := (v.x - pp.x) * (v.x - pp.x) + (v.z - pp.z) * (v.z - pp.z)
			if dd2 > lim or n >= PROXY_CAP:
				continue
			var yw := fposmod(v.x * 12.9898 + v.z * 78.233, TAU)
			var sw := 0.94 + 0.12 * fposmod(v.x * 3.7 + v.z * 1.3, 1.0)
			mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yw).scaled(Vector3.ONE * sw), v))
			n += 1
	for dx in range(-rc, rc + 1):
		for dz in range(-rc, rc + 1):
			var cx := pc.x + dx
			var cz := pc.y + dz
			if cx < 0 or cz < 0 or cx >= NC or cz >= NC:
				continue
			var k := cx * 64 + cz
			if not cells.has(k):
				continue
			for v in (cells[k] as PackedVector3Array):
				var d2 := (v.x - pp.x) * (v.x - pp.x) + (v.z - pp.z) * (v.z - pp.z)
				if d2 > lim:
					continue
				if n >= PROXY_CAP:
					break
				var yaw := fposmod(v.x * 12.9898 + v.z * 78.233, TAU)
				var sc := 0.94 + 0.12 * fposmod(v.x * 3.7 + v.z * 1.3, 1.0)
				mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), v))
				n += 1
	proxy_n = n
	mm.visible_instance_count = n


# ------------------------------------------------------------------ hordes
## Creates a horde of `n` around `at`; returns members made.
func spawn_horde(at: Vector2, n: int, rng: RandomNumberGenerator = null) -> int:
	var r := rng if rng != null else RandomNumberGenerator.new()
	var h := Horde.new()
	h.center = at
	h.target = at
	h.rest_len = r.randf_range(20.0, 60.0)
	var spread := 2.2 * sqrt(float(n))
	for i in n:
		var a := r.randf() * TAU
		var d := spread * sqrt(r.randf())
		var x := at.x + cos(a) * d
		var z := at.y + sin(a) * d
		var hy: float = terrain.data.get_height(Vector3(x, 0.0, z))
		if is_nan(hy):
			continue
		h.pts.append(Vector3(x, hy, z))
	if h.pts.size() < 4:
		return 0
	hordes.append(h)
	return h.pts.size()


func dissolve_all() -> void:
	for h in hordes.duplicate():
		_dissolve(h)


func _dissolve(h: Horde) -> void:
	for v in h.pts:
		add_virtual(v)
	hordes.erase(h)


func _nearest_road(p: Vector2) -> int:
	var bi := -1
	var bd := 1e18
	for i in road_pts.size():
		var q: Vector2 = road_pts[i]
		var d := (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y)
		if d < bd:
			bd = d
			bi = i
	return bi


## Road-following route (road polyline between the two nearest road points), else straight line.
func _plan(h: Horde, goal: Vector2) -> void:
	h.path = []
	if road_pts.is_empty():
		h.path.append(goal)
		return
	var i0 := _nearest_road(h.center)
	var i1 := _nearest_road(goal)
	var q0: Vector2 = road_pts[i0]
	var q1: Vector2 = road_pts[i1]
	if q0.distance_to(h.center) > 250.0 or q1.distance_to(goal) > 250.0 or i0 == i1:
		h.path.append(goal)
		return
	h.path.append(q0)
	var step := 1 if i1 > i0 else -1
	var i := i0 + step * 3
	while (i1 - i) * step > 0:
		h.path.append(road_pts[i])
		i += step * 3
	h.path.append(q1)
	h.path.append(goal)


func _horde_step(dt: float) -> void:
	for hi in range(hordes.size() - 1, -1, -1):
		var h: Horde = hordes[hi]
		if h.pts.size() < 4:
			_dissolve(h)
			continue
		h.t += dt
		var speed := 0.0
		match h.state:
			0:
				if h.path.is_empty():
					if randf() < 0.3:
						h.state = 3
						h.t = 0.0
						h.rest_len = randf_range(20.0, 60.0)
					else:
						var goal := h.center + Vector2.from_angle(randf() * TAU) * randf_range(120.0, 260.0)
						if not road_pts.is_empty():
							var i0 := _nearest_road(h.center)
							var j := clampi(i0 + (1 if randf() < 0.5 else -1) * randi_range(30, 90), 0, road_pts.size() - 1)
							goal = road_pts[j]
						goal.x = clampf(goal.x, -930.0, 930.0)
						goal.y = clampf(goal.y, -930.0, 930.0)
						_plan(h, goal)
				speed = H_WANDER
			1:
				speed = H_RESPOND
				if h.path.is_empty():
					h.state = 2
					h.t = 0.0
			2:
				speed = 0.4
				if h.path.is_empty() and fmod(h.t, 6.0) < dt:
					h.path.append(h.target + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 16.0))
				if h.t > 60.0:
					h.state = 0
					h.t = 0.0
					h.path = []
			3:
				if h.t > h.rest_len:
					h.state = 0
					h.t = 0.0
		if speed > 0.0 and not h.path.is_empty():
			var wp: Vector2 = h.path[0]
			var to := wp - h.center
			var d := to.length()
			var step := speed * dt
			if d <= step + 0.5:
				h.center = wp
				h.path.remove_at(0)
				step = d
			else:
				step = minf(step, d)
			var mv := to / maxf(d, 0.001) * step
			h.center += mv
			for i in h.pts.size():
				var v := h.pts[i]
				var nx := v.x + mv.x
				var nz := v.z + mv.y
				var hy: float = terrain.data.get_height(Vector3(nx, 0.0, nz))
				h.pts[i] = Vector3(nx, v.y if is_nan(hy) else hy, nz)
		# strays within 20 m join (snowball), up to HORDE_MAX
		h.abs_t += dt
		if h.abs_t >= 2.0 and h.pts.size() < HORDE_MAX:
			h.abs_t = 0.0
			_absorb(h)


func _absorb(h: Horde) -> void:
	var c0 := cell_of(h.center.x - 20.0, h.center.y - 20.0)
	var c1 := cell_of(h.center.x + 20.0, h.center.y + 20.0)
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var k := cx * 64 + cz
			if not cells.has(k):
				continue
			var arr: PackedVector3Array = cells[k]
			var keep := PackedVector3Array()
			for v in arr:
				if h.pts.size() < HORDE_MAX and Vector2(v.x - h.center.x, v.z - h.center.y).length() < 20.0:
					h.pts.append(v)
				else:
					keep.append(v)
			if keep.is_empty():
				cells.erase(k)
			else:
				cells[k] = keep


## For audio: nearest horde that is NOT already real (distance, direction, size), or {}.
func nearest_horde(pp: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e9
	for h in hordes:
		var hh := h as Horde
		var d := hh.center.distance_to(Vector2(pp.x, pp.z))
		if d < bd:
			bd = d
			best = {"dist": d, "dir": Vector3(hh.center.x - pp.x, 0.0, hh.center.y - pp.z).normalized(), "size": hh.pts.size(), "state": hh.state}
	return best


func horde_list() -> Array:
	var out: Array = []
	for h in hordes:
		var hh := h as Horde
		var pts: Array = []
		for v in hh.pts:
			pts.append([v.x, v.z])
		out.append({"cx": hh.center.x, "cz": hh.center.y, "tx": hh.target.x, "tz": hh.target.y, "state": hh.state, "pts": pts})
	return out


func restore_hordes(lst: Array) -> void:
	for e in lst:
		var h := Horde.new()
		h.center = Vector2(float(e["cx"]), float(e["cz"]))
		h.target = Vector2(float(e["tx"]), float(e["tz"]))
		h.state = int(e["state"]) if int(e["state"]) != 3 else 0
		for q in e["pts"]:
			var hy: float = terrain.data.get_height(Vector3(float(q[0]), 0.0, float(q[1])))
			h.pts.append(Vector3(float(q[0]), 0.0 if is_nan(hy) else hy, float(q[1])))
		if h.state == 1:
			_plan(h, h.target)
		if h.pts.size() >= 4:
			hordes.append(h)