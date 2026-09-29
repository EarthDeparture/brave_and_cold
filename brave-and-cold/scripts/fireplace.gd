extends StaticBody3D

signal lit_changed(lit: bool)

@export var seconds_per_wood: float = 20.0
@export var heat_radius: float = 3.0
@export var warmth_per_second: float = 5.0
var fuel_remaining: float = 0.0
var _was_lit: bool = false


func is_lit() -> bool:
	return fuel_remaining > 0.0


func _ready() -> void:
	_update_visuals()


func interact(player: Node) -> void:
	if seconds_per_wood > 0.0 and player.consume_wood():
		fuel_remaining += seconds_per_wood
		_update_visuals()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var burn_time := minf(maxf(delta, 0.0), fuel_remaining)
	if burn_time <= 0.0:
		return
	fuel_remaining = maxf(0.0, fuel_remaining - burn_time)
	for player in get_tree().get_nodes_in_group("players"):
		if global_position.distance_to(player.global_position) <= maxf(heat_radius, 0.0):
			Temperature.current_temperature += maxf(warmth_per_second, 0.0) * burn_time
			break
	_update_visuals()


func _update_visuals() -> void:
	var lit := is_lit()
	$Flame.visible = lit
	$Light.visible = lit
	$Prompt.text = "E: Add wood | %.0fs fuel" % fuel_remaining if fuel_remaining > 0.0 else "E: Light fire (1 wood)"
	if lit != _was_lit:
		_was_lit = lit
		lit_changed.emit(lit)
