class_name FireSource
extends RefCounted
## The one fire standard: every stove, campfire and future heat source owns one of
## these. Rules come from data/fire_sources.json; owners only add a model, a point
## and presentation. Fuel and embers are GAME seconds of real burn.
const DATA_PATH := "res://data/fire_sources.json"
static var _data: Dictionary = {}
var type := ""
var spec: Dictionary = {}
var fuel_s := 0.0
var ember_s := 0.0
var cooking: CookBatch
var water := PreparedWater.new()
var rack: FoodPreservation  # null when this type has no drying rack

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null: _data = JSON.parse_string(f.get_as_text())
	return _data

static func type_spec(t: String) -> Dictionary:
	return (data().get("types", {}) as Dictionary).get(t, {})

## Fuel ids, longest burning first.
static func fuel_ids() -> Array:
	var ids: Array = (data().get("fuels", {}) as Dictionary).keys()
	ids.sort_custom(func(a, b) -> bool: return float(data().fuels[a].stove_min) > float(data().fuels[b].stove_min))
	return ids

static func burn_s_for(t: String, fuel_id: String) -> float:
	var f: Dictionary = (data().get("fuels", {}) as Dictionary).get(fuel_id, {})
	if f.is_empty(): return 0.0
	return float(f.stove_min) * 60.0 * float(type_spec(t).get("efficiency", 1.0))

## `overrides` are per-model facts only (cook_slots = how many pans fit the top).
func _init(t: String = "wood_stove", overrides: Dictionary = {}) -> void:
	type = t; spec = type_spec(t).duplicate(true); spec.merge(overrides, true)
	assert(not spec.is_empty(), "unknown fire type " + t)
	cooking = CookBatch.new(int(spec.get("cook_slots", 2)))
	rack = FoodPreservation.new() if bool(spec.get("rack", false)) else null

func label() -> String: return String(spec.get("name", "fire"))
func max_fuel_s() -> float: return float(spec.get("max_fuel_h", 12)) * 3600.0
func ember_full_s() -> float: return float(spec.get("ember_min", 0)) * 60.0
func hold_s() -> float: return float(spec.get("stoke_hold_s", 2.0))
func is_lit() -> bool: return fuel_s > 0.0
func has_embers() -> bool: return fuel_s <= 0.0 and ember_s > 0.0
func needs_starter() -> bool: return fuel_s <= 0.0 and ember_s <= 0.0
func burn_s(fuel_id: String) -> float: return burn_s_for(type, fuel_id)
func fits(fuel_id: String) -> bool: return fuel_s + burn_s(fuel_id) <= max_fuel_s() + 0.001

## Fuel the player carries for this fire, longest first.
func fuel_options(inv: Inventory) -> Array:
	return fuel_ids().filter(func(id: String) -> bool: return inv.count(id) > 0 and burn_s(id) > 0.0)

## Scripted state (owner property setters, crew-left fire, tests): exact fuel, no embers.
func set_fuel(v: float) -> void:
	fuel_s = maxf(0.0, v); ember_s = 0.0

## Raw fuel for scripted state (crew-left fire, tests). Players go through stoke().
func add_fuel(fuel_id: String, n: int = 1) -> void:
	fuel_s += burn_s(fuel_id) * n; ember_s = 0.0

## The single stoke rule for every fire. {ok: bool, msg: String}
func stoke(inv: Inventory, fuel_id: String) -> Dictionary:
	var b := burn_s(fuel_id)
	if b <= 0.0: return {"ok": false, "msg": "That will not burn"}
	if inv.count(fuel_id) < 1: return {"ok": false, "msg": "Need %s" % inv.name_of(fuel_id).to_lower()}
	if not fits(fuel_id): return {"ok": false, "msg": "The %s is too full for that; let it burn down" % label()}
	var how := ""
	if needs_starter():
		if inv.count("matches") < 1: return {"ok": false, "msg": "Need a match to light the cold %s" % label()}
		inv.remove("matches"); how = "Struck a match: the %s catches. " % label()
	elif has_embers():
		how = "The embers catch. "
	inv.remove(fuel_id); fuel_s += b; ember_s = 0.0
	return {"ok": true, "msg": how + "%s burns %s. %s of fuel" % [inv.name_of(fuel_id), duration(b), duration(fuel_s)]}

## ember_rate > 1 shortens embers (snow or rain on an open fire).
func advance(game_s: float, ember_rate: float = 1.0) -> void:
	var elapsed := maxf(0.0, game_s)
	var burn := minf(fuel_s, elapsed)
	water.advance(burn); cooking.advance(elapsed, burn)
	if rack != null: rack.advance(elapsed, burn)
	if fuel_s > 0.0:
		if elapsed >= fuel_s:
			ember_s = maxf(0.0, ember_full_s() - (elapsed - fuel_s) * ember_rate); fuel_s = 0.0
		else:
			fuel_s -= elapsed
	else:
		ember_s = maxf(0.0, ember_s - elapsed * ember_rate)

## Radiant/room heat in W. `inside` = the point is in the room this stove heats.
func heat_at(distance: float, inside: bool = true) -> float:
	if not is_lit(): return 0.0
	var h: Dictionary = spec.get("heat", {})
	var ramp := minf(1.0, fuel_s / maxf(1.0, float(h.get("ramp_s", 300))))
	if String(h.get("kind", "room")) == "room":
		if not inside: return 0.0
		return (float(h.room_w) + float(h.near_w) * pow(maxf(0.0, 1.0 - distance / float(h.near_r)), 2)) * ramp
	var radius := float(h.radius)
	if distance >= radius: return 0.0
	var f := 1.0 - distance / radius
	return float(h.near_w) * f * f * (0.6 + 0.4 * ramp)

## Beacon: lit windows / firelight at night, smoke by day. `leak` 0..1 = how much
## light escapes the owner's walls (an open campfire is 1).
func cue(bus: NoiseBus, pos: Vector3, night: float, leak: float, source: Object) -> void:
	if bus == null or not is_lit(): return
	if night > 0.15:
		var r := float(spec.get("light_r", 0)) * clampf(leak, 0, 1) * night
		if r > 1.0: bus.emit_light(pos, r, source)
	elif float(spec.get("smoke_r", 0)) > 0.0:
		bus.emit_smoke(pos, float(spec.smoke_r), source)

## Visual intensity 0..1: flames while lit, a dull glow on embers.
func glow() -> float:
	if is_lit(): return 0.55 + 0.45 * minf(1.0, fuel_s / 900.0)
	if has_embers(): return 0.18 * minf(1.0, ember_s / 600.0) + 0.06
	return 0.0

func status() -> String:
	if is_lit(): return "%s of fuel" % duration(fuel_s)
	if has_embers(): return "embers %s" % duration(ember_s)
	return "cold"

static func duration(s: float) -> String:
	if s >= 3600.0: return "%.1f h" % (s / 3600.0)
	return "%d min" % int(ceil(s / 60.0))

func to_dict() -> Dictionary:
	return {"type": type, "fuel_s": fuel_s, "ember_s": ember_s, "cooking": cooking.to_dict(), "water": water.to_dict(), "rack": rack.to_dict() if rack != null else {}}

func restore(d: Dictionary) -> void:
	fuel_s = clampf(float(d.get("fuel_s", 0)), 0.0, max_fuel_s())
	ember_s = clampf(float(d.get("ember_s", 0)), 0.0, ember_full_s())
	cooking.restore(d.get("cooking", {})); water.restore(d.get("water", {}))
	if rack != null: rack.restore(d.get("rack", {}))
