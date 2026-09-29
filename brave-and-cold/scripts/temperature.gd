extends Node
## Survival warmth points, not degrees. Runtime follows the DayNight clock.

signal temperature_changed(current: float, maximum: float)
signal frozen_changed(frozen: bool)
signal exposure_changed(outdoors: bool)

@export var max_temperature: float = 100.0
@export var drain_rate: float = 0.25
@export var outdoor_multiplier: float = 2.0
@export var night_multiplier: float = 2.0
@export var day_length: float = 240.0

var current_temperature: float = 100.0:
	set(value):
		var previous := current_temperature
		var was_frozen := is_frozen
		current_temperature = clampf(value, 0.0, maxf(max_temperature, 0.0))
		is_frozen = current_temperature <= 0.0
		if previous != current_temperature:
			temperature_changed.emit(current_temperature, max_temperature)
		if was_frozen != is_frozen:
			frozen_changed.emit(is_frozen)

var is_frozen: bool = false
var is_outdoors: bool = true:
	set(value):
		if is_outdoors == value:
			return
		is_outdoors = value
		exposure_changed.emit(is_outdoors)
var is_night: bool = false
var cycle_time: float = 0.0


func _ready() -> void:
	set_process(true)
	DayNight.time_advanced.connect(_advance_world_time)


func _advance_world_time(seconds: float, night: bool) -> void:
	if not is_processing():
		return
	day_length = DayNight.day_length
	_drain(seconds, night)
	is_night = DayNight.is_night
	cycle_time = fposmod(DayNight.cycle_time, maxf(day_length, 1.0))


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	# Split at day/night boundaries so drain is independent of frame size.
	var half_day := maxf(day_length, 1.0) / 2.0
	var remaining := delta
	cycle_time = fposmod(cycle_time, half_day * 2.0)
	while remaining > 0.0:
		is_night = cycle_time >= half_day
		var boundary := half_day * 2.0 if is_night else half_day
		var step := minf(remaining, boundary - cycle_time)
		_drain(step, is_night)
		remaining -= step
		cycle_time = fposmod(cycle_time + step, half_day * 2.0)
	is_night = cycle_time >= half_day


func _drain(seconds: float, night: bool) -> void:
	var rate := maxf(drain_rate, 0.0)
	if is_outdoors:
		rate *= maxf(outdoor_multiplier, 1.0)
	if night:
		rate *= maxf(night_multiplier, 1.0)
	current_temperature -= rate * seconds
