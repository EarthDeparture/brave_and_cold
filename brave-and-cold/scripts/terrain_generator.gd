extends RefCounted
## Generates a heightmap-based ArrayMesh for the outdoor terrain.
## Tuned for Long Dark-style rolling tundra/mountain terrain: rocky
## highlands, carved valleys, and sparse flats near the cottage.
class_name TerrainGenerator

const DEFAULT_RESOLUTION := 512
const DEFAULT_SIZE := 1000.0
const DEFAULT_HEIGHT_SCALE := 60.0
const DEFAULT_SEED := 1

var resolution: int
var size: float
var height_scale: float
var noise_seed: int

var _base_noise: FastNoiseLite
var _ridge_noise: FastNoiseLite
var _detail_noise: FastNoiseLite


func _init(
	p_resolution: int = DEFAULT_RESOLUTION,
	p_size: float = DEFAULT_SIZE,
	p_height_scale: float = DEFAULT_HEIGHT_SCALE,
	p_seed: int = DEFAULT_SEED
) -> void:
	resolution = p_resolution
	size = p_size
	height_scale = p_height_scale
	noise_seed = p_seed
	_build_noise()


func _build_noise() -> void:
	# Broad rolling hills / valleys.
	_base_noise = FastNoiseLite.new()
	_base_noise.seed = noise_seed
	_base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base_noise.frequency = 0.0025
	_base_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_base_noise.fractal_octaves = 4
	_base_noise.fractal_lacunarity = 2.0
	_base_noise.fractal_gain = 0.5

	# Ridged noise for rocky highlands/mountain ridgelines.
	_ridge_noise = FastNoiseLite.new()
	_ridge_noise.seed = noise_seed + 1
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge_noise.frequency = 0.006
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 5
	_ridge_noise.fractal_lacunarity = 2.1
	_ridge_noise.fractal_gain = 0.55

	# Fine detail for surface roughness.
	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = noise_seed + 2
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.02
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 3


## Returns the world-space height at the given (x, z) world coordinates.
func get_height(world_x: float, world_z: float) -> float:
	var base := _base_noise.get_noise_2d(world_x, world_z)
	var ridge := _ridge_noise.get_noise_2d(world_x, world_z)
	var detail := _detail_noise.get_noise_2d(world_x, world_z)

	# Push flats near zero elevation and let ridges dominate the highlands
	# so valleys stay gentle while peaks rise sharply.
	var rolling := base * 0.5
	var mountains := max(ridge, 0.0)
	mountains = mountains * mountains
	var elevation := rolling + mountains * 0.85 + detail * 0.05

	return elevation * height_scale


## Builds a resolution x resolution heightmap sampled across a size x size
## world area centered on the origin.
func generate_heightmap() -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	var half := size * 0.5
	for row in range(resolution):
		var world_z := -half + (float(row) / float(resolution - 1)) * size
		for col in range(resolution):
			var world_x := -half + (float(col) / float(resolution - 1)) * size
			heights[row * resolution + col] = get_height(world_x, world_z)
	return heights


## Builds an ArrayMesh from a heightmap with per-vertex normals and UVs.
func generate_mesh(heights: PackedFloat32Array = PackedFloat32Array()) -> ArrayMesh:
	if heights.is_empty():
		heights = generate_heightmap()

	var vertex_count := resolution * resolution
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)

	var half := size * 0.5
	var step := size / float(resolution - 1)

	for row in range(resolution):
		var world_z := -half + float(row) * step
		for col in range(resolution):
			var world_x := -half + float(col) * step
			var index := row * resolution + col
			vertices[index] = Vector3(world_x, heights[index], world_z)
			uvs[index] = Vector2(float(col) / float(resolution - 1), float(row) / float(resolution - 1))

	_compute_normals(normals, heights, step)

	var indices := PackedInt32Array()
	indices.resize((resolution - 1) * (resolution - 1) * 6)
	var idx := 0
	for row in range(resolution - 1):
		for col in range(resolution - 1):
			var top_left := row * resolution + col
			var top_right := top_left + 1
			var bottom_left := top_left + resolution
			var bottom_right := bottom_left + 1

			indices[idx] = top_left
			indices[idx + 1] = bottom_left
			indices[idx + 2] = top_right
			indices[idx + 3] = top_right
			indices[idx + 4] = bottom_left
			indices[idx + 5] = bottom_right
			idx += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Computes smooth per-vertex normals from neighboring heightmap samples
## using central differences (avoids cross products across the full mesh).
func _compute_normals(
	normals: PackedVector3Array,
	heights: PackedFloat32Array,
	step: float
) -> void:
	for row in range(resolution):
		for col in range(resolution):
			var index := row * resolution + col

			var left := heights[index - 1] if col > 0 else heights[index]
			var right := heights[index + 1] if col < resolution - 1 else heights[index]
			var up := heights[index - resolution] if row > 0 else heights[index]
			var down := heights[index + resolution] if row < resolution - 1 else heights[index]

			var dx := (right - left) / (2.0 * step)
			var dz := (down - up) / (2.0 * step)

			normals[index] = Vector3(-dx, 1.0, -dz).normalized()
