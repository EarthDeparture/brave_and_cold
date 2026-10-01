class_name Weather
extends RefCounted
## Weather state machine: CLEAR -> CLOUDY -> FLURRY -> SNOW -> BLIZZARD (and back). Values blend smoothly toward the
## active state's targets. Drives wind, air temperature offset, precipitation, overcast, fog and cloud coverage.

enum S { CLEAR, CLOUDY, FLURRY, SNOW, BLIZZARD }

const NAMES: Array[String] = ["Clear", "Cloudy", "Light snow", "Snowfall", "Blizzard"]
# per state: wind m/s, temp offset C, precip 0..1, overcast 0..1, fog density multiplier, cloud coverage 0..1
const TBL: Array = [
	[2.0, 0.0, 0.0, 0.0, 1.0, 0.35],
	[4.0, -1.5, 0.0, 0.55, 1.5, 0.7],
	[5.5, -2.5, 0.3, 0.72, 3.0, 0.8],
	[9.0, -5.0, 0.65, 0.88, 7.0, 0.92],
	[19.0, -10.0, 1.0, 1.0, 24.0, 1.0],
]
# row = from state, columns = weights to each next state
const NEXT: Array = [
	[0.25, 0.65, 0.10, 0.0, 0.0],
	[0.20, 0.15, 0.45, 0.20, 0.0],
	[0.10, 0.25, 0.20, 0.40, 0.05],
	[0.0, 0.15, 0.30, 0.25, 0.30],
	[0.0, 0.0, 0.25, 0.65, 0.10],
]

var state: int = S.CLOUDY
var locked := false
var wind := 4.0          # gusting, m/s (use this)
var wind_base := 4.0
var temp_off := 0.0
var precip := 0.0
var overcast := 0.0
var fog_mult := 1.0
var coverage := 0.5
var wind_dir := Vector2(0.8, 0.6)  # unit xz direction the wind blows TOWARD
var _left_h := 3.0       # game hours left in this state
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _init(seed_v := 7) -> void:
	_rng.seed = seed_v
	_snap()


func set_state(s: int, snap := false) -> void:
	state = clampi(s, 0, S.BLIZZARD)
	_left_h = _rng.randf_range(1.5, 4.0)
	if snap:
		_snap()


func lock_state(s: int) -> void:
	locked = true
	set_state(s, true)


func state_name() -> String:
	return NAMES[state]


## real_delta seconds, game_s game seconds elapsed this frame.
func advance(real_delta: float, game_s: float) -> void:
	_t += real_delta
	if not locked:
		_left_h -= game_s / 3600.0
		if _left_h <= 0.0:
			_pick_next()
	var row: Array = TBL[state]
	var k := clampf(game_s / 1500.0, 0.0, 1.0)  # ~25 game-min blend
	wind_base = lerpf(wind_base, row[0], k)
	temp_off = lerpf(temp_off, row[1], k)
	precip = lerpf(precip, row[2], k)
	overcast = lerpf(overcast, row[3], k)
	fog_mult = lerpf(fog_mult, row[4], k)
	coverage = lerpf(coverage, row[5], k)
	var gust := 1.0 + 0.35 * sin(_t * 0.7) * sin(_t * 0.23 + 1.3) + 0.15 * sin(_t * 2.1)
	wind = maxf(wind_base * gust, 0.0)
	var a := 0.9 + 0.35 * sin(_t * 0.011)
	wind_dir = Vector2(cos(a), sin(a))


func _pick_next() -> void:
	var w: Array = NEXT[state]
	var r := _rng.randf()
	var acc := 0.0
	var nxt := state
	for i in range(w.size()):
		acc += float(w[i])
		if r <= acc:
			nxt = i
			break
	set_state(nxt)
	if nxt == S.BLIZZARD:
		_left_h = _rng.randf_range(0.8, 2.5)


func _snap() -> void:
	var row: Array = TBL[state]
	wind_base = row[0]
	wind = wind_base
	temp_off = row[1]
	precip = row[2]
	overcast = row[3]
	fog_mult = row[4]
	coverage = row[5]


func to_dict() -> Dictionary:
	return {"state": state, "left": _left_h}


func from_dict(d: Dictionary) -> void:
	set_state(int(d.get("state", state)), true)
	_left_h = float(d.get("left", _left_h))
