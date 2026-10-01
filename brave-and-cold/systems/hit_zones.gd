class_name HitZones
extends RefCounted
## Ray vs 3 spheres per creature. Spec rows: [zone, forward offset m, height m, radius m, damage multiplier].

const SPECS := {
	"deer": [["head", 1.0, 1.45, 0.24, 2.5], ["chest", 0.2, 1.05, 0.42, 1.0], ["hind", -0.65, 0.95, 0.40, 0.35]],
	"wolf": [["head", 0.65, 0.8, 0.2, 2.5], ["chest", 0.15, 0.65, 0.3, 1.0], ["hind", -0.45, 0.6, 0.28, 0.6]],
	"bear": [["head", 0.9, 1.2, 0.32, 2.0], ["chest", 0.2, 1.0, 0.55, 1.0], ["hind", -0.7, 0.9, 0.5, 0.7]],
	"zombie": [["head", 0.0, 1.65, 0.22, 2.5], ["chest", 0.0, 1.2, 0.36, 1.0], ["legs", 0.0, 0.6, 0.3, 0.6]],
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


static func center_of(n: Node3D, row: Array) -> Vector3:
	var fwd := Vector3(-sin(n.rotation.y), 0.0, -cos(n.rotation.y))
	return n.global_position + fwd * float(row[1]) + Vector3(0.0, float(row[2]), 0.0)


## Nearest zone hit by the ray, or {}. {t, mult, zone}
static func ray(n: Node3D, eye: Vector3, dir: Vector3, max_t: float) -> Dictionary:
	var key := kind_of(n)
	if key == "":
		return {}
	var best := {}
	for row: Array in SPECS[key]:
		var c := center_of(n, row)
		var r := float(row[3])
		var oc := eye - c
		var b := oc.dot(dir)
		var disc := b * b - (oc.dot(oc) - r * r)
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t < 0.0:
			t = -b + sqrt(disc)
		if t < 0.0 or t > max_t:
			continue
		if best.is_empty() or t < float(best["t"]):
			best = {"t": t, "mult": float(row[4]), "zone": String(row[0])}
	return best
