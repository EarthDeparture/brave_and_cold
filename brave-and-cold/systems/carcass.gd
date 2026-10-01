class_name Carcass
extends RefCounted
## Species yield tables + multi-step butchery rules + zombie body loot. Pure data/logic (the world builds the actions).

const SPECIES := {
	"deer": {"label": "deer", "meat": "venison_raw", "meat_n": 6, "hide": "deer_hide", "hide_n": 1, "gut": "gut", "gut_n": 1, "fat": "", "fat_n": 0, "scale": 1.0},
	"wolf": {"label": "wolf", "meat": "wolf_meat_raw", "meat_n": 3, "hide": "wolf_pelt", "hide_n": 1, "gut": "gut", "gut_n": 1, "fat": "", "fat_n": 0, "scale": 0.6},
	"bear": {"label": "bear", "meat": "bear_meat_raw", "meat_n": 10, "hide": "bear_pelt", "hide_n": 1, "gut": "gut", "gut_n": 2, "fat": "fat", "fat_n": 3, "scale": 1.5},
}
const STEP_ORDER := ["meat", "hide", "gut", "fat"]
const STEP_VERB := {"meat": "Quarter", "hide": "Skin", "gut": "Gut", "fat": "Render fat from"}
const STEP_TIME := {"meat": 10.0, "hide": 8.0, "gut": 4.0, "fat": 4.0}


static func species_of(n: Node) -> String:
	if n is Deer:
		return "deer"
	if n is Wolf:
		return "bear" if (n as Wolf).part_prefix == "bear" else "wolf"
	return ""


## Steps this species still offers, minus the ones done.
static func open_steps(species: String, done: Dictionary) -> Array:
	var out: Array = []
	if not SPECIES.has(species):
		return out
	var d: Dictionary = SPECIES[species]
	for st in STEP_ORDER:
		if int(d.get(st + "_n", 0)) > 0 and not done.get(st, false):
			out.append(st)
	return out


## {id, n, time, ok, need}. Knife = full yield. Hatchet = meat only, half yield, double time. Hands = nothing.
static func step_info(species: String, step: String, has_knife: bool, has_axe: bool) -> Dictionary:
	var d: Dictionary = SPECIES[species]
	var id: String = String(d[step])
	var n: int = int(d[step + "_n"])
	var t: float = float(STEP_TIME[step]) * float(d["scale"])
	if has_knife:
		return {"id": id, "n": n, "time": t, "ok": true, "need": ""}
	if has_axe and step == "meat":
		return {"id": id, "n": maxi(1, int(ceil(float(n) * 0.5))), "time": t * 2.0, "ok": true, "need": ""}
	return {"id": id, "n": n, "time": t, "ok": false, "need": "knife"}


## Deterministic loot for a zombie body (seed from position). Returns {id: n}.
static func body_loot(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := {}
	if rng.randf() < 0.45:
		out["matches"] = rng.randi_range(1, 3)
	if rng.randf() < 0.25:
		out["beans"] = 1
	if rng.randf() < 0.2:
		out["ammo"] = rng.randi_range(2, 4)
	if rng.randf() < 0.06:
		out["knife"] = 1
	if rng.randf() < 0.1:
		out["sweater"] = 1
	return out


# ---- scent: fresh carcasses draw predators. Radius grows with age, longer downwind.
static var wind_dir := Vector2(0.8, 0.6)  # xz direction the wind blows toward (set by the world each frame)


static func age_s(n: Node) -> float:
	return (Time.get_ticks_msec() - int(n.get_meta("born", Time.get_ticks_msec()))) / 1000.0


static func scent_radius(age: float) -> float:
	return 25.0 + 75.0 * clampf(age / 600.0, 0.0, 1.0)


static func smelled_by(carcass: Node3D, listener: Vector3) -> bool:
	var to := Vector2(listener.x - carcass.global_position.x, listener.z - carcass.global_position.z)
	var d := to.length()
	var k := 1.0 + 0.6 * (to / maxf(d, 0.001)).dot(wind_dir)
	return d < scent_radius(age_s(carcass)) * k


static func has_meat(n: Node) -> bool:
	return not (n.get_meta("done", {}) as Dictionary).get("meat", false)


# ---- blood decals on the snow
static func blood(parent: Node, pos: Vector3, size: float) -> void:
	var tree := parent.get_tree()
	var all := tree.get_nodes_in_group("blood")
	if all.size() > 250:
		(all[0] as Node).queue_free()
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size * randf_range(0.7, 1.2))
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.02, 0.03)
	m.roughness = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("blood")
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.07, 0)
	mi.rotation = Vector3(-PI / 2.0, randf() * TAU, 0.0)
