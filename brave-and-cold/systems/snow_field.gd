class_name SnowField
extends RefCounted
## Snow depth field: base depth from terrain/canopy/slope (coarse, 2 m cells) + sparse trample layer (0.5 m cells).
## Tiers 0-5: bare, ankle, shin, knee, thigh, waist. Trampled cells are TRAMPLE_DROP tiers shallower and fade over TRAMPLE_LIFE_S.
## Zombies/animals/player query tier_at() / speed_mult_*() -- the "deep snow slows chases" pillar lives here.

const BASE_CELL := 2.0
const TRAMPLE_CELL := 0.5
const TRAMPLE_DROP := 2
const TRAMPLE_LIFE_S := 240.0  # real game seconds until a trail refills (tunable; GDD: trackable ~90 s)
const TIER_NAMES: Array[String] = ["bare", "ankle", "shin", "knee", "thigh", "waist"]
## Speed multipliers by tier (GDD: zombies 100/95/75/50/30/20 %). Player is slowed less (boots, awareness), tunable.
const ZOMBIE_SPEED: Array[float] = [1.0, 0.95, 0.75, 0.5, 0.3, 0.2]
const PLAYER_SPEED: Array[float] = [1.0, 0.97, 0.88, 0.72, 0.55, 0.42]
const PLAYER_STAMINA_COST: Array[float] = [1.0, 1.05, 1.2, 1.5, 1.9, 2.4]

var size_m: int = 2048
var half: float = 1024.0
var _base_n: int = 0
var _base: PackedByteArray  # tier per BASE_CELL
var _trample: Dictionary = {}  # cell key -> expiry time (seconds, game clock)
var _now: float = 0.0
var canopy_m: Image  # for shelter queries
var interior_check: Callable = Callable()  # (x, z) -> bool; true inside a building
var _canopy_scale := 40.0


func build(map_dir: String) -> void:
	var meta = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/meta.json"))
	size_m = int(meta["size_m"])
	half = size_m * 0.5
	var can := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/canopy.png"))
	var slope := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/slope.png"))
	var water := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/water_mask.png"))
	can.convert(Image.FORMAT_L8)
	slope.convert(Image.FORMAT_L8)
	water.convert(Image.FORMAT_L8)
	canopy_m = can
	_base_n = int(size_m / BASE_CELL)
	_base = PackedByteArray()
	_base.resize(_base_n * _base_n)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.004
	var step := int(BASE_CELL)
	for cy in range(_base_n):
		for cx in range(_base_n):
			var px := cx * step
			var py := cy * step
			var s: float = slope.get_pixel(px, py).r * 90.0
			var c: float = can.get_pixel(px, py).r * _canopy_scale
			var d := 0.95
			if c > 10.0:
				d = 0.55 - 0.1 * clampf((c - 10.0) / 15.0, 0.0, 1.0)  # under dense canopy: snow caught by boughs
			d *= 1.0 - clampf((s - 14.0) / 30.0, 0.0, 1.0)
			d += noise.get_noise_2d(px, py) * 0.25
			if water.get_pixel(px, py).r > 0.5:
				d = 0.06  # wind-scoured ice
			if s > 42.0:
				d = 0.0
			_base[cy * _base_n + cx] = _depth_to_tier(d)


static func _depth_to_tier(d: float) -> int:
	if d < 0.05:
		return 0
	if d < 0.15:
		return 1
	if d < 0.30:
		return 2
	if d < 0.50:
		return 3
	if d < 0.75:
		return 4
	return 5


func base_tier_at(x: float, z: float) -> int:
	var cx := clampi(int((x + half) / BASE_CELL), 0, _base_n - 1)
	var cz := clampi(int((z + half) / BASE_CELL), 0, _base_n - 1)
	return _base[cz * _base_n + cx]


func tier_at(x: float, z: float) -> int:
	if interior_check.is_valid() and interior_check.call(x, z):
		return 0
	var t := base_tier_at(x, z)
	if _trample.has(_key(x, z)) and float(_trample[_key(x, z)]) > _now:
		t = maxi(0, t - TRAMPLE_DROP)
	return t


func is_trampled(x: float, z: float) -> bool:
	return _trample.has(_key(x, z)) and float(_trample[_key(x, z)]) > _now


func trample(x: float, z: float, radius: float = 0.5) -> void:
	var expiry := _now + TRAMPLE_LIFE_S
	var r := int(ceil(radius / TRAMPLE_CELL))
	for oz in range(-r, r + 1):
		for ox in range(-r, r + 1):
			if Vector2(ox, oz).length() * TRAMPLE_CELL <= radius + 0.001:
				_trample[_key(x + ox * TRAMPLE_CELL, z + oz * TRAMPLE_CELL)] = expiry


func advance(delta: float) -> void:
	_now += delta
	# prune occasionally so the dictionary stays bounded
	if int(_now) % 30 == 0 and _trample.size() > 20000:
		for k in _trample.keys():
			if float(_trample[k]) <= _now:
				_trample.erase(k)


func zombie_speed_mult(x: float, z: float) -> float:
	return ZOMBIE_SPEED[tier_at(x, z)]


func player_speed_mult(x: float, z: float) -> float:
	return PLAYER_SPEED[tier_at(x, z)]


func canopy_height_at(x: float, z: float) -> float:
	if interior_check.is_valid() and interior_check.call(x, z):
		return 20.0
	var px := clampi(int(x + half), 0, size_m - 1)
	var pz := clampi(int(z + half), 0, size_m - 1)
	return canopy_m.get_pixel(px, pz).r * _canopy_scale


func _key(x: float, z: float) -> int:
	var cx := int(floor((x + half) / TRAMPLE_CELL))
	var cz := int(floor((z + half) / TRAMPLE_CELL))
	return cz * 100000 + cx
