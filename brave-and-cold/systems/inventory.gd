class_name Inventory
extends RefCounted
## Minimal inventory: stackable items + one body clothing slot that drives BodyTemperature insulation.

const ITEMS := {
	"venison_dried": {"shelf_h":240.0,"name":"Dried Venison","kind":"food","stack":4,"kcal":900.0,"weight":0.3,"desc":"Stove-dried strips. Same energy as the cooked portion, half its weight. Ten-day shelf life when fresh; existing spoilage is retained."},
	"wolf_meat_dried": {"shelf_h":240.0,"name":"Dried Wolf Meat","kind":"food","stack":4,"kcal":650.0,"weight":0.25,"desc":"Stove-dried strips. Same energy as the cooked portion, half its weight. Ten-day shelf life when fresh; existing spoilage is retained."},
	"bear_meat_dried": {"shelf_h":240.0,"name":"Dried Bear Meat","kind":"food","stack":4,"kcal":800.0,"weight":0.325,"desc":"Stove-dried strips. Same energy as the cooked portion, half its weight. Ten-day shelf life when fresh; existing spoilage is retained."},
	"trout_dried": {"shelf_h":240.0,"name":"Dried Trout","kind":"food","stack":4,"kcal":600.0,"weight":0.225,"desc":"Stove-dried strips. Same energy as the cooked portion, half its weight. Ten-day shelf life when fresh; existing spoilage is retained."},
	"whitefish_dried": {"shelf_h":240.0,"name":"Dried Whitefish","kind":"food","stack":4,"kcal":520.0,"weight":0.19,"desc":"Stove-dried strips. Same energy as the cooked portion, half its weight. Ten-day shelf life when fresh; existing spoilage is retained."},
	"pike_dried": {"shelf_h":240.0,"name":"Dried Pike","kind":"food","stack":4,"kcal":1000.0,"weight":0.6,"desc":"Stove-dried strips. Same energy as the cooked portion, half its weight. Ten-day shelf life when fresh; existing spoilage is retained."},

	"dc_fuse":{"name":"Matched DC Fuse","kind":"misc","stack":4,"desc":"One correctly rated spare for the compound solar circuit. Fit only to a diagnosed open fuse with your service kit."},
	"sealed_connector":{"name":"Sealed Connector Pair","kind":"misc","stack":2,"desc":"Matched weather-sealed plugs for the optional winter controller refit. Issued with the crew-cache fuse."},
	"dc_cable":{"name":"Recovered DC Cable","kind":"misc","stack":1,"desc":"Tested lead recovered once from the isolated crew spur. Repairs a damaged solar cable, or fits the winter controller."},
	"winter_controller":{"name":"Winter Charge Controller","kind":"misc","stack":1,"desc":"Matched replacement from North Ridge Supply. Fit at the compound array with recovered cable, sealed connectors and your service kit. More efficient conversion; does not fill the battery."},
	"whetstone":{"name":"Whetstone","kind":"tool","stack":1,"desc":"Hone an axe or knife at the lookout desk. Each session uses a rag and 8% stone condition."},
	"sewing_kit":{"name":"Sewing Kit","kind":"tool","stack":1,"desc":"Mend clothing at the lookout desk with two rags and cordage. Thread and needle supply wears down."},
	"clean_water": {"name":"Drinking Water • 0.5 L","kind":"drink","stack":4,"desc":"Boiled water. Drink +25% hydration; keeps its empty bottle."},
	"empty_bottle": {"name":"Empty Bottle • 0.5 L","kind":"misc","stack":4,"desc":"Reusable water container. Bring it and a snow portion to the lookout kettle."},
	"snow_portion": {"name":"Clean Snow Portion","kind":"misc","stack":4,"desc":"Gathered snow for 0.5 L of water. Boil it before drinking."},
	"service_kit": {"name":"Insulated Service Kit","kind":"tool","stack":1,"desc":"Meters, insulated tools and a lockout kit for the North Ridge relay assignment."},
	"power_relay": {"name":"Transfer Relay","kind":"misc","stack":1,"desc":"Reserved replacement for the lookout transfer cabinet. Install with your service kit."},
	"wood": {"name": "Firewood", "kind": "fuel", "stack": 4, "desc": "Split firewood. Fuels a stove or campfire (40 min per log at a campfire). Gear > Craft: hatchet one firewood into two planks."},
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
	"timber_bolt_carbine": {"name": "Timber Bolt Carbine", "kind": "weapon", "stack": 1, "weight": 3.6, "desc": "Green-camo bolt carbine with a short scout scope. Five rounds, slow and sure. Loud: everything for a kilometre hears it."},
	"ranger_box_rifle": {"name": "Ranger Hunting Rifle", "kind": "weapon", "stack": 1, "weight": 3.9, "desc": "Amber-stocked hunting rifle under a long red scope. Four heavy rounds. Loud: everything for a kilometre hears it."},
	"frontier_vented_rifle": {"name": "Frontier Vented Rifle", "kind": "weapon", "stack": 1, "weight": 4.3, "desc": "Self-loading rifle with a vented shroud. Ten rounds, quick follow-ups. Loud: everything for a kilometre hears it."},
	"ridge_scout_rifle": {"name": "Ridge Marksman Rifle", "kind": "weapon", "stack": 1, "weight": 4.6, "desc": "Long-receiver marksman rifle with a big scope. Accurate at range. Loud: everything for a kilometre hears it."},
	"brush_lever_rifle": {"name": "Brush Lever Rifle", "kind": "weapon", "stack": 1, "weight": 3.3, "desc": "Thumbhole lever gun with a block sight. Six rounds, loaded one at a time. Loud: everything for a kilometre hears it."},
	"north_service_rifle": {"name": "North Service Rifle", "kind": "weapon", "stack": 1, "weight": 4.1, "desc": "Lime-stocked service rifle with a red-dot tube. Ten rounds. Loud: everything for a kilometre hears it."},
	"compact_patrol_rifle": {"name": "Compact Patrol Carbine", "kind": "weapon", "stack": 1, "weight": 3.0, "desc": "Folding-stock carbine. Twenty light rounds, short reach. Loud: everything for a kilometre hears it."},
	"expedition_rifle": {"name": "Expedition Long Rifle", "kind": "weapon", "stack": 1, "weight": 5.6, "desc": "Grey-camo heavy rifle with a large optic. Five devastating, very loud rounds. Loud: everything for a kilometre hears it."},
	"ammo": {"name": "Rifle Rounds", "kind": "ammo", "stack": 10, "desc": "Soft-point hunting rounds."},
	"beans": {"name": "Canned Beans", "kind": "food", "stack": 4, "kcal": 650.0, "desc": "Tinned beans. Safe to eat cold."},
	"venison_raw": {"shelf_h": 30.0, "name": "Raw Venison", "kind": "food", "stack": 4, "kcal": 900.0, "raw": true, "cooked": "venison_cooked", "desc": "Uncooked portion. Cook before eating; cooking removes water without adding calories."},
	"venison_cooked": {"shelf_h": 72.0, "name": "Cooked Venison", "kind": "food", "stack": 4, "kcal": 900.0, "desc": "Seared venison steak."},
	"tackle": {"name": "Fishing Tackle", "kind": "tool", "stack": 1, "desc": "Line, hook and lure. Fish through a hole in the ice. Wears with use."},
	"trout_raw": {"shelf_h": 24.0, "name": "Raw Trout", "kind": "food", "stack": 4, "kcal": 600.0, "raw": true, "cooked": "trout_cooked", "desc": "Fresh lake trout. Cook it."},
	"trout_cooked": {"shelf_h": 60.0, "name": "Cooked Trout", "kind": "food", "stack": 4, "kcal": 600.0, "desc": "Flaky, fatty trout."},
	"whitefish_raw": {"shelf_h": 24.0, "name": "Raw Whitefish", "kind": "food", "stack": 4, "kcal": 520.0, "raw": true, "cooked": "whitefish_cooked", "desc": "Lean lake whitefish. Cook it."},
	"whitefish_cooked": {"shelf_h": 60.0, "name": "Cooked Whitefish", "kind": "food", "stack": 4, "kcal": 520.0, "desc": "Mild, filling whitefish."},
	"pike_raw": {"shelf_h": 24.0, "name": "Raw Pike", "kind": "food", "stack": 2, "kcal": 1000.0, "raw": true, "cooked": "pike_cooked", "desc": "A big, bony pike. Cook it."},
	"pike_cooked": {"shelf_h": 60.0, "name": "Cooked Pike", "kind": "food", "stack": 2, "kcal": 1000.0, "desc": "A whole pike, roasted. A real meal."},
	"hammer": {"name": "Hammer", "kind": "tool", "stack": 1, "desc": "Claw hammer. Needed to board up windows and doors. Wears a little with every board (about six fully boarded houses) and breaks at 0%. Loud."},
	"cooking_pot": {"name": "Cooking Pot", "kind": "tool", "stack": 1, "desc": "Dented steel pot. Sits on a lit stove or campfire for teas and stews, and stays there until you collect."},
	"rose_hips": {"name": "Rose Hips", "kind": "misc", "stack": 12, "desc": "Wild rose fruit frozen on the cane. Two steep a cup of rose hip tea."},
	"reishi": {"name": "Reishi Mushroom", "kind": "misc", "stack": 6, "desc": "Lacquered bracket fungus cut from birch stumps. Its bitter tea fights early wound infection."},
	"birch_bark": {"name": "Birch Bark", "kind": "misc", "stack": 12, "desc": "Papery bark peeled from fallen birch. Two make a tea that eases aches."},
	"tea_rose_hip": {"name": "Rose Hip Tea", "kind": "food", "stack": 2, "kcal": 40.0, "water": 12.5, "hot_min": 40.0, "heal": 3.0, "desc": "Tart and hot. Warms you from the inside for a while."},
	"tea_birch": {"name": "Birch Bark Tea", "kind": "food", "stack": 2, "kcal": 10.0, "water": 12.5, "hot_min": 40.0, "heal": 8.0, "desc": "Woody and bitter. Eases aches: restores a little condition, and warms you."},
	"tea_reishi": {"name": "Reishi Tea", "kind": "food", "stack": 2, "kcal": 10.0, "water": 12.5, "hot_min": 30.0, "cure": "reishi", "desc": "Earthy, bitter. Clears a wound infection before fever sets in and only slows it after. Useless against the outbreak."},
	"meat_stew": {"shelf_h": 48.0, "name": "Meat Stew", "kind": "food", "stack": 2, "kcal": 1100.0, "water": 20.0, "hot_min": 60.0, "desc": "Meat simmered down in a pot of water. More filling than a steak, and hot."},
	"fish_stew": {"shelf_h": 40.0, "name": "Fish Stew", "kind": "food", "stack": 2, "kcal": 800.0, "water": 20.0, "hot_min": 60.0, "desc": "Fish boiled to a thin, hot chowder."},
	"bandage": {"name": "Bandage", "kind": "med", "stack": 6, "desc": "Stops bleeding. Recovery needs >900 kcal and >45% water."},
	"antiseptic": {"name": "Antiseptic", "kind": "med", "stack": 3, "desc": "Disinfectant. Clean recent wounds within two hours. Outbreak risk is separate."},
	"antibiotics": {"name": "Antibiotics", "kind": "med", "stack": 2, "desc": "A full course. Treats ordinary wound infection. Cannot cure outbreak transmission."},
	"nails": {"name": "Nails", "kind": "misc", "stack": 50, "desc": "Box of nails. One per board."},
	"plank": {"name": "Plank", "kind": "misc", "stack": 8, "desc": "Rough plank. Board windows from the inside (4 per window)."},
	"rag": {"name": "Rags", "kind": "misc", "stack": 10, "desc": "Cloth strips. Two make a curtain that hides your light and your silhouette."},
	"knife": {"name": "Hunting Knife", "kind": "tool", "stack": 1, "desc": "Sharp skinning knife. Needed to skin, gut and fully butcher animals."},
	"wolf_meat_raw": {"shelf_h": 30.0, "name": "Raw Wolf Meat", "kind": "food", "stack": 4, "kcal": 650.0, "raw": true, "cooked": "wolf_meat_cooked", "desc": "Gamey, lean. Cook it."},
	"wolf_meat_cooked": {"shelf_h": 72.0, "name": "Cooked Wolf Meat", "kind": "food", "stack": 4, "kcal": 650.0, "desc": "Tough but filling."},
	"bear_meat_raw": {"shelf_h": 30.0, "name": "Raw Bear Meat", "kind": "food", "stack": 4, "kcal": 800.0, "raw": true, "cooked": "bear_meat_cooked", "desc": "Rich, fatty meat. Cook it."},
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
## Eight real rifles (rifle sheet art). "rifle" stays a legacy alias: count("rifle") = rifles carried,
## add("rifle") gives the default carbine, remove("rifle") drops the one in the equipment slot.
const RIFLE_IDS := ["timber_bolt_carbine", "ranger_box_rifle", "frontier_vented_rifle", "ridge_scout_rifle", "brush_lever_rifle", "north_service_rifle", "compact_patrol_rifle", "expedition_rifle"]
const DEFAULT_RIFLE := "timber_bolt_carbine"
const WEIGHTS := {"whetstone":.25,"sewing_kit":.15,"clean_water":.6,"empty_bottle":.1,"snow_portion":.5,"service_kit":1.4,"power_relay":0.7,"wood": 1.2, "stick": 0.15, "thatch": 0.05, "cordage": 0.05, "kindling": 0.1, "bow_drill": 0.4, "jerky": 0.2, "reed": 0.06, "tinder": 0.02, "matches": 0.02, "flare": 0.3, "axe": 1.1, "rifle": 3.6, "ammo": 0.03, "beans": 0.45, "venison_raw": 0.9, "knife": 0.25, "wolf_meat_raw": 0.7, "wolf_meat_cooked": 0.5, "bear_meat_raw": 0.9, "bear_meat_cooked": 0.65, "fat": 0.4, "gut": 0.3, "deer_hide": 1.5, "wolf_pelt": 0.9, "bear_pelt": 4.0, "venison_cooked": 0.6, "sweater": 0.7, "parka": 1.6, "cured_hide": 1.0, "wolf_fur": 0.7, "bear_fur": 3.0, "toque": 0.1, "hide_cap": 0.3, "wolf_hat": 0.3, "hide_mitts": 0.3, "wolf_mitts": 0.3, "hide_boots": 0.8, "hide_leggings": 0.8, "bear_coat": 4.5, "rotten_meat": 0.5, "hammer": 0.8, "nails": 0.01, "plank": 0.9, "bandage": 0.05, "antiseptic": 0.2, "antibiotics": 0.05, "rag": 0.05, "tackle": 0.1, "trout_raw": 0.6, "trout_cooked": 0.45, "whitefish_raw": 0.5, "whitefish_cooked": 0.38, "pike_raw": 1.6, "pike_cooked": 1.2}
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
const WEAR_IDS := ["whetstone","sewing_kit","axe", "knife", "hammer", "bow_drill", "tackle"]   # items whose condition is tracked and shown in the Gear screen
var cond: Dictionary = {}       # id -> 0..1 condition for tools/weapons (missing = 1.0)
var age: Dictionary = {}           # perishable id -> average age of the stack, game seconds
var extra: Dictionary = {}          # slot (head/top/jacket/legs/hands/feet) -> id
var active_rifle := ""              # rifle in the equipment slot (others ride in the pack)
var loaded: Dictionary = {}         # rifle id -> rounds in its magazine / tube (taken from "ammo")
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
## rate: Spoilage.rate_c(air where the pack is); 1.0 = baseline shelf life.
func tick(game_s: float, rate: float = 1.0) -> Array:
	var spoiled: Array = []
	for id in counts.keys():
		var s := shelf_s(String(id))
		if s <= 0.0:
			continue
		age[id] = float(age.get(id, 0.0)) + game_s * rate
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
	if id in ["dc_fuse","sealed_connector","dc_cable","winter_controller"]:return {"dc_fuse":.025,"sealed_connector":.12,"dc_cable":1.1,"winter_controller":.65}[id]
	return float(ITEMS.get(id,{}).get("weight",WEIGHTS.get(id, 0.5)))


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
	if is_worn(id):_recompute()
	return c


static func wears(id: String) -> bool:
	return WEAR_IDS.has(id) or kind_of(id)=="clothing"


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
	var eq := _equipped_rifle(cnt)
	for id in cnt.keys():
		if EQUIP_ITEMS.has(id):
			continue
		var n: int = int(cnt[id]) - (1 if worn.has(id) or id == eq else 0)
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
	if id == "rifle": return true   # legacy query: the equipment slot always takes a rifle
	if EQUIP_ITEMS.has(id) or (is_rifle(id) and rifle_id() == ""):
		return true
	if total_weight() + weight_of(id) * float(n) > WEIGHT_HARD:
		return false
	var c := counts.duplicate()
	c[id] = int(c.get(id, 0)) + n
	return stacks_for(c, worn_list()).size() <= CAPACITY


func count(id: String) -> int:
	if id == "rifle":
		var n := int(counts.get("rifle", 0))
		for r: String in RIFLE_IDS: n += int(counts.get(r, 0))
		return n
	return int(counts.get(id, 0))


static func is_rifle(id: String) -> bool:
	return RIFLE_IDS.has(id)


## The rifle in the equipment slot: the chosen one if still carried, else the first carried.
func rifle_id() -> String:
	return _equipped_rifle(counts)


func _equipped_rifle(cnt: Dictionary) -> String:
	if active_rifle != "" and int(cnt.get(active_rifle, 0)) > 0: return active_rifle
	for r: String in RIFLE_IDS:
		if int(cnt.get(r, 0)) > 0: return r
	return ""


## Rounds ready in the equipped rifle (never more than the loose "ammo" actually carried).
func rifle_loaded() -> int:
	var r := rifle_id()
	return mini(int(loaded.get(r, 0)), count("ammo")) if r != "" else 0


func set_loaded(n: int) -> void:
	var r := rifle_id()
	if r != "": loaded[r] = clampi(n, 0, RifleDB.mag(r))


## Old saves / tests stored the single "rifle" item.
func migrate_legacy() -> void:
	if counts.has("rifle"):
		var n := int(counts["rifle"]); counts.erase("rifle")
		counts[DEFAULT_RIFLE] = int(counts.get(DEFAULT_RIFLE, 0)) + n
		if not loaded.has(DEFAULT_RIFLE): loaded[DEFAULT_RIFLE] = RifleDB.mag(DEFAULT_RIFLE)


func add_aged(id:String,n:int,seconds:float) -> void:
	if n<=0:return
	var had:=count(id);var prior:=float(age.get(id,0))
	add(id,n)
	if shelf_s(id)>0:age[id]=(prior*had+maxf(0,seconds)*n)/float(had+n)

func add(id: String, n: int = 1) -> void:
	if n<=0:return
	if id == "rifle": id = DEFAULT_RIFLE
	if is_rifle(id) and not loaded.has(id): loaded[id] = RifleDB.mag(id)   # found rifles come loaded
	if shelf_s(id) > 0.0:
		var old := count(id)
		age[id] = float(age.get(id, 0.0)) * float(old) / float(old + n)   # new items are fresh: stack age averages down
	counts[id] = count(id) + n


func remove(id: String, n: int = 1) -> bool:
	if infinite and INFINITE_IDS.has(id):
		return true
	if id == "rifle":
		id = rifle_id()
		if id == "": return false
	if count(id) < n:
		return false
	counts[id] = count(id) - n
	if counts[id] <= 0:
		counts.erase(id)
		cond.erase(id)
		if is_rifle(id):
			loaded.erase(id)
			if active_rifle == id: active_rifle = ""
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
		return "No ordinary wound infection to treat; outbreak risk cannot be removed" if injury.outbreak_exposed else "You feel no sign of infection"
	remove(id)
	return "Ordinary wound infection cleared; outbreak risk remains" if injury.outbreak_exposed else "Took the antibiotics: infection cleared"


## Pot food extras (N3): water, a hot-drink warmth window, condition, reishi's cure.
func _food_effects(id: String) -> String:
	var it: Dictionary = ITEMS[id]; var out := ""
	if it.has("water") and needs != null:
		needs.drink(float(it.water)); out += ", +%.2f L water" % (float(it.water) / 50.0)
	if it.has("hot_min") and body != null:
		body.hot_s = maxf(body.hot_s, float(it.hot_min) * 60.0); out += ", warming you"
	if it.has("heal") and injury != null and injury.player != null:
		injury.player.health = minf(100.0, float(injury.player.health) + float(it.heal))
	if String(it.get("cure", "")) == "reishi" and injury != null:
		out += ". " + injury.reishi()
	return out


## Toggle equip/unequip. Returns a short status message.
static var injury: Injury   # set by the world; medical items act on it


func use(id: String) -> String:
	if is_rifle(id):
		if count(id) < 1: return ""
		active_rifle = id
		return "Slung the " + name_of(id)
	if id=="clean_water":
		if needs==null or count(id)<1:return "No drinking water"
		if needs.water>=100:return "Already hydrated"
		# Reserve space for the retained container before mutating either pool.
		remove(id)
		if not can_add("empty_bottle"):
			add(id);return "Make room for the empty bottle first"
		add("empty_bottle");needs.drink(25);return "Drank 0.5 L; empty bottle retained"
	if id == "bandage" or id == "antiseptic" or id == "antibiotics":
		return _use_med(id)
	if ITEMS.has(id) and ITEMS[id].has("kcal") and needs != null:
		if ITEMS[id].get("raw",false):
			return "Cook %s at a lit stove before eating" % name_of(id)
		var k: float = ITEMS[id]["kcal"]
		if not remove(id):
			return 'None left'
		needs.eat(k)
		return "%s %s (+%d kcal)%s" % ["Drank" if id.begins_with("tea_") else "Ate", name_of(id), int(k), _food_effects(id)]
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
	var jd: Dictionary = _garment_data(extra["jacket"]) if extra.has("jacket") else {}
	var td: Dictionary = _garment_data(extra["top"]) if extra.has("top") else {}
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
			var e: Dictionary = _garment_data(extra[s])
			w += float(e["warmth"])
			wp += float(e["windproof"])
			wa += float(e["waterproof"])
	body.warmth = minf(w, WARM_CAP)
	body.windproof = minf(wp, PROOF_CAP)
	body.waterproof = minf(wa, PROOF_CAP)

func _garment_data(id:String)->Dictionary:
	var d:Dictionary=ITEMS[id].duplicate();var k:=lerpf(.35,1,condition(id))
	for prop:String in ["warmth","windproof","waterproof"]:d[prop]=float(d.get(prop,0))*k
	return d
func wear_clothing(gs:float,activity:int,precip:float)->void:
	if gs<=0 or infinite or activity==0:return
	var amount:=gs/3600*(.0045 if activity==1 else .008)*(1+clampf(precip,0,1))
	for id:String in worn_list():wear(id,amount)
