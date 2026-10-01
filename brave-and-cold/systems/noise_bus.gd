class_name NoiseBus
extends RefCounted
## Sound events that AI perceives (zombies/animals). Radii in metres (GDD): walk 8, run 18, axe 45, gunshot 150.

signal noise(position: Vector3, radius: float, source: Object)

const RADIUS_CROUCH := 3.0
const RADIUS_WALK := 8.0
const RADIUS_RUN := 18.0
const RADIUS_AXE := 45.0
const RADIUS_GUNSHOT := 150.0

var buildings: Array = []        # cabins/huts: walls muffle sound made inside them
var listeners: Array = []        # zombies register here: one cheap loop instead of N signal callbacks
var last_radius: float = 0.0
var last_time_left: float = 0.0


func emit_noise(pos: Vector3, radius: float, source: Object = null) -> void:
	last_radius = radius
	last_time_left = 1.0
	var r2 := radius * radius
	var bld = null
	var leak2 := 1.0
	for b in buildings:
		if b.contains_xz(pos.x, pos.z):
			bld = b
			var lk: float = b.noise_leak()
			leak2 = lk * lk
			break
	for z in listeners:
		var zp: Vector3 = z.position
		var dx := zp.x - pos.x
		var dz := zp.z - pos.z
		var dy := zp.y - pos.y
		var d2 := dx * dx + dz * dz + dy * dy
		if d2 > r2:
			continue
		if bld != null and leak2 < 1.0 and d2 > r2 * leak2 and not bld.contains_xz(zp.x, zp.z):
			continue  # muffled by walls: outsiders only hear the leaked radius
		z.on_noise(pos, radius, source)
	noise.emit(pos, radius, source)


func register(z: Object) -> void:
	if not listeners.has(z):
		listeners.append(z)


func unregister(z: Object) -> void:
	listeners.erase(z)


## Light cue (lit windows at night): weak lure, idle zombies come and look.
func emit_light(pos: Vector3, radius: float, source: Object = null) -> void:
	var r2 := radius * radius
	for z in listeners:
		var zp: Vector3 = z.position
		var dx := zp.x - pos.x
		var dz := zp.z - pos.z
		if dx * dx + dz * dz <= r2:
			z.on_light(pos, radius, source)
