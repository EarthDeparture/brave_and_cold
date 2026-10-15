class_name Injury
extends RefCounted
## Bleeding, treatable ordinary infection and independently rolled outbreak transmission.
## Older inf saves retain their existing medicine behaviour; new infected strikes use outbreak_t.
##  - wound(sev, p_infect): adds bleeding; p_infect chance to start the infection clock.
##  - bleeding drains HP per REAL second; shallow wounds (< DEEP) clot by themselves, deep ones need a bandage.
##  - infection counts GAME seconds: hidden until INCUBATION_S (then fever + slow HP drain), death at DEATH_S.
##  - antiseptic and antibiotics treat ordinary infection only, never outbreak transmission.

const RECOVERY_CAL := Needs.HUNGRY
const RECOVERY_WATER := 45.0
const RECOVERY_PER_H := 1.0
const REST_RECOVERY_MULT := 3.0
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
var outbreak_t:=-1.0
var outbreak_exposed:=false
var wound_age := -1.0
var rng := RandomNumberGenerator.new()


func wound(sev: float, p_infect: float, outbreak:bool=false) -> void:
	bleed = minf(1.5, bleed + sev)
	wound_age = 0.0
	if outbreak:
		outbreak_exposed=true
		if outbreak_t<0 and rng.randf()<p_infect:outbreak_t=0
	elif inf_t < 0.0 and rng.randf() < p_infect:
		inf_t = 0.0


## Reishi tea: clears an ordinary wound infection before fever (like antibiotics);
## once feverish it only pushes the fever back a few hours. Never the outbreak.
func reishi() -> String:
	if inf_t < 0.0:
		return "It cannot touch the outbreak" if outbreak_exposed else "No infection for it to fight"
	if inf_t < INCUBATION_S:
		inf_t = -1.0
		return "The wound infection fades"
	inf_t = maxf(INCUBATION_S - 3600.0, inf_t - 6.0 * 3600.0)
	return "The fever eases for now; it needs antibiotics"


func infected() -> bool:
	return inf_t >= 0.0 or outbreak_t>=0


func symptomatic() -> bool:
	return inf_t >= INCUBATION_S or outbreak_t>=INCUBATION_S


func bleeding() -> bool:
	return bleed >= 0.02


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
		if inf_t>=INCUBATION_S:
			player.hurt(SICK_DRAIN_PER_H * game_s / 3600.0, "Succumbed to the infection")
		if inf_t >= DEATH_S:
			player.hurt(9999.0, "Succumbed to the infection")

	if outbreak_t>=0:
		outbreak_t+=game_s
		if outbreak_t>=INCUBATION_S:player.hurt(SICK_DRAIN_PER_H*game_s/3600,"Succumbed to the outbreak")
		if outbreak_t>=DEATH_S:player.hurt(9999,"Succumbed to the outbreak")

## Blood is represented by the existing health pool. Game time makes normal
## updates and accelerated sleep use the same recovery clock, exactly once.
func recovery_block(needs: Needs, core: float) -> String:
	if player==null or not is_instance_valid(player) or player.dead:return "Recovery unavailable"
	if bleeding():return "Bleeding • apply a bandage"
	if symptomatic():return "Recovery paused • fever"
	if core<BodyTemperature.HYPOTHERMIA:return "Recovery paused • warm up"
	if needs.calories<=RECOVERY_CAL:return "Recovery needs food above 900 kcal"
	if needs.water<=RECOVERY_WATER:return "Recovery needs water above 45%"
	return ""
func recovery_status(needs: Needs, core: float) -> String:
	var blocked:=recovery_block(needs,core)
	if blocked!="":return blocked
	return "Blood replenished" if player.health>=100 else "Recovering • fed and hydrated"
func recover(game_s: float, needs: Needs, core: float, rest_mult: float=1.0) -> float:
	if game_s<=0 or recovery_block(needs,core)!="" or player.health>=100:return 0
	var gain:=minf(100-player.health,RECOVERY_PER_H*game_s/3600*clampf(rest_mult,0,REST_RECOVERY_MULT))
	player.health+=gain
	return gain

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
	if outbreak_exposed:out.append("Infected contact • transmission risk")
	if symptomatic():
		out.append("Fever: infection")
	return out


func to_dict() -> Dictionary:
	return {"bleed": bleed, "inf": inf_t, "age": wound_age,"outbreak_t":outbreak_t,"outbreak_exposed":outbreak_exposed}


func from_dict(d: Dictionary) -> void:
	bleed = float(d.get("bleed", 0.0))
	inf_t = float(d.get("inf", -1.0))
	wound_age = float(d.get("age", -1.0))
	outbreak_t=float(d.get("outbreak_t",-1));outbreak_exposed=bool(d.get("outbreak_exposed",false))
