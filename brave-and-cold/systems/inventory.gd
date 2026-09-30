class_name Inventory
extends RefCounted
## Minimal inventory: stackable items + one body clothing slot that drives BodyTemperature insulation.

const ITEMS := {
	"wood": {"name": "Firewood"},
	"matches": {"name": "Matches"},
	"axe": {"name": "Hatchet"},
	"rifle": {"name": "Hunting Rifle"},
	"ammo": {"name": "Rifle Rounds"},
	"beans": {"name": "Canned Beans", "kcal": 650.0},
	"venison_raw": {"name": "Raw Venison", "kcal": 350.0, "raw": true, "cooked": "venison_cooked"},
	"venison_cooked": {"name": "Cooked Venison", "kcal": 900.0},
	"sweater": {"name": "Wool Sweater", "slot": "body", "warmth": 0.55, "windproof": 0.2, "waterproof": 0.1},
	"parka": {"name": "Down Parka", "slot": "body", "warmth": 0.85, "windproof": 0.8, "waterproof": 0.6},
}
const BASE_WARMTH := 0.25
const BASE_WINDPROOF := 0.1
const BASE_WATERPROOF := 0.1

var counts: Dictionary = {}
var equipped_body: String = ""
var body: BodyTemperature
var needs: Needs


func _init(b: BodyTemperature = null) -> void:
	body = b


func count(id: String) -> int:
	return int(counts.get(id, 0))


func add(id: String, n: int = 1) -> void:
	counts[id] = count(id) + n


func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	counts[id] = count(id) - n
	if counts[id] <= 0:
		counts.erase(id)
		if equipped_body == id:
			_apply("")
	return true


func ids() -> Array:
	return counts.keys()


func name_of(id: String) -> String:
	return String(ITEMS[id]["name"])


## Cook all raw food in the pack. Returns number of items cooked.
func cook_all() -> int:
	var n := 0
	for id in counts.keys():
		if ITEMS[id].get("raw", false):
			var c: int = count(id)
			var out: String = ITEMS[id]["cooked"]
			counts.erase(id)
			add(out, c)
			n += c
	return n


func is_wearable(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].has("slot")


## Toggle equip/unequip. Returns a short status message.
func use(id: String) -> String:
	if ITEMS.has(id) and ITEMS[id].has("kcal") and needs != null:
		var k: float = ITEMS[id]["kcal"]
		if not remove(id):
			return 'None left'
		needs.eat(k)
		return "Ate %s (+%d kcal)" % [name_of(id), int(k)]
	if not is_wearable(id):
		return "%s: nothing to do" % name_of(id)
	if equipped_body == id:
		_apply("")
		return "Took off %s" % name_of(id)
	_apply(id)
	return "Wearing %s" % name_of(id)


func _apply(id: String) -> void:
	equipped_body = id
	if body == null:
		return
	if id == "":
		body.warmth = BASE_WARMTH
		body.windproof = BASE_WINDPROOF
		body.waterproof = BASE_WATERPROOF
	else:
		var d: Dictionary = ITEMS[id]
		body.warmth = d["warmth"]
		body.windproof = d["windproof"]
		body.waterproof = d["waterproof"]
