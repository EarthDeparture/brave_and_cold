class_name RecipeDB
extends RefCounted
## Data-driven crafting recipes (res://data/recipes.json).
## Recipe: {id, name, desc, inputs{id:n}, tools[ids], station ("" | "fire"), time_s, kcal, noise, out{id:n}}

const PATH := "res://data/recipes.json"
static var _cache: Array = []
static var _loaded := false


static func all() -> Array:
	if not _loaded:
		_loaded = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Array:
			_cache = parsed
	return _cache


static func get_recipe(id: String) -> Dictionary:
	for r: Dictionary in all():
		if r["id"] == id:
			return r
	return {}


## "" when craftable now, else a short reason.
static func blocked(inv: Inventory, r: Dictionary, near_fire: bool) -> String:
	for id in r["inputs"].keys():
		var need := int(r["inputs"][id])
		if inv.count(String(id)) < need:
			return "Need %s x%d (have %d)" % [inv.name_of(String(id)), need, inv.count(String(id))]
	for t in r.get("tools", []):
		if inv.count(String(t)) < 1:
			return "Needs a %s" % inv.name_of(String(t))
	if String(r.get("station", "")) == "fire" and not near_fire:
		return "Stand next to a lit fire"
	return ""


## Items that reference unknown item ids (data validation).
static func validate() -> Array:
	var bad: Array = []
	for r: Dictionary in all():
		for id in r["inputs"].keys():
			if not Inventory.ITEMS.has(String(id)):
				bad.append("%s input %s" % [r["id"], id])
		for id in r["out"].keys():
			if not Inventory.ITEMS.has(String(id)):
				bad.append("%s out %s" % [r["id"], id])
		for t in r.get("tools", []):
			if not Inventory.ITEMS.has(String(t)):
				bad.append("%s tool %s" % [r["id"], t])
	return bad
