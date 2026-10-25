extends StaticBody3D
## Generates a single heightmap-driven ground mesh with matching collision.
## Standard tier: one chunk, no streaming. Resolution/size are exported so a
## future LOD/chunking pass can subdivide without changing the generation math.

@export var terrain_size: Vector2 = Vector2(100.0, 100.0)
## Vertices per side of the heightmap grid (also the HeightMapShape3D dimensions).
@export_range(2, 512) var resolution: int = 64
## Kept at 0 by default so gameplay (nav mesh, spawn points) stays on a flat
## plane; raise this once terrain height is actually wanted.
@export var height_scale: float = 0.0
@export var noise_frequency: float = 0.03
@export var noise_seed: int = 0

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var heights: PackedFloat32Array


func _ready() -> void:
	regenerate()


func regenerate() -> void:
	heights = _build_heightmap()
	_mesh_instance.mesh = _build_mesh(heights)
	_collision_shape.shape = _build_collision_shape(heights)
	# HeightMapShape3D uses a fixed 1-unit grid spacing, so stretch the shape's
	# own transform to match the mesh's world-space cell size.
	var cell_size := Vector2(terrain_size.x, terrain_size.y) / float(resolution - 1)
	_collision_shape.scale = Vector3(cell_size.x, 1.0, cell_size.y)


func height_at(x_index: int, z_index: int) -> float:
	return heights[z_index * resolution + x_index]


func _build_heightmap() -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	var data := PackedFloat32Array()
	data.resize(resolution * resolution)
	for z in range(resolution):
		for x in range(resolution):
			data[z * resolution + x] = noise.get_noise_2d(x, z) * height_scale
	return data


func _build_mesh(heightmap: PackedFloat32Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := terrain_size * 0.5
	var step := Vector2(terrain_size.x, terrain_size.y) / float(resolution - 1)
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var v00 := Vector3(x * step.x - half.x, heightmap[z * resolution + x], z * step.y - half.y)
			var v10 := Vector3((x + 1) * step.x - half.x, heightmap[z * resolution + x + 1], z * step.y - half.y)
			var v01 := Vector3(x * step.x - half.x, heightmap[(z + 1) * resolution + x], (z + 1) * step.y - half.y)
			var v11 := Vector3((x + 1) * step.x - half.x, heightmap[(z + 1) * resolution + x + 1], (z + 1) * step.y - half.y)
			surface.add_vertex(v00)
			surface.add_vertex(v01)
			surface.add_vertex(v10)
			surface.add_vertex(v10)
			surface.add_vertex(v01)
			surface.add_vertex(v11)
	surface.generate_normals()
	return surface.commit()


func _build_collision_shape(heightmap: PackedFloat32Array) -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = resolution
	shape.map_depth = resolution
	shape.map_data = heightmap
	return shape
