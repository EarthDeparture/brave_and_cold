class_name ZoneDebug
extends Node3D
## Dev view: draws every hit sphere (HitZones.spheres) of the creatures around the player, coloured by zone.
## Toggle in the dev menu. What you see is exactly what bullets collide with.

const MAX := 160
const COL := {"head": Color(1.0, 0.9, 0.1, 0.45), "chest": Color(1.0, 0.15, 0.1, 0.35), "arm": Color(1.0, 0.55, 0.1, 0.4), "legs": Color(0.2, 0.5, 1.0, 0.4), "hind": Color(0.7, 0.3, 1.0, 0.4), "neck": Color(0.2, 1.0, 0.4, 0.4)}

var player: Player
var _pool: Array[MeshInstance3D] = []


func _ready() -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	for i in MAX:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		mi.material_override = m
		add_child(mi)
		_pool.append(mi)


func _process(_dt: float) -> void:
	var used := 0
	if visible and player != null:
		for g in ["hostile", "prey"]:
			for c in get_tree().get_nodes_in_group(g):
				var n := c as Node3D
				if n == null or not is_instance_valid(n) or n.global_position.distance_to(player.position) > 45.0:
					continue
				for sp: Dictionary in HitZones.spheres(n):
					if used >= MAX:
						break
					var mi := _pool[used]
					used += 1
					mi.visible = true
					mi.global_transform = Transform3D(Basis().scaled(Vector3.ONE * float(sp["r"])), sp["c"])
					(mi.material_override as StandardMaterial3D).albedo_color = COL.get(String(sp["zone"]), Color(1, 1, 1, 0.4))
	for i in range(used, MAX):
		_pool[i].visible = false
