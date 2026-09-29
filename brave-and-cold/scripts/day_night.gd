extends Node
## One cycle is 240 real seconds. Phase 0 is dawn, phase 0.5 is dusk.

signal dawn
signal dusk
signal time_advanced(seconds: float, night: bool)

@export_range(1.0, 3600.0) var day_length: float = 240.0
var cycle_time: float = 0.0
var time_of_day: float:
	get:
		return fposmod(cycle_time, maxf(day_length, 1.0)) / maxf(day_length, 1.0)
var is_night: bool:
	get:
		return time_of_day >= 0.5
var darkness: float:
	get:
		return 1.0 if is_night else 0.0
var aggro_multiplier: float:
	get:
		return lerpf(1.0, 1.5, darkness)
var spawn_multiplier: float:
	get:
		return lerpf(1.0, 2.0, darkness)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var length := maxf(day_length, 1.0)
	cycle_time = fposmod(cycle_time, length)
	var remaining := delta
	while remaining > 0.0:
		var night := is_night
		var boundary := length if night else length * 0.5
		var step := minf(remaining, boundary - cycle_time)
		cycle_time += step
		remaining -= step
		time_advanced.emit(step, night)
		if cycle_time >= boundary:
			if night:
				cycle_time = 0.0
				dawn.emit()
			else:
				dusk.emit()
