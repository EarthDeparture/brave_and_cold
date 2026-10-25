extends RefCounted
## Ground surfaces must also use physics layer 3 (mask 4).
## Keep buildings and actors off that layer so roofs cannot become spawn points.
const TERRAIN_MASK := 4
const RAY_REACH := 1024.0
const SPAWN_CLEARANCE := 0.02


static func project(context: Node3D, point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * RAY_REACH,
		point - Vector3.UP * RAY_REACH, TERRAIN_MASK)
	var hit := context.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	return point


static func place(body: CharacterBody3D) -> void:
	var point := project(body, body.global_position)
	body.global_position = point + Vector3.UP * SPAWN_CLEARANCE
	body.velocity.y = 0.0
