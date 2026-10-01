class_name Inventory
extends RefCounted
## Minimal inventory: stackable items + one body clothing slot that drives BodyTemperature insulation.

const ITEMS := {
	"wood": {"name": "Firewood", "kind": "fuel", "stack": 4, "desc": "Split firewood. Feeds a stove or campfire (40 min per log at a campfire)."},
	"stick": {"name": "Sticks", "kind": "fuel", "stack": 8, "desc": "Dry branches. Kindling for fires; useful for crafting."},
	"thatch": {"name": "Dry Grass", "kind": "misc", "stack": 10, "desc": "Bundle of dry grass. Tinder and thatch."},
	"reed": {"name": "Cattail Reeds", "kind": "misc", "stack": 10, "desc": "Tough reed stalks. Future: cordage, torches."},
	"tinder": {"name": "Tinder", "kind": "misc", "stack": 10, "desc": "Dry lichen or a grass nest. Catches a spark from a bow drill."},
	"cordage": {"name": "Cordage", "kind": "misc", "stack": 10, "desc": "Twisted line. Binds, lashes and strings a bow drill."},
	"kindling": {"name": "Kindling", "kind": "fuel", "stack": 8, "desc": "Shaved sticks packed with dry grass. Two kindling plus one log start a campfire."},
	"bow_drill": {"name": "Bow Drill", "kind": "tool", "stack": 1, "desc": "Friction fire set. Lights a campfire without matches: needs tinder, can fail."},
	"jerky": {"name": "Venison Jerky", "kind": "food", "stack": 6, "kcal": 500.0, "desc": "Dried strips. Light and calorie dense."},
	"matches": {"name": "Matches", "kind": "misc", "stack": 10, "desc": "Wooden matches. One is used up to light a fire."},
	"flare": {"name": "Road Flare", "kind": "tool", "stack": 3, "desc": "Burns red for 60 seconds. Predators keep well away from it."},
	"axe": {"name": "Hatchet", "kind": "tool", "stack": 1, "desc": "Melee weapon. Loud. Zombies take two good hits."},
	"rifle": {"name": "Hunting Rifle", "kind": "weapon", "stack": 1, "desc": "Bolt-action hunting rifle. Loud: everything for a kilometre hears it."},
	"ammo": {"name": "Rifle Rounds", "kind": "ammo", "stack": 10, "desc": "Soft-point hunting rounds."},
	"beans": {"name": "Canned Beans", "kind": "food", "stack": 4, "kcal": 650.0, "desc": "Tinned beans. Safe to eat cold."},
	"venison_raw": {"shelf_h": 30.0, "name": "Raw Venison", "kind": "food", "stack": 4, "kcal": 350.0, "raw": true, "cooked": "venison_cooked", "desc": "Fresh meat. Cook it over a fire for more calories."},
	"venison_cooked": {"shelf_h": 72.0, "name": "Cooked Venison", "kind": "food", "stack": 4, "kcal": 900.0, "desc": "Seared venison steak."},
	"hammer": {"name": "Hammer", "kind": "tool", "stack": 1, "desc": "Claw hammer. Needed to board up windows and doors. Loud."},
	"nails": {"name": "Nails", "kind": "misc", "stack": 25, "desc": "Box of nails. Two per plank."},
	"plank": {"name": "Plank", "kind": "misc", "stack": 8, "desc": "Rough plank. Board windows from the inside (4 per window)."},
	"rag": {"name": "Rags", "kind": "misc", "stack": 10, "desc": "Cloth strips. Two make a curtain that hides your light and your silhouette."},
	"knife": {"name": "Hunting Knife", "kind": "tool", "stack": 1, "desc": "Sharp skinning knife. Needed to skin, gut and fully butcher animals."},
	"wolf_meat_raw": {"shelf_h": 30.0, "name": "Raw Wolf Meat", "kind": "food", "stack": 4, "kcal": 250.0, "raw": true, "cooked": "wolf_meat_cooked", "desc": "Gamey, lean. Cook it."},
	"wolf_meat_cooked": {"shelf_h": 72.0, "name": "Cooked Wolf Meat", "kind": "food", "stack": 4, "kcal": 650.0, "desc": "Tough but filling."},
	"bear_meat_raw": {"shelf_h": 30.0, "name": "Raw Bear Meat", "kind": "food", "stack": 4, "kcal": 300.0, "raw": true, "cooked": "bear_meat_cooked", "desc": "Rich, fatty meat. Cook it."},
	"bear_meat_cooked": {"shelf_h": 72.0, "name": "Cooked Bear Meat", "kind": "food", "stack": 4, "kcal": 800.0, "desc": "Fatty and calorie dense."},
	"fat": {"name": "Animal Fat", "kind": "misc", "stack": 4, "desc": "Rendered fat. Future: candles, waterproofing, tinder."},
	"gut": {"name": "Gut", "kind": "misc", "stack": 4, "desc": "Cleaned animal gut. Future: cordage, sewing."},
	"deer_hide": {"name": "Deer Hide", "kind": "misc", "stack": 2, "desc": "Raw hide. Cure it by a fire, then sew it into clothing."},
	"wolf_pelt": {"name": "Wolf Pelt", "kind": "misc", "stack": 2, "desc": "Thick grey fur. Cure it by a fire, then sew it into warm clothing."},
	"bear_pelt": {"name": "Bear Pelt", "kind": "misc", "stack": 1, "desc": "Huge heavy pelt. Cure it by a fire: the warmest coat there is."},
	"cured_hide": {"name": "Cured Hide", "kind": "misc", "stack": 4, "desc": "Scraped and smoked deer leather. Sews into hats, mitts, boots and leggings."},
	"wolf_fur": {"name": "Wolf Fur", "kind": "misc", "stack": 2, "desc": "Cured wolf pelt. Warm, thick fur for hats and mitts."},
	"bear_fur": {"name": "Bear Fur", "kind": "misc", "stack": 1, "desc": "Cured bear pelt. Enough for a full coat."},
	"toque": {"name": "Wool Toque", "kind": "clothing", "stack": 1, "slot": "head", "warmth": 0.08, "windproof": 0.05, "waterproof": 0.02, "desc": "Knit cap. Warm head, cold-day basics."},
	"hide_cap": {"name": "Hide Cap", "kind": "clothing", "stack": 1, "slot": "head", "warmth": 0.06, "windproof": 0.05, "waterproof": 0.02, "desc": "Crude leather cap."},
	"wolf_hat": {"name": "Wolf Fur Hat", "kind": "clothing", "stack": 1, "slot": "head", "warmth": 0.10, "windproof": 0.10, "waterproof": 0.05, "desc": "Fur hat with ear flaps. Keeps the wind off your skull."},
	"hide_mitts": {"name": "Hide Mitts", "kind": "clothing", "stack": 1, "slot": "hands", "warmth": 0.06, "windproof": 0.10, "waterproof": 0.05, "desc": "Rough leather mitts."},
	"wolf_mitts": {"name": "Wolf Fur Mitts", "kind": "clothing", "stack": 1, "slot": "hands", "warmth": 0.10, "windproof": 0.12, "waterproof": 0.05, "desc": "Fur-lined mitts. Hands stay alive."},
	"hide_boots": {"name": "Hide Boots", "kind": "clothing", "stack": 1, "slot": "feet", "warmth": 0.08, "windproof": 0.10, "waterproof": 0.10, "desc": "Laced leather boots. Not pretty, dry-ish."},
	"hide_leggings": {"name": "Hide Leggings", "kind": "clothing", "stack": 1, "slot": "legs", "warmth": 0.10, "windproof": 0.10, "waterproof": 0.05, "desc": "Leather leggings tied at the knee."},
	"bear_coat": {"name": "Bear Fur Coat", "kind": "clothing", "stack": 1, "slot": "body", "warmth": 0.95, "windproof": 0.75, "waterproof": 0.45, "desc": "Heavy as sin, warmest thing you can wear. Weaker against rain than the parka."},
	"rotten_meat": {"name": "Rotten Meat", "kind": "misc", "stack": 4, "desc": "Spoiled. Slimy and green. Do not eat it; drop it before wolves smell it on you."},
	"sweater": {"name": "Wool Sweater", "kind": "clothing", "stack": 1, "slot": "body", "warmth": 0.55, "windproof": 0.2, "waterproof": 0.1, "desc": "Warm but lets the wind straight through."},
	"parka": {"name": "Down Parka", "kind": "clothing", "stack": 1, "slot": "body", "warmth": 0.85, "windproof": 0.8, "waterproof": 0.6, "desc": "Heavy insulated parka. Wind and water resistant."},
}
const KIND_ORDER := ["weapon", "tool", "ammo", "clothing", "food", "fuel", "misc"]
const CAPACITY := 24          # backpack cells
const EQUIP_ITEMS := ["rifle", "axe"]   # live in equipment slots, not backpack cells
const WEIGHTS := {"wood": 1.2, "stick": 0.15, "thatch": 0.05, "cordage": 0.05, "kindling": 0.1, "bow_drill": 0.4, "jerky": 0.2, "reed": 0.06, "tinder": 0.02, "matches": 0.02, "flare": 0.3, "axe": 1.1, "rifle": 3.6, "ammo": 0.03, "beans": 0.45, "venison_raw": 0.9, "knife": 0.25, "wolf_meat_raw": 0.7, "wolf_meat_cooked": 0.5, "bear_meat_raw": 0.9, "bear_meat_cooked": 0.65, "fat": 0.4, "gut": 0.3, "deer_hide": 1.5, "wolf_pelt": 0.9, "bear_pelt": 4.0, "venison_cooked": 0.6, "sweater": 0.7, "parka": 1.6, "cured_hide": 1.0, "wolf_fur": 0.7, "bear_fur": 3.0, "toque": 0.1, "hide_cap": 0.3, "wolf_hat": 0.3, "hide_mitts": 0.3, "wolf_mitts": 0.3, "hide_boots": 0.8, "hide_leggings": 0.8, "bear_coat": 4.5, "rotten_meat": 0.5, "hammer": 0.8, "nails": 0.01, "plank": 0.9, "rag": 0.05}
const WEIGHT_SOFT := 30.0   # kg carried before you slow down
const WEIGHT_HARD := 45.0   # kg hard cap (cannot pick up more)
const BASE_WARMTH := 0.25
const BASE_WINDPROOF := 0.1
const BASE_WATERPROOF := 0.1
const WARM_CAP := 0.97
const PROOF_CAP := 0.95
const EXTRA_SLOTS := ["head", "legs", "hands", "feet"]

var counts: Dictionary = {}
var cond: Dictionary = {}       # id -> 0..1 condition for tools/weapons (missing = 1.0)
var age: Dictionary = {}           # perishable id -> average age of the stack, game seconds
var equipped_body: String = ""      # torso slot (also the one that sets the base insulation)
var extra: Dictionary = {}          # slot (head/legs/hands/feet) -> id, adds to the torso insulation
var body: BodyTemperature
var needs: Needs


func _init(b: BodyTemperature = null) -> void:
	body = b


static func shelf_s(id: String) -> float:
	return float(ITEMS[id].get("shelf_h", 0.0)) * 3600.0 if ITEMS.has(id) else 0.0


## 1.0 fresh .. 0.0 about to spoil (always 1.0 for non-perishables).
func freshness(id: String) -> float:
	var s := shelf_s(id)
	if s <= 0.0:
		return 1.0
	return clampf(1.0 - float(age.get(id, 0.0)) / s, 0.0, 1.0)


## Age perishables by game seconds. A whole stack spoils at once into Rotten Meat. Returns names of spoiled items.
func tick(game_s: float) -> Array:
	var spoiled: Array = []
	for id in counts.keys():
		var s := shelf_s(String(id))
		if s <= 0.0:
			continue
		age[id] = float(age.get(id, 0.0)) + game_s
		if float(age[id]) >= s:
			spoiled.append(String(id))
	var names: Array = []
	for id in spoiled:
		var n: int = count(id)
		names.append(name_of(id))
		counts.erase(id)
		cond.erase(id)
		age.erase(id)
		add("rotten_meat", n)
	return names


static func slot_of(id: String) -> String:
	return String(ITEMS[id].get("slot", "")) if ITEMS.has(id) else ""


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


## Ids currently worn: torso first, then head/legs/hands/feet.
func worn_list() -> Array:
	var out: Array = []
	if equipped_body != "":
		out.append(equipped_body)
	for s in EXTRA_SLOTS:
		if extra.has(s):
			out.append(extra[s])
	return out


func is_worn(id: String) -> bool:
	return id != "" and (equipped_body == id or extra.values().has(id))


## Backpack cells: [{id, n}] sorted by kind. Worn clothing (one unit each) and equipment-slot items are not counted.
func stacks_for(cnt: Dictionary, worn: Array) -> Array:
	var out: Array = []
	for id in cnt.keys():
		if EQUIP_ITEMS.has(id):
			continue
		var n: int = int(cnt[id]) - (1 if worn.has(id) else 0)
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
	return stacks_for(counts, worn_list())


func slots_used() -> int:
	return stacks().size()


func can_add(id: String, n: int = 1) -> bool:
	if EQUIP_ITEMS.has(id):
		return true
	if total_weight() + weight_of(id) * float(n) > WEIGHT_HARD:
		return false
	var c := counts.duplicate()
	c[id] = int(c.get(id, 0)) + n
	return stacks_for(c, worn_list()).size() <= CAPACITY


func count(id: String) -> int:
	return int(counts.get(id, 0))


func add(id: String, n: int = 1) -> void:
	if shelf_s(id) > 0.0:
		var old := count(id)
		age[id] = float(age.get(id, 0.0)) * float(old) / float(old + n)   # new items are fresh: stack age averages down
	counts[id] = count(id) + n


func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	counts[id] = count(id) - n
	if counts[id] <= 0:
		counts.erase(id)
		cond.erase(id)
		age.erase(id)
		if equipped_body == id:
			_apply("")
		else:
			for s in EXTRA_SLOTS:
				if extra.get(s, "") == id:
					extra.erase(s)
			_recompute()
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
			age.erase(id)
			add(out, c)
			n += c
	return n


func has_raw() -> bool:
	for id in counts.keys():
		if ITEMS.has(id) and ITEMS[id].get("raw", false):
			return true
	return false


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
	var slot := slot_of(id)
	if slot != "body":
		if extra.get(slot, "") == id:
			extra.erase(slot)
			_recompute()
			return "Took off %s" % name_of(id)
		extra[slot] = id
		_recompute()
		return "Wearing %s" % name_of(id)
	if equipped_body == id:
		_apply("")
		return "Took off %s" % name_of(id)
	_apply(id)
	return "Wearing %s" % name_of(id)


func _apply(id: String) -> void:
	equipped_body = id
	_recompute()


## Torso item sets the base, head/legs/hands/feet add on top (capped so no outfit is a perfect shell).
func _recompute() -> void:
	if body == null:
		return
	var w := BASE_WARMTH
	var wp := BASE_WINDPROOF
	var wa := BASE_WATERPROOF
	if equipped_body != "":
		var d: Dictionary = ITEMS[equipped_body]
		w = float(d["warmth"])
		wp = float(d["windproof"])
		wa = float(d["waterproof"])
	for s in EXTRA_SLOTS:
		if extra.has(s):
			var e: Dictionary = ITEMS[extra[s]]
			w += float(e["warmth"])
			wp += float(e["windproof"])
			wa += float(e["waterproof"])
	body.warmth = minf(w, WARM_CAP)
	body.windproof = minf(wp, PROOF_CAP)
	body.waterproof = minf(wa, PROOF_CAP)
