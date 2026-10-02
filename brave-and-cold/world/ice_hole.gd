class_name IceHole
extends Node3D
## A hole through the ice. perm = pre-cut beside an ice-camp hut (kept open); player-chopped holes freeze over after LIFE_S.

const LIFE_S := 12.0 * 3600.0

var perm := false
var born_s := 0.0
var spooked_until := 0.0


func setup(ice_y: float, p_perm: bool, now_s: float) -> void:
	perm = p_perm
	born_s = now_s
	position.y = ice_y
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.62
	rm.bottom_radius = 0.66
	rm.height = 0.05
	rm.radial_segments = 14
	rim.mesh = rm
	rim.position.y = 0.012
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.80, 0.86, 0.90)
	rmat.roughness = 0.5
	rim.material_override = rmat
	add_child(rim)
	var wat := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.40
	wm.bottom_radius = 0.40
	wm.height = 0.05
	wm.radial_segments = 14
	wat.mesh = wm
	wat.position.y = 0.022
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.015, 0.03, 0.05)
	wmat.roughness = 0.08
	wmat.metallic_specular = 0.9
	wat.material_override = wmat
	add_child(wat)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 31.0 + absf(position.z) * 17.0)
	for i in 5:
		var ch := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(0.08, 0.2)
		bm.size = Vector3(s, s * 0.6, s * 0.8)
		ch.mesh = bm
		var a := rng.randf() * TAU
		ch.position = Vector3(cos(a) * rng.randf_range(0.55, 0.85), 0.03, sin(a) * rng.randf_range(0.55, 0.85))
		ch.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		ch.material_override = rmat
		add_child(ch)


func expired(now_s: float) -> bool:
	return not perm and now_s - born_s > LIFE_S


func to_dict() -> Dictionary:
	return {"x": position.x, "z": position.z, "perm": perm, "born": born_s, "spooked": spooked_until}