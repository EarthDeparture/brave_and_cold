class_name Frostbite
extends RefCounted
## N6 per-region cold injury (TLD). Head, hands and feet each build a frostbite risk 0..100
## while the wind-chilled air ("feels like") is colder than that region's gear can hold off:
##   need  = how much head/hand/foot protection this cold calls for (0 above -10 C, 0.15 at -40)
##   have  = the worn item's warmth + half its windproofing; wet boots lose most of theirs
##   risk rises with the shortfall (bare hands at -30 feels-like: about 3 game hours to 100)
## Shelter, a fire or a warm room bring risk back down. At 100 the region is frostbitten:
## permanent, it costs 6 condition and caps condition 6 lower (one per region). Game seconds.
const REGIONS := {"head": "head", "hands": "hands", "feet": "feet"}
const LABEL := {"head": "face and ears", "hands": "fingers", "feet": "toes"}
const FULL_NEED := 0.15
const RISE_H := 2.0          # hours from 0 to 100 at a full shortfall
const FALL_H := 1.5          # hours from 100 to 0 once warm
const CAP_LOSS := 6.0
var risk := {"head": 0.0, "hands": 0.0, "feet": 0.0}
var bitten := {"head": false, "hands": false, "feet": false}
var _warned := {"head": false, "hands": false, "feet": false}

static func need_at(feels_c: float) -> float:
	return clampf((-feels_c - 10.0) / 30.0, 0.0, 1.0) * FULL_NEED

## Protection the worn item in this region gives (wet boots lose 70%).
static func have(inv: Inventory, region: String, wetness: float) -> float:
	var id := String(inv.extra.get(REGIONS[region], "")) if inv != null else ""
	if id == "" or not Inventory.ITEMS.has(id): return 0.0
	var it: Dictionary = Inventory.ITEMS[id]
	var p := float(it.get("warmth", 0.0)) + 0.5 * float(it.get("windproof", 0.0))
	if region == "feet": p *= 1.0 - 0.7 * clampf(wetness, 0.0, 1.0) * (1.0 - float(it.get("waterproof", 0.0)))
	return p

## warm: indoors in a heated room, by a fire, or feels-like above -5 C.
## Returns messages for the player (warnings and new frostbite).
func advance(game_s: float, feels_c: float, warm: bool, inv: Inventory, wetness: float) -> Array:
	var out: Array = []
	var need := need_at(feels_c)
	for r: String in risk:
		var gap := 0.0 if warm else maxf(0.0, need - have(inv, r, wetness)) / FULL_NEED
		var before := float(risk[r])
		if gap > 0.0:
			risk[r] = minf(100.0, before + gap * 100.0 * game_s / (RISE_H * 3600.0))
		else:
			risk[r] = maxf(0.0, before - 100.0 * game_s / (FALL_H * 3600.0) * (1.0 if warm else 0.4))
		if float(risk[r]) >= 50.0 and not bool(_warned[r]) and not bool(bitten[r]):
			_warned[r] = true; out.append("Your %s are going numb. Get them covered or get warm" % LABEL[r] if r != "head" else "Your face and ears are going numb. Cover up or get warm")
		elif float(risk[r]) < 30.0:
			_warned[r] = false
		if float(risk[r]) >= 100.0 and not bool(bitten[r]):
			bitten[r] = true; risk[r] = 60.0
			out.append("FROSTBITE: %s. Permanent: -%d condition" % [LABEL[r], int(CAP_LOSS)])
	return out

func count() -> int:
	return bitten.values().filter(func(b: bool) -> bool: return b).size()

## Highest condition the body can recover to.
func max_condition() -> float: return 100.0 - CAP_LOSS * count()

func worst() -> String:
	var best := ""; var v := 0.0
	for r: String in risk:
		if float(risk[r]) > v: v = float(risk[r]); best = r
	return best

func to_dict() -> Dictionary: return {"risk": risk.duplicate(), "bitten": bitten.duplicate()}

func restore(d: Dictionary) -> void:
	for r: String in risk:
		risk[r] = clampf(float((d.get("risk", {}) as Dictionary).get(r, 0.0)), 0.0, 100.0)
		bitten[r] = bool((d.get("bitten", {}) as Dictionary).get(r, false))
