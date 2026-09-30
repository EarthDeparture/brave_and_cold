class_name WaterSurfaces
extends Node3D
## Builds frozen river + lake surfaces from data/maps/<map>/water.json (authored hydrology, see tools/terrain/carve_water.py).
## Surfaces sit at the authored water level; carved banks hide the edges.

const ICE_ALB := "res://assets/terrain/ice_alb.png"
const ICE_NRM := "res://assets/terrain/ice_nrm.png"


func build(map_dir: String = "res://data/maps/valley_b") -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/water.json"))
	var zmin: float = data["z_min_m"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(ICE_ALB)
	mat.normal_enabled = true
	mat.normal_texture = load(ICE_NRM)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.04, 0.04, 0.04)
	mat.roughness = 0.22
	mat.metallic_specular = 0.7
	mat.albedo_color = Color(0.85, 0.95, 1.0)

	add_child(_river_mesh(data["river"], zmin, mat))
	add_child(_lake_mesh(data["lake"], zmin, mat))
	print("WATER_BUILT")


func _river_mesh(river: Dictionary, zmin: float, mat: Material) -> MeshInstance3D:
	var pts: Array = river["points"]
	var half: float = float(river["width_m"]) * 0.5 + 3.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in range(pts.size()):
		var p: Array = pts[i]
		var c := Vector3(p[0], float(p[2]) - zmin, p[1])
		var nxt: Array = pts[min(i + 1, pts.size() - 1)]
		var prv: Array = pts[max(i - 1, 0)]
		var tangent := Vector3(float(nxt[0]) - float(prv[0]), 0.0, float(nxt[1]) - float(prv[1])).normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x)
		var l := c + side * half
		var r := c - side * half
		if i > 0:
			st.set_normal(Vector3.UP)
			st.add_vertex(prev_l)
			st.add_vertex(prev_r)
			st.add_vertex(l)
			st.add_vertex(l)
			st.add_vertex(prev_r)
			st.add_vertex(r)
		prev_l = l
		prev_r = r
	var mi := MeshInstance3D.new()
	mi.name = "RiverIce"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _lake_mesh(lake: Dictionary, zmin: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cx: float = lake["cx"]
	var cz: float = lake["cz"]
	var rx: float = float(lake["rx"]) * 1.06
	var rz: float = float(lake["rz"]) * 1.06
	var ang: float = lake["angle_rad"]
	var y: float = float(lake["level"]) - zmin
	var seg := 72
	var center := Vector3(cx, y, cz)
	st.set_normal(Vector3.UP)
	for i in range(seg):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		st.add_vertex(center)
		st.add_vertex(_ell(cx, cz, rx, rz, ang, a1, y))
		st.add_vertex(_ell(cx, cz, rx, rz, ang, a0, y))
	var mi := MeshInstance3D.new()
	mi.name = "LakeIce"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _ell(cx: float, cz: float, rx: float, rz: float, ang: float, a: float, y: float) -> Vector3:
	var u := cos(a) * rx
	var v := sin(a) * rz
	# inverse of the u,v rotation used in carve_water.py (u = dx cos + dy sin ; v = -dx sin + dy cos)
	var dx := u * cos(ang) - v * sin(ang)
	var dz := u * sin(ang) + v * cos(ang)
	return Vector3(cx + dx, y, cz + dz)
