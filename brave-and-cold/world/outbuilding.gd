class_name Outbuilding
extends Node3D
## Solid, non-enterable props (woodshed, outhouse). Same collider API as Cabin/Hut so player, zombies and wolves bounce off the walls.
## Local frame: +Z is the front (open side of the woodshed / door of the outhouse).

const KINDS := {
	"woodshed": {"model": "res://assets/models/buildings/woodshed.glb", "hx": 1.75, "hz": 1.15},
	"outhouse": {"model": "res://assets/models/buildings/outhouse.glb", "hx": 0.65, "hz": 0.65},
}

var kind := "woodshed"
var hx := 1.75
var hz := 1.15
var floor_y := 0.0
var door_open := true
var door_boards := 0
var crate_looted := true
var wood_left := 0
var openings: Array[Opening] = []


## Footprint half-extents for planning without instancing.
static func half_extents(k: String) -> Vector2:
	var d: Dictionary = KINDS[k]
	return Vector2(float(d["hx"]), float(d["hz"]))


func setup(terrain: Terrain3D, k: String, x: float, z: float, yaw_deg: float) -> bool:
	kind = k
	var d: Dictionary = KINDS[k]
	hx = float(d["hx"])
	hz = float(d["hz"])
	var hmax := -1e9
	for cx in [-hx, 0.0, hx]:
		for cz in [-hz, 0.0, hz]:
			var p := Vector3(x, 0, z) + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(cx, 0, cz)
			var h: float = terrain.data.get_height(p)
			if is_nan(h):
				return false
			hmax = maxf(hmax, h)
	position = Vector3(x, hmax - 0.08, z)
	rotation_degrees = Vector3(0, yaw_deg, 0)
	floor_y = position.y
	wood_left = 5 if k == "woodshed" else 0
	var model := (load(String(d["model"])) as PackedScene).instantiate()
	add_child(model)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	return true


func noise_leak() -> float:
	return 1.0


func sight_line_open(_a: Vector3, _b: Vector3) -> bool:
	return true


func door_world_pos() -> Vector3:
	return to_global(Vector3(0.0, 0.0, hz + 0.8))


func bash_door(_dmg: float) -> void:
	pass


func to_local_xz(x: float, z: float) -> Vector2:
	var l := to_local(Vector3(x, position.y, z))
	return Vector2(l.x, l.z)


func contains_xz(_x: float, _z: float) -> bool:
	return false   # never "inside": no shelter, no muffling


func resolve(x: float, z: float, r: float) -> Vector2:
	var l := to_local_xz(x, z)
	var cx := clampf(l.x, -hx, hx)
	var cz := clampf(l.y, -hz, hz)
	var dv := l - Vector2(cx, cz)
	var dl := dv.length()
	if dl >= r:
		return Vector2(x, z)
	if dl > 0.0001:
		l = Vector2(cx, cz) + dv / dl * r
	else:
		# centre is inside the rect: push out through the nearest face
		var px := hx - absf(l.x)
		var pz := hz - absf(l.y)
		if px < pz:
			l.x = signf(l.x if l.x != 0.0 else 1.0) * (hx + r)
		else:
			l.y = signf(l.y if l.y != 0.0 else 1.0) * (hz + r)
	var wv := to_global(Vector3(l.x, 0.0, l.y))
	return Vector2(wv.x, wv.z)


func floor_at(_x: float, _z: float, _terrain_h: float) -> float:
	return NAN


## Spot at the open front of the woodshed where the cordwood stack is reachable.
func wood_world_pos() -> Vector3:
	return to_global(Vector3(0.0, 0.3, hz + 0.1))
