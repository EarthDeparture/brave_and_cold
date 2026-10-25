class_name Snare
extends Node3D
## A set wire snare (TLD). Every game hour it rolls a catch: up to 15%/h right at a
## rabbit warren, falling to a 2% stray chance 60 m away. A caught hare hangs in the loop
## until taken; each catch wears the snare 25% and it breaks at 0. Model: gen_rabbit.py.
const MODEL := "res://assets/smallgame/snare.glb"
const RABBIT := "res://assets/smallgame/rabbit.glb"
const ROLL_S := 3600.0
var caught := false
var condition := 1.0
var _acc := 0.0
var _rabbit: Node3D
var _rng := RandomNumberGenerator.new()

func setup(pos: Vector3, yaw: float, seed_value: int) -> void:
	position = pos; rotation.y = yaw; _rng.seed = seed_value
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.85
	var m := (load(MODEL) as PackedScene).instantiate() as Node3D; add_child(m)
	_rabbit = (load(RABBIT) as PackedScene).instantiate() as Node3D; add_child(_rabbit)
	_rabbit.rotation = Vector3(0, 0.4, PI / 2); _rabbit.position = Vector3(0.05, 0.08, 0.02)   # lying on its side in the loop
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat; mi.visibility_range_end = 80.0
	_rabbit.visible = false

## Odds per hour at this distance from the nearest warren.
static func hourly_chance(warren_dist: float) -> float:
	return 0.02 + 0.13 * clampf(1.0 - warren_dist / 60.0, 0.0, 1.0)

func advance(game_s: float, warren_dist: float) -> void:
	if caught or condition <= 0.0: return
	_acc += game_s
	while _acc >= ROLL_S and not caught:
		_acc -= ROLL_S
		if _rng.randf() < hourly_chance(warren_dist): set_caught(true)

func set_caught(v: bool) -> void:
	caught = v
	if _rabbit != null: _rabbit.visible = v

## Take the hare. Returns a message; inventory gets a "rabbit".
func take(inv: Inventory) -> String:
	if not caught: return "Nothing in the snare yet"
	inv.add("rabbit"); set_caught(false); condition -= 0.25
	if condition <= 0.0: return "Took a rabbit. The snare is worn through"
	return "Took a rabbit and reset the snare (%d%%)" % int(condition * 100.0)

func point() -> Vector3: return to_global(Vector3(0, 0.2, 0))

func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "z": position.z, "yaw": rotation.y, "caught": caught, "cond": condition, "acc": _acc}
