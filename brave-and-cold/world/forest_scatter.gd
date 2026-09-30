class_name ForestScatter
extends Node3D
## Scatters conifers from the real lidar canopy-height mask (canopy.png: 8-bit, metres/40).
## Chunked MultiMeshes (CHUNK m) with visibility ranges so distant chunks are culled.

const CHUNK := 128
const SPACING := 5.0
const MIN_CANOPY_M := 6.0
const VIS_END := 700.0
const VARIANTS := ["spruce_a", "spruce_b", "spruce_c"]
const TREE_UNIT_M := 1.0  # source models are 1.0 high; scale = real canopy height

var terrain: Terrain3D
var map_dir := "res://data/maps/valley_b"
var tree_count := 0


func build(t: Terrain3D, seed_value: int = 1337) -> void:
	terrain = t
	var meta = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/meta.json"))
	var size_m: int = int(meta["size_m"])
	var half := size_m / 2
	var canopy := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/canopy.png"))
	var slope := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/slope.png"))
	canopy.convert(Image.FORMAT_L8)
	slope.convert(Image.FORMAT_L8)
	var water := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/water_mask.png"))
	water.convert(Image.FORMAT_L8)

	var meshes: Array[Mesh] = []
	for v in VARIANTS:
		meshes.append(_load_mesh("res://assets/models/trees/%s.glb" % v))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# chunk key -> per-variant transform arrays
	var buckets := {}
	var gx := int(size_m / SPACING)
	for iy in range(gx):
		for ix in range(gx):
			var px := int((ix + rng.randf()) * SPACING)
			var py := int((iy + rng.randf()) * SPACING)
			if px >= size_m or py >= size_m:
				continue
			var c_m: float = canopy.get_pixel(px, py).r * 255.0 / 255.0 * 40.0
			if c_m < MIN_CANOPY_M:
				continue
			if slope.get_pixel(px, py).r * 90.0 > 34.0:
				continue
			if _near_water(water, px, py):
				continue
			# density falls off in sparse canopy so edges break up naturally
			if rng.randf() > clampf((c_m - MIN_CANOPY_M) / 10.0 + 0.25, 0.0, 1.0):
				continue
			var wx := float(px - half) + 0.5
			var wz := float(py - half) + 0.5
			var h: float = terrain.data.get_height(Vector3(wx, 0, wz))
			if is_nan(h):
				continue
			var height_m := clampf(c_m * rng.randf_range(0.9, 1.1), 5.0, 26.0)
			var girth := height_m * rng.randf_range(0.9, 1.3)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(girth, height_m, girth))
			var key := Vector2i(int(floor((wx + half) / CHUNK)), int(floor((wz + half) / CHUNK)))
			var vi := rng.randi() % VARIANTS.size()
			if not buckets.has(key):
				buckets[key] = [[], [], []]
			buckets[key][vi].append(Transform3D(b, Vector3(wx, h - 0.15, wz)))
			tree_count += 1

	for key in buckets:
		var per_variant: Array = buckets[key]
		for vi in range(VARIANTS.size()):
			var xf: Array = per_variant[vi]
			if xf.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[vi]
			mm.instance_count = xf.size()
			for i in range(xf.size()):
				mm.set_instance_transform(i, xf[i])
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.material_override = mat
			inst.visibility_range_end = VIS_END
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(inst)
	print("FOREST_TREES ", tree_count, " chunks ", buckets.size())


func _load_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	var n := scene.instantiate()
	var found: Mesh = null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	n.queue_free()
	return found


func _near_water(w: Image, px: int, py: int) -> bool:
	for d in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		var x := clampi(px + d.x, 0, w.get_width() - 1)
		var y := clampi(py + d.y, 0, w.get_height() - 1)
		if w.get_pixel(x, y).r > 0.5:
			return true
	return false
