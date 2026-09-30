class_name GameClock
extends RefCounted
## World clock. hour 0..24. time_scale = game seconds per real second (48 -> a 24 h day lasts 30 real minutes).

var hour: float = 16.5
var day: int = 1
var time_scale: float = 48.0
var total_game_s: float = 0.0
var weather_offset_c: float = 0.0  # cold snaps / storms later


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
	var m := int((hour - h) * 60.0)
	return "Day %d  %02d:%02d" % [day, h, m]
