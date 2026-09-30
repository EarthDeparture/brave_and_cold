class_name Inventory
extends RefCounted
## Minimal inventory: stackable items + one body clothing slot that drives BodyTemperature insulation.

const ITEMS := {
	"wood": {"name": "Firewood"},
	"matches": {"name": "Matches"},
	"sweater": {"name": "Wool Sweater", "slot": "body", "warmth": 0.55, "windproof": 0.2, "waterproof": 0.1},
	"parka": {"name": "Down Parka", "slot": "body", "warmth": 0.85, "windproof": 0.8, "waterproof": 0.6},
}
const BASE_WARMTH := 0.25
const BASE_WINDPROOF := 0.1
const BASE_WATERPROOF := 0.1

var counts: Dictionary = {}
var equipped_body: String = ""
var body: BodyTemperature


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


func is_wearable(id: String) -> bool:
	return ITEMS.has(id) and ITEMS[id].has("slot")


## Toggle equip/unequip. Returns a short status message.
func use(id: String) -> String:
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
