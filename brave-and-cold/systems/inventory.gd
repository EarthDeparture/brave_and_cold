class_name Inventory
extends RefCounted
## Minimal inventory: stackable items + one body clothing slot that drives BodyTemperature insulation.

const ITEMS := {
	"wood": {"name": "Firewood", "kind": "fuel", "stack": 4, "desc": "Split firewood. Feeds a stove or campfire (40 min per log at a campfire)."},
	"stick": {"name": "Sticks", "kind": "fuel", "stack": 8, "desc": "Dry branches. Kindling for fires; useful for crafting."},
	"matches": {"name": "Matches", "kind": "misc", "stack": 10, "desc": "Wooden matches. One is used up to light a fire."},
	"flare": {"name": "Road Flare", "kind": "tool", "stack": 3, "desc": "Burns red for 60 seconds. Predators keep well away from it."},
	"axe": {"name": "Hatchet", "kind": "tool", "stack": 1, "desc": "Melee weapon. Loud. Zombies take two good hits."},
	"rifle": {"name": "Hunting Rifle", "kind": "weapon", "stack": 1, "desc": "Bolt-action hunting rifle. Loud: everything for a kilometre hears it."},
	"ammo": {"name": "Rifle Rounds", "kind": "ammo", "stack": 10, "desc": "Soft-point hunting rounds."},
	"beans": {"name": "Canned Beans", "kind": "food", "stack": 4, "kcal": 650.0, "desc": "Tinned beans. Safe to eat cold."},
	"venison_raw": {"name": "Raw Venison", "kind": "food", "stack": 4, "kcal": 350.0, "raw": true, "cooked": "venison_cooked", "desc": "Fresh meat. Cook it over a fire for more calories."},
	"venison_cooked": {"name": "Cooked Venison", "kind": "food", "stack": 4, "kcal": 900.0, "desc": "Seared venison steak."},
	"sweater": {"name": "Wool Sweater", "kind": "clothing", "stack": 1, "slot": "body", "warmth": 0.55, "windproof": 0.2, "waterproof": 0.1, "desc": "Warm but lets the wind straight through."},
	"parka": {"name": "Down Parka", "kind": "clothing", "stack": 1, "slot": "body", "warmth": 0.85, "windproof": 0.8, "waterproof": 0.6, "desc": "Heavy insulated parka. Wind and water resistant."},
}
const KIND_ORDER := ["weapon", "tool", "ammo", "clothing", "food", "fuel", "misc"]
const CAPACITY := 24          # backpack cells
const EQUIP_ITEMS := ["rifle", "axe"]   # live in equipment slots, not backpack cells
const WEIGHTS := {"wood": 1.2, "stick": 0.15, "matches": 0.02, "flare": 0.3, "axe": 1.1, "rifle": 3.6, "ammo": 0.03, "beans": 0.45, "venison_raw": 0.9, "venison_cooked": 0.6, "sweater": 0.7, "parka": 1.6}
const WEIGHT_SOFT := 30.0   # kg carried before you slow down
const WEIGHT_HARD := 45.0   # kg hard cap (cannot pick up more)
const BASE_WARMTH := 0.25
const BASE_WINDPROOF := 0.1
const BASE_WATERPROOF := 0.1

var counts: Dictionary = {}
var cond: Dictionary = {}       # id -> 0..1 condition for tools/weapons (missing = 1.0)
var equipped_body: String = ""
var body: BodyTemperature
var needs: Needs


func _init(b: BodyTemperature = null) -> void:
	body = b


static func stack_max(id: String) -> int:
	return int(ITEMS[id].get("stack", 1)) if ITEMS.has(id) else 1


static func weight_of(id: String) -> float:
	return float(WEIGHTS.get(id, 0.5))


## Total carried weight in kg (backpack + worn + equipment slots).
func total_weight() -> float:
	var w := 0.0
	for id in counts.keys():
		w += weight_of(String(id)) * float(counts[id])
	return w


## Movement multiplier from encumbrance: 1.0 up to WEIGHT_SOFT, easing to 0.6 at WEIGHT_HARD.
func speed_mult() -> float:
	return clampf(remap(total_weight(), WEIGHT_SOFT, WEIGHT_HARD, 1.0, 0.6), 0.6, 1.0)


func condition(id: String) -> float:
	return float(cond.get(id, 1.0))


## Wear a tool by amt (0..1 fraction). Returns remaining condition.
func wear(id: String, amt: float) -> float:
	var c := clampf(condition(id) - amt, 0.0, 1.0)
	cond[id] = c
	return c


static func kind_of(id: String) -> String:
	return String(ITEMS[id].get("kind", "misc")) if ITEMS.has(id) else "misc"


## Backpack cells: [{id, n}] sorted by kind. Worn clothing (one unit) and equipment-slot items are not counted.
func stacks_for(cnt: Dictionary, worn: String) -> Array:
	var out: Array = []
	for id in cnt.keys():
		if EQUIP_ITEMS.has(id):
			continue
		var n: int = int(cnt[id]) - (1 if id == worn else 0)
		var sm := stack_max(id)
		while n > 0:
			out.append({"id": id, "n": mini(n, sm)})
			n -= sm
	out.sort_custom(func(a, b) -> bool:
		var ka := KIND_ORDER.find(kind_of(a["id"]))
		var kb := KIND_ORDER.find(kind_of(b["id"]))
		if ka != kb:
			return ka < kb
		if a["id"] != b["id"]:
			return String(a["id"]) < String(b["id"])
		return int(a["n"]) > int(b["n"]))
	return out


func stacks() -> Array:
	return stacks_for(counts, equipped_body)


func slots_used() -> int:
	return stacks().size()


func can_add(id: String, n: int = 1) -> bool:
	if EQUIP_ITEMS.has(id):
		return true
	if total_weight() + weight_of(id) * float(n) > WEIGHT_HARD:
		return false
	var c := counts.duplicate()
	c[id] = int(c.get(id, 0)) + n
	return stacks_for(c, equipped_body).size() <= CAPACITY


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
		cond.erase(id)
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
