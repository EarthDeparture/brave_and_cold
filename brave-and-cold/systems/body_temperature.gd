class_name BodyTemperature
extends RefCounted
## Core body temperature model (deg C). Heat balance: metabolic + fire gain vs. conductive/convective loss through clothing.
## Thresholds (GDD): shivering < 36, hypothermia < 35, severe < 32, fatal <= 28.

const NORMAL := 37.0
const SHIVER := 36.0
const HYPOTHERMIA := 35.0
const SEVERE := 32.0
const FATAL := 28.0

const THERMAL_MASS := 3500.0        # J per (kg*C) * kg -> effective, tuned for pacing (game minutes matter, not physics)
const BASE_METABOLISM_W := 90.0
const ACTIVITY_W: Array[float] = [0.0, 70.0, 260.0]  # rest, walk, sprint added watts (index by int activity 0..2)
const LOSS_W_PER_C := 4.2           # watts lost per deg C skin-ambient difference at zero insulation, 0 wind
const WIND_FACTOR := 0.055          # extra loss multiplier per m/s of wind (reduced by windproofing)
const WET_LOSS_MULT := 2.5          # fully wet clothing multiplies loss

var core: float = NORMAL
var wetness: float = 0.0            # 0..1 clothing wetness
var warmth: float = 0.25            # 0..1 clothing insulation (base layer only ~0.25)
var windproof: float = 0.1          # 0..1
var waterproof: float = 0.1         # 0..1
var last_loss_w: float = 0.0
var last_gain_w: float = 0.0
var feels_like: float = -10.0


## delta: game seconds. ambient in C, wind in m/s. sheltered: under canopy/indoors reduces wind. fire_w: radiant gain (W).
## activity: 0 rest, 1 walk, 2 sprint. precipitation 0..1. in_water: drenches quickly.
func update(delta: float, ambient: float, wind: float, sheltered: bool, fire_w: float, activity: int, precipitation: float, in_water: bool) -> void:
	var eff_wind := wind * (0.3 if sheltered else 1.0)
	eff_wind *= (1.0 - 0.85 * windproof)
	var wind_mult := 1.0 + WIND_FACTOR * eff_wind
	var wet_gain := precipitation * (1.0 - waterproof) * 0.02
	if in_water:
		wet_gain = 0.5
	var dry := 0.0
	if ambient > 0.0 or fire_w > 100.0:
		dry = 0.004
	wetness = clampf(wetness + (wet_gain - dry) * delta, 0.0, 1.0)

	var insulation := clampf(warmth * (1.0 - 0.65 * wetness), 0.0, 0.97)
	var diff := maxf(NORMAL - 10.0 - ambient, -20.0)  # skin ~27 C
	var loss := LOSS_W_PER_C * diff * wind_mult * (1.0 - insulation) * (1.0 + (WET_LOSS_MULT - 1.0) * wetness)
	loss = maxf(loss, 0.0)
	var gain: float = BASE_METABOLISM_W + ACTIVITY_W[clampi(activity, 0, 2)] + fire_w
	last_loss_w = loss
	last_gain_w = gain
	# Net watts -> deg C / s. Comfort band: gain==loss at ~zero net.
	var net: float = gain - loss - 60.0  # 60 W basal dissipation baseline keeps a rested, dressed body stable in mild cold
	core += net / THERMAL_MASS * delta * 0.02
	if core > NORMAL:
		# homeostasis: excess heat is shed as sweat (dampens heavily insulated, exerting bodies) instead of overheating
		if activity >= 1 and warmth > 0.55:
			wetness = clampf(wetness + 0.0004 * (warmth - 0.5) * (1 + activity) * delta, 0.0, 1.0)
		core = move_toward(core, NORMAL, 0.05 * delta)
	core = clampf(core, 25.0, 38.5)
	feels_like = ambient - 0.9 * eff_wind * (1.0 - windproof) * 0.5 - 6.0 * wetness


func state_name() -> String:
	if core <= FATAL:
		return "fatal"
	if core < SEVERE:
		return "severe hypothermia"
	if core < HYPOTHERMIA:
		return "hypothermia"
	if core < SHIVER:
		return "shivering"
	return "ok"


func stamina_penalty() -> float:
	## 1.0 = full stamina regen, lower when cold.
	if core >= SHIVER:
		return 1.0
	return clampf(remap(core, SEVERE, SHIVER, 0.2, 1.0), 0.2, 1.0)
