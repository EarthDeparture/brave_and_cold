class_name WaterSurfaces
extends Node3D
## Frozen water surfaces (river + lake) from data/maps/<map>/water_mask.png + water_level.r16 (see tools/terrain/carve_water.py).
## One quad per STRIDE m cell where the mask is set, at the authored level; carved banks hide the edges.

const ICE_ALB := "res://assets/terrain/ice_alb.png"
const ICE_NRM := "res://assets/terrain/ice_nrm.png"
const STRIDE := 2


func build(map_dir: String = "res://data/maps/valley_b") -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/water.json"))
	var zmin: float = data["z_min_m"]
	var zmax: float = data["z_max_m"]
	var n: int = int(data["size_m"])
	var half := n / 2
	var mask := Image.load_from_file(ProjectSettings.globalize_path(map_dir + "/water_mask.png"))
	mask.convert(Image.FORMAT_L8)
	var f := FileAccess.open(map_dir + "/water_level.r16", FileAccess.READ)
	var buf := f.get_buffer(n * n * 2)
	f.close()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var quads := 0
	for y in range(0, n - STRIDE, STRIDE):
		for x in range(0, n - STRIDE, STRIDE):
			if mask.get_pixel(x, y).r < 0.5 and mask.get_pixel(x + STRIDE, y + STRIDE).r < 0.5 \
					and mask.get_pixel(x + STRIDE, y).r < 0.5 and mask.get_pixel(x, y + STRIDE).r < 0.5:
				continue
			var yy := _lvl(buf, x + 1, y + 1, n, zmin, zmax) - zmin
			var x0 := float(x - half)
			var z0 := float(y - half)
			var x1 := x0 + STRIDE
			var z1 := z0 + STRIDE
			st.add_vertex(Vector3(x0, yy, z0))
			st.add_vertex(Vector3(x0, yy, z1))
			st.add_vertex(Vector3(x1, yy, z0))
			st.add_vertex(Vector3(x1, yy, z0))
			st.add_vertex(Vector3(x0, yy, z1))
			st.add_vertex(Vector3(x1, yy, z1))
			quads += 1

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(ICE_ALB)
	mat.normal_enabled = true
	mat.normal_texture = load(ICE_NRM)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.04, 0.04, 0.04)
	mat.roughness = 0.22
	mat.metallic_specular = 0.7
	mat.albedo_color = Color(0.85, 0.95, 1.0)

	var mi := MeshInstance3D.new()
	mi.name = "FrozenWater"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	print("WATER_BUILT quads ", quads)


func _lvl(buf: PackedByteArray, x: int, y: int, n: int, zmin: float, zmax: float) -> float:
	var raw := buf.decode_u16((y * n + x) * 2)
	return zmin + float(raw) / 65535.0 * (zmax - zmin)
