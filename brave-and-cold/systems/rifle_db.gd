class_name RifleDB
extends RefCounted
## Per-rifle handling data (data/rifles.json). The eight ids match WeaponPresentation.IDS / the GLB art.

const PATH := "res://data/rifles.json"
const DEFAULT := "timber_bolt_carbine"
static var _data: Dictionary = {}


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(parsed is Dictionary, "rifles.json failed to parse")
	for k: String in parsed:
		if not k.begins_with("_"):
			_data[k] = parsed[k]


static func ids() -> Array:
	_load()
	return _data.keys()


static func spec(id: String) -> Dictionary:
	_load()
	return _data.get(id, _data.get(DEFAULT, {}))


static func mag(id: String) -> int:
	return int(spec(id).get("mag", 5))


static func value(id: String, key: String, fallback: float) -> float:
	return float(spec(id).get(key, fallback))


## Action type: bolt | semi | lever (drives the viewmodel cycle and the reload style).
static func action(id: String) -> String:
	var a := String(spec(id).get("action", ""))
	if a != "": return a
	return {"timber_bolt_carbine": "bolt", "brush_lever_rifle": "lever"}.get(id, "semi")


## Hip view the magnifications are measured against (Player.HIP_FOV, vertical degrees).
const HIP_FOV := 70.0
static var _zoom_cache: Dictionary = {}


const IRONS := {"type": "iron", "mag": [1.1], "reticle": "none", "label": "iron sights"}
const ATT_PATH := "res://data/attachments.json"
static var _att: Dictionary = {}
## The player's Inventory (GameWorld sets it): v3 rifles read their fitted attachments from it.
static var inv: Object = null


static func attachments() -> Dictionary:
	if _att.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ATT_PATH))
		assert(parsed is Dictionary, "attachments.json failed to parse")
		for k: String in parsed:
			if not k.begins_with("_"): _att[k] = parsed[k]
	return _att


static func attachment(aid: String) -> Dictionary:
	return attachments().get(aid, {})


## Weapon kit v3 rifle: modular art (assets/weapons/v3), sight from the fitted optic.
static func is_v3(id: String) -> bool:
	return bool(spec(id).get("v3", false))


const SLOTS := ["mount", "optic", "light", "muzzle"]   # fit order: an adapter mount carries the optic


## What a v3 rifle is found with: {mount, optic, light, muzzle, light_h (battery hours left)}.
static func factory(id: String) -> Dictionary:
	var f: Dictionary = spec(id).get("factory", {})
	var lid := String(f.get("light", ""))
	return {"mount": String(f.get("mount", "")), "optic": String(f.get("optic", "")), "light": lid, "muzzle": String(f.get("muzzle", "")),
			"light_h": float(attachment(lid).get("light", {}).get("battery_h", 0.0)) if lid != "" else 0.0}


## Current fit of a rifle id (shared by every rifle of that id; per-instance items are later work).
static func fitted(id: String) -> Dictionary:
	if not is_v3(id): return {}
	if inv != null and (inv.get("fitted") as Dictionary).has(id): return (inv.get("fitted") as Dictionary)[id]
	return factory(id)


## The rifle's mount for a slot, after adapters: a fitted clamp-on scout mount gives an optic mount.
static func mount_for(id: String, slot: String, f: Dictionary = {}) -> String:
	var mounts: Dictionary = spec(id).get("mounts", {})
	if slot == "optic":
		var fit := f if not f.is_empty() else fitted(id)
		var gives := String(attachment(String(fit.get("mount", ""))).get("gives", ""))
		if gives != "": return gives
	return String(mounts.get(slot, "none"))


## Can attachment `aid` go on rifle `id`? Its mount (string or list) must include the rifle's
## mount for that slot ("any" fits all). `f` = the fit to check against (default: current).
static func fits(id: String, aid: String, f: Dictionary = {}) -> bool:
	var a := attachment(aid)
	if a.is_empty() or not is_v3(id): return false
	var need = a.get("mount", "")
	var have := mount_for(id, String(a.get("kind", "")), f)
	if need is String:
		return need == "any" or (need == have and have != "none")
	return have != "none" and (need as Array).has(have)


## Why `aid` can't go on `id` (for the gunsmith screen), or "".
static func fit_reason(id: String, aid: String) -> String:
	if fits(id, aid): return ""
	var a := attachment(aid)
	var have := mount_for(id, String(a.get("kind", "")))
	match String(a.get("kind", "")):
		"optic": return "No scope mount on this rifle" if have == "none" else "Needs %s, this rifle has %s" % [_mount_words(a.get("mount", "")), _mount_words(have)]
		"muzzle": return "The barrel isn't threaded"
		"light": return "No room on this barrel for a clamp" if have == "none" else "Doesn't fit this barrel"
		"mount": return "Only fits a surplus barrel"
	return "Doesn't fit"


static func _mount_words(m) -> String:
	var words := {"rail": "a rail", "bases": "scope bases", "scout": "a scout rail", "barrel": "a barrel clamp", "thread": "a threaded muzzle", "none": "none"}
	if m is Array: return " or ".join((m as Array).map(func(x): return String(words.get(String(x), String(x)))))
	return String(words.get(String(m), String(m)))


## Fitted muzzle device stats ({} = bare muzzle): noise_mult, spread_mult.
static func muzzle(id: String) -> Dictionary:
	var a := attachment(String(fitted(id).get("muzzle", "")))
	if not a.has("muzzle"): return {}
	var m: Dictionary = (a["muzzle"] as Dictionary).duplicate()
	if bool(spec(id).get("rimfire", false)) and m.has("rimfire_noise_mult"): m["noise_mult"] = m["rimfire_noise_mult"]
	return m


## Signature of the fit (art rebuild + zoom cache key).
static func fit_sig(id: String) -> String:
	var f := fitted(id)
	return "%s|%s|%s|%s|%s" % [id, String(f.get("mount", "")), String(f.get("optic", "")), String(f.get("light", "")), String(f.get("muzzle", ""))]


static func optic(id: String) -> Dictionary:
	if is_v3(id):
		var oid := String(fitted(id).get("optic", ""))
		var a := attachment(oid)
		if a.has("optic"): return a["optic"]
		return spec(id).get("irons", IRONS)
	return spec(id).get("optic", {"type": "iron", "mag": [1.4], "reticle": "none", "label": "iron sights"})


## Fitted weapon light spec (+ "id"), or {} when none.
static func light(id: String) -> Dictionary:
	var lid := String(fitted(id).get("light", ""))
	var a := attachment(lid)
	if not a.has("light"): return {}
	var l: Dictionary = (a["light"] as Dictionary).duplicate()
	l["id"] = lid
	return l


## True magnification m -> vertical FOV: the image is m times larger than the hip view.
static func fov_for(m: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(HIP_FOV) * 0.5) / maxf(m, 1.0)))


## Fixed optics have one power; variable scopes step min -> geometric middle -> max.
static func magnifications(id: String) -> Array:
	var m: Array = optic(id).get("mag", [1.4])
	if m.size() >= 2: return [float(m[0]), sqrt(float(m[0]) * float(m[1])), float(m[1])]
	return [float(m[0])]


## Black-tube optic picture (model hidden) vs looking past the model (iron, reflex, red-dot
## tube: the v3 lens shader draws their collimated dot; a 1x tube is used with both eyes open).
## Legacy kit-v2 tube_dot rifles keep the old tube picture (their art has no clear lens).
static func is_scoped(id: String) -> bool:
	var t := String(optic(id).get("type", "iron"))
	return t == "scope" or (t == "tube_dot" and not is_v3(id))


## Aim FOV steps (mouse wheel), cached: called every frame by the viewmodel sync.
static func zoom(id: String) -> Array:
	var key := fit_sig(id) if is_v3(id) else id
	if not _zoom_cache.has(key): _zoom_cache[key] = magnifications(id).map(func(v) -> float: return fov_for(float(v)))
	return _zoom_cache[key]
