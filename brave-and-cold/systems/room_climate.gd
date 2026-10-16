class_name RoomClimate
extends RefCounted
## Air temperature of one enclosed room. It moves toward a steady target:
##   outside + walls' insulation (reduced by leaks) + the stove's heat (FireSource glow)
## warming over tens of game minutes and cooling more slowly, faster with an open
## door or broken window. Lighting a cold cabin therefore warms it gradually, and a
## stove that goes out leaves residual warmth (TLD). Game seconds throughout.
const WARM_TAU_S := 45.0 * 60.0
const COOL_TAU_S := 120.0 * 60.0
var room_c := 0.0
var insulation_c := 6.0   # still air + walls, stove out, door shut
var fire_c := 24.0        # extra degrees a roaring stove holds at steady state
var fire: FireSource
var leak := 0.0           # 0 sealed .. 1 wide open (set by the owner each update)
var solar_c := 0.0        # degrees full sun adds through glazing (greenhouse)
var sun := 0.0            # 0..1 sun on the glazing now (set by the owner each update)

func _init(p_insulation := 6.0, p_fire: FireSource = null, p_fire_c := 24.0) -> void:
	insulation_c = p_insulation; fire = p_fire; fire_c = p_fire_c

func target_c(outside_c: float) -> float:
	var heat := fire.glow() * fire_c if fire != null else 0.0
	return outside_c + insulation_c * (1.0 - 0.8 * leak) + heat * (1.0 - 0.6 * leak) + solar_c * sun * (1.0 - 0.5 * leak)

## Start at steady state (new game / legacy save) so a crew-lit stove is already warm.
func settle(outside_c: float) -> void:
	room_c = target_c(outside_c)

func advance(game_s: float, outside_c: float) -> void:
	if game_s <= 0.0: return
	var target := target_c(outside_c)
	var tau := (WARM_TAU_S if target > room_c else COOL_TAU_S) / (1.0 + 3.0 * leak)
	room_c = target + (room_c - target) * exp(-game_s / tau)

## Door / broken-window leak from any building exposing door_open, door_broken, openings.
static func leak_of(building: Object) -> float:
	var l := 0.0
	if building == null: return l
	if "door_open" in building and bool(building.get("door_open")): l += 0.5
	if "door_broken" in building and bool(building.get("door_broken")): l += 0.2
	if "openings" in building:
		for o: Variant in building.get("openings"):
			if o is Opening and (o as Opening).passable(): l += 0.25
	return clampf(l, 0.0, 1.0)
