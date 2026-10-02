class_name HitZones
extends RefCounted
## Weapon hit detection. Ray vs a chain of body spheres per creature (padded: a click on the body must hit),
## plus world occlusion (terrain, tree trunks). The ray always starts at the CAMERA, never an offset guess.
## Spec rows: [zone, forward offset m, height m, radius m, damage multiplier].

const PAD := 0.06  # forgiveness added to every sphere radius

# Numbers come from the actual glb part bounds (models face -Z; zombie arms reach out at y~1.44).
const SPECS := {
	"deer": [["head", 0.85, 1.6, 0.27, 2.5], ["neck", 0.6, 1.45, 0.24, 1.5], ["chest", 0.1, 1.12, 0.46, 1.0], ["chest", 0.1, 0.85, 0.42, 1.0], ["hind", -0.4, 1.0, 0.42, 0.4], ["hind", -0.4, 0.78, 0.36, 0.4], ["legs", 0.0, 0.4, 0.26, 0.3]],
	"wolf": [["head", 0.75, 0.85, 0.22, 2.5], ["chest", 0.3, 0.75, 0.3, 1.0], ["chest", 0.3, 0.5, 0.27, 1.0], ["hind", -0.3, 0.7, 0.3, 0.6], ["hind", -0.3, 0.42, 0.27, 0.6], ["legs", 0.0, 0.25, 0.32, 0.4]],
	"bear": [["head", 1.25, 1.25, 0.38, 2.0], ["chest", 0.55, 1.05, 0.6, 1.0], ["chest", 0.55, 0.7, 0.52, 1.0], ["hind", -0.3, 1.0, 0.58, 0.7], ["hind", -0.3, 0.65, 0.52, 0.7], ["legs", 0.0, 0.3, 0.46, 0.4]],
	"zombie": [["head", 0.0, 1.76, 0.26, 2.5], ["chest", 0.0, 1.44, 0.34, 1.0], ["chest", 0.0, 1.12, 0.34, 1.0], ["chest", 0.0, 0.85, 0.3, 0.8], ["arm", 0.42, 1.44, 0.2, 0.5], ["legs", 0.0, 0.55, 0.28, 0.6], ["legs", 0.0, 0.2, 0.24, 0.6]],
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


## Creatures scale their model (zombie variants 0.94-1.15); the zones must follow.
static func scale_of(n: Node3D) -> float:
	var s := n.scale.x
	var m = n.get("_model")
	if m is Node3D:
		s *= (m as Node3D).scale.x
	return s


static func center_of(n: Node3D, row: Array) -> Vector3:
	var fwd := Vector3(-sin(n.rotation.y), 0.0, -cos(n.rotation.y))
	var s := scale_of(n)
	return n.global_position + fwd * float(row[1]) * s + Vector3(0.0, float(row[2]) * s, 0.0)


## Nearest zone hit by the ray, or {}. {t, mult, zone}. An origin inside a sphere counts as t = 0 (point blank).
static func ray(n: Node3D, eye: Vector3, dir: Vector3, max_t: float) -> Dictionary:
	var key := kind_of(n)
	if key == "":
		return {}
	var best := {}
	for row: Array in SPECS[key]:
		var c := center_of(n, row)
		var r := float(row[3]) * scale_of(n) + PAD
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
		if best.is_empty() or t < float(best["t"]) or (is_equal_approx(t, float(best["t"])) and float(row[4]) > float(best["mult"])):
			best = {"t": t, "mult": float(row[4]), "zone": String(row[0])}
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


## Full trace. Returns {} on nothing, {"world": true, "t": t} when ground/trunk ate the shot,
## or {"node", "zone", "mult", "t"} for a creature hit that is not occluded.
static func trace(tree: SceneTree, terrain: Terrain3D, forest, eye: Vector3, dir: Vector3, max_t: float, groups: Array = ["hostile", "prey"]) -> Dictionary:
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
	if wb < bt:
		return {"world": true, "t": wb}
	return best
