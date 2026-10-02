class_name HitZones
extends RefCounted
## Weapon hit detection. Ray vs a chain of body spheres per creature (padded: a click on the body must hit),
## plus world occlusion (terrain, tree trunks). The ray always starts at the CAMERA, never an offset guess.
## Spec rows: [zone, forward offset m, height m, radius m, damage multiplier].

const PAD := 0.06  # forgiveness added to every sphere radius
const OUT_H := 2.4  # outbuilding solid height

# Numbers come from the actual glb part bounds (models face -Z; zombie arms reach out at y~1.44).
const SPECS := {
	"deer": [["head", 0.85, 1.6, 0.27, 2.5], ["neck", 0.6, 1.45, 0.24, 1.5], ["chest", 0.1, 1.12, 0.46, 1.0], ["chest", 0.1, 0.85, 0.42, 1.0], ["hind", -0.4, 1.0, 0.42, 0.4], ["hind", -0.4, 0.78, 0.36, 0.4], ["legs", 0.0, 0.4, 0.26, 0.3]],
	"wolf": [["head", 0.75, 0.85, 0.22, 2.5], ["chest", 0.3, 0.75, 0.3, 1.0], ["chest", 0.3, 0.5, 0.27, 1.0], ["hind", -0.3, 0.7, 0.3, 0.6], ["hind", -0.3, 0.42, 0.27, 0.6], ["legs", 0.0, 0.25, 0.32, 0.4]],
	"bear": [["head", 1.25, 1.25, 0.38, 2.0], ["chest", 0.55, 1.05, 0.6, 1.0], ["chest", 0.55, 0.7, 0.52, 1.0], ["hind", -0.3, 1.0, 0.58, 0.7], ["hind", -0.3, 0.65, 0.52, 0.7], ["legs", 0.0, 0.3, 0.46, 0.4]],
	"zombie": [["head", 0.0, 1.76, 0.26, 2.5], ["chest", 0.0, 1.44, 0.34, 1.0], ["chest", 0.0, 1.12, 0.34, 1.0], ["chest", 0.0, 0.85, 0.3, 0.8]],
}

## Spheres glued to an animated limb node (they swing with it): [zone, limb node name, offset in limb space, radius m, multiplier].
## Offsets come from the glb part bounds (zombie arms are 0.72 m long pointing -Z from the shoulder, legs hang 1.0 m below the hip).
const LIMBS := {
	"zombie": [
		["arm", "zombie_arm_l", Vector3(0.0, -0.03, -0.40), 0.15, 0.5],
		["arm", "zombie_arm_r", Vector3(0.0, -0.03, -0.40), 0.15, 0.5],
		["legs", "zombie_leg_l", Vector3(0.0, -0.32, -0.03), 0.17, 0.6],
		["legs", "zombie_leg_l", Vector3(0.0, -0.78, -0.03), 0.16, 0.6],
		["legs", "zombie_leg_r", Vector3(0.0, -0.32, -0.03), 0.17, 0.6],
		["legs", "zombie_leg_r", Vector3(0.0, -0.78, -0.03), 0.16, 0.6],
	],
}


static func kind_of(n: Node) -> String:
	if n is Deer:
		return "deer"
	if n is Bear:
		return "bear"
	if n is Wolf:
		return "wolf"
	if n is Zombie:
		return "zombie"
	return ""


## Zones live in MODEL space, so they follow whatever the creature does to its model: variant scale (0.94-1.15),
## crawler tilt/drop, sleeper lying flat, window lean.
static func model_xf(n: Node3D) -> Transform3D:
	var m = n.get("_model")
	if m is Node3D and (m as Node3D).is_inside_tree():
		return (m as Node3D).global_transform
	return n.global_transform


static func scale_of(n: Node3D) -> float:
	return model_xf(n).basis.x.length()


static func center_of(n: Node3D, row: Array, xf: Transform3D = Transform3D.IDENTITY) -> Vector3:
	var t := xf if xf != Transform3D.IDENTITY else model_xf(n)
	return t * Vector3(0.0, float(row[2]), -float(row[1]))


static func _limb(n: Node3D, nm: String) -> Node3D:
	var cache: Dictionary = n.get_meta("_hz_limbs") if n.has_meta("_hz_limbs") else {}
	if not cache.has(nm):
		cache[nm] = n.find_child(nm, true, false)
		n.set_meta("_hz_limbs", cache)
	return cache[nm] as Node3D


## Every hit sphere of a creature right now: [{c, r, zone, mult}] (body rows in model space, limb rows on the limb nodes).
static func spheres(n: Node3D) -> Array:
	var out: Array = []
	var key := kind_of(n)
	if key == "":
		return out
	var xf := model_xf(n)
	var sc := xf.basis.x.length()
	for row: Array in SPECS[key]:
		out.append({"c": center_of(n, row, xf), "r": float(row[3]) * sc + PAD, "zone": String(row[0]), "mult": float(row[4])})
	for lrow: Array in LIMBS.get(key, []):
		var limb := _limb(n, String(lrow[1]))
		if limb == null or not limb.visible:
			continue
		var lx := limb.global_transform
		out.append({"c": lx * (lrow[2] as Vector3), "r": float(lrow[3]) * lx.basis.x.length() + PAD, "zone": String(lrow[0]), "mult": float(lrow[4])})
	return out


## Nearest zone hit by the ray, or {}. {t, mult, zone}. An origin inside a sphere counts as t = 0 (point blank).
static func ray(n: Node3D, eye: Vector3, dir: Vector3, max_t: float) -> Dictionary:
	var best := {}
	for sp: Dictionary in spheres(n):
		var c: Vector3 = sp["c"]
		var r: float = sp["r"]
		var oc := eye - c
		var b := oc.dot(dir)
		var disc := b * b - (oc.dot(oc) - r * r)
		if disc < 0.0:
			continue
		var sq := sqrt(disc)
		var t := -b - sq
		if t < 0.0:
			if -b + sq < 0.0:
				continue  # sphere fully behind
			t = 0.0
		if t > max_t:
			continue
		if best.is_empty() or t < float(best["t"]) or (is_equal_approx(t, float(best["t"])) and float(sp["mult"]) > float(best["mult"])):
			best = {"t": t, "mult": float(sp["mult"]), "zone": String(sp["zone"])}
	return best


## Distance along the ray to the first thing that blocks bullets (terrain, trunk), or INF.
static func world_block(terrain: Terrain3D, forest, eye: Vector3, dir: Vector3, max_t: float) -> float:
	if terrain != null:
		var t := 0.5
		var prev := 0.0
		while t <= max_t:
			var p := eye + dir * t
			var h: float = terrain.data.get_height(p)
			if not is_nan(h) and p.y < h:
				return (prev + t) * 0.5
			prev = t
			t += 0.5 if t < 40.0 else 1.5
	if forest != null:
		var step := 6.0
		var a := 0.0
		while a < max_t:
			var b := minf(a + step, max_t)
			var pa := eye + dir * a
			var pb := eye + dir * b
			if forest.trunks_on_segment(pa.x, pa.z, pb.x, pb.z) > 0 and minf(pa.y, pb.y) < _trunk_top(terrain, pa):
				return _bisect(forest, eye, dir, a, b)
			a = b
	return INF


static func _trunk_top(terrain: Terrain3D, p: Vector3) -> float:
	var h: float = terrain.data.get_height(p) if terrain != null else 0.0
	return (0.0 if is_nan(h) else h) + 9.0  # shots well above the ground pass over trunk-only cover


static func _bisect(forest, eye: Vector3, dir: Vector3, a: float, b: float) -> float:
	var lo := a
	var hi := b
	for i in 5:
		var mid := (lo + hi) * 0.5
		var pa := eye + dir * lo
		var pm := eye + dir * mid
		if forest.trunks_on_segment(pa.x, pa.z, pm.x, pm.z) > 0:
			hi = mid
		else:
			lo = mid
	return hi


## Walls stop bullets. Steps along the ray through every nearby building; a point inside a wall rect is blocked unless
## the ray goes through the open door gap or an uncovered window (same rule the zombies use for sight).
static func building_block(blds: Array, eye: Vector3, dir: Vector3, max_t: float) -> float:
	for b in blds:
		var bn := b as Node3D
		if bn == null or not is_instance_valid(bn):
			continue
		var to := bn.global_position - eye
		var mid := to.dot(dir)
		if (to - dir * clampf(mid, 0.0, max_t)).length() > 5.0:
			continue
		if bn is Outbuilding:
			var ob := bn as Outbuilding
			var tb := clampf(mid - 5.0, 0.0, max_t)
			var tb1 := clampf(mid + 5.0, 0.0, max_t)
			while tb <= tb1:
				var lb := bn.to_local(eye + dir * tb)
				if lb.y > -0.3 and lb.y < OUT_H and absf(lb.x) < ob.hx and absf(lb.z) < ob.hz:
					return tb
				tb += 0.07
			continue
		if bn.get("_walls") == null:
			continue
		var rects: Array = (bn.get("_walls") as Array).duplicate()
		if not bool(bn.get("door_open")):
			rects.append(bn.get("_door_rect"))
		var foot := Rect2()
		var first := true
		for wr in (bn.get("_walls") as Array):
			var gr := (wr as Rect2).grow(0.3)
			foot = gr if first else foot.merge(gr)
			first = false
		var roof_lo := 2.45 if bn is Cabin else (2.25 if bn is Hut else 2.35)
		var t := clampf(mid - 5.0, 0.0, max_t)
		var t1 := clampf(mid + 5.0, 0.0, max_t)
		while t <= t1:
			var p := eye + dir * t
			var l := bn.to_local(p)
			if l.y > roof_lo and l.y < roof_lo + 0.9 and foot.has_point(Vector2(l.x, l.z)):
				return t   # the roof is solid
			if l.y > 0.0 and l.y < 2.7:
				var l2 := Vector2(l.x, l.z)
				for w in rects:
					if (w as Rect2).has_point(l2):
						if not bn.call("sight_line_open", p - dir * 0.25, p + dir * 0.25):
							return t
						break
			t += 0.07
	return INF


## Full trace. Returns {} on nothing, {"world": true, "t": t} when ground/trunk ate the shot,
## or {"node", "zone", "mult", "t"} for a creature hit that is not occluded.
static func trace(tree: SceneTree, terrain: Terrain3D, forest, eye: Vector3, dir: Vector3, max_t: float, groups: Array = ["hostile", "prey"], blds: Array = []) -> Dictionary:
	var best := {}
	var bt := max_t
	for g in groups:
		for h in tree.get_nodes_in_group(g):
			var n := h as Node3D
			if n == null or not is_instance_valid(n):
				continue
			if n.has_method("is_dead") and n.call("is_dead"):
				continue
			var mid := n.global_position + Vector3(0, 1.0, 0)
			var to := mid - eye
			var along := to.dot(dir)
			if along < -2.0 or along > bt + 2.0:
				continue
			if (to - dir * along).length() > 3.0:
				continue
			var zr := ray(n, eye, dir, bt)
			if not zr.is_empty() and float(zr["t"]) <= bt:
				bt = float(zr["t"])
				best = {"node": n, "zone": zr["zone"], "mult": zr["mult"], "t": bt}
	var wb := world_block(terrain, forest, eye, dir, bt) if bt > 0.5 else INF
	if not blds.is_empty() and bt > 0.3:
		wb = minf(wb, building_block(blds, eye, dir, minf(bt, max_t)))
	if wb < bt:
		return {"world": true, "t": wb}
	return best
