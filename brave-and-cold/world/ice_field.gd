class_name IceField
extends RefCounted
## Map planning uses authored water. activate_shoreline() switches rendering and
## walkers to the repaired connected basin. ice_at() = surface y, or NAN on land.

static var current: IceField   # the loaded map's ice, so creatures can stand ON it without being handed a reference
var mask: Image
var render_mask: Image
var buf: PackedByteArray
var n := 2048
var half := 1024
var span := 1.0
var map_dir := ""
var shoreline_active := false


func load_map(dir: String = "res://data/maps/valley_b") -> void:
	current = self
	map_dir = dir
	shoreline_active = false
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "/water.json"))
	span = float(data["z_max_m"]) - float(data["z_min_m"])
	n = int(data["size_m"])
	half = n / 2
	mask = MapIO.load_png(dir + "/water_mask.png")
	mask.convert(Image.FORMAT_L8)
	render_mask = mask
	var f := FileAccess.open(dir + "/water_level.r16", FileAccess.READ)
	buf = f.get_buffer(n * n * 2)
	f.close()


## Activate after deterministic map planning, keeping existing building sites.
func activate_shoreline() -> void:
	mask = MapIO.load_png(map_dir + "/ice_mask.png")
	mask.convert(Image.FORMAT_L8)
	render_mask = MapIO.load_png(map_dir + "/ice_render_mask.png")
	render_mask.convert(Image.FORMAT_L8)
	buf = FileAccess.get_file_as_bytes(map_dir + "/ice_level.r16")
	assert(buf.size() == n * n * 2, "Missing repaired ice surface data")
	shoreline_active = true


func level_at_pixel(x: int, y: int) -> float:
	x = clampi(x, 0, n - 1)
	y = clampi(y, 0, n - 1)
	return float(buf.decode_u16((y * n + x) * 2)) / 65535.0 * span


## Same 2 m triangles as the rendered top, with continuous sub-pixel support.
func surface_height(x: float, z: float) -> float:
	var px := x + half
	var pz := z + half
	var ix := floori(px / 2.0) * 2
	var iz := floori(pz / 2.0) * 2
	var u := (px - ix) * 0.5
	var v := (pz - iz) * 0.5
	var a := level_at_pixel(ix, iz)
	var b := level_at_pixel(ix + 2, iz)
	var c := level_at_pixel(ix + 2, iz + 2)
	var d := level_at_pixel(ix, iz + 2)
	return a + (b-a)*u + (c-b)*v if u >= v else a + (c-d)*u + (d-a)*v


func ice_at(x: float, z: float) -> float:
	var px := int(floorf(x)) + half
	var py := int(floorf(z)) + half
	if px < 0 or py < 0 or px >= n or py >= n:
		return NAN
	if mask.get_pixel(px, py).r < 0.5:
		return NAN
	return surface_height(x, z) if shoreline_active else level_at_pixel(px, py)


## Ground height for a walker: the terrain, or the ice sheet when that is higher (lake bed is far below the surface).
static func lift(h: float, x: float, z: float) -> float:
	if current == null or current.mask == null:
		return h
	var iy := current.ice_at(x, z)
	if not is_nan(iy) and (is_nan(h) or iy > h):
		return iy
	return h


## Metres from (x,z) to the nearest shore along 16 rays (capped): how far out on the ice a spot is.
func clearance(x: float, z: float, cap: float = 40.0) -> float:
	var best := cap
	for a in 16:
		var d := Vector2.from_angle(float(a) * TAU / 16.0)
		var r := 2.0
		while r < best:
			if is_nan(ice_at(x + d.x * r, z + d.y * r)):
				best = r
				break
			r += 2.0
	return best
