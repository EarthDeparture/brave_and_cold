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


## Seed `n` zombies: 40 % around buildings, 20 % along the road, 40 % forest scatter, in clumps of 1-4.
## Nothing within `safe_r` of `home` (the start cabin).
func generate(n: int, home: Vector2, anchors: Array, road_pts: Array, water: Image, rng_seed: int = 7, safe_r: float = 120.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
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
		elif roll < 0.6 and not road_pts.is_empty():
			var rp: Vector2 = road_pts[rng.randi() % road_pts.size()]
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
		_t_slow = 0.0
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


func _materialize(v: Vector3) -> void:
	var z := acquire(v)
	z.from_pop = true
	active.append(z)
	world_list.append(z)
	spawned_total += 1
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
