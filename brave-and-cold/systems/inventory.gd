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
	"tackle": {"name": "Fishing Tackle", "kind": "tool", "stack": 1, "desc": "Line, hook and lure. Fish through a hole in the ice. Wears with use."},
	"trout_raw": {"shelf_h": 24.0, "name": "Raw Trout", "kind": "food", "stack": 4, "kcal": 250.0, "raw": true, "cooked": "trout_cooked", "desc": "Fresh lake trout. Cook it."},
	"trout_cooked": {"shelf_h": 60.0, "name": "Cooked Trout", "kind": "food", "stack": 4, "kcal": 600.0, "desc": "Flaky, fatty trout."},
	"whitefish_raw": {"shelf_h": 24.0, "name": "Raw Whitefish", "kind": "food", "stack": 4, "kcal": 220.0, "raw": true, "cooked": "whitefish_cooked", "desc": "Lean lake whitefish. Cook it."},
	"whitefish_cooked": {"shelf_h": 60.0, "name": "Cooked Whitefish", "kind": "food", "stack": 4, "kcal": 520.0, "desc": "Mild, filling whitefish."},
	"pike_raw": {"shelf_h": 24.0, "name": "Raw Pike", "kind": "food", "stack": 2, "kcal": 450.0, "raw": true, "cooked": "pike_cooked", "desc": "A big, bony pike. Cook it."},
	"pike_cooked": {"shelf_h": 60.0, "name": "Cooked Pike", "kind": "food", "stack": 2, "kcal": 1000.0, "desc": "A whole pike, roasted. A real meal."},
	"hammer": {"name": "Hammer", "kind": "tool", "stack": 1, "desc": "Claw hammer. Needed to board up windows and doors. Loud."},
	"bandage": {"name": "Bandage", "kind": "med", "stack": 6, "desc": "Clean cloth wrap. Stops bleeding."},
	"antiseptic": {"name": "Antiseptic", "kind": "med", "stack": 3, "desc": "Disinfectant. Clean a wound within two hours or the infection takes hold."},
	"antibiotics": {"name": "Antibiotics", "kind": "med", "stack": 2, "desc": "A full course. Cures an infection at any stage."},
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
	"bear_coat": {"name": "Bear Fur Coat", "kind": "clothing", "stack": 1, "slot": "jacket", "warmth": 0.95, "windproof": 0.75, "waterproof": 0.45, "desc": "Heavy as sin, warmest thing you can wear. Weaker against rain than the parka."},
	"rotten_meat": {"name": "Rotten Meat", "kind": "misc", "stack": 4, "desc": "Spoiled. Slimy and green. Do not eat it; drop it before wolves smell it on you."},
	"sweater": {"name": "Wool Sweater", "kind": "clothing", "stack": 1, "slot": "top", "warmth": 0.55, "windproof": 0.2, "waterproof": 0.1, "desc": "Warm but lets the wind straight through."},
	"parka": {"name": "Down Parka", "kind": "clothing", "stack": 1, "slot": "jacket", "warmth": 0.85, "windproof": 0.8, "waterproof": 0.6, "desc": "Heavy insulated parka. Wind and water resistant."},
}
## God mode (set by GameWorld every frame from Player.god): ammo, flares and matches are never used up, nothing wears.
static var infinite := false
const INFINITE_IDS := ["ammo", "flare", "matches"]
const KIND_ORDER := ["weapon", "tool", "ammo", "clothing", "food", "fuel", "misc"]
const CAPACITY := 24          # backpack cells
const EQUIP_ITEMS := ["rifle", "axe"]   # live in equipment slots, not backpack cells
const WEIGHTS := {"wood": 1.2, "stick": 0.15, "thatch": 0.05, "cordage": 0.05, "kindling": 0.1, "bow_drill": 0.4, "jerky": 0.2, "reed": 0.06, "tinder": 0.02, "matches": 0.02, "flare": 0.3, "axe": 1.1, "rifle": 3.6, "ammo": 0.03, "beans": 0.45, "venison_raw": 0.9, "knife": 0.25, "wolf_meat_raw": 0.7, "wolf_meat_cooked": 0.5, "bear_meat_raw": 0.9, "bear_meat_cooked": 0.65, "fat": 0.4, "gut": 0.3, "deer_hide": 1.5, "wolf_pelt": 0.9, "bear_pelt": 4.0, "venison_cooked": 0.6, "sweater": 0.7, "parka": 1.6, "cured_hide": 1.0, "wolf_fur": 0.7, "bear_fur": 3.0, "toque": 0.1, "hide_cap": 0.3, "wolf_hat": 0.3, "hide_mitts": 0.3, "wolf_mitts": 0.3, "hide_boots": 0.8, "hide_leggings": 0.8, "bear_coat": 4.5, "rotten_meat": 0.5, "hammer": 0.8, "nails": 0.01, "plank": 0.9, "bandage": 0.05, "antiseptic": 0.2, "antibiotics": 0.05, "rag": 0.05, "tackle": 0.1, "trout_raw": 0.6, "trout_cooked": 0.45, "whitefish_raw": 0.5, "whitefish_cooked": 0.38, "pike_raw": 1.6, "pike_cooked": 1.2}
const WEIGHT_SOFT := 30.0   # kg carried before you slow down
const WEIGHT_HARD := 45.0   # kg hard cap (cannot pick up more)
const BASE_WARMTH := 0.25
const BASE_WINDPROOF := 0.1
const BASE_WATERPROOF := 0.1
const WARM_CAP := 0.97
const PROOF_CAP := 0.95
## Clothing slots, in the order the gear screen draws them. TOP (sweater) goes under JACKET (parka / coat) and the two
## layer: a jacket alone is as warm as before, a top alone replaces the bare base, both together beat either one.
const EXTRA_SLOTS := ["head", "top", "jacket", "legs", "hands", "feet"]
const WORN_ORDER := ["jacket", "top", "head", "legs", "hands", "feet"]
const LAYER_K := 0.4          # share of the top's warmth above bare that survives under a jacket (compression)

var counts: Dictionary = {}
var cond: Dictionary = {}       # id -> 0..1 condition for tools/weapons (missing = 1.0)
var age: Dictionary = {}           # perishable id -> average age of the stack, game seconds
var extra: Dictionary = {}          # slot (head/top/jacket/legs/hands/feet) -> id
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
	if infinite:
		return condition(id)
	var c := clampf(condition(id) - amt, 0.0, 1.0)
	cond[id] = c
	return c


static func kind_of(id: String) -> String:
	return String(ITEMS[id].get("kind", "misc")) if ITEMS.has(id) else "misc"


## Ids currently worn, outermost first (jacket, top, head, legs, hands, feet).
func worn_list() -> Array:
	var out: Array = []
	for s in WORN_ORDER:
		if extra.has(s):
			out.append(extra[s])
	return out


func is_worn(id: String) -> bool:
	return id != "" and extra.values().has(id)


func jacket() -> String:
	return String(extra.get("jacket", ""))


func top() -> String:
	return String(extra.get("top", ""))


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
	if infinite and INFINITE_IDS.has(id):
		return true
	if count(id) < n:
		return false
	counts[id] = count(id) - n
	if counts[id] <= 0:
		counts.erase(id)
		cond.erase(id)
		age.erase(id)
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


func _use_med(id: String) -> String:
	if injury == null or count(id) < 1:
		return "None left"
	if id == "bandage":
		if not injury.bandage():
			return "Not bleeding"
		remove(id)
		return "Bandaged: bleeding stopped"
	if id == "antiseptic":
		var m := injury.antiseptic()
		if m == "":
			return "No fresh wound to clean"
		remove(id)
		return m
	if not injury.antibiotics():
		return "You feel no sign of infection"
	remove(id)
	return "Took the antibiotics: infection cleared"


## Toggle equip/unequip. Returns a short status message.
static var injury: Injury   # set by the world; medical items act on it


func use(id: String) -> String:
	if id == "bandage" or id == "antiseptic" or id == "antibiotics":
		return _use_med(id)
	if ITEMS.has(id) and ITEMS[id].has("kcal") and needs != null:
		var k: float = ITEMS[id]["kcal"]
		if not remove(id):
			return 'None left'
		needs.eat(k)
		return "Ate %s (+%d kcal)" % [name_of(id), int(k)]
	if not is_wearable(id):
		return "%s: nothing to do" % name_of(id)
	var slot := slot_of(id)
	if extra.get(slot, "") == id:
		extra.erase(slot)
		_recompute()
		return "Took off %s" % name_of(id)
	extra[slot] = id
	_recompute()
	return "Wearing %s" % name_of(id)


## Torso layers set the base: jacket alone, top alone, or both layered (the top is squashed under the jacket, so it adds
## LAYER_K of its warmth above bare and a little wind / water resistance). Head / legs / hands / feet add on top.
## Capped so no outfit is a perfect shell.
func _recompute() -> void:
	if body == null:
		return
	var w := BASE_WARMTH
	var wp := BASE_WINDPROOF
	var wa := BASE_WATERPROOF
	var jd: Dictionary = ITEMS[extra["jacket"]] if extra.has("jacket") else {}
	var td: Dictionary = ITEMS[extra["top"]] if extra.has("top") else {}
	if not jd.is_empty() and not td.is_empty():
		w = float(jd["warmth"]) + (float(td["warmth"]) - BASE_WARMTH) * LAYER_K
		wp = float(jd["windproof"]) + (1.0 - float(jd["windproof"])) * float(td["windproof"]) * 0.5
		wa = float(jd["waterproof"]) + (1.0 - float(jd["waterproof"])) * float(td["waterproof"]) * 0.5
	elif not jd.is_empty():
		w = float(jd["warmth"])
		wp = float(jd["windproof"])
		wa = float(jd["waterproof"])
	elif not td.is_empty():
		w = float(td["warmth"])
		wp = float(td["windproof"])
		wa = float(td["waterproof"])
	for s in EXTRA_SLOTS:
		if s == "top" or s == "jacket":
			continue
		if extra.has(s):
			var e: Dictionary = ITEMS[extra[s]]
			w += float(e["warmth"])
			wp += float(e["windproof"])
			wa += float(e["waterproof"])
	body.warmth = minf(w, WARM_CAP)
	body.windproof = minf(wp, PROOF_CAP)
	body.waterproof = minf(wa, PROOF_CAP)
