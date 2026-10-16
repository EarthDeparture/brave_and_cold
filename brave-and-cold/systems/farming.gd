class_name Farming
extends RefCounted
## Phase F: winter greenhouse plots. One plot = one crop. Growth needs all three of
## warmth (the greenhouse room's air, heated by its stove), light (daylight through the
## glazing; nothing at night) and moisture (kettle water poured from a bottle).
##   - air below 0 C for frost_kill_h (2 h) kills the plot; 0-8 C crawls; 15-28 C is full rate
##   - soil dries over ~a day; dry soil stops growth and dry_kill_h (24 h) kills it
## Seeds are finite (packets, seed potatoes); harvested potatoes replant. Game seconds.
const DATA_PATH := "res://data/crops.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null: _data = JSON.parse_string(f.get_as_text())
	return _data

static func crop(id: String) -> Dictionary: return (data().get("crops", {}) as Dictionary).get(id, {})
static func crop_ids() -> Array: return (data().get("crops", {}) as Dictionary).keys()
static func rule(k: String) -> float: return float((data().get("rules", {}) as Dictionary).get(k, 0.0))

static func new_plot() -> Dictionary:
	return {"crop": "", "growth": 0.0, "water": 0.0, "frost_s": 0.0, "dry_s": 0.0, "dead": false}

## Growth multiplier from air temperature.
static func temp_factor(c: float) -> float:
	if c < 0.0: return 0.0
	if c < 8.0: return 0.2
	if c < 15.0: return 0.2 + 0.8 * (c - 8.0) / 7.0
	if c <= 28.0: return 1.0
	return maxf(0.3, 1.0 - (c - 28.0) / 10.0)

## Light through the glazing: daylight 0..1 (sky), less under heavy overcast.
static func light_factor(day: float, overcast: float) -> float:
	return clampf(day, 0.0, 1.0) * (1.0 - 0.45 * clampf(overcast, 0.0, 1.0)) * rule("glazing") / 0.8 if day > 0.05 else rule("night_growth")

static func can_grow(p: Dictionary) -> bool: return String(p.crop) != "" and not bool(p.dead) and float(p.growth) < 1.0

static func ripe(p: Dictionary) -> bool: return String(p.crop) != "" and not bool(p.dead) and float(p.growth) >= 1.0

## Advance one plot by game seconds at this air temperature and light.
static func advance(p: Dictionary, game_s: float, air_c: float, light: float) -> void:
	if String(p.crop) == "" or bool(p.dead) or game_s <= 0.0: return
	p.water = maxf(0.0, float(p.water) - rule("dry_per_h") * game_s / 3600.0 * (0.4 + 0.6 * temp_factor(air_c)))
	p.frost_s = float(p.frost_s) + game_s if air_c < 0.0 else 0.0
	p.dry_s = float(p.dry_s) + game_s if float(p.water) <= 0.0 else 0.0
	if float(p.frost_s) >= rule("frost_kill_h") * 3600.0 or float(p.dry_s) >= rule("dry_kill_h") * 3600.0:
		p.dead = true; return
	if float(p.growth) >= 1.0: return
	var wet := clampf(float(p.water) / 0.15, 0.0, 1.0)
	var rate := temp_factor(air_c) * light * wet / (float(crop(String(p.crop)).get("grow_h", 48.0)) * 3600.0)
	p.growth = minf(1.0, float(p.growth) + rate * game_s)

static func plant(p: Dictionary, crop_id: String, inv: Inventory) -> String:
	var c := crop(crop_id)
	if c.is_empty(): return "Unknown crop"
	if String(p.crop) != "": return "The plot is taken"
	var seed_id := String(c.seed)
	if inv.count(seed_id) < 1: return "Need %s" % inv.name_of(seed_id).to_lower()
	inv.remove(seed_id)  # seed packets stack one per sowing
	p.merge({"crop": crop_id, "growth": 0.0, "frost_s": 0.0, "dry_s": 0.0, "dead": false}, true)
	return "Planted %s" % String(c.name)

## Pour one 0.5 L bottle of drinking water.
static func water(p: Dictionary, inv: Inventory) -> String:
	if inv.count("clean_water") < 1: return "Need a bottle of drinking water"
	if float(p.water) >= 0.95: return "The soil is already wet"
	inv.remove("clean_water"); inv.add("empty_bottle")
	p.water = minf(1.0, float(p.water) + rule("water_per_l") * 0.5)
	return "Watered the plot"

static func harvest(p: Dictionary, inv: Inventory) -> String:
	if bool(p.dead):
		var what := String(crop(String(p.crop)).get("name", "plants"))
		p.merge(new_plot(), true); return "Cleared the dead %s" % what
	if not ripe(p): return "Not ready"
	var c := crop(String(p.crop)); var n := randi_range(int(c.yield[0]), int(c.yield[1]))
	inv.add(String(c.harvest), n)
	var w := float(p.water)
	p.merge(new_plot(), true); p.water = w
	return "Harvested %d %s" % [n, String(c.name)]

static func status(p: Dictionary) -> String:
	if String(p.crop) == "": return "empty plot"
	var nm := String(crop(String(p.crop)).name)
	if bool(p.dead): return "dead %s" % nm
	var s := "%s %d%%" % [nm, int(float(p.growth) * 100.0)]
	if float(p.water) <= 0.15: s += " • dry"
	return s
