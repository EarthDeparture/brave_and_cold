class_name AnimalTracks
extends Node3D
## Alive L2: traces in the snow. Deer, wolf, bear and hare prints and blood drops as pooled projected decals,
## the TLD way of reading the land: a line of cloven hoofprints to follow for meat, a wolf trot line crossing
## yours as a warning, a blood trail from a wounded deer to where it bedded down and died.
##  * Prints are stamped for animals within STAMP_R of the player, on snow (tier > 0), per species stride:
##    a walk lays a single alternating line, a run lays bounding groups of four.
##  * Prints age in GAME time (PRINT_LIFE_H) and fill in up to SNOW_COVER_MULT x faster in falling snow;
##    blood lasts longer (BLOOD_LIFE_H) and is buried the same way.
##  * Carcass.blood() routes here (irregular splatters instead of the old square quads).

const POOL := 520
const BLOOD_POOL := 180
const PRINT_LIFE_H := 6.0
const BLOOD_LIFE_H := 12.0
const SNOW_COVER_MULT := 7.0
const STAMP_R := 160.0
const KINDS := {
	"deer": {"size": Vector2(0.10, 0.13), "stride": 0.62, "run_stride": 2.8, "run_v": 3.5, "lat": 0.09},
	"wolf": {"size": Vector2(0.11, 0.13), "stride": 0.70, "run_stride": 2.3, "run_v": 4.5, "lat": 0.05},
	"bear": {"size": Vector2(0.20, 0.28), "stride": 0.85, "run_stride": 2.0, "run_v": 4.5, "lat": 0.17},
	"hare": {"size": Vector2(0.06, 0.12), "stride": 0.50, "run_stride": 1.4, "run_v": 2.5, "lat": 0.05},
}
## Bounding group: (forward, lateral) offsets in units of `lat`; the hind feet land ahead of the front ones.
const GROUP := [[0.30, -1.0], [0.30, 1.0], [-0.05, 0.15], [-0.32, -0.15]]

static var instance: AnimalTracks

var world: Node
var stamped := 0                       # tests / debug
var _tex: Dictionary = {}
var _blood_tex: Array = []
var _decals: Array[Decal] = []
var _kind: PackedStringArray = PackedStringArray()
var _age: PackedFloat32Array = PackedFloat32Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _next := 0
var _bdecals: Array[Decal] = []
var _bage: PackedFloat32Array = PackedFloat32Array()
var _balpha: PackedFloat32Array = PackedFloat32Array()
var _bnext := 0
var _state: Dictionary = {}            # instance id -> {last: Vector3, acc: float, left: bool}
var _acc := 0.0
var _scan := 0.0
var _rng := RandomNumberGenerator.new()   # own stream: never perturbs the game's global randf() sequence


func _ready() -> void:
	instance = self
	for k in KINDS:
		_tex[k] = _make_print(k)
	for i in 4:
		_blood_tex.append(_make_blood(i))
	for i in POOL:
		var d := _new_decal()
		_decals.append(d)
		_kind.append("")
		_age.append(1e9)
		_alpha.append(0.0)
	for i in BLOOD_POOL:
		var d := _new_decal()
		d.distance_fade_begin = 50.0
		_bdecals.append(d)
		_bage.append(1e9)
		_balpha.append(0.0)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _new_decal() -> Decal:
	var d := Decal.new()
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 1
	d.visible = false
	d.distance_fade_enabled = true
	d.distance_fade_begin = 32.0
	d.distance_fade_length = 15.0
	add_child(d)
	return d


# ------------------------------------------------------------------ stamping
## One print (or a bounding group when `group`) of `kind` at ground position p heading `yaw`.
func stamp(kind: String, p: Vector3, yaw: float, left: bool, group := false) -> void:
	var k: Dictionary = KINDS[kind]
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var lat: float = k.lat
	var offs: Array = GROUP if group else [[0.0, 1.0 if left else -1.0]]
	for o in offs:
		var q: Vector3 = p + fwd * (float(o[0]) * (2.4 if kind == "bear" else 1.0)) + right * (float(o[1]) * lat)
		q.y = _ground(q.x, q.z)
		var d := _decals[_next]
		var sz: Vector2 = k.size
		d.texture_albedo = _tex[kind]
		d.size = Vector3(sz.x, 1.2, sz.y)
		d.global_position = q
		d.rotation = Vector3(0.0, yaw + _rng.randf_range(-0.12, 0.12), 0.0)
		var a := 0.85 if group else 0.78
		d.modulate = Color(1, 1, 1, a)
		d.visible = true
		_kind[_next] = kind
		_age[_next] = 0.0
		_alpha[_next] = a
		_next = (_next + 1) % POOL
		stamped += 1


## A blood splatter (replaces the old square quad). size ~ diameter in metres.
func blood(p: Vector3, size: float) -> void:
	var d := _bdecals[_bnext]
	d.texture_albedo = _blood_tex[_rng.randi() % _blood_tex.size()]
	var s := size * _rng.randf_range(0.8, 1.25)
	d.size = Vector3(s, 1.0, s * _rng.randf_range(0.75, 1.2))
	p.y = _ground(p.x, p.z) if world != null else p.y
	d.global_position = p
	d.rotation = Vector3(0.0, _rng.randf() * TAU, 0.0)
	d.modulate = Color(1, 1, 1, 0.95)
	d.visible = true
	_bage[_bnext] = 0.0
	_balpha[_bnext] = 0.95
	_bnext = (_bnext + 1) % BLOOD_POOL


func _ground(x: float, z: float) -> float:
	return float(world.call("_ground_y", x, z)) if world != null and world.has_method("_ground_y") else 0.0


func _animals() -> Array:
	var out: Array = []
	if world == null:
		return out
	for pair in [["deer", "deer"], ["wolves", "wolf"], ["bears", "bear"], ["rabbits", "hare"]]:
		var arr = world.get(pair[0])
		if arr == null:
			continue
		for a in arr:
			if is_instance_valid(a):
				out.append([a, pair[1]])
	return out


func _process(delta: float) -> void:
	if world == null:
		return
	_track_animals()
	_acc += delta
	if _acc >= 0.5:
		_fade(_acc)
		_acc = 0.0


func _track_animals() -> void:
	var p = world.get("player")
	if p == null:
		return
	var pp: Vector3 = (p as Node3D).global_position
	var snow: SnowField = world.get("snow")
	for e in _animals():
		var a: Node3D = e[0]
		var kind: String = e[1]
		var id := a.get_instance_id()
		var dead: bool = a.call("is_dead") if a.has_method("is_dead") else false
		var pos := a.global_position
		if dead or Vector2(pos.x - pp.x, pos.z - pp.z).length() > STAMP_R:
			_state.erase(id)
			continue
		if not _state.has(id):
			_state[id] = {"last": pos, "acc": 0.0, "left": false}
			continue
		var st: Dictionary = _state[id]
		var mv: Vector3 = pos - st.last
		mv.y = 0.0
		st.last = pos
		var dist := mv.length()
		if dist < 0.0001 or dist > 5.0:   # teleported / respawned: no streak of prints
			continue
		st.acc += dist
		var k: Dictionary = KINDS[kind]
		var spd := float(a.get("speed_now")) if a.get("speed_now") != null else 0.0
		var run := spd > float(k.run_v)
		var stride: float = k.run_stride if run else k.stride
		if st.acc < stride:
			continue
		st.acc = 0.0
		if snow != null and snow.tier_at(pos.x, pos.z) <= 0:
			continue
		var yaw := atan2(-mv.x, -mv.z)
		st.left = not st.left
		stamp(kind, pos, yaw, st.left, run)


func _fade(dt: float) -> void:
	var clock: GameClock = world.get("clock")
	var weather: Weather = world.get("weather")
	var gs := dt * (clock.time_scale if clock != null else 48.0)
	var cover := 1.0 + SNOW_COVER_MULT * (weather.precip if weather != null else 0.0)
	var pl := PRINT_LIFE_H * 3600.0
	for i in POOL:
		if _age[i] >= pl:
			continue
		_age[i] += gs * cover
		var d := _decals[i]
		if _age[i] >= pl:
			d.visible = false
		else:
			d.modulate.a = _alpha[i] * (1.0 - pow(_age[i] / pl, 1.5))
	var bl := BLOOD_LIFE_H * 3600.0
	for i in BLOOD_POOL:
		if _bage[i] >= bl:
			continue
		_bage[i] += gs * cover
		var d := _bdecals[i]
		if _bage[i] >= bl:
			d.visible = false
		else:
			d.modulate.a = _balpha[i] * (1.0 - pow(_bage[i] / bl, 2.0))


## How many prints / blood decals are showing (tests).
func visible_counts() -> Vector2i:
	var a := 0
	var b := 0
	for d in _decals:
		if d.visible: a += 1
	for d in _bdecals:
		if d.visible: b += 1
	return Vector2i(a, b)


func prints_of(kind: String) -> Array:
	var out: Array = []
	for i in POOL:
		if _decals[i].visible and _kind[i] == kind:
			out.append(_decals[i])
	return out


# ------------------------------------------------------------------ textures
## 64x64 print, top of the image = forward. Coloured as a shadowed hollow in the snow (cool blue-grey, like the
## boot prints); alpha soft-edged.
static func _make_print(kind: String) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0   # -1 = forward
			var a := 0.0
			match kind:
				"deer":   # two cloven halves, pointed forward, a narrow gap between; heels rounded
					for s: float in [-1.0, 1.0]:
						var cu: float = (u - s * 0.30) / 0.36
						var cv := (v + 0.05) / 0.80
						var w := 1.0 - cv * cv
						var taper := 1.0 - 0.45 * clampf(-cv, 0.0, 1.0)   # narrower toward the tip
						var dd: float = cu * cu / (taper * taper) + cv * cv
						a = maxf(a, 1.0 - smoothstep(0.75, 1.0, dd) if w > 0.0 else 0.0)
					if absf(u) < 0.06: a *= 0.3
				"wolf":   # lobed heel pad + four oval toes, claw marks ahead of the front pair
					var pad := pow(u / 0.46, 2.0) + pow((v - 0.42) / 0.34, 2.0)
					a = 1.0 - smoothstep(0.7, 1.0, pad)
					for t in [[-0.52, -0.05], [0.52, -0.05], [-0.20, -0.48], [0.20, -0.48]]:
						var td := pow((u - t[0]) / 0.20, 2.0) + pow((v - t[1]) / 0.25, 2.0)
						a = maxf(a, 1.0 - smoothstep(0.7, 1.0, td))
					for c in [[-0.22, -0.84], [0.22, -0.84]]:
						var cd := pow((u - c[0]) / 0.06, 2.0) + pow((v - c[1]) / 0.09, 2.0)
						a = maxf(a, 0.8 * (1.0 - smoothstep(0.6, 1.0, cd)))
				"bear":   # broad pad and five toes in an arc, claws well ahead
					var pad := pow(u / 0.70, 2.0) + pow((v - 0.30) / 0.52, 2.0)
					a = 1.0 - smoothstep(0.75, 1.0, pad)
					for i in 5:
						var ang := lerpf(-0.95, 0.95, i / 4.0)
						var tu := sin(ang) * 0.62
						var tv := -0.30 - cos(ang) * 0.30
						var td := pow((u - tu) / 0.15, 2.0) + pow((v - tv) / 0.15, 2.0)
						a = maxf(a, 1.0 - smoothstep(0.7, 1.0, td))
						var cd := pow((u - tu * 1.08) / 0.05, 2.0) + pow((v - tv + 0.27) / 0.08, 2.0)
						a = maxf(a, 0.75 * (1.0 - smoothstep(0.6, 1.0, cd)))
				"hare":   # long hind foot, furred and soft-edged
					var hd := pow(u / 0.55, 2.0) + pow(v / 0.92, 2.0)
					a = 1.0 - smoothstep(0.45, 1.0, hd)
			var shade := 0.88 + 0.12 * v   # the forward wall of the hollow is in shadow, the heel is shallow
			img.set_pixel(x, y, Color(0.40 * shade, 0.47 * shade, 0.68 * shade, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Irregular blood splatter: a main drop of overlapping blobs, ragged edge, satellite droplets thrown out in one
## direction; darker where it pooled.
static func _make_blood(seed_v: int) -> ImageTexture:
	var n := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + seed_v * 17
	var blobs: Array = []
	for i in rng.randi_range(3, 5):
		blobs.append([rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22), rng.randf_range(0.16, 0.34)])
	var throw := rng.randf() * TAU
	for i in rng.randi_range(4, 9):
		var r := rng.randf_range(0.45, 0.9)
		var aa := throw + rng.randf_range(-0.7, 0.7)
		blobs.append([cos(aa) * r, sin(aa) * r, rng.randf_range(0.025, 0.07)])
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var a := 0.0
			var depth := 0.0
			for b in blobs:
				var d := Vector2(u - b[0], v - b[1]).length() / float(b[2])
				var ragged := 1.0 + 0.18 * sin(atan2(v - b[1], u - b[0]) * 7.0 + float(b[0]) * 13.0)
				a = maxf(a, 1.0 - smoothstep(0.80 * ragged, 1.0 * ragged, d))
				depth = maxf(depth, 1.0 - d)
			var c := Color(0.36, 0.015, 0.025).lerp(Color(0.20, 0.0, 0.01), clampf(depth, 0.0, 1.0))
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
