class_name Injury
extends RefCounted
## Wounds: bleeding + a lethal, hidden infection timer (Project Zomboid tone).
##  - wound(sev, p_infect): adds bleeding; p_infect chance to start the infection clock.
##  - bleeding drains HP per REAL second; shallow wounds (< DEEP) clot by themselves, deep ones need a bandage.
##  - infection counts GAME seconds: hidden until INCUBATION_S (then fever + slow HP drain), death at DEATH_S.
##  - antiseptic works only inside EARLY_S of the last wound; antibiotics cure at any stage.

const BLEED_HP_PER_S := 0.35
const CLOT_RATE := 0.004
const DEEP := 0.35
const INCUBATION_S := 6.0 * 3600.0
const DEATH_S := 24.0 * 3600.0
const EARLY_S := 2.0 * 3600.0
const SICK_DRAIN_PER_H := 1.5

var player: Object
var bleed := 0.0
var inf_t := -1.0
var wound_age := -1.0
var rng := RandomNumberGenerator.new()


func wound(sev: float, p_infect: float) -> void:
	bleed = minf(1.5, bleed + sev)
	wound_age = 0.0
	if inf_t < 0.0 and rng.randf() < p_infect:
		inf_t = 0.0


func infected() -> bool:
	return inf_t >= 0.0


func symptomatic() -> bool:
	return inf_t >= INCUBATION_S


func bleeding() -> bool:
	return bleed > 0.02


func update(game_s: float, dt: float) -> void:
	if player == null or player.dead:
		return
	if wound_age >= 0.0:
		wound_age += game_s
	if bleed > 0.0:
		if bleed >= 0.02:
			player.hurt(BLEED_HP_PER_S * bleed * dt, "Bled out")
		if bleed < DEEP:
			bleed = maxf(0.0, bleed - CLOT_RATE * dt)
	if inf_t >= 0.0:
		inf_t += game_s
		if symptomatic():
			player.hurt(SICK_DRAIN_PER_H * game_s / 3600.0, "Succumbed to the infection")
		if inf_t >= DEATH_S:
			player.hurt(9999.0, "Succumbed to the infection")


## true = used up
func bandage() -> bool:
	if not bleeding():
		return false
	bleed = 0.0
	return true


## "" = nothing to clean (no recent wound); else a message. Cures an infection that is still younger than EARLY_S.
func antiseptic() -> String:
	if wound_age < 0.0 or wound_age > EARLY_S:
		return ""
	wound_age = -1.0
	if inf_t >= 0.0 and inf_t < EARLY_S:
		inf_t = -1.0
	return "Wound cleaned"


## true = used up (only when there was something to treat)
func antibiotics() -> bool:
	if inf_t < 0.0:
		return false
	inf_t = -1.0
	return true


func status_lines() -> Array[String]:
	var out: Array[String] = []
	if bleeding():
		out.append("Bleeding (heavy)" if bleed >= DEEP else "Bleeding (light)")
	if symptomatic():
		out.append("Fever: infection")
	return out


func to_dict() -> Dictionary:
	return {"bleed": bleed, "inf": inf_t, "age": wound_age}


func from_dict(d: Dictionary) -> void:
	bleed = float(d.get("bleed", 0.0))
	inf_t = float(d.get("inf", -1.0))
	wound_age = float(d.get("age", -1.0))
