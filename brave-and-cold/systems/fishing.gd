class_name Fishing
extends RefCounted
## Ice-fishing odds. Pure functions so the later skill system can plug a level in without touching the world code.

## Raw fish: [item id, weight]. Pike is rare and big.
const SPECIES: Array = [["trout_raw", 0.45], ["whitefish_raw", 0.40], ["pike_raw", 0.15]]
const SPOOK_S := 900.0       # game seconds a hole stays quiet after a catch
const SPOOK_MULT := 0.35


## Time-of-day factor: fish feed at dawn and dusk, sulk at midday, barely move at night.
static func time_factor(hour: float) -> float:
	if (hour >= 5.0 and hour < 8.5) or (hour >= 16.0 and hour < 19.5):
		return 1.35
	if hour >= 21.0 or hour < 4.0:
		return 0.6
	return 1.0


## Chance of a bite for one attempt. level: fishing skill 0..10 (hook for the skill system).
static func bite_chance(hour: float, tackle_cond: float, level: int = 0, spooked: bool = false) -> float:
	var p := 0.5 * time_factor(hour) * (0.55 + 0.45 * tackle_cond) * (1.0 + 0.06 * float(level))
	if spooked:
		p *= SPOOK_MULT
	return clampf(p, 0.03, 0.92)


static func pick(u: float) -> String:
	var acc := 0.0
	for s in SPECIES:
		acc += float(s[1])
		if u < acc:
			return String(s[0])
	return String(SPECIES[0][0])