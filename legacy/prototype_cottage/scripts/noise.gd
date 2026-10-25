extends Node
## Shared world-space noise events. Radius is measured in metres.
signal emitted(position: Vector3, radius: float)


func emit_noise(position: Vector3, radius: float) -> void:
	if radius > 0.0:
		emitted.emit(position, radius)
