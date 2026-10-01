class_name NoiseBus
extends RefCounted
## Sound events that AI perceives (zombies/animals). Radii in metres (GDD): walk 8, run 18, axe 45, gunshot 150.

signal noise(position: Vector3, radius: float, source: Object)

const RADIUS_CROUCH := 3.0
const RADIUS_WALK := 8.0
const RADIUS_RUN := 18.0
const RADIUS_AXE := 45.0
const RADIUS_GUNSHOT := 150.0

var listeners: Array = []        # zombies register here: one cheap loop instead of N signal callbacks
var last_radius: float = 0.0
var last_time_left: float = 0.0


func emit_noise(pos: Vector3, radius: float, source: Object = null) -> void:
	last_radius = radius
	last_time_left = 1.0
	var r2 := radius * radius
	for z in listeners:
		var zp: Vector3 = z.position
		var dx := zp.x - pos.x
		var dz := zp.z - pos.z
		var dy := zp.y - pos.y
		if dx * dx + dz * dz + dy * dy <= r2:
			z.on_noise(pos, radius, source)
	noise.emit(pos, radius, source)


func register(z: Object) -> void:
	if not listeners.has(z):
		listeners.append(z)


func unregister(z: Object) -> void:
	listeners.erase(z)
