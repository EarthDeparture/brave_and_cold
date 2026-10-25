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


static func tool_step(species:String,step:String,inv:Inventory,chosen:String="") -> Dictionary:
	var knife:=inv.count("knife")>0 and inv.condition("knife")>=.01 and chosen in ["","knife"]
	var axe:=inv.count("axe")>0 and inv.condition("axe")>=.02 and chosen in ["","axe"]
	var info:=step_info(species,step,knife,axe)
	info.tool="knife" if knife else "axe";info.wear=.01 if knife else .02;return info

static func food_age(n:Node) -> float:return maxf(0,float(n.get_meta("food_age_s",0)))
static func advance_food(n:Node,game_s:float) -> void:
	n.set_meta("food_age_s",food_age(n)+maxf(0,game_s)*StorageChest.COLD_RATE)
	n.set_meta("scent_age_s",age_s(n)+maxf(0,game_s))

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
	return maxf(0,float(n.get_meta("scent_age_s",0)))


static func scent_radius(age: float) -> float:
	return 25.0 + 75.0 * clampf(age / (5.0*3600.0), 0.0, 1.0)


static func smelled_by(carcass: Node3D, listener: Vector3) -> bool:
	var to := Vector2(listener.x - carcass.global_position.x, listener.z - carcass.global_position.z)
	var d := to.length()
	var k := 1.0 + 0.6 * (to / maxf(d, 0.001)).dot(wind_dir)
	return d < scent_radius(age_s(carcass)) * k


## Meat portions ravens have pecked off (float meta, saved). The butcher's yield drops by the whole portions,
## never below one.
static func scavenged(n: Node) -> float:
	return maxf(0.0, float(n.get_meta("scavenged", 0.0)))


static func meat_left(n: Node, full: int) -> int:
	return maxi(1, full - int(floor(scavenged(n))))


static func has_meat(n: Node) -> bool:
	return not (n.get_meta("done", {}) as Dictionary).get("meat", false)


# ---- A6 carcass stages: what is left shows on the body
## Meat left (scavenged by wolves / ravens / you) darkens the body with a wet, dark-red overlay and spreads a blood
## ring on the snow under it; stripped (meat gone) the body is flattened and a rib cage shows; skinned too, only the
## bones are left. Cheap: re-applied only when the fraction changes.
static func meat_frac(n: Node) -> float:
	var sp := species_of(n)
	if not SPECIES.has(sp): return 1.0
	if not has_meat(n): return 0.0
	return clampf(1.0 - scavenged(n) / float(SPECIES[sp].meat_n), 0.0, 1.0)


static func update_stage(n: Node3D) -> void:
	if n == null or not is_instance_valid(n): return
	var sp := species_of(n)
	if not SPECIES.has(sp): return
	var frac := meat_frac(n)
	var skinned := bool((n.get_meta("done", {}) as Dictionary).get("hide", false))
	var key := frac + (10.0 if skinned else 0.0)
	if absf(key - float(n.get_meta("stage_key", -1.0))) < 0.01: return
	n.set_meta("stage_key", key)
	var sc := float(SPECIES[sp].scale)
	var ov: StandardMaterial3D = n.get_meta("stage_mat") if n.has_meta("stage_mat") else null
	if ov == null:
		ov = StandardMaterial3D.new()
		ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ov.albedo_color = Color(0.2, 0.018, 0.015, 0.0)
		ov.roughness = 0.35   # wet
		n.set_meta("stage_mat", ov)
	ov.albedo_color.a = (1.0 - frac) * 0.85   # torn open: dark raw meat and soaked fur (0.6 didn't read at range)
	var helpers := ["StageRing", "StageRibs"]
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var skip := false
		for h in helpers:
			if mi.name == h or (mi.get_parent() != null and mi.get_parent().name == h): skip = true
		if skip: continue
		# the body's own (vertex-colour) material, made unique to this carcass, tinted toward dark raw red: the
		# overlay pass didn't read on these models
		var m3 := mi as MeshInstance3D
		var own = m3.get_meta("stage_own") if m3.has_meta("stage_own") else null
		if own == null and m3.material_override is StandardMaterial3D:
			own = (m3.material_override as StandardMaterial3D).duplicate()
			m3.material_override = own
			m3.set_meta("stage_own", own)
			m3.set_meta("stage_base", (own as StandardMaterial3D).albedo_color)
		elif own == null and m3.material_override is ShaderMaterial:   # X3 animal fur: tint + wet uniforms
			own = (m3.material_override as ShaderMaterial).duplicate()
			m3.material_override = own
			m3.set_meta("stage_own", own)
			var t0 = (own as ShaderMaterial).get_shader_parameter("tint")
			m3.set_meta("stage_base", t0 if t0 is Color else Color.WHITE)
		if own != null:
			var base: Color = m3.get_meta("stage_base", Color.WHITE)
			var tc := base.lerp(Color(0.40, 0.07, 0.06), (1.0 - frac) * 0.8)
			if own is StandardMaterial3D:
				(own as StandardMaterial3D).albedo_color = tc
				(own as StandardMaterial3D).roughness = lerpf(1.0, 0.45, 1.0 - frac)   # wet
			else:
				(own as ShaderMaterial).set_shader_parameter("tint", tc)
				(own as ShaderMaterial).set_shader_parameter("wet", 1.0 - frac)
		else:
			m3.material_overlay = ov
	# blood ring under the body (top level: dead wolves lie rolled on their side)
	var ring: Decal = n.get_node_or_null("StageRing")
	if ring == null:
		ring = Decal.new(); ring.name = "StageRing"; ring.top_level = true
		ring.texture_albedo = AnimalTracks._make_blood(int(n.get_instance_id() % 4))
		ring.upper_fade = 0.3; ring.lower_fade = 0.3
		n.add_child(ring)
		ring.global_position = n.global_position
		ring.global_rotation = Vector3(0, float(n.get_instance_id() % 628) * 0.01, 0)
	var rs := sc * (1.2 + 1.8 * (1.0 - frac))
	ring.size = Vector3(rs, 2.0, rs * 0.8)
	ring.modulate.a = 0.35 + 0.55 * (1.0 - frac)
	if frac <= 0.0 and not n.has_meta("stripped"):
		n.set_meta("stripped", true)
		for ch in n.get_children():
			if ch is Node3D and not (ch is Decal) and not (String(ch.name) in helpers):
				(ch as Node3D).scale *= Vector3(1.0, 0.6, 1.0)
		var ribs := MeshInstance3D.new(); ribs.name = "StageRibs"; ribs.top_level = true
		ribs.mesh = rib_cage(sc)
		var bm := StandardMaterial3D.new(); bm.vertex_color_use_as_albedo = true; bm.roughness = 0.55
		ribs.material_override = bm
		n.add_child(ribs)
		# lie on the slope, not flat in the air over it
		var gp := n.global_position
		var par := n.get_parent()
		var nrm := Vector3.UP
		if par != null and par.has_method("_ground_y"):
			var hx0: float = par.call("_ground_y", gp.x - 0.8, gp.z); var hx1: float = par.call("_ground_y", gp.x + 0.8, gp.z)
			var hz0: float = par.call("_ground_y", gp.x, gp.z - 0.8); var hz1: float = par.call("_ground_y", gp.x, gp.z + 0.8)
			nrm = Vector3(-(hx1 - hx0) / 1.6, 1.0, -(hz1 - hz0) / 1.6).normalized()
			gp.y = par.call("_ground_y", gp.x, gp.z)
		var yaw := float(n.get_instance_id() % 628) * 0.01
		var fwd := Vector3(sin(yaw), 0, cos(yaw)).slide(nrm).normalized()
		ribs.global_transform = Transform3D(Basis(nrm.cross(fwd).normalized(), nrm, fwd).orthonormalized(), gp + nrm * 0.04 * sc)
	if frac <= 0.0 and skinned:   # meat and hide gone: only the bones
		for ch in n.get_children():
			if ch is Node3D and not (ch is Decal) and not (String(ch.name) in helpers): (ch as Node3D).visible = false


## A stripped rib cage: a spine along z, ribs arching up from it, bone stained dark red.
static func rib_cage(sc: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed = int(sc * 1000.0)
	var L := 0.95 * sc
	var bone := Color(0.66, 0.58, 0.49)
	var blood := Color(0.38, 0.06, 0.05)
	var tube := func(pts: Array, r: float) -> void:
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
			var d := (b - a).normalized()
			var u := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			var v := d.cross(u)
			for k in 6:
				var t0 := TAU * k / 6.0; var t1 := TAU * (k + 1) / 6.0
				var o0 := (u * cos(t0) + v * sin(t0)) * r; var o1 := (u * cos(t1) + v * sin(t1)) * r
				var c := bone.lerp(blood, clampf(rng.randf() * 1.3 - 0.2, 0.0, 1.0))
				for q in [a + o0, b + o0, b + o1, a + o0, b + o1, a + o1]:
					st.set_color(c); st.add_vertex(q)
	var spine: Array = []
	for i in 9: spine.append(Vector3(0, 0.03 * sc, -L * 0.5 + L * i / 8.0))
	tube.call(spine, 0.035 * sc)
	for j in 7:
		var z := -L * 0.32 + L * 0.64 * j / 6.0
		var rr := sc * (0.22 + 0.08 * sin(PI * j / 6.0))
		for side in [-1.0, 1.0]:
			var arc: Array = []
			for i in 8:
				var a := PI * (0.06 + 0.42 * i / 7.0)
				arc.append(Vector3(side * sin(a) * rr, 0.03 * sc + (1.0 - cos(a)) * rr * 0.9 * (0.75 if i > 5 else 1.0), z + 0.02 * sc * i))
			tube.call(arc, 0.014 * sc)
	st.generate_normals()
	return st.commit()


# ---- blood decals on the snow
static func blood(parent: Node, pos: Vector3, size: float) -> void:
	if AnimalTracks.instance != null and is_instance_valid(AnimalTracks.instance):   # splatter decals (L2)
		AnimalTracks.instance.blood(pos, size)
		return
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
