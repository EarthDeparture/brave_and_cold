extends Node
## Shared stamina pool. Call drain() each frame while using stamina.

signal stamina_changed(current: float, maximum: float)
signal exhausted

@export var max_stamina: float = 100.0:
	set(value):
		max_stamina = maxf(value, 0.0)
		current_stamina = current_stamina
@export var current_stamina: float = 100.0:
	set(value):
		var previous := current_stamina
		var was_exhausted := is_exhausted
		current_stamina = clampf(value, 0.0, max_stamina)
		is_exhausted = current_stamina <= 0.0
		if current_stamina != previous:
			stamina_changed.emit(current_stamina, max_stamina)
		if is_exhausted and not was_exhausted:
			exhausted.emit()
@export var drain_rate: float = 20.0
@export var regen_rate: float = 10.0

var is_exhausted: bool = false
var _drained_since_process: bool = false


func _ready() -> void:
	current_stamina = current_stamina


func _process(delta: float) -> void:
	if not _drained_since_process:
		regain(maxf(regen_rate, 0.0) * delta)
	_drained_since_process = false


## With no argument, drains drain_rate per second using this frame's delta.
## Explicit amounts are immediate costs; negative amounts other than -1 are ignored.
func drain(amount: float = -1.0) -> void:
	if amount == -1.0:
		amount = maxf(drain_rate, 0.0) * get_process_delta_time()
	if amount <= 0.0:
		return
	_drained_since_process = true
	current_stamina -= amount


func regain(amount: float) -> void:
	current_stamina += maxf(amount, 0.0)


func can_use(amount: float) -> bool:
	return amount >= 0.0 and not is_exhausted and current_stamina >= amount
