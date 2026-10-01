class_name Needs
extends RefCounted
## Calories + hydration. update() takes GAME seconds. Cold/exertion burn more; starving reduces metabolic heat (BodyTemperature.metabolism_mult).

const MAX_CAL := 2500.0
const BASE_CAL_PER_H := 75.0
const ACTIVITY_CAL_PER_H: Array[float] = [0.0, 120.0, 420.0]
const SHIVER_BONUS_PER_H := 90.0
const WATER_PER_H := 4.0   # % per game hour
const HUNGRY := 900.0
const STARVING := 300.0

var calories := 2000.0
var water := 85.0  # 0..100
var starve_dmg_accum := 0.0
var rest_mult := 1.0   # < 1 while asleep: resting bodies burn less


func update(game_s: float, activity: int, core_temp: float) -> void:
	var h := game_s / 3600.0
	var burn := (BASE_CAL_PER_H + ACTIVITY_CAL_PER_H[clampi(activity, 0, 2)]) * rest_mult
	if core_temp < BodyTemperature.SHIVER:
		burn += SHIVER_BONUS_PER_H
	calories = maxf(0.0, calories - burn * h)
	var w := WATER_PER_H * (1.0 + 0.5 * activity) * rest_mult
	water = maxf(0.0, water - w * h)


func eat(kcal: float) -> void:
	calories = minf(MAX_CAL, calories + kcal)


func drink(amount: float) -> void:
	water = minf(100.0, water + amount)


func hunger_state() -> String:
	if calories <= 0.0:
		return "starving"
	if calories < STARVING:
		return "famished"
	if calories < HUNGRY:
		return "hungry"
	return "fed"


func thirst_state() -> String:
	if water <= 0.0:
		return "dehydrated"
	if water < 20.0:
		return "parched"
	if water < 45.0:
		return "thirsty"
	return "hydrated"


## Metabolic heat multiplier: starving bodies make less heat.
func metabolism_mult() -> float:
	if calories < STARVING:
		return 0.75 + 0.25 * (calories / STARVING)
	return 1.0


## HP damage per real second from starvation / dehydration (0 when fine).
func damage_per_s() -> float:
	var d := 0.0
	if calories <= 0.0:
		d += 0.25
	if water <= 0.0:
		d += 0.35
	return d
