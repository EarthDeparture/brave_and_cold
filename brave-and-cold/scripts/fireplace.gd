extends StaticBody3D

signal lit_changed(lit: bool)

enum FireState { OUT, DYING, LIT }

@export var seconds_per_wood: float = 20.0
@export var heat_radius: float = 3.0
@export var warmth_per_second: float = 5.0
@export var dying_seconds: float = 5.0
@export var lit_light_radius: float = 6.0
@export var dying_light_radius: float = 3.0
@export var lit_noise_radius: float = 24.0
@export var dying_noise_radius: float = 8.0
@export var noise_interval: float = 1.0
var _noise_elapsed: float = 0.0
var fuel_remaining: float = 0.0
var _was_lit: bool = false


func is_lit() -> bool:
	return fuel_remaining > 0.0


func get_fire_state() -> FireState:
	if not is_lit():
		return FireState.OUT
	return FireState.DYING if fuel_remaining <= maxf(dying_seconds, 0.0) else FireState.LIT


func _emit_fire_noise() -> void:
	var state := get_fire_state()
	if state != FireState.OUT:
		NoiseEvents.emit_noise(global_position, dying_noise_radius if state == FireState.DYING else lit_noise_radius)


func _ready() -> void:
	_update_visuals()


func interact(player: Node) -> void:
	if seconds_per_wood > 0.0 and player.consume_wood():
		var previous_state := get_fire_state()
		fuel_remaining += seconds_per_wood
		if get_fire_state() != previous_state:
			_noise_elapsed = 0.0
			_emit_fire_noise()
		_update_visuals()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var burn_time := minf(maxf(delta, 0.0), fuel_remaining)
	if burn_time <= 0.0:
		return
	# Sample fuel at each pulse, including when a frame spans state boundaries.
	var remaining := burn_time
	var interval := maxf(noise_interval, 0.1)
	while remaining > 0.0:
		var step := minf(remaining, maxf(0.0, interval - _noise_elapsed))
		fuel_remaining = maxf(0.0, fuel_remaining - step)
		remaining = maxf(0.0, remaining - step)
		_noise_elapsed += step
		if _noise_elapsed >= interval:
			_noise_elapsed = 0.0
			_emit_fire_noise()
	if not is_lit():
		_noise_elapsed = 0.0
	for player in get_tree().get_nodes_in_group("players"):
		if global_position.distance_to(player.global_position) <= maxf(heat_radius, 0.0):
			Temperature.current_temperature += maxf(warmth_per_second, 0.0) * burn_time
			break
	_update_visuals()


func _update_visuals() -> void:
	var state := get_fire_state()
	var lit := state != FireState.OUT
	$Flame.visible = lit
	$Light.visible = lit
	$Light.omni_range = maxf(dying_light_radius if state == FireState.DYING else lit_light_radius, 0.0)
	$Light.light_energy = 1.0 if state == FireState.DYING else 2.5
	$Flame.scale = Vector3.ONE * (0.5 if state == FireState.DYING else 1.0)
	$Prompt.text = "E: Add wood | %s | %.0fs fuel" % ["Dying" if state == FireState.DYING else "Lit", fuel_remaining] if fuel_remaining > 0.0 else "E: Light fire (1 wood)"
	if lit != _was_lit:
		_was_lit = lit
		lit_changed.emit(lit)
