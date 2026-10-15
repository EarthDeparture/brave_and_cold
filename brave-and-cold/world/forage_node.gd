class_name ForageNode
extends Node3D
## N3 tea ingredients in the world (models from tools/blender/gen_forage.py):
##   rose   - wild rose canes in snow; pick the hips by hand (bush stays, hips vanish)
##   reishi - cut birch stump with bracket fungi; needs a knife
##   birch  - fallen white birch log; peel loose bark with a knife (log stays, solid)
## One harvest each per game (TLD). Positions are rebuilt from the seed, so only the
## harvested flags save.
const KINDS := {
	"rose": {"glb": "res://assets/forage/rose_bush.glb", "node": "rose_hips", "item": "rose_hips", "n": [2, 4], "hold": 2.0, "tool": "", "verb": "Pick rose hips", "solid": 0.0},
	"reishi": {"glb": "res://assets/forage/reishi_stump.glb", "node": "reishi_caps", "item": "reishi", "n": [1, 2], "hold": 3.0, "tool": "knife", "verb": "Cut reishi mushroom", "solid": 0.32},
	"birch": {"glb": "res://assets/forage/birch_log.glb", "node": "birch_bark", "item": "birch_bark", "n": [2, 4], "hold": 3.0, "tool": "knife", "verb": "Peel birch bark", "solid": 0.2},
}
var kind := ""
var harvested := false
var _yield_node: Node3D

func setup(p_kind: String, pos: Vector3, yaw: float) -> void:
	kind = p_kind; position = pos; rotation.y = yaw
	var spec: Dictionary = KINDS[kind]
	var model := (load(spec.glb) as PackedScene).instantiate() as Node3D; add_child(model)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.9
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat; mi.visibility_range_end = 90.0
		if kind == "rose": mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # thin canes: shadows cost more than they read
	_yield_node = model.find_child(String(spec.node), true, false) as Node3D
	if kind == "reishi" and _yield_node is MeshInstance3D:
		var gloss := mat.duplicate() as StandardMaterial3D; gloss.roughness = 0.35   # reishi's lacquered cap
		(_yield_node as MeshInstance3D).material_override = gloss
	set_harvested(harvested)

func set_harvested(v: bool) -> void:
	harvested = v
	if _yield_node != null: _yield_node.visible = not v

func spec() -> Dictionary: return KINDS[kind]

## Where the player aims to harvest.
func aim_point() -> Vector3:
	match kind:
		"rose": return to_global(Vector3(0, 0.55, 0))
		"reishi": return to_global(Vector3(0, 0.3, 0.3))
		_: return to_global(Vector3(0, 0.2, 0))

## player.spatial_structures contract: no walkable surface, no shelter, only a blocker.
func floor_at_world(_foot: Vector3, _terrain_h: float = NAN) -> float: return NAN
func is_sheltered_at(_eye: Vector3) -> bool: return false

## Player collision (GameWorld adds solid nodes to player.spatial_structures).
func resolve_at(candidate: Vector3, _previous: Vector3, radius: float) -> Vector2:
	var solid := float(spec().solid)
	var c2 := Vector2(candidate.x, candidate.z)
	if solid <= 0.0 or candidate.y > global_position.y + 0.6: return c2
	var l := to_local(Vector3(candidate.x, global_position.y, candidate.z))
	var near := Vector2(clampf(l.x, -1.1, 1.1) if kind == "birch" else 0.0, 0.0)
	var d := Vector2(l.x, l.z) - near; var need := solid + radius
	if d.length() >= need: return c2
	var out := near + (d.normalized() if d.length() > 0.0001 else Vector2(0, 1)) * need
	var g := to_global(Vector3(out.x, 0, out.y))
	return Vector2(g.x, g.z)
