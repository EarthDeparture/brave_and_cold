class_name GameClock
extends RefCounted
## Game seconds per real second. Preserve the awake rate separately from sleep acceleration.

const LEGACY_TIME_SCALE := 48.0
const OPENING_TIME_SCALE := 30.0 # 48 real minutes per day.

var hour: float = 16.5
var day: int = 1
var base_time_scale: float = LEGACY_TIME_SCALE
var time_scale: float = LEGACY_TIME_SCALE
var total_game_s: float = 0.0
var weather_offset_c: float = 0.0  # cold snaps / storms later


func set_pace(rate: float) -> void:
	base_time_scale = rate if is_finite(rate) and rate > 0.0 else LEGACY_TIME_SCALE
	time_scale = base_time_scale


func to_dict() -> Dictionary:
	return {"hour": hour, "day": day, "total": total_game_s,
		"pace_schema": 1, "base_time_scale": base_time_scale}


func restore(data: Dictionary) -> void:
	hour = float(data.get("hour", hour))
	day = int(data.get("day", day))
	total_game_s = float(data.get("total", total_game_s))
	# Saves without pace metadata keep the original resource/radio time scale.
	set_pace(float(data.get("base_time_scale", LEGACY_TIME_SCALE)))


func advance(real_delta: float) -> float:
	var gd := real_delta * time_scale
	total_game_s += gd
	hour += gd / 3600.0
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	return gd  # game seconds elapsed, for survival models


## Ambient air temperature (C): coldest ~05:00, warmest ~14:00. Boreal midwinter.
func ambient_c() -> float:
	var t := (hour - 5.0) / 24.0 * TAU
	var curve := (1.0 - cos(t)) * 0.5  # 0 at 05:00, 1 at 17:00 -> shift so peak ~14:00
	var peak_shift := clampf((hour - 5.0) / 9.0, 0.0, 1.0) if hour >= 5.0 and hour <= 14.0 else 0.0
	var day_frac: float
	if hour >= 5.0 and hour <= 14.0:
		day_frac = smoothstep(0.0, 1.0, peak_shift)
	elif hour > 14.0:
		day_frac = 1.0 - smoothstep(0.0, 1.0, clampf((hour - 14.0) / 15.0, 0.0, 1.0))
	else:
		day_frac = 1.0 - smoothstep(0.0, 1.0, clampf((hour + 10.0) / 15.0, 0.0, 1.0))
	return lerpf(-22.0, -8.0, day_frac) + weather_offset_c + 0.0 * curve


func time_string() -> String:
	var h := int(hour)
	# Prevent an exact minute boundary from displaying the previous minute
	# because subtracting the hour introduces floating-point round-off.
	var m := clampi(int((hour - h) * 60.0 + 0.000001), 0, 59)
	return "Day %d  %02d:%02d" % [day, h, m]
