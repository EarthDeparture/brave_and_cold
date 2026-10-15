class_name PotCooking
extends RefCounted
## N3 cook pot: teas and stews brewed in a pot that sits in one pan slot of any lit
## FireSource (lookout, cabin and hut stoves, the pot-belly, campfires). The pot and the
## water bottle leave the pack while it cooks and come back with the food on collect,
## so one pot means one brew at a time. Recipes: data/pot_recipes.json.
const DATA_PATH := "res://data/pot_recipes.json"
const POT := "cooking_pot"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null: _data = JSON.parse_string(f.get_as_text())
	return _data

static func recipes() -> Array: return data().get("recipes", [])

static func outputs() -> Array: return recipes().map(func(r: Dictionary) -> String: return String(r.id))

static func by_id(id: String) -> Dictionary:
	for r: Dictionary in recipes():
		if String(r.id) == id: return r
	return {}

static func cook_s(r: Dictionary) -> float: return float(r.get("cook_min", 20)) * 60.0

## Item ids an input slot accepts (a group name or a plain item id).
static func options(slot: String) -> Array:
	return (data().get("groups", {}) as Dictionary).get(slot, [slot])

## The carried item that fills a slot: the stalest perishable first, like the pans.
static func pick(inv: Inventory, slot: String, n: int) -> String:
	var have: Array = options(slot).filter(func(id: String) -> bool: return inv.count(id) >= n and (Inventory.shelf_s(id) <= 0.0 or inv.freshness(id) > 0.0))
	have.sort_custom(func(a: String, b: String) -> bool: return inv.freshness(a) < inv.freshness(b))
	return have[0] if not have.is_empty() else ""

## "" when the pack holds the pot and every input, else what is missing.
static func missing(inv: Inventory, r: Dictionary) -> String:
	if inv.count(POT) < 1: return "Need a cooking pot"
	for slot: String in (r.inputs as Dictionary):
		var n := int(r.inputs[slot])
		if pick(inv, slot, n) == "":
			var first: String = options(slot)[0]
			var what := "drinking water" if slot == "water" else (slot.replace("_", " ") if options(slot).size() > 1 else inv.name_of(first).to_lower())
			return "Need %s%s" % [("%d " % n) if n > 1 else "", what]
	return ""

static func ready_recipes(inv: Inventory) -> Array:
	return recipes().filter(func(r: Dictionary) -> bool: return missing(inv, r) == "")

## Put a recipe on the fire. Returns the message for the player.
static func begin(batch: CookBatch, inv: Inventory, r: Dictionary, lit: bool, fire_label := "fire") -> String:
	if not lit: return "Light the %s first" % fire_label
	if batch.free_slots() == 0: return "No room on the %s: collect something first" % fire_label
	var why := missing(inv, r)
	if why != "": return why
	var age := 0.0; var main := ""
	var returns := {POT: 1}
	for slot: String in (r.inputs as Dictionary):
		var n := int(r.inputs[slot]); var id := pick(inv, slot, n)
		if Inventory.shelf_s(id) > 0.0 and age <= float(inv.age.get(id, 0.0)):
			age = float(inv.age.get(id, 0.0)); main = id
		inv.remove(id, n)
		if id == "clean_water": returns["empty_bottle"] = int(returns.get("empty_bottle", 0)) + n
	inv.remove(POT)
	var p := FoodPortion.create(main if main != "" else String(r.id), String(r.id), cook_s(r), age)
	p["cook_s"] = cook_s(r); p["returns"] = returns
	batch.portions.append(p)
	return "%s on the %s: %d min of burn" % [String(r.name), fire_label, int(r.get("cook_min", 20))]

## What a pot on the fire gives back with its food (the pot, the bottle).
static func give_back(p: Dictionary, inv: Inventory) -> void:
	for id: String in (p.get("returns", {}) as Dictionary):
		inv.add(id, int(p.returns[id]))
