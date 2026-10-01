class_name WoodLog
extends Node3D
## A felled trunk lying on the snow (splits into firewood + sticks), plus the static stump helper.

static var _log_mesh: Mesh
static var _stump_mesh: Mesh
static var _mat: StandardMaterial3D

var tx := 0.0
var tz := 0.0
var dir := Vector3(0, 0, -1)
var tree_h := 10.0
var tree_r := 0.3
var length := 4.0
var firewood := 3
var sticks := 3
var p0 := Vector3.ZERO
var p1 := Vector3.ZERO


static func _mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	var n := scene.instantiate()
	var found: Mesh = null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	n.queue_free()
	return found


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 1.0
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


static func make_stump(parent: Node, terrain: Terrain3D, x: float, z: float, r: float) -> MeshInstance3D:
	if _stump_mesh == null:
		_stump_mesh = _mesh("res://assets/models/props/stump.glb")
	var mi := MeshInstance3D.new()
	mi.mesh = _stump_mesh
	mi.material_override = material()
	var sr := r / 0.25
	mi.scale = Vector3(sr, clampf(sr, 0.8, 1.4), sr)
	var h: float = terrain.data.get_height(Vector3(x, 0, z))
	if is_nan(h):
		h = 0.0
	parent.add_child(mi)
	mi.position = Vector3(x, h - 0.05, z)
	return mi


func setup(terrain: Terrain3D, x: float, z: float, d: Vector3, h: float, r: float) -> void:
	tx = x
	tz = z
	dir = Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.001 else Vector3(0, 0, -1)
	tree_h = h
	tree_r = r
	length = clampf(h * 0.55, 3.0, 9.0)
	firewood = clampi(roundi(h / 2.2), 2, 8)
	sticks = 3
	var b := Vector3(x, 0, z)
	p0 = b + dir * 0.4
	p1 = b + dir * (0.4 + length)
	p0.y = _h(terrain, p0)
	p1.y = _h(terrain, p1)
	var ax := (p1 - p0).normalized()
	var side := ax.cross(Vector3.UP).normalized()
	var up := side.cross(ax)
	var sr := r / 0.25
	if _log_mesh == null:
		_log_mesh = _mesh("res://assets/models/props/log.glb")
	var mi := MeshInstance3D.new()
	mi.mesh = _log_mesh
	mi.material_override = material()
	add_child(mi)
	mi.global_transform = Transform3D(Basis(ax * length, up * sr, side * sr), (p0 + p1) * 0.5 + Vector3(0, -0.05, 0))
	add_to_group("logs")


static func _h(terrain: Terrain3D, p: Vector3) -> float:
	var h: float = terrain.data.get_height(p)
	return 0.0 if is_nan(h) else h


func center() -> Vector3:
	return (p0 + p1) * 0.5


## xz distance from a point to the log's axis segment.
func dist_to(p: Vector3) -> float:
	var a := Vector2(p0.x, p0.z)
	var b := Vector2(p1.x, p1.z)
	var q := Vector2(p.x, p.z)
	var ab := b - a
	var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return maxf(0.0, q.distance_to(a + ab * t) - tree_r)


func to_save() -> Dictionary:
	return {"x": tx, "z": tz, "dx": dir.x, "dz": dir.z, "h": tree_h, "r": tree_r}
